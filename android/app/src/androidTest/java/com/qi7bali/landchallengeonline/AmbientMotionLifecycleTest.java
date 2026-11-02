package com.qi7bali.landchallengeonline;

import android.content.Context;
import android.os.SystemClock;
import android.test.InstrumentationTestCase;
import android.view.View;
import android.view.animation.Animation;
import android.widget.FrameLayout;
import android.widget.ImageView;
import android.widget.RelativeLayout;

import java.lang.reflect.Field;
import java.lang.reflect.Method;

/** Runs production motion callbacks on view-only scenes, without creating a game or loading ads. */
@SuppressWarnings("deprecation")
public final class AmbientMotionLifecycleTest extends InstrumentationTestCase {
    private Object ambientActivity;
    private Class<?> ambientOwner;
    private RainScene rainActivity;

    public void testClassicMotionStopsAndRestartsWithoutDuplicateCallbacks() throws Exception {
        getInstrumentation().runOnMainSync(() -> {
            ClassicScene activity = new ClassicScene(getInstrumentation().getTargetContext());
            ambientActivity = activity;
            ambientOwner = GameActivity.class;
        });
        exerciseAmbient(((ClassicScene) ambientActivity).scene);
    }

    public void testMultiplayerMotionStopsAndRestartsWithoutDuplicateCallbacks() throws Exception {
        getInstrumentation().runOnMainSync(() -> {
            MultiplayerScene activity = new MultiplayerScene(getInstrumentation().getTargetContext());
            ambientActivity = activity;
            ambientOwner = BaseGameActivity.class;
        });
        exerciseAmbient(((MultiplayerScene) ambientActivity).scene);
    }

    private void exerciseAmbient(Scene scene) throws Exception {
        getInstrumentation().runOnMainSync(() -> {
            invoke(ambientOwner, ambientActivity, "startAmbientMotion");
            Object lights = field(ambientOwner, ambientActivity, "lightsRunnable");
            Object blinking = field(ambientOwner, ambientActivity, "blinkingRunnable");
            assertNotNull(lights);
            assertNotNull(blinking);
            invoke(ambientOwner, ambientActivity, "startAmbientMotion");
            assertSame(lights, field(ambientOwner, ambientActivity, "lightsRunnable"));
            assertSame(blinking, field(ambientOwner, ambientActivity, "blinkingRunnable"));
        });
        SystemClock.sleep(1300);
        final int[] pausedCounts = new int[2];
        getInstrumentation().runOnMainSync(() -> {
            assertTrue("Stage lights must animate while resumed", scene.light.animationCount > 0);
            assertTrue("Presenter must blink while resumed", scene.presenter.blinkCount > 0);
            invoke(ambientOwner, ambientActivity, "stopAmbientMotion");
            assertNull(scene.light.getAnimation());
            pausedCounts[0] = scene.light.animationCount;
            pausedCounts[1] = scene.presenter.blinkCount;
        });
        SystemClock.sleep(1400);
        getInstrumentation().runOnMainSync(() -> {
            assertEquals("Paused lights must not receive updates", pausedCounts[0], scene.light.animationCount);
            assertEquals("Paused presenter must not receive updates", pausedCounts[1], scene.presenter.blinkCount);
            assertNull(field(ambientOwner, ambientActivity, "lightsRunnable"));
            assertNull(field(ambientOwner, ambientActivity, "blinkingRunnable"));
            invoke(ambientOwner, ambientActivity, "startAmbientMotion");
        });
        SystemClock.sleep(1300);
        getInstrumentation().runOnMainSync(() -> {
            assertTrue("Lights must restart after resume", scene.light.animationCount > pausedCounts[0]);
            assertTrue("Blinking must restart after resume", scene.presenter.blinkCount > pausedCounts[1]);
        });
    }

    public void testMoneyRainCancelsSpawningAndRemovesAnimatedViewsOnPause() {
        getInstrumentation().runOnMainSync(() -> {
            rainActivity = new RainScene(getInstrumentation().getTargetContext());
            invoke(WinnerActivity.class, rainActivity, "startMoneyRain");
            Object callback = field(WinnerActivity.class, rainActivity, "dollarRunnable");
            invoke(WinnerActivity.class, rainActivity, "startMoneyRain");
            assertSame(callback, field(WinnerActivity.class, rainActivity, "dollarRunnable"));
            rainActivity.newDollar();
            assertEquals(1, rainActivity.screen.getChildCount());
            invoke(WinnerActivity.class, rainActivity, "stopMoneyRain");
            assertEquals("Stopping must remove active rain views", 0, rainActivity.screen.getChildCount());
        });
        SystemClock.sleep(1300);
        getInstrumentation().runOnMainSync(() -> {
            assertEquals("Stopped rain must not create more views", 0, rainActivity.screen.getChildCount());
            assertNull(field(WinnerActivity.class, rainActivity, "dollarRunnable"));
            invoke(WinnerActivity.class, rainActivity, "startMoneyRain");
        });
        SystemClock.sleep(1300);
        getInstrumentation().runOnMainSync(() ->
                assertTrue("Rain must restart after resume", rainActivity.screen.getChildCount() > 0));
    }

    @Override protected void tearDown() throws Exception {
        try {
            getInstrumentation().runOnMainSync(() -> {
                if (ambientActivity != null) invoke(ambientOwner, ambientActivity, "stopAmbientMotion");
                if (rainActivity != null) invoke(WinnerActivity.class, rainActivity, "stopMoneyRain");
            });
        } finally { super.tearDown(); }
    }

    private static void invoke(Class<?> owner, Object target, String name) {
        try {
            Method method = owner.getDeclaredMethod(name);
            method.setAccessible(true);
            method.invoke(target);
        } catch (ReflectiveOperationException error) { throw new AssertionError(error); }
    }

    private static Object field(Class<?> owner, Object target, String name) {
        try {
            Field field = owner.getDeclaredField(name);
            field.setAccessible(true);
            return field.get(target);
        } catch (ReflectiveOperationException error) { throw new AssertionError(error); }
    }

    private static final class Scene {
        final FrameLayout root;
        final CountingImage light;
        final CountingPresenter presenter;

        Scene(Context context) {
            root = new FrameLayout(context);
            light = new CountingImage(context);
            light.setId(R.id.imgLight1);
            root.addView(light);
            for (int id : new int[]{R.id.imgLight2, R.id.imgLight3, R.id.imgLight4, R.id.imgShadow}) {
                ImageView view = new ImageView(context);
                view.setId(id);
                root.addView(view);
            }
            RelativeLayout person = new RelativeLayout(context);
            person.addView(new ImageView(context));
            RelativeLayout head = new RelativeLayout(context);
            for (int i = 0; i < 6; i++) head.addView(new ImageView(context));
            person.addView(head);
            presenter = new CountingPresenter(person);
        }
    }

    private static final class CountingImage extends ImageView {
        int animationCount;
        CountingImage(Context context) { super(context); }
        @Override public void startAnimation(Animation animation) {
            animationCount++;
            super.startAnimation(animation);
        }
    }

    private static final class CountingPresenter extends Person {
        int blinkCount;
        CountingPresenter(RelativeLayout view) { super(view); }
        @Override public void blinkEyes(int times) { blinkCount++; }
    }

    private static final class ClassicScene extends GameActivity {
        final Scene scene;
        ClassicScene(Context context) {
            attachBaseContext(context);
            scene = new Scene(context);
            person = scene.presenter;
        }
        @Override public <T extends View> T findViewById(int id) { return scene.root.findViewById(id); }
    }

    private static final class MultiplayerScene extends BaseGameActivity {
        final Scene scene;
        MultiplayerScene(Context context) {
            attachBaseContext(context);
            scene = new Scene(context);
            person = scene.presenter;
        }
        @Override protected int getLayoutResId() { return R.layout.activity_game_battle; }
        @Override protected String getMatchModeId() { return "battle"; }
        @Override public <T extends View> T findViewById(int id) { return scene.root.findViewById(id); }
    }

    private static final class RainScene extends WinnerActivity {
        final RelativeLayout screen;
        RainScene(Context context) {
            attachBaseContext(context);
            screen = new RelativeLayout(context);
            screen.setId(R.id.rlyScreen);
            width = 800;
            height = 400;
            interval = 80;
        }
        @Override public <T extends View> T findViewById(int id) { return screen.findViewById(id); }
    }
}
