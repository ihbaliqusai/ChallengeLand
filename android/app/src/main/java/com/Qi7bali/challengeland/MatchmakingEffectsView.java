package com.qi7bali.landchallengeonline;

import android.animation.Animator;
import android.animation.AnimatorListenerAdapter;
import android.animation.ValueAnimator;
import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Matrix;
import android.graphics.Paint;
import android.graphics.RadialGradient;
import android.graphics.Shader;
import android.util.AttributeSet;
import android.view.View;
import android.view.animation.LinearInterpolator;

/** Brief, passive light effects shared by the opponent reveal and versus slam. */
public final class MatchmakingEffectsView extends View {
    public static final long REVEAL_DURATION_MS = 420L;
    public static final long VERSUS_DURATION_MS = 1050L;

    private static final int SPARK_COUNT = 38;
    private final Paint revealPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint impactPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint corePaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint sparkPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Matrix revealMatrix = new Matrix();
    private final Matrix impactMatrix = new Matrix();
    private final RadialGradient revealGradient = new RadialGradient(0f, 0f, 1f,
            new int[]{0xFFFFFFFF, 0xFFF8DEFF, 0xD9B75CFF, 0x559B24F4, 0x009B24F4},
            new float[]{0f, 0.12f, 0.30f, 0.60f, 1f}, Shader.TileMode.CLAMP);
    private final RadialGradient impactGradient = new RadialGradient(0f, 0f, 1f,
            new int[]{0xFFFFFFFF, 0xFFFFFFC2, 0x88FFE693, 0x00FFFFFF},
            new float[]{0f, 0.16f, 0.43f, 1f}, Shader.TileMode.CLAMP);
    private final int[] ownLocation = new int[2];
    private final int[] targetLocation = new int[2];
    private final float[] sparkDelay = new float[SPARK_COUNT];
    private final float[] sparkOrigin = new float[SPARK_COUNT];
    private final float[] sparkOffset = new float[SPARK_COUNT];
    private final float[] sparkTravel = new float[SPARK_COUNT];
    private final float[] sparkLength = new float[SPARK_COUNT];
    private final float density;

    private ValueAnimator revealAnimator;
    private ValueAnimator impactAnimator;
    private float revealProgress = -1f;
    private float impactProgress = -1f;
    private float revealX;
    private float revealY;
    private float revealRadius;
    private float impactCenterX;
    private float impactCenterY;
    private float seamTopX;
    private float seamSlope;

    public MatchmakingEffectsView(Context context) {
        this(context, null);
    }

    public MatchmakingEffectsView(Context context, AttributeSet attrs) {
        this(context, attrs, 0);
    }

    public MatchmakingEffectsView(Context context, AttributeSet attrs, int defStyleAttr) {
        super(context, attrs, defStyleAttr);
        density = getResources().getDisplayMetrics().density;
        setClickable(false);
        setFocusable(false);
        setImportantForAccessibility(IMPORTANT_FOR_ACCESSIBILITY_NO);
        revealPaint.setShader(revealGradient);
        impactPaint.setShader(impactGradient);
        sparkPaint.setStrokeCap(Paint.Cap.ROUND);
        // Fixed seeds keep the burst stable between draws and avoid frame-time allocations.
        for (int i = 0; i < SPARK_COUNT; i++) {
            sparkDelay[i] = fraction(i * 0.618034f) * 0.34f;
            sparkOrigin[i] = fraction(i * 0.381966f + 0.13f);
            sparkOffset[i] = fraction(i * 0.754878f + 0.29f) * 2f - 1f;
            sparkTravel[i] = 0.65f + fraction(i * 0.569840f) * 0.70f;
            sparkLength[i] = 0.45f + fraction(i * 0.438447f) * 0.90f;
        }
    }

    /** Call before starting the card collapse so its full-size center is recorded. */
    public void playOpponentReveal(View target) {
        cancelReveal();
        if (target == null || target.getWidth() == 0 || target.getHeight() == 0) return;
        getLocationOnScreen(ownLocation);
        target.getLocationOnScreen(targetLocation);
        revealX = targetLocation[0] - ownLocation[0] + target.getWidth() * 0.5f;
        revealY = targetLocation[1] - ownLocation[1] + target.getHeight() * 0.5f;
        revealRadius = Math.max(target.getWidth(), target.getHeight()) * 0.85f;
        revealProgress = 0f;
        revealAnimator = ValueAnimator.ofFloat(0f, 1f);
        revealAnimator.setDuration(REVEAL_DURATION_MS);
        revealAnimator.setInterpolator(new LinearInterpolator());
        revealAnimator.addUpdateListener(animation -> {
            revealProgress = (float) animation.getAnimatedValue();
            invalidate();
        });
        revealAnimator.addListener(new AnimatorListenerAdapter() {
            @Override public void onAnimationEnd(Animator animation) {
                if (revealAnimator != animation) return;
                revealAnimator = null;
                revealProgress = -1f;
                invalidate();
            }
        });
        revealAnimator.start();
    }

    /** Call when the two panels meet, together with the versus sound and punch. */
    public void playVersusImpact() {
        cancelImpact();
        View root = getRootView();
        getLocationOnScreen(ownLocation);
        root.getLocationOnScreen(targetLocation);
        float rootWidth = Math.max(1, root.getWidth());
        float rootHeight = Math.max(1, root.getHeight());
        float originX = targetLocation[0] - ownLocation[0];
        float originY = targetLocation[1] - ownLocation[1];
        impactCenterX = originX + rootWidth * 0.5f;
        impactCenterY = originY + rootHeight * 0.5f;
        seamSlope = -rootWidth / (6f * rootHeight);
        seamTopX = originX + rootWidth * (7f / 12f) - seamSlope * originY;
        impactProgress = 0f;
        impactAnimator = ValueAnimator.ofFloat(0f, 1f);
        impactAnimator.setDuration(VERSUS_DURATION_MS);
        impactAnimator.setInterpolator(new LinearInterpolator());
        impactAnimator.addUpdateListener(animation -> {
            impactProgress = (float) animation.getAnimatedValue();
            invalidate();
        });
        impactAnimator.addListener(new AnimatorListenerAdapter() {
            @Override public void onAnimationEnd(Animator animation) {
                if (impactAnimator != animation) return;
                impactAnimator = null;
                impactProgress = -1f;
                invalidate();
            }
        });
        impactAnimator.start();
    }

    @Override protected void onDraw(Canvas canvas) {
        super.onDraw(canvas);
        if (revealProgress >= 0f) drawReveal(canvas);
        if (impactProgress >= 0f) drawImpact(canvas);
    }

    private void drawReveal(Canvas canvas) {
        float progress = revealProgress;
        // Flash across the card first, contract into a bright tile, then bloom on reveal.
        float radius;
        float opacity;
        if (progress < 0.38f) {
            float phase = progress / 0.38f;
            radius = revealRadius * (0.90f - 0.58f * phase);
            opacity = 0.95f;
        } else {
            float phase = (progress - 0.38f) / 0.62f;
            radius = revealRadius * (0.32f + 0.60f * phase);
            opacity = (1f - phase) * (1f - phase);
        }
        revealMatrix.setScale(radius, radius);
        revealMatrix.postTranslate(revealX, revealY);
        revealGradient.setLocalMatrix(revealMatrix);
        revealPaint.setAlpha(Math.round(255f * opacity));
        canvas.drawCircle(revealX, revealY, radius, revealPaint);

        float coreSize = Math.max(3f * density, revealRadius * 0.055f);
        corePaint.setColor(Color.WHITE);
        corePaint.setAlpha(Math.round(235f * opacity));
        canvas.save();
        canvas.rotate(12f - 24f * progress, revealX, revealY);
        canvas.drawRoundRect(revealX - coreSize, revealY - coreSize,
                revealX + coreSize, revealY + coreSize, density, density, corePaint);
        canvas.restore();
    }

    private void drawImpact(Canvas canvas) {
        float width = getWidth();
        float height = getHeight();
        if (width <= 0f || height <= 0f) return;
        float progress = impactProgress;
        float centerX = impactCenterX;
        float centerY = impactCenterY;
        float shortSide = Math.min(width, height);

        // The center flash lasts only the first 150 ms, leaving readable cards afterwards.
        float flash = Math.max(0f, 1f - progress * 7f);
        if (flash > 0f) {
            float radius = shortSide * (0.24f + 0.24f * progress);
            impactMatrix.setScale(radius, radius);
            impactMatrix.postTranslate(centerX, centerY);
            impactGradient.setLocalMatrix(impactMatrix);
            impactPaint.setAlpha(Math.round(255f * flash * flash));
            canvas.drawCircle(centerX, centerY, radius, impactPaint);
        }

        float tangentLength = (float) Math.sqrt(1f + seamSlope * seamSlope);
        float tangentX = seamSlope / tangentLength;
        float tangentY = 1f / tangentLength;
        for (int i = 0; i < SPARK_COUNT; i++) {
            float local = (progress - sparkDelay[i]) / 0.66f;
            if (local <= 0f || local >= 1f) continue;
            float side = (i & 1) == 0 ? -1f : 1f;
            float originY = height * (0.08f + sparkOrigin[i] * 0.84f);
            float originX = seamTopX + seamSlope * originY;
            float distance = shortSide * 0.38f * sparkTravel[i] * local;
            float spread = sparkOffset[i] * shortSide * (0.025f + local * 0.10f);
            float x = originX + tangentX * distance * side + spread;
            float y = originY + tangentY * distance * side;
            float length = density * (6f + 14f * sparkLength[i]) * (1f - local * 0.45f);
            float opacity = Math.min(1f, local * 7f) * (1f - local);
            sparkPaint.setColor(i % 5 == 0 ? 0xFFFFE8A0 : Color.WHITE);
            sparkPaint.setAlpha(Math.round(245f * opacity));
            sparkPaint.setStrokeWidth(density * (i % 3 == 0 ? 1.8f : 1.1f));
            canvas.drawLine(x, y, x - tangentX * length * side,
                    y - tangentY * length * side, sparkPaint);
        }
    }

    public void stop() {
        cancelReveal();
        cancelImpact();
        invalidate();
    }

    private void cancelReveal() {
        ValueAnimator previous = revealAnimator;
        revealAnimator = null;
        if (previous != null) previous.cancel();
        revealProgress = -1f;
    }

    private void cancelImpact() {
        ValueAnimator previous = impactAnimator;
        impactAnimator = null;
        if (previous != null) previous.cancel();
        impactProgress = -1f;
    }

    private static float fraction(float value) {
        return value - (float) Math.floor(value);
    }

    @Override protected void onDetachedFromWindow() {
        stop();
        super.onDetachedFromWindow();
    }
}
