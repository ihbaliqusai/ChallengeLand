package com.qi7bali.landchallengeonline;

import android.animation.Animator;
import android.animation.AnimatorListenerAdapter;
import android.animation.ValueAnimator;
import android.app.Activity;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.graphics.Path;
import android.graphics.Rect;
import android.graphics.RectF;
import android.graphics.drawable.Drawable;
import android.media.MediaPlayer;
import android.os.Handler;
import android.os.Looper;
import android.view.View;
import android.view.ViewGroup;
import android.view.ViewTreeObserver;
import android.view.animation.AccelerateInterpolator;
import android.widget.VideoView;

/** Carries the completed showdown across the Activity boundary without a blank frame. */
final class MatchmakingGameTransition {
    private static final long SNAPSHOT_LIFETIME_MS = 8000L;
    private static final long VIDEO_READY_TIMEOUT_MS = 1000L;
    private static final long OPEN_DURATION_MS = 320L;
    private static final Handler HANDLER = new Handler(Looper.getMainLooper());
    private static Snapshot pending;
    private static Runnable pendingExpiry;

    private MatchmakingGameTransition() {}

    /** Capture the window, including the full-bleed layers moved by GameViewportActivity. */
    static void capture(View scene, View versus) {
        clearPending();
        if (scene == null || scene.getWidth() <= 0 || scene.getHeight() <= 0) return;
        View root = scene.getRootView();
        if (root.getWidth() <= 0 || root.getHeight() <= 0) return;
        Bitmap background = null;
        Bitmap badge = null;
        float originalAlpha = versus == null ? 1f : versus.getAlpha();
        try {
            // Bound memory on high-resolution phones without changing the window geometry.
            float scale = Math.min(1f, 2048f / Math.max(root.getWidth(), root.getHeight()));
            background = Bitmap.createBitmap(Math.max(1, Math.round(root.getWidth() * scale)),
                    Math.max(1, Math.round(root.getHeight() * scale)), Bitmap.Config.ARGB_8888);
            RectF badgeBounds = new RectF();
            if (versus != null && versus.getWidth() > 0 && versus.getHeight() > 0) {
                Rect bounds = new Rect();
                int[] rootLocation = new int[2];
                root.getLocationOnScreen(rootLocation);
                if (versus.getGlobalVisibleRect(bounds)) {
                    badgeBounds.set((bounds.left - rootLocation[0]) / (float) root.getWidth(),
                            (bounds.top - rootLocation[1]) / (float) root.getHeight(),
                            (bounds.right - rootLocation[0]) / (float) root.getWidth(),
                            (bounds.bottom - rootLocation[1]) / (float) root.getHeight());
                    badge = Bitmap.createBitmap(versus.getWidth(), versus.getHeight(), Bitmap.Config.ARGB_8888);
                    versus.draw(new Canvas(badge));
                }
                versus.setAlpha(0f);
            }
            Canvas canvas = new Canvas(background);
            canvas.scale(scale, scale);
            root.draw(canvas);
            pending = new Snapshot(background, badge, badgeBounds);
            pendingExpiry = MatchmakingGameTransition::clearPending;
            HANDLER.postDelayed(pendingExpiry, SNAPSHOT_LIFETIME_MS);
        } catch (RuntimeException | OutOfMemoryError failure) {
            if (background != null) background.recycle();
            if (badge != null) badge.recycle();
        } finally {
            if (versus != null) versus.setAlpha(originalAlpha);
        }
    }

    private static void clearPending() {
        if (pendingExpiry != null) HANDLER.removeCallbacks(pendingExpiry);
        pendingExpiry = null;
        if (pending != null) pending.recycle();
        pending = null;
    }

    static Entrance attach(Activity activity, ViewGroup decor, VideoView video) {
        Snapshot snapshot = pending;
        pending = null;
        if (pendingExpiry != null) HANDLER.removeCallbacks(pendingExpiry);
        pendingExpiry = null;
        Entrance entrance = new Entrance(activity, decor, video, snapshot);
        decor.addView(entrance, new ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
        entrance.awaitGameplay();
        return entrance;
    }

    private static final class Snapshot {
        final Bitmap scene;
        final Bitmap badge;
        final RectF badgeBounds;

        Snapshot(Bitmap scene, Bitmap badge, RectF badgeBounds) {
            this.scene = scene;
            this.badge = badge;
            this.badgeBounds = badgeBounds;
        }

        void recycle() {
            if (!scene.isRecycled()) scene.recycle();
            if (badge != null && !badge.isRecycled()) badge.recycle();
        }
    }

    /** One overlay owns the snapshots, callbacks and animator until the doors are gone. */
    static final class Entrance extends View {
        private final Activity activity;
        private final ViewGroup decor;
        private final VideoView video;
        private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG | Paint.FILTER_BITMAP_FLAG);
        private final Path leftClip = new Path();
        private final Path rightClip = new Path();
        private final RectF destination = new RectF();
        private final RectF badgeDestination = new RectF();
        private final Drawable fallbackLeft;
        private final Drawable fallbackRight;
        private Snapshot snapshot;
        private ValueAnimator animator;
        private float progress;
        private boolean gameplayDrawn;
        private boolean videoReady;
        private boolean disposed;
        private final Runnable readinessTimeout = () -> {
            videoReady = true;
            maybeOpen();
        };
        private final Runnable safetyCleanup = this::dispose;
        private final ViewTreeObserver.OnPreDrawListener firstDraw = new ViewTreeObserver.OnPreDrawListener() {
            @Override public boolean onPreDraw() {
                removePreDrawListener();
                // Let the first gameplay display list reach the renderer before revealing it.
                postOnAnimation(() -> {
                    gameplayDrawn = true;
                    maybeOpen();
                });
                return true;
            }
        };

        Entrance(Activity activity, ViewGroup decor, VideoView video, Snapshot snapshot) {
            super(activity);
            this.activity = activity;
            this.decor = decor;
            this.video = video;
            this.snapshot = snapshot;
            fallbackLeft = activity.getDrawable(R.drawable.bg_split_left_purple);
            fallbackRight = activity.getDrawable(R.drawable.bg_split_right_orange);
            setClickable(true);
            setImportantForAccessibility(IMPORTANT_FOR_ACCESSIBILITY_NO);
            setTag("matchmaking-game-entrance");
        }

        private void awaitGameplay() {
            videoReady = video == null || video.getVisibility() != View.VISIBLE;
            if (video != null) {
                video.setOnInfoListener((player, what, extra) -> {
                    if (what == MediaPlayer.MEDIA_INFO_VIDEO_RENDERING_START) {
                        videoReady = true;
                        maybeOpen();
                    }
                    return false;
                });
            }
            decor.getViewTreeObserver().addOnPreDrawListener(firstDraw);
            postDelayed(readinessTimeout, VIDEO_READY_TIMEOUT_MS);
            postDelayed(safetyCleanup, VIDEO_READY_TIMEOUT_MS + OPEN_DURATION_MS + 1500L);
        }

        private void maybeOpen() {
            if (disposed || animator != null || !gameplayDrawn || !videoReady) return;
            if (activity.isFinishing() || activity.isDestroyed()) {
                dispose();
                return;
            }
            removeCallbacks(readinessTimeout);
            animator = ValueAnimator.ofFloat(0f, 1f);
            animator.setDuration(OPEN_DURATION_MS);
            animator.setInterpolator(new AccelerateInterpolator(1.35f));
            animator.addUpdateListener(animation -> {
                progress = (float) animation.getAnimatedValue();
                invalidate();
            });
            animator.addListener(new AnimatorListenerAdapter() {
                @Override public void onAnimationEnd(Animator animation) { dispose(); }
            });
            animator.start();
        }

        @Override protected void onSizeChanged(int width, int height, int oldWidth, int oldHeight) {
            destination.set(0, 0, width, height);
            // The seam matches the diagonal in the existing purple/orange panel artwork.
            float top = width * (7f / 12f);
            float bottom = width * (5f / 12f);
            leftClip.reset();
            leftClip.moveTo(0, 0);
            leftClip.lineTo(top, 0);
            leftClip.lineTo(bottom, height);
            leftClip.lineTo(0, height);
            leftClip.close();
            rightClip.reset();
            rightClip.moveTo(top, 0);
            rightClip.lineTo(width, 0);
            rightClip.lineTo(width, height);
            rightClip.lineTo(bottom, height);
            rightClip.close();
            fallbackLeft.setBounds(0, 0, width, height);
            fallbackRight.setBounds(0, 0, width, height);
        }

        @Override protected void onDraw(Canvas canvas) {
            if (disposed) return;
            float distance = getWidth() * 1.05f * progress;
            if (snapshot == null) {
                canvas.save();
                canvas.translate(-distance, 0);
                fallbackLeft.draw(canvas);
                canvas.restore();
                canvas.save();
                canvas.translate(distance, 0);
                fallbackRight.draw(canvas);
                canvas.restore();
                return;
            }
            drawPanel(canvas, leftClip, -distance);
            drawPanel(canvas, rightClip, distance);
            if (snapshot.badge != null) {
                RectF bounds = snapshot.badgeBounds;
                float cx = bounds.centerX() * getWidth();
                float cy = bounds.centerY() * getHeight();
                float scale = Math.max(0f, 1f - progress * 1.35f);
                float halfWidth = bounds.width() * getWidth() * 0.5f * scale;
                float halfHeight = bounds.height() * getHeight() * 0.5f * scale;
                badgeDestination.set(cx - halfWidth, cy - halfHeight, cx + halfWidth, cy + halfHeight);
                paint.setAlpha(Math.round(255 * Math.max(0f, 1f - progress * 1.6f)));
                canvas.drawBitmap(snapshot.badge, null, badgeDestination, paint);
                paint.setAlpha(255);
            }
        }

        private void drawPanel(Canvas canvas, Path clip, float x) {
            canvas.save();
            canvas.translate(x, 0);
            canvas.clipPath(clip);
            canvas.drawBitmap(snapshot.scene, null, destination, paint);
            canvas.restore();
        }

        private void removePreDrawListener() {
            ViewTreeObserver observer = decor.getViewTreeObserver();
            if (observer.isAlive()) observer.removeOnPreDrawListener(firstDraw);
        }

        void dispose() {
            if (disposed) return;
            disposed = true;
            removeCallbacks(readinessTimeout);
            removeCallbacks(safetyCleanup);
            removePreDrawListener();
            if (video != null) video.setOnInfoListener(null);
            if (animator != null) {
                animator.removeAllListeners();
                animator.cancel();
                animator = null;
            }
            if (getParent() instanceof ViewGroup) ((ViewGroup) getParent()).removeView(this);
            if (snapshot != null) snapshot.recycle();
            snapshot = null;
        }

        @Override protected void onDetachedFromWindow() {
            super.onDetachedFromWindow();
            dispose();
        }
    }
}
