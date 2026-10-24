package com.qi7bali.landchallengeonline;

import android.app.Activity;
import android.app.UiAutomation;
import android.accessibilityservice.AccessibilityServiceInfo;
import android.content.Intent;
import android.graphics.Bitmap;
import android.graphics.Rect;
import android.test.InstrumentationTestCase;
import android.view.View;
import android.view.ViewGroup;
import android.view.ViewTreeObserver;
import android.view.accessibility.AccessibilityNodeInfo;
import android.view.accessibility.AccessibilityWindowInfo;
import android.widget.TextView;

import androidx.core.graphics.Insets;
import androidx.core.view.ViewCompat;
import androidx.core.view.WindowInsetsCompat;

import java.io.File;
import java.io.FileOutputStream;
import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.util.concurrent.atomic.AtomicReference;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;

/** Exercises the real Android stage, SurfaceView and presenter together. */
@SuppressWarnings("deprecation")
public final class GameSceneLayoutTest extends InstrumentationTestCase {
    private Activity activity;
    private static final String MESSAGE = "نتابع من حيث توقفنا..\nأكمل هذه المرحلة!";

    public void testBackgroundAndBubbleWithLeftAndRightCutouts() throws Exception {
        exerciseScene(true);
    }

    public void testClassicHudWithLeftAndRightCutouts() throws Exception {
        exerciseScene(false);
    }

    private void exerciseScene(boolean board) throws Exception {
        Intent intent = new Intent(getInstrumentation().getTargetContext(), GameActivity.class)
                .putExtra("mode", "campaign").putExtra("stageId", "stage_22")
                .putExtra("campaignId", "layout-check").putExtra("campaignBoard", board)
                .putExtra("boardTargetScore", 1400).putExtra("boardSoloPicks", 6)
                .putExtra("questionCount", 6).putExtra("targetScore", 1400)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        activity = getInstrumentation().startActivitySync(intent);
        getInstrumentation().waitForIdleSync();
        // Freeze match callbacks while testing the production rendering code.
        Field exiting = GameActivity.class.getDeclaredField("EXITING");
        exiting.setAccessible(true);
        getInstrumentation().runOnMainSync(() -> {
            try { exiting.setBoolean(activity, true); }
            catch (Exception error) { throw new RuntimeException(error); }
        });

        for (Insets cutout : new Insets[]{Insets.of(133, 0, 0, 0),
                Insets.of(0, 0, 133, 0), Insets.NONE}) {
            View video = activity.findViewById(R.id.gameBackgroundVideo);
            ViewGroup frame = (ViewGroup) video.getParent();
            getInstrumentation().runOnMainSync(() -> {
                ViewCompat.dispatchApplyWindowInsets(frame, new WindowInsetsCompat.Builder()
                        .setInsets(WindowInsetsCompat.Type.displayCutout(), cutout).build());
                frame.requestLayout();
            });
            awaitDraw(frame);
            showBubble(false);
            awaitDraw(frame);
            saveScreenshot((board ? "stage-" : "classic-") + frame.getWidth() + "x" + frame.getHeight()
                    + "-cutout-" + cutout.left + "-" + cutout.right);
            checkLayout(() -> {
                View fallback = activity.findViewById(R.id.stageFallback);
                View scrim = activity.findViewById(R.id.stageScrim);
                for (View background : new View[]{video, fallback, scrim}) {
                    assertSame("Backgrounds must share one full-screen parent", frame, background.getParent());
                    assertEquals(0, background.getLeft());
                    assertEquals(0, background.getTop());
                    assertEquals(frame.getWidth(), background.getWidth());
                    assertEquals(frame.getHeight(), background.getHeight());
                }
                View bubble = activity.findViewById(R.id.rlyDialog);
                View scene = (View) bubble.getParent();
                assertEquals(cutout.left, scene.getLeft());
                assertEquals(frame.getWidth() - cutout.left - cutout.right, scene.getWidth());
                Rect callout = bounds(bubble);
                Rect face = bounds(activity.findViewById(R.id.rlyHead));
                Rect home = bounds(activity.findViewById(R.id.imgHome));
                Rect volume = bounds(activity.findViewById(R.id.imgVolume));
                Rect question = bounds(activity.findViewById(R.id.llyQA));
                float density = activity.getResources().getDisplayMetrics().density;
                assertTrue("Bubble must remain beside the question", callout.right < question.left);
                assertTrue("Home and sound must stay together on the right",
                        home.centerX() > bounds(scene).centerX() && home.right < volume.left);
                assertEquals("Navigation buttons must align", home.centerY(), volume.centerY());
                assertTrue("Navigation gap must stay compact", volume.left - home.right <= 16 * density);
                assertFalse("Bubble must not cover Home", Rect.intersects(callout, home));
                assertFalse("Bubble must not cover sound", Rect.intersects(callout, volume));
                assertTrue("Raised bubble must stay inside the safe area", bounds(scene).contains(callout));
                assertTrue("Bubble tail must touch the head", Math.abs(callout.bottom - face.top) <= 8 * density);
                View hud = board ? activity.findViewById(R.id.offlineScoreBoard)
                        : ((GameActivity) activity).campaignHudPanel;
                Rect information = bounds(hud);
                assertSame("Stage information must stay inside the safe scene", scene, hud.getParent());
                assertFalse("Stage information must not cover navigation", Rect.intersects(information, home));
                assertFalse("Stage information must not cover the presenter", Rect.intersects(information, callout));
                assertFalse("Stage information must not cover the question", Rect.intersects(information, question));
                TextView text = activity.findViewById(R.id.txtDialog);
                int textHeight = text.getHeight() - text.getPaddingTop() - text.getPaddingBottom();
                assertTrue("Intro text must fit without clipping",
                        text.getLayout().getLineBottom(text.getLineCount() - 1) <= textHeight + 1);
            });
            showBubble(true);
            awaitDraw(frame);
            checkLayout(() -> {
                Rect yes = bounds(activity.findViewById(R.id.btnDialogYes));
                Rect no = bounds(activity.findViewById(R.id.btnDialogNo));
                Rect callout = bounds(activity.findViewById(R.id.rlyDialog));
                assertTrue(callout.contains(yes));
                assertTrue(callout.contains(no));
                assertFalse("Confirmation controls must not overlap", Rect.intersects(yes, no));
            });
            verifyModalEdges(frame);
        }
    }

    private void showBubble(boolean confirmation) throws Exception {
        Field field = GameActivity.class.getDeclaredField("presenterBubble");
        field.setAccessible(true);
        Object controller = field.get(activity);
        Method prepare = controller.getClass().getDeclaredMethod("prepare", String.class, boolean.class);
        prepare.setAccessible(true);
        getInstrumentation().runOnMainSync(() -> {
            try {
                View bubble = activity.findViewById(R.id.rlyDialog);
                activity.findViewById(R.id.boardOverlay).setVisibility(View.GONE);
                bubble.animate().cancel();
                bubble.clearAnimation();
                bubble.setAlpha(1);
                bubble.setVisibility(View.VISIBLE);
                bubble.bringToFront();
                prepare.invoke(controller, MESSAGE, confirmation);
                Typewriter text = activity.findViewById(R.id.txtDialog);
                text.stopAnimation();
                text.setText(MESSAGE);
                activity.findViewById(R.id.btnDialogYes).setVisibility(confirmation ? View.VISIBLE : View.INVISIBLE);
                activity.findViewById(R.id.btnDialogNo).setVisibility(confirmation ? View.VISIBLE : View.INVISIBLE);
            } catch (Exception error) { throw new RuntimeException(error); }
        });
    }

    private static Rect bounds(View view) {
        Rect bounds = new Rect();
        assertTrue("Expected visible view " + view.getId(), view.getGlobalVisibleRect(bounds));
        return bounds;
    }

    private void checkLayout(Runnable check) {
        AtomicReference<AssertionError> failure = new AtomicReference<>();
        getInstrumentation().runOnMainSync(() -> {
            try { check.run(); }
            catch (AssertionError error) { failure.set(error); }
        });
        if (failure.get() != null) throw failure.get();
    }

    private void awaitDraw(View view) throws Exception {
        CountDownLatch drawn = new CountDownLatch(1);
        getInstrumentation().runOnMainSync(() -> {
            view.getViewTreeObserver().addOnPreDrawListener(new ViewTreeObserver.OnPreDrawListener() {
                @Override public boolean onPreDraw() {
                    view.getViewTreeObserver().removeOnPreDrawListener(this);
                    view.post(drawn::countDown);
                    return true;
                }
            });
            view.invalidate();
        });
        assertTrue("Stage failed to draw", drawn.await(5, TimeUnit.SECONDS));
        getInstrumentation().waitForIdleSync();
    }

    private void saveScreenshot(String name) throws Exception {
        UiAutomation automation = getInstrumentation().getUiAutomation();
        AccessibilityServiceInfo service = automation.getServiceInfo();
        service.flags |= AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS;
        automation.setServiceInfo(service);
        for (AccessibilityWindowInfo window : automation.getWindows()) {
            AccessibilityNodeInfo root = window.getRoot();
            if (root == null || root.getPackageName() == null
                    || (!"com.android.systemui".contentEquals(root.getPackageName())
                        && !"android".contentEquals(root.getPackageName()))) continue;
            for (AccessibilityNodeInfo button : root.findAccessibilityNodeInfosByText("Got it")) {
                if (button.performAction(AccessibilityNodeInfo.ACTION_CLICK)) {
                    awaitDraw(activity.getWindow().getDecorView());
                    automation.waitForIdle(250, 3000);
                }
            }
        }
        Bitmap screenshot = getInstrumentation().getUiAutomation().takeScreenshot();
        assertNotNull(screenshot);
        File directory = new File(activity.getExternalFilesDir(null), "layout-checks");
        assertTrue(directory.isDirectory() || directory.mkdirs());
        try (FileOutputStream output = new FileOutputStream(new File(directory, name + ".png"))) {
            screenshot.compress(Bitmap.CompressFormat.PNG, 100, output);
        } finally { screenshot.recycle(); }
    }

    private void verifyModalEdges(View frame) throws Exception {
        final int shade = 0xFF0E182A;
        getInstrumentation().runOnMainSync(() -> {
            ViewGroup overlay = activity.findViewById(R.id.boardOverlay);
            overlay.animate().cancel();
            overlay.clearAnimation();
            overlay.setAlpha(1f);
            overlay.removeAllViews();
            overlay.setBackgroundColor(shade);
            overlay.setVisibility(View.VISIBLE);
            overlay.bringToFront();
        });
        awaitDraw(frame);
        getInstrumentation().getUiAutomation().waitForIdle(200, 3000);
        Bitmap screenshot = getInstrumentation().getUiAutomation().takeScreenshot();
        try {
            int middle = screenshot.getPixel(screenshot.getWidth() / 2, screenshot.getHeight() / 2);
            assertEquals("Modal center must be opaque", shade, middle);
            assertEquals("Modal must also shade the left cutout gutter", middle,
                    screenshot.getPixel(1, screenshot.getHeight() / 2));
            assertEquals("Modal must also shade the right cutout gutter", middle,
                    screenshot.getPixel(screenshot.getWidth() - 2, screenshot.getHeight() / 2));
        } finally { screenshot.recycle(); }
        getInstrumentation().runOnMainSync(() -> activity.findViewById(R.id.boardOverlay).setVisibility(View.GONE));
    }

    @Override protected void tearDown() throws Exception {
        if (activity != null) getInstrumentation().runOnMainSync(activity::finish);
        super.tearDown();
    }
}
