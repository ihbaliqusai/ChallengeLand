package com.qi7bali.landchallengeonline;

import android.app.Activity;
import android.content.Intent;
import android.media.MediaPlayer;
import android.opengl.EGL14;
import android.os.Handler;
import android.os.SystemClock;
import android.test.InstrumentationTestCase;
import android.test.InstrumentationTestRunner;
import android.util.Log;
import android.widget.GridLayout;

import java.lang.reflect.Field;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicReference;

/** Real decoder/EGL smoke test, with no game session, account changes or ad loading. */
@SuppressWarnings("deprecation")
public final class ChromaPlaybackTest extends InstrumentationTestCase {
    private static final int[] CLIPS = {
            R.raw.video_khaled, R.raw.video_omar, R.raw.video_fahad, R.raw.video_mazen,
            R.raw.video_mahmoud, R.raw.video_ellen, R.raw.video_sarah, R.raw.video_talia
    };
    private Activity host;
    private GridLayout grid;
    private final List<ChromaVideoView> videos = new ArrayList<>();
    private final List<Object> renderers = new ArrayList<>();

    @Override protected void setUp() throws Exception {
        super.setUp();
        host = getInstrumentation().startActivitySync(new Intent(
                getInstrumentation().getTargetContext(), PrivacyPolicyActivity.class)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
        onUi(() -> {
            grid = new GridLayout(host);
            grid.setColumnCount(4);
            grid.setRowCount(2);
            host.setContentView(grid);
        });
    }

    public void testEightConcurrentCharactersPauseResumeAndReleaseTheirSurfaces() throws Exception {
        CountDownLatch firstFrames = new CountDownLatch(CLIPS.length);
        onUi(() -> {
            for (int i = 0; i < CLIPS.length; i++) {
                ChromaVideoView video = new ChromaVideoView(host, CLIPS[i]);
                video.setOnFirstFrameListener(firstFrames::countDown);
                GridLayout.LayoutParams params = new GridLayout.LayoutParams(
                        GridLayout.spec(i / 4, 1f), GridLayout.spec(i % 4, 1f));
                params.width = 0;
                params.height = 0;
                video.setLayoutParams(params);
                videos.add(video);
                grid.addView(video);
            }
        });
        assertTrue("All eight decoders must publish a first frame concurrently; remaining: "
                        + firstFrames.getCount(), firstFrames.await(30, TimeUnit.SECONDS));

        sampleConcurrentPlayback();

        onUi(() -> {
            for (ChromaVideoView video : videos) {
                assertTrue("Each character needs its own available output surface", video.isAvailable());
                Object renderer = field(video, "renderer");
                assertNotNull(renderer);
                renderers.add(renderer);
                video.setPaused(true);
            }
        });
        assertDecoderState(false);

        CountDownLatch resumedFrames = new CountDownLatch(CLIPS.length);
        onUi(() -> {
            for (ChromaVideoView video : videos) {
                video.setOnFirstFrameListener(resumedFrames::countDown);
                video.setPaused(false);
            }
        });
        assertTrue("All eight characters must publish frames again after resume; remaining: "
                        + resumedFrames.getCount(), resumedFrames.await(30, TimeUnit.SECONDS));
        assertDecoderState(true);
        assertFramesKeepAdvancing();

        onUi(() -> {
            for (ChromaVideoView video : videos) video.release();
            grid.removeAllViews();
        });
        getInstrumentation().waitForIdleSync();
        awaitRendererCleanup();
    }

    /** Optional real-device comparison; sampling runs outside the UI thread. */
    private void sampleConcurrentPlayback() throws Exception {
        String argument = ((InstrumentationTestRunner) getInstrumentation())
                .getArguments().getString("sampleMs");
        if (argument == null) return;
        int duration = Math.min(30000, Math.max(1000, Integer.parseInt(argument)));
        List<Object> active = new ArrayList<>();
        onUi(() -> { for (ChromaVideoView video : videos) active.add(field(video, "renderer")); });
        long[] previous = new long[active.size()];
        int[] fresh = new int[active.size()];
        long started = SystemClock.elapsedRealtime();
        Log.i("CL_VideoPerf", "eight-player sample started");
        while (SystemClock.elapsedRealtime() - started < duration) {
            CountDownLatch sampled = new CountDownLatch(active.size());
            for (int i = 0; i < active.size(); i++) {
                final int index = i;
                Object renderer = active.get(i);
                ((Handler) field(renderer, "handler")).post(() -> {
                    long timestamp = (long) field(renderer, "lastFrameTimestamp");
                    if (timestamp != Long.MIN_VALUE && timestamp != previous[index]) fresh[index]++;
                    previous[index] = timestamp;
                    sampled.countDown();
                });
            }
            assertTrue("All eight renderers must respond", sampled.await(3, TimeUnit.SECONDS));
            SystemClock.sleep(15);
        }
        long elapsed = SystemClock.elapsedRealtime() - started;
        Log.i("CL_VideoPerf", "eight-player sample elapsedMs=" + elapsed
                + " observedFreshFrames=" + java.util.Arrays.toString(fresh));
        for (int count : fresh) assertTrue("Every decoder must keep advancing", count > 0);
    }

    /** A GL-thread barrier observes MediaPlayer after the queued pause/resume command. */
    private void assertFramesKeepAdvancing() throws Exception {
        long[] before = new long[renderers.size()];
        CountDownLatch captured = new CountDownLatch(renderers.size());
        for (int i = 0; i < renderers.size(); i++) {
            final int index = i;
            Object renderer = renderers.get(i);
            ((Handler) field(renderer, "handler")).post(() -> {
                before[index] = (long) field(renderer, "lastFrameTimestamp");
                captured.countDown();
            });
        }
        assertTrue(captured.await(5, TimeUnit.SECONDS));
        SystemClock.sleep(350);
        CountDownLatch checked = new CountDownLatch(renderers.size());
        AtomicReference<Throwable> failure = new AtomicReference<>();
        for (int i = 0; i < renderers.size(); i++) {
            final int index = i;
            Object renderer = renderers.get(i);
            ((Handler) field(renderer, "handler")).post(() -> {
                try {
                    assertTrue("Resumed decoder must keep publishing fresh frames: " + index,
                            before[index] != (long) field(renderer, "lastFrameTimestamp"));
                } catch (Throwable error) { failure.compareAndSet(null, error); }
                finally { checked.countDown(); }
            });
        }
        assertTrue(checked.await(5, TimeUnit.SECONDS));
        if (failure.get() != null) throw new AssertionError(failure.get());
    }

    /** A GL-thread barrier observes MediaPlayer after the queued pause/resume command. */
    private void assertDecoderState(boolean playing) throws Exception {
        CountDownLatch checked = new CountDownLatch(renderers.size());
        AtomicReference<Throwable> failure = new AtomicReference<>();
        for (Object renderer : renderers) {
            Handler handler = (Handler) field(renderer, "handler");
            assertTrue("Renderer thread must still accept work", handler.post(() -> {
                try {
                    assertEquals(!playing, field(renderer, "playbackPaused"));
                    MediaPlayer player = (MediaPlayer) field(renderer, "player");
                    assertNotNull("The active renderer must retain its decoder", player);
                    assertEquals("Decoder state must match the foreground state", playing, player.isPlaying());
                } catch (Throwable error) {
                    failure.compareAndSet(null, error);
                } finally { checked.countDown(); }
            }));
        }
        assertTrue("Renderer state checks must finish", checked.await(10, TimeUnit.SECONDS));
        if (failure.get() != null) throw new AssertionError(failure.get());
    }

    private void awaitRendererCleanup() throws Exception {
        long deadline = SystemClock.uptimeMillis() + 15000;
        for (Object renderer : renderers) {
            Thread thread = (Thread) field(renderer, "thread");
            long remaining = deadline - SystemClock.uptimeMillis();
            if (remaining > 0) thread.join(remaining);
            assertFalse("Detached characters must not retain a GL thread", thread.isAlive());
            assertEquals(true, field(renderer, "cleanupComplete"));
            assertNull("The decoder must be released", field(renderer, "player"));
            assertNull("The decoder surface must be released", field(renderer, "videoSurface"));
            assertNull("The decoder texture must be released", field(renderer, "videoTexture"));
            assertEquals(EGL14.EGL_NO_DISPLAY, field(renderer, "eglDisplay"));
            assertEquals(EGL14.EGL_NO_CONTEXT, field(renderer, "eglContext"));
            assertEquals(EGL14.EGL_NO_SURFACE, field(renderer, "eglSurface"));
            AtomicBoolean outputReleased = (AtomicBoolean) field(renderer, "outputReleased");
            // If detachment followed an already completed teardown, the release
            // is handed to the surface-release executor rather than the UI.
            while (!outputReleased.get() && SystemClock.uptimeMillis() < deadline) {
                SystemClock.sleep(10);
            }
            assertTrue("The detached TextureView output must be released", outputReleased.get());
        }
    }

    private static Object field(Object target, String name) {
        try {
            Field field = target.getClass().getDeclaredField(name);
            field.setAccessible(true);
            return field.get(target);
        } catch (ReflectiveOperationException error) { throw new AssertionError(error); }
    }

    private void onUi(Runnable action) {
        AtomicReference<Throwable> failure = new AtomicReference<>();
        getInstrumentation().runOnMainSync(() -> {
            try { action.run(); }
            catch (Throwable error) { failure.set(error); }
        });
        if (failure.get() != null) throw new AssertionError(failure.get());
    }

    @Override protected void tearDown() throws Exception {
        try {
            onUi(() -> {
                for (ChromaVideoView video : videos) video.release();
                if (grid != null) grid.removeAllViews();
                if (host != null) host.finish();
            });
        } finally { super.tearDown(); }
    }
}
