package com.qi7bali.landchallengeonline;

import android.app.Activity;
import android.app.Application;
import android.app.UiAutomation;
import android.accessibilityservice.AccessibilityServiceInfo;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.pm.ActivityInfo;
import android.graphics.Bitmap;
import android.graphics.Color;
import android.media.MediaPlayer;
import android.os.SystemClock;
import android.test.InstrumentationTestCase;
import android.view.View;
import android.view.ViewGroup;
import android.view.accessibility.AccessibilityNodeInfo;
import android.view.accessibility.AccessibilityWindowInfo;
import android.widget.FrameLayout;
import android.widget.TextView;
import android.widget.VideoView;

import java.io.File;
import java.io.FileOutputStream;
import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicLong;
import java.util.concurrent.atomic.AtomicReference;

/** Runs the production animation without creating a queue entry or an account. */
@SuppressWarnings("deprecation")
public final class OpponentAnimationTest extends InstrumentationTestCase {
    private Activity host;
    private OpponentActivity opponent;
    private Context soundContext;
    private boolean originalSoundEnabled;
    private View[] verticalAnchors;
    private float[] restingVerticalCenters;

    public void testSearchAudioRespectsMutePauseAndCleanup() throws Exception {
        prepareOpponentFixture(false);
        checkOnMain(() -> assertNull("Muted search must not create a player", currentSound()));

        getInstrumentation().runOnMainSync(() -> {
            AppPrefs.setSoundEnabled(soundContext, true);
            invokeUnchecked("startSearchSound");
        });
        MediaPlayer firstLoop = assertSearchLoopPlaying();
        checkOnMain(this::pauseSearchFixture);
        checkOnMain(() -> assertNull("Pausing must release the search loop", currentSound()));
        assertPlayerReleased(firstLoop);

        checkOnMain(this::resumeSearchFixture);
        MediaPlayer resumedLoop = assertSearchLoopPlaying();
        assertNotSame("Resuming must create a fresh player", firstLoop, resumedLoop);
        checkOnMain(() -> {
            pauseSearchFixture();
            AppPrefs.setSoundEnabled(soundContext, false);
            resumeSearchFixture();
        });
        checkOnMain(() -> assertNull("Muted resume must not restart the search loop", currentSound()));
        assertPlayerReleased(resumedLoop);

        getInstrumentation().runOnMainSync(() -> {
            AppPrefs.setSoundEnabled(soundContext, true);
            invokeUnchecked("startSearchSound");
        });
        MediaPlayer finalLoop = assertSearchLoopPlaying();
        getInstrumentation().runOnMainSync(() -> invokeUnchecked("cleanupPendingRequest"));
        checkOnMain(() -> assertNull("Leaving search must release the loop", currentSound()));
        assertPlayerReleased(finalLoop);
    }

    public void testGameplayEntranceReleasesOverlayAfterFirstFrame() throws Exception {
        Context target = getInstrumentation().getTargetContext();
        host = getInstrumentation().startActivitySync(new Intent(target, PrivacyPolicyActivity.class)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
        dismissImmersiveHint();
        getInstrumentation().runOnMainSync(() -> {
            FrameLayout scene = new FrameLayout(host);
            scene.setBackgroundColor(Color.rgb(40, 10, 65));
            TextView label = new TextView(host);
            label.setText("الانتقال إلى اللعب");
            label.setTextColor(Color.WHITE);
            label.setTextSize(32);
            scene.addView(label);
            host.setContentView(scene);
        });
        getInstrumentation().waitForIdleSync();
        getInstrumentation().runOnMainSync(() -> MatchmakingGameTransition.capture(
                host.getWindow().getDecorView(), null));
        Activity source = host;
        host = getInstrumentation().startActivitySync(new Intent(target, GameActivity.class)
                .putExtra("mode", "campaign").putExtra("stageId", "stage_22")
                .putExtra("campaignId", "animation-check").putExtra("campaignBoard", true)
                .putExtra("boardTargetScore", 1400).putExtra("boardSoloPicks", 6)
                .putExtra("questionCount", 6).putExtra("targetScore", 1400)
                .putExtra("openSplitDoorsTransition", true)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
        getInstrumentation().runOnMainSync(source::finish);
        SystemClock.sleep(1600);
        checkOnMain(() -> {
            assertNull("Real gameplay must clear the entrance overlay",
                    host.getWindow().getDecorView().findViewWithTag("matchmaking-game-entrance"));
        });
        awaitBackgroundVideo();
        saveScreenshot("08-real-gameplay-after-wipe");
    }

    public void testSearchRevealAndForegroundHandoff() throws Exception {
        exerciseSearchReveal(true);
    }

    public void testSearchRevealKeepsPositionsAndStopsSearchAudio() throws Exception {
        exerciseSearchReveal(false);
    }

    private void exerciseSearchReveal(boolean verifyGameplay) throws Exception {
        Context target = prepareOpponentFixture(true);
        getInstrumentation().waitForIdleSync();
        SystemClock.sleep(500);
        saveScreenshot("01-search");
        MediaPlayer searchLoop = assertSearchLoopPlaying();

        float[] searchScale = new float[2];
        checkOnMain(() -> {
            searchScale[0] = opponent.imgSearchGlass.getScaleX();
            assertEquals(View.VISIBLE, opponent.btnCancel.getVisibility());
            assertEquals(View.INVISIBLE, opponent.imgSplitLeft.getVisibility());
        });
        boolean searchMoved = false;
        // Samples either side of a breathing peak can be identical; observe several frames.
        for (int sample = 0; sample < 8 && !searchMoved; sample++) {
            SystemClock.sleep(100);
            getInstrumentation().runOnMainSync(() -> searchScale[1] = opponent.imgSearchGlass.getScaleX());
            searchMoved = Math.abs(searchScale[0] - searchScale[1]) > 0.001f;
        }
        assertTrue("Search glass must animate", searchMoved);

        CountDownLatch finished = new CountDownLatch(1);
        AtomicLong startedAt = new AtomicLong();
        AtomicLong completedAt = new AtomicLong();
        AtomicReference<Throwable> callbackFailure = new AtomicReference<>();
        Runnable handoff = () -> {
            completedAt.set(SystemClock.uptimeMillis());
            try {
                assertEquals("The player must remain visible until handoff", 1f,
                        opponent.layoutArena.getAlpha(), 0.01f);
                assertEquals("The opponent card must remain visible", 1f,
                        opponent.cardOpponent.getAlpha(), 0.01f);
                assertFixedVerticalPositions();
                assertEquals("The panel must be closed before handoff", 0f,
                        opponent.imgSplitLeft.getTranslationX(), 1f);
                assertEquals(View.VISIBLE, opponent.imgPhoto2.getVisibility());
            } catch (Throwable failure) { callbackFailure.set(failure); }
            finished.countDown();
        };
        getInstrumentation().runOnMainSync(() -> {
            try {
                opponent.launchingGame = true;
                Method found = OpponentActivity.class.getDeclaredMethod(
                        "playOpponentFoundTransition", String.class, String.class,
                        int.class, int.class, boolean.class, Runnable.class);
                found.setAccessible(true);
                startedAt.set(SystemClock.uptimeMillis());
                found.invoke(opponent, "المنافس", "   ", 7, 100, false, handoff);
            } catch (Exception failure) { throw new RuntimeException(failure); }
        });
        checkOnMain(() -> {
            MediaPlayer foundSound = currentSound();
            assertNotSame("The found chime must replace the search loop", searchLoop, foundSound);
            if (foundSound != null) assertFalse("Found sound must not loop", foundSound.isLooping());
            assertFixedVerticalPositions();
        });
        assertPlayerReleased(searchLoop);
        SystemClock.sleep(100);
        checkOnMain(() -> {
            assertEquals("Opponent found state must be displayed",
                    "تم العثور على منافس!", opponent.txtStatus.getText().toString());
            assertEquals("The showdown should wait for the reveal",
                    View.INVISIBLE, opponent.imgSplitLeft.getVisibility());
        });
        saveScreenshot("02-found-glow");
        sleepUntil(startedAt.get() + 650);
        checkOnMain(this::assertFixedVerticalPositions);
        saveScreenshot("03-revealed-opponent");
        sleepUntil(startedAt.get() + 1200);
        checkOnMain(this::assertFixedVerticalPositions);
        saveScreenshot("04-versus-impact");
        sleepUntil(startedAt.get() + 2200);
        checkOnMain(this::assertFixedVerticalPositions);
        assertTrue("Opponent animation must hand off without hanging", finished.await(5, TimeUnit.SECONDS));
        if (callbackFailure.get() != null) throw new AssertionError(callbackFailure.get());
        assertTrue("Reveal must hold long enough before gameplay", completedAt.get() - startedAt.get() >= 2100);
        assertTrue("Handoff must remain bounded", completedAt.get() - startedAt.get() < 4500);
        saveScreenshot("05-retained-foreground");

        Field pending = MatchmakingGameTransition.class.getDeclaredField("pending");
        pending.setAccessible(true);
        Object snapshot = pending.get(null);
        assertNotNull("Handoff must retain the outgoing scene", snapshot);
        Field scene = snapshot.getClass().getDeclaredField("scene");
        scene.setAccessible(true);
        Bitmap retainedScene = (Bitmap) scene.get(snapshot);
        assertNotNull(retainedScene);
        assertFalse("Scene must survive the activity handoff", retainedScene.isRecycled());

        if (!verifyGameplay) {
            Method clearSnapshot = MatchmakingGameTransition.class.getDeclaredMethod("clearPending");
            clearSnapshot.setAccessible(true);
            getInstrumentation().runOnMainSync(() -> {
                try { clearSnapshot.invoke(null); }
                catch (Exception failure) { throw new RuntimeException(failure); }
            });
            assertTrue("The focused check must release its captured scene", retainedScene.isRecycled());
            return;
        }

        Activity source = host;
        host = getInstrumentation().startActivitySync(new Intent(target, GameActivity.class)
                .putExtra("mode", "campaign").putExtra("stageId", "stage_22")
                .putExtra("campaignId", "animation-check").putExtra("campaignBoard", true)
                .putExtra("boardTargetScore", 1400).putExtra("boardSoloPicks", 6)
                .putExtra("questionCount", 6).putExtra("targetScore", 1400)
                .putExtra("openSplitDoorsTransition", true)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
        getInstrumentation().runOnMainSync(source::finish);
        assertNull("A snapshot must be consumed only once", pending.get(null));
        SystemClock.sleep(100);
        saveScreenshot("06-gameplay-wipe");
        SystemClock.sleep(1600);
        checkOnMain(() -> {
            assertNull("Opening overlay must release touches after the wipe",
                    host.getWindow().getDecorView().findViewWithTag("matchmaking-game-entrance"));
        });
        awaitBackgroundVideo();
        assertTrue("Snapshot memory must be released after opening", retainedScene.isRecycled());
        saveScreenshot("07-gameplay-visible");
    }

    private Context prepareOpponentFixture(boolean soundEnabled) throws Exception {
        Context target = getInstrumentation().getTargetContext();
        soundContext = target;
        originalSoundEnabled = AppPrefs.isSoundEnabled(target);
        AppPrefs.setSoundEnabled(target, soundEnabled);
        Intent hostIntent = new Intent(target, PrivacyPolicyActivity.class)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        host = getInstrumentation().startActivitySync(hostIntent);
        getInstrumentation().waitForIdleSync();
        dismissImmersiveHint();

        ActivityInfo info = target.getPackageManager().getActivityInfo(
                new ComponentName(target, OpponentActivity.class), 0);
        getInstrumentation().runOnMainSync(() -> {
            try {
                // Attach a genuine OpponentActivity context, but deliberately do not
                // enter onCreate: that method owns matchmaking and Firebase writes.
                opponent = (OpponentActivity) getInstrumentation().newActivity(
                        OpponentActivity.class, target,
                        host.getWindow().getDecorView().getWindowToken(),
                        (Application) target.getApplicationContext(),
                        new Intent(target, OpponentActivity.class), info,
                        "Animation verification", host, "animation-verification", null);
                host.setContentView(R.layout.activity_opponent);
                for (Field field : OpponentActivity.class.getDeclaredFields()) {
                    if (!View.class.isAssignableFrom(field.getType())) continue;
                    int id = target.getResources().getIdentifier(
                            field.getName(), "id", target.getPackageName());
                    if (id == 0) continue;
                    field.setAccessible(true);
                    field.set(opponent, host.findViewById(id));
                }
                opponent.txtOpponent1.setText("أنت");
                opponent.txtLevel1.setText("50");
                opponent.imgPhoto1.setImageResource(R.drawable.opponent01);
                opponent.imgSplitLeft.setVisibility(View.INVISIBLE);
                opponent.imgSplitRight.setVisibility(View.INVISIBLE);
                setField("audioPaused", false);
                invoke("startStatusPulseAnimation");
                invoke("startMagnifyingGlassSearchAnimation");
                invoke("startBrowsingOpponents");
            } catch (Exception failure) { throw new RuntimeException(failure); }
        });
        getInstrumentation().waitForIdleSync();
        getInstrumentation().runOnMainSync(() -> {
            verticalAnchors = new View[]{opponent.layoutArena,
                    host.findViewById(R.id.layoutPlayerGroup),
                    host.findViewById(R.id.layoutOpponentGroup), opponent.vsBadgeView};
            restingVerticalCenters = new float[verticalAnchors.length];
            for (int index = 0; index < verticalAnchors.length; index++) {
                restingVerticalCenters[index] = pivotCenterY(verticalAnchors[index])
                        - verticalAnchors[index].getTranslationY();
            }
        });
        return target;
    }

    private MediaPlayer currentSound() {
        try {
            Field field = OpponentActivity.class.getDeclaredField("matchmakingSound");
            field.setAccessible(true);
            return (MediaPlayer) field.get(opponent);
        } catch (Exception failure) { throw new RuntimeException(failure); }
    }

    private void pauseSearchFixture() {
        try { opponent.onPause(); }
        catch (IllegalStateException failure) {
            // The production pause body executes before FragmentActivity. This
            // offline fixture never attaches a FragmentManager through onCreate.
            if (!"No activity".equals(failure.getMessage())) throw failure;
        }
        invokeUnchecked("startSearchSound");
    }

    private void resumeSearchFixture() {
        // Exercise the same shared sound entry point without entering the
        // detached FragmentActivity lifecycle or starting online matchmaking.
        try { setField("audioPaused", false); }
        catch (Exception failure) { throw new RuntimeException(failure); }
        invokeUnchecked("startSearchSound");
    }

    private MediaPlayer assertSearchLoopPlaying() {
        AtomicReference<MediaPlayer> loop = new AtomicReference<>();
        checkOnMain(() -> {
            MediaPlayer player = currentSound();
            assertNotNull("Searching must have its own sound", player);
            assertTrue("Search sound must repeat continuously", player.isLooping());
            assertTrue("Search sound must be playing", player.isPlaying());
            loop.set(player);
        });
        return loop.get();
    }

    private void assertPlayerReleased(MediaPlayer player) {
        try {
            player.isPlaying();
            fail("The previous media player must be released");
        } catch (IllegalStateException expected) {
            // Released native players reject calls rather than leaking a silent decoder.
        }
    }

    private void assertFixedVerticalPositions() {
        for (int index = 0; index < verticalAnchors.length; index++) {
            View view = verticalAnchors[index];
            assertEquals("Showdown must keep its vertical position: " + view.getId(),
                    0f, view.getTranslationY(), 0.01f);
            assertEquals("Player, opponent and VS centers must remain fixed: " + view.getId(),
                    restingVerticalCenters[index], pivotCenterY(view), 1.5f);
        }
    }

    private float pivotCenterY(View view) {
        int[] parentLocation = new int[2];
        ((View) view.getParent()).getLocationOnScreen(parentLocation);
        return parentLocation[1] + view.getTop() + view.getHeight() * 0.5f + view.getTranslationY();
    }

    private void invokeUnchecked(String name) {
        try { invoke(name); }
        catch (Exception failure) { throw new RuntimeException(failure); }
    }

    private void invoke(String name) throws Exception {
        Method method = OpponentActivity.class.getDeclaredMethod(name);
        method.setAccessible(true);
        method.invoke(opponent);
    }

    private void checkOnMain(Runnable assertion) {
        AtomicReference<Throwable> failure = new AtomicReference<>();
        getInstrumentation().runOnMainSync(() -> {
            try { assertion.run(); }
            catch (Throwable error) { failure.set(error); }
        });
        if (failure.get() instanceof AssertionError) throw (AssertionError) failure.get();
        if (failure.get() != null) throw new RuntimeException(failure.get());
    }

    private void awaitBackgroundVideo() {
        boolean[] playing = new boolean[1];
        long deadline = SystemClock.uptimeMillis() + 5000;
        do {
            getInstrumentation().runOnMainSync(() -> {
                VideoView video = host.findViewById(R.id.gameBackgroundVideo);
                playing[0] = video != null && video.isPlaying();
            });
            if (playing[0]) return;
            SystemClock.sleep(100);
        } while (SystemClock.uptimeMillis() < deadline);
        assertTrue("Gameplay background must become playable within five seconds", playing[0]);
    }

    private void setField(String name, Object value) throws Exception {
        Field field = OpponentActivity.class.getDeclaredField(name);
        field.setAccessible(true);
        field.set(opponent, value);
    }

    private static void sleepUntil(long deadline) {
        long remaining = deadline - SystemClock.uptimeMillis();
        if (remaining > 0) SystemClock.sleep(remaining);
    }

    private void saveScreenshot(String name) throws Exception {
        Bitmap screenshot = getInstrumentation().getUiAutomation().takeScreenshot();
        assertNotNull("Screenshot must be available", screenshot);
        File directory = new File(host.getExternalFilesDir(null), "opponent-search-audio-checks");
        assertTrue(directory.isDirectory() || directory.mkdirs());
        try (FileOutputStream output = new FileOutputStream(new File(directory, name + ".png"))) {
            screenshot.compress(Bitmap.CompressFormat.PNG, 100, output);
        } finally { screenshot.recycle(); }
    }

    private void dismissImmersiveHint() throws Exception {
        UiAutomation automation = getInstrumentation().getUiAutomation();
        AccessibilityServiceInfo service = automation.getServiceInfo();
        service.flags |= AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS;
        automation.setServiceInfo(service);
        // Android posts this hint after the first immersive window is drawn.
        for (int attempt = 0; attempt < 12; attempt++) {
            for (AccessibilityWindowInfo window : automation.getWindows()) {
                AccessibilityNodeInfo root = window.getRoot();
                if (root == null) continue;
                for (AccessibilityNodeInfo button : root.findAccessibilityNodeInfosByText("Got it")) {
                    if (button.performAction(AccessibilityNodeInfo.ACTION_CLICK)) {
                        automation.waitForIdle(150, 3000);
                        assertNoImmersiveHint(automation);
                        return;
                    }
                }
            }
            SystemClock.sleep(200);
        }
        assertNoImmersiveHint(automation);
    }

    private void assertNoImmersiveHint(UiAutomation automation) {
        for (AccessibilityWindowInfo window : automation.getWindows()) {
            AccessibilityNodeInfo root = window.getRoot();
            if (root != null) assertTrue("System immersive hint must not obscure animation verification",
                    root.findAccessibilityNodeInfosByText("Viewing full screen").isEmpty());
        }
    }

    @Override protected void tearDown() throws Exception {
        getInstrumentation().runOnMainSync(() -> {
            if (opponent != null) {
                try { invoke("cleanupPendingRequest"); }
                catch (Exception failure) { throw new RuntimeException(failure); }
            }
            if (soundContext != null) AppPrefs.setSoundEnabled(soundContext, originalSoundEnabled);
            if (host != null) host.finish();
        });
        super.tearDown();
    }
}
