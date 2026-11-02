package com.qi7bali.landchallengeonline;

import android.app.Activity;
import android.content.Intent;
import android.os.SystemClock;
import android.test.InstrumentationTestCase;
import android.view.View;
import android.widget.FrameLayout;

import java.util.concurrent.atomic.AtomicBoolean;

/** Local view-only checks: no game session, account, wallet or network request. */
@SuppressWarnings("deprecation")
public final class ProgressMotionTest extends InstrumentationTestCase {
    private Activity host;
    private View ring;

    @Override protected void setUp() throws Exception {
        super.setUp();
        host = getInstrumentation().startActivitySync(new Intent(
                getInstrumentation().getTargetContext(), PrivacyPolicyActivity.class)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
        getInstrumentation().runOnMainSync(() -> {
            FrameLayout root = new FrameLayout(host);
            ring = new View(host);
            root.addView(ring, new FrameLayout.LayoutParams(180, 180));
            host.setContentView(root);
        });
        getInstrumentation().waitForIdleSync();
    }

    public void testHideThenRevealCannotLeaveAStaleInvisibleRing() {
        getInstrumentation().runOnMainSync(() -> Animations.progressZoomOut(ring));
        SystemClock.sleep(40);
        getInstrumentation().runOnMainSync(() -> Animations.progressZoomIn(ring));
        waitForSettledVisibility(View.VISIBLE);
        getInstrumentation().runOnMainSync(() -> {
            assertEquals(View.VISIBLE, ring.getVisibility());
            assertEquals(1f, ring.getAlpha(), .001f);
            assertEquals(1f, ring.getScaleX(), .001f);
            assertEquals(1f, ring.getScaleY(), .001f);
            assertNull("No legacy fillAfter transform should remain", ring.getAnimation());
        });
    }

    public void testCompletedHideResetsTransformsAndPreservesLayoutSize() {
        getInstrumentation().runOnMainSync(() -> Animations.progressZoomOut(ring));
        waitForSettledVisibility(View.INVISIBLE);
        getInstrumentation().runOnMainSync(() -> {
            assertEquals(View.INVISIBLE, ring.getVisibility());
            assertEquals(1f, ring.getScaleX(), .001f);
            assertEquals(1f, ring.getScaleY(), .001f);
            assertEquals(1f, ring.getAlpha(), .001f);
            assertEquals(180, ring.getLayoutParams().width);
            assertEquals(180, ring.getLayoutParams().height);
        });
    }

    private void waitForSettledVisibility(int visibility) {
        long deadline = SystemClock.uptimeMillis() + 6000;
        AtomicBoolean settled = new AtomicBoolean();
        while (SystemClock.uptimeMillis() < deadline) {
            getInstrumentation().runOnMainSync(() -> settled.set(
                    ring.getVisibility() == visibility
                    && Math.abs(ring.getScaleX() - 1f) < .001f
                    && Math.abs(ring.getScaleY() - 1f) < .001f
                    && Math.abs(ring.getAlpha() - 1f) < .001f));
            if (settled.get()) return;
            SystemClock.sleep(16);
        }
        fail("Progress motion did not settle within six seconds");
    }

    @Override protected void tearDown() throws Exception {
        try {
            if (host != null) getInstrumentation().runOnMainSync(() -> {
                if (ring != null) ring.animate().cancel();
                host.finish();
            });
        } finally { super.tearDown(); }
    }
}
