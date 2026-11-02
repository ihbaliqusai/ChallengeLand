package com.qi7bali.landchallengeonline;

import android.app.Activity;
import android.content.Intent;
import android.os.SystemClock;
import android.test.InstrumentationTestCase;

/** Uses only SDK APIs so this test also exercises the signed Release build. */
@SuppressWarnings("deprecation")
public final class FlutterActivityShutdownTest extends InstrumentationTestCase {
    private Activity activity;

    public void testPlayingTexturesCanFinishAndRecreateTheirFlutterEngine() {
        for (int cycle = 0; cycle < 2; cycle++) {
            activity = getInstrumentation().startActivitySync(new Intent()
                    .setClassName(getInstrumentation().getTargetContext().getPackageName(),
                            "com.qi7bali.landchallengeonline.MainActivity")
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
            waitForVideoThreads(true);
            getInstrumentation().runOnMainSync(() -> activity.finish());
            getInstrumentation().waitForIdleSync();
            // An uncaught delayed JNI unregister would terminate this runner.
            waitForVideoThreads(false);
            SystemClock.sleep(500);
            assertTrue("The activity and its Flutter engine must really finish", activity.isDestroyed());
        }
    }

    private void waitForVideoThreads(boolean running) {
        long deadline = SystemClock.uptimeMillis() + 15000;
        while (SystemClock.uptimeMillis() < deadline) {
            boolean background = false, character = false;
            for (Thread thread : Thread.getAllStackTraces().keySet()) {
                if (!thread.isAlive()) continue;
                background |= "LobbyVideo".equals(thread.getName());
                character |= "ChromaGL".equals(thread.getName());
            }
            if (running ? background && character : !background && !character) return;
            SystemClock.sleep(100);
        }
        fail(running ? "Unlock the phone: both production video renderers must start"
                : "Finished activities must release their video threads");
    }

    @Override protected void tearDown() throws Exception {
        try {
            if (activity != null) getInstrumentation().runOnMainSync(() -> activity.finish());
        } finally { super.tearDown(); }
    }
}
