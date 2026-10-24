package com.qi7bali.landchallengeonline;

import android.content.Context;
import android.content.res.Configuration;
import android.graphics.Color;
import android.graphics.Rect;
import android.os.Build;
import android.os.Bundle;
import android.util.DisplayMetrics;
import android.view.View;
import android.view.ViewGroup;
import android.view.SurfaceView;
import android.view.TextureView;
import android.view.Window;
import android.view.WindowManager;
import android.widget.FrameLayout;
import android.widget.ImageView;

import java.util.ArrayList;
import java.util.List;

import androidx.appcompat.app.AppCompatActivity;
import androidx.core.graphics.Insets;
import androidx.core.view.ViewCompat;
import androidx.core.view.WindowCompat;
import androidx.core.view.WindowInsetsCompat;
import androidx.core.view.WindowInsetsControllerCompat;

/** Keeps native controls proportional while backgrounds fill the whole window. */
public abstract class GameViewportActivity extends AppCompatActivity {
    private CanvasFrame canvas;

    @Override
    protected void attachBaseContext(Context base) {
        Rect bounds = usableWindowBounds(base);
        int width = bounds.width();
        int height = bounds.height();
        Configuration config = new Configuration(base.getResources().getConfiguration());
        config.densityDpi = GameViewportSpec.densityDpi(width, height);
        config.fontScale = 1f;
        float density = config.densityDpi / 160f;
        config.screenWidthDp = Math.round(width / density);
        config.screenHeightDp = Math.round(height / density);
        config.smallestScreenWidthDp = GameViewportSpec.HEIGHT_DP;
        super.attachBaseContext(base.createConfigurationContext(config));
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        configureWindow(getWindow());
    }

    /** Also used by Flutter so older Android versions draw beneath cutouts. */
    public static void configureWindow(Window window) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            WindowManager.LayoutParams attributes = window.getAttributes();
            attributes.layoutInDisplayCutoutMode = Build.VERSION.SDK_INT >= Build.VERSION_CODES.R
                    ? WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS
                    : WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES;
            window.setAttributes(attributes);
        }
        WindowCompat.setDecorFitsSystemWindows(window, false);
        WindowInsetsControllerCompat controller =
                WindowCompat.getInsetsController(window, window.getDecorView());
        controller.setSystemBarsBehavior(
                WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE);
        controller.hide(WindowInsetsCompat.Type.systemBars());
    }

    private static Rect usableWindowBounds(Context context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            WindowManager manager = (WindowManager) context.getSystemService(Context.WINDOW_SERVICE);
            if (manager != null) {
                android.view.WindowMetrics window = manager.getCurrentWindowMetrics();
                android.graphics.Insets safe = window.getWindowInsets()
                        .getInsetsIgnoringVisibility(android.view.WindowInsets.Type.displayCutout());
                Rect bounds = new Rect(window.getBounds());
                bounds.inset(safe.left, safe.top, safe.right, safe.bottom);
                return bounds;
            }
        }
        DisplayMetrics metrics = context.getResources().getDisplayMetrics();
        return new Rect(0, 0, metrics.widthPixels, metrics.heightPixels);
    }

    /** Geometry follows the usable window aspect ratio, without a fixed frame. */
    static DisplayMetrics canvasMetrics(Context context) {
        DisplayMetrics metrics = new DisplayMetrics();
        metrics.setTo(context.getResources().getDisplayMetrics());
        Rect bounds = usableWindowBounds(context);
        if (context instanceof GameViewportActivity) {
            CanvasFrame frame = ((GameViewportActivity) context).canvas;
            if (frame != null && frame.getMeasuredWidth() > 0 && frame.getMeasuredHeight() > 0) {
                bounds = new Rect(0, 0,
                        frame.getMeasuredWidth() - frame.cutout.left - frame.cutout.right,
                        frame.getMeasuredHeight() - frame.cutout.top - frame.cutout.bottom);
            }
        }
        metrics.widthPixels = Math.max(0, bounds.width());
        metrics.heightPixels = Math.max(0, bounds.height());
        return metrics;
    }

    @Override
    public void setContentView(int layoutResId) {
        CanvasFrame frame = new CanvasFrame(this);
        canvas = frame;
        getLayoutInflater().inflate(layoutResId, frame, true);
        frame.arrangeScene();
        super.setContentView(frame);
    }

    @Override
    public void setContentView(View view) {
        setContentView(view, new ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
    }

    @Override
    public void setContentView(View view, ViewGroup.LayoutParams params) {
        CanvasFrame frame = new CanvasFrame(this);
        canvas = frame;
        frame.addView(view, new FrameLayout.LayoutParams(params));
        frame.arrangeScene();
        super.setContentView(frame);
    }

    private static final class CanvasFrame extends FrameLayout {
        private Insets cutout = Insets.NONE;
        private View content;
        private GameOverlayLayout overlay;
        private final List<View> backgrounds = new ArrayList<>();

        CanvasFrame(Context context) {
            super(context);
            setBackgroundColor(Color.BLACK);
            ViewCompat.setOnApplyWindowInsetsListener(this, (view, insets) -> {
                Insets next = insets.getInsets(WindowInsetsCompat.Type.displayCutout());
                if (!next.equals(cutout)) {
                    cutout = next;
                    requestLayout();
                }
                return insets;
            });
        }

        @Override
        protected void onMeasure(int widthMeasureSpec, int heightMeasureSpec) {
            int width = MeasureSpec.getSize(widthMeasureSpec);
            int height = MeasureSpec.getSize(heightMeasureSpec);
            setMeasuredDimension(width, height);
            if (overlay != null) overlay.setBleedInsets(cutout);
            for (int index = 0; index < getChildCount(); index++) {
                View child = getChildAt(index);
                int childWidth = child == content
                        ? Math.max(0, width - cutout.left - cutout.right) : width;
                int childHeight = child == content
                        ? Math.max(0, height - cutout.top - cutout.bottom) : height;
                child.measure(MeasureSpec.makeMeasureSpec(childWidth, MeasureSpec.EXACTLY),
                        MeasureSpec.makeMeasureSpec(childHeight, MeasureSpec.EXACTLY));
            }
        }

        @Override
        protected void onLayout(boolean changed, int left, int top, int right, int bottom) {
            for (int index = 0; index < getChildCount(); index++) {
                View child = getChildAt(index);
                int x = child == content ? cutout.left : 0;
                int y = child == content ? cutout.top : 0;
                child.layout(x, y, x + child.getMeasuredWidth(), y + child.getMeasuredHeight());
            }
        }

        void arrangeScene() {
            content = getChildAt(0);
            View scene = content;
            while (scene instanceof ViewGroup && scene.getBackground() == null) {
                ViewGroup wrapper = (ViewGroup) scene;
                if (wrapper.getChildCount() != 1 || !(wrapper.getChildAt(0) instanceof ViewGroup)) break;
                scene = wrapper.getChildAt(0);
            }
            // A background is drawn once, across the entire window. The scene
            // containing controls is independently laid out inside the cutout.
            if (scene.getBackground() != null) {
                android.graphics.drawable.Drawable background = scene.getBackground();
                scene.setBackground(null);
                setBackground(background);
            }
            if (!(scene instanceof ViewGroup)) return;
            ViewGroup group = (ViewGroup) scene;
            while (group.getChildCount() > 0) {
                View layer = group.getChildAt(0);
                ViewGroup.LayoutParams params = layer.getLayoutParams();
                boolean videoBackground = layer.getId() == R.id.gameBackgroundVideo;
                boolean background = videoBackground || (!layer.isClickable() && !layer.isFocusable()
                        && (layer instanceof ImageView || layer instanceof SurfaceView
                            || layer instanceof TextureView || layer.getClass() == View.class));
                if (!background || params.width != LayoutParams.MATCH_PARENT
                        || params.height != LayoutParams.MATCH_PARENT) break;
                group.removeView(layer);
                if (videoBackground) {
                    // VideoView requests focus by default even for a decorative
                    // background; it must still share the full-window surface.
                    layer.setFocusable(false);
                    layer.setFocusableInTouchMode(false);
                }
                addView(layer, backgrounds.size(), new FrameLayout.LayoutParams(
                        LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT));
                backgrounds.add(layer);
            }
            View modal = content.findViewById(R.id.boardOverlay);
            if (modal instanceof GameOverlayLayout) {
                overlay = (GameOverlayLayout) modal;
                // Let modal shading reach through the cutout gutter without
                // moving any modal controls or changing the scene's z-order.
                View current = overlay;
                while (current.getParent() instanceof ViewGroup) {
                    ViewGroup parent = (ViewGroup) current.getParent();
                    parent.setClipChildren(false);
                    parent.setClipToPadding(false);
                    if (parent == this) break;
                    current = parent;
                }
            }
        }
    }
}
