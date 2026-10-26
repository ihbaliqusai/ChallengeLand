package com.qi7bali.landchallengeonline;

import android.animation.ValueAnimator;
import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.LinearGradient;
import android.graphics.Paint;
import android.graphics.Path;
import android.graphics.RadialGradient;
import android.graphics.Shader;
import android.util.AttributeSet;
import android.view.View;
import android.view.animation.DecelerateInterpolator;

import java.util.Random;

/**
 * High-performance background view for the matchmaking screen.
 * - In searching mode: Renders a deep cosmic gradient with twinkling ambient stars.
 * - In versus mode: Sweeps a dramatic dynamic diagonal split (Blue on left, Hot Magenta on right)
 *   with an electric neon laser seam, exactly matching the reference video.
 */
public class MatchmakingSplitBackgroundView extends View {

    private final Paint bgPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint leftPolyPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint rightPolyPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint seamGlowPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint seamCorePaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint flashPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint starPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint streakPaint = new Paint(Paint.ANTI_ALIAS_FLAG);

    private final Path leftPath = new Path();
    private final Path rightPath = new Path();
    private final Path seamPath = new Path();

    private boolean isSplit = false;
    private float splitProgress = 0f;
    private float flashAlpha = 0f;

    // Twinkling background stars
    private static final int STAR_COUNT = 38;
    private final float[] starX = new float[STAR_COUNT];
    private final float[] starY = new float[STAR_COUNT];
    private final float[] starSize = new float[STAR_COUNT];
    private final float[] starAlpha = new float[STAR_COUNT];
    private final float[] starSpeed = new float[STAR_COUNT];
    private float time = 0f;

    public MatchmakingSplitBackgroundView(Context context) {
        super(context);
        init();
    }

    public MatchmakingSplitBackgroundView(Context context, AttributeSet attrs) {
        super(context, attrs);
        init();
    }

    public MatchmakingSplitBackgroundView(Context context, AttributeSet attrs, int defStyleAttr) {
        super(context, attrs, defStyleAttr);
        init();
    }

    private void init() {
        setLayerType(LAYER_TYPE_HARDWARE, null);

        seamGlowPaint.setStyle(Paint.Style.STROKE);
        seamGlowPaint.setStrokeWidth(14f);
        seamGlowPaint.setColor(Color.argb(120, 255, 255, 255));

        seamCorePaint.setStyle(Paint.Style.STROKE);
        seamCorePaint.setStrokeWidth(4.5f);
        seamCorePaint.setColor(Color.WHITE);

        flashPaint.setColor(Color.WHITE);
        flashPaint.setStyle(Paint.Style.FILL);

        streakPaint.setStyle(Paint.Style.STROKE);
        streakPaint.setStrokeCap(Paint.Cap.ROUND);

        // Generate stars
        Random rnd = new Random(42);
        for (int i = 0; i < STAR_COUNT; i++) {
            starX[i] = rnd.nextFloat();
            starY[i] = rnd.nextFloat();
            starSize[i] = 1.2f + rnd.nextFloat() * 2.8f;
            starAlpha[i] = 0.25f + rnd.nextFloat() * 0.75f;
            starSpeed[i] = 1.5f + rnd.nextFloat() * 3.5f;
        }
    }

    /**
     * Triggers the dramatic diagonal split-screen transition.
     */
    public void triggerSplitTransition() {
        if (isSplit) return;
        isSplit = true;

        // Flash animation
        flashAlpha = 0.85f;
        ValueAnimator flashAnim = ValueAnimator.ofFloat(0.85f, 0f);
        flashAnim.setDuration(280);
        flashAnim.addUpdateListener(animation -> {
            flashAlpha = (float) animation.getAnimatedValue();
            invalidate();
        });
        flashAnim.start();

        // Split slam sweep animation
        ValueAnimator splitAnim = ValueAnimator.ofFloat(0f, 1f);
        splitAnim.setDuration(450);
        splitAnim.setInterpolator(new DecelerateInterpolator(2.0f));
        splitAnim.addUpdateListener(animation -> {
            splitProgress = (float) animation.getAnimatedValue();
            invalidate();
        });
        splitAnim.start();
    }

    @Override
    protected void onDraw(Canvas canvas) {
        super.onDraw(canvas);
        final int w = getWidth();
        final int h = getHeight();
        if (w <= 0 || h <= 0) return;

        time += 0.05f;

        // 1. Draw base deep space gradient
        bgPaint.setShader(new RadialGradient(
                w * 0.5f, h * 0.45f, Math.max(w, h) * 0.7f,
                new int[]{0xFF131138, 0xFF0A0920, 0xFF04030E},
                new float[]{0f, 0.55f, 1f},
                Shader.TileMode.CLAMP
        ));
        canvas.drawRect(0, 0, w, h, bgPaint);

        // 2. Draw ambient twinkling stars (if not fully split)
        if (splitProgress < 1f) {
            float baseAlpha = 1f - splitProgress;
            for (int i = 0; i < STAR_COUNT; i++) {
                float pulse = 0.5f + 0.5f * (float) Math.sin(time * starSpeed[i] + i);
                int alpha = (int) (255 * starAlpha[i] * pulse * baseAlpha);
                if (alpha <= 0) continue;
                starPaint.setColor(Color.argb(alpha, 255, 255, 255));
                float sx = starX[i] * w;
                float sy = starY[i] * h;
                canvas.drawCircle(sx, sy, starSize[i], starPaint);

                // Cross sparkle on brighter stars
                if (starSize[i] > 2.8f && pulse > 0.75f) {
                    starPaint.setStrokeWidth(1.2f);
                    float span = starSize[i] * 2.2f;
                    canvas.drawLine(sx - span, sy, sx + span, sy, starPaint);
                    canvas.drawLine(sx, sy - span, sx, sy + span, starPaint);
                }
            }
            // Trigger gentle continuous repaint for twinkling stars in search mode
            if (!isSplit) {
                postInvalidateDelayed(40);
            }
        }

        // 3. Draw Versus Diagonal Split
        if (splitProgress > 0f) {
            // Diagonal division:
            // Top point: x = w * 0.56f
            // Bottom point: x = w * 0.44f
            final float targetTopX = w * 0.56f;
            final float targetBottomX = w * 0.44f;

            // Animate split entering from screen edges or center
            final float curTopX = w * 0.5f + (targetTopX - w * 0.5f) * splitProgress;
            final float curBottomX = w * 0.5f + (targetBottomX - w * 0.5f) * splitProgress;

            // Left polygon (Electric Blue)
            leftPath.reset();
            leftPath.moveTo(0, 0);
            leftPath.lineTo(curTopX, 0);
            leftPath.lineTo(curBottomX, h);
            leftPath.lineTo(0, h);
            leftPath.close();

            leftPolyPaint.setShader(new LinearGradient(
                    0, 0, curTopX, h,
                    new int[]{0xFF0084FF, 0xFF005BD6, 0xFF003F9E},
                    new float[]{0f, 0.65f, 1f},
                    Shader.TileMode.CLAMP
            ));
            leftPolyPaint.setAlpha((int) (255 * Math.min(1f, splitProgress * 1.5f)));
            canvas.drawPath(leftPath, leftPolyPaint);

            // Right polygon (Hot Magenta / Coral Red)
            rightPath.reset();
            rightPath.moveTo(curTopX, 0);
            rightPath.lineTo(w, 0);
            rightPath.lineTo(w, h);
            rightPath.lineTo(curBottomX, h);
            rightPath.close();

            rightPolyPaint.setShader(new LinearGradient(
                    curTopX, 0, w, h,
                    new int[]{0xFFFF2A85, 0xFFE60060, 0xFF9E003D},
                    new float[]{0f, 0.65f, 1f},
                    Shader.TileMode.CLAMP
            ));
            rightPolyPaint.setAlpha((int) (255 * Math.min(1f, splitProgress * 1.5f)));
            canvas.drawPath(rightPath, rightPolyPaint);

            // Dynamic angled speed streaks for action energy
            canvas.save();
            canvas.clipPath(leftPath);
            streakPaint.setColor(Color.argb(35, 255, 255, 255));
            streakPaint.setStrokeWidth(2.5f);
            for (int i = 0; i < 5; i++) {
                float yOffset = h * (0.15f + i * 0.18f);
                canvas.drawLine(w * 0.05f + i * 15, yOffset, w * 0.35f + i * 25, yOffset - 30, streakPaint);
            }
            canvas.restore();

            canvas.save();
            canvas.clipPath(rightPath);
            streakPaint.setColor(Color.argb(35, 255, 255, 255));
            streakPaint.setStrokeWidth(2.5f);
            for (int i = 0; i < 5; i++) {
                float yOffset = h * (0.18f + i * 0.18f);
                canvas.drawLine(w * 0.65f + i * 15, yOffset, w * 0.95f + i * 25, yOffset - 30, streakPaint);
            }
            canvas.restore();

            // Diagonal dividing seam (black crisp line + neon laser core)
            seamPath.reset();
            seamPath.moveTo(curTopX, -10);
            seamPath.lineTo(curBottomX, h + 10);

            // 1. Dark comic divider edge behind seam
            Paint seamDarkPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
            seamDarkPaint.setStyle(Paint.Style.STROKE);
            seamDarkPaint.setStrokeWidth(6.5f);
            seamDarkPaint.setColor(0xFF0F040A);
            canvas.drawPath(seamPath, seamDarkPaint);

            // 2. Multi-layer neon aura & crisp white core
            seamGlowPaint.setColor(Color.argb((int) (180 * splitProgress), 255, 230, 160));
            seamGlowPaint.setStrokeWidth(14f);
            canvas.drawPath(seamPath, seamGlowPaint);

            seamCorePaint.setColor(Color.WHITE);
            seamCorePaint.setStrokeWidth(3.5f);
            seamCorePaint.setAlpha((int) (255 * splitProgress));
            canvas.drawPath(seamPath, seamCorePaint);

            // 3. Dynamic Comic Speed Slashes exploding along the seam (matching frame_014.png)
            if (splitProgress > 0.3f) {
                float slashAlpha = Math.min(1f, (splitProgress - 0.3f) / 0.7f);
                streakPaint.setColor(Color.argb((int) (235 * slashAlpha), 255, 255, 255));
                streakPaint.setStrokeCap(Paint.Cap.ROUND);

                final float[] slashFractions = {
                        0.08f, 0.14f, 0.20f, 0.27f, 0.33f, 0.40f, 0.47f,
                        0.55f, 0.62f, 0.68f, 0.75f, 0.82f, 0.89f, 0.95f
                };
                final float[] slashLengths = {
                        42f, 26f, 54f, 32f, 60f, 38f, 65f,
                        50f, 35f, 58f, 30f, 52f, 28f, 44f
                };
                final float[] slashAngles = {
                        -0.55f, 0.45f, -0.7f, 0.6f, -0.45f, 0.65f, -0.6f,
                        0.55f, -0.75f, 0.5f, -0.65f, 0.6f, -0.5f, 0.4f
                };
                final float[] slashOffsets = {
                        -18f, 20f, -28f, 24f, -32f, 36f, -25f,
                        28f, -34f, 26f, -22f, 30f, -16f, 22f
                };

                for (int i = 0; i < slashFractions.length; i++) {
                    float frac = slashFractions[i];
                    float sy = frac * h;
                    float sx = curTopX + (curBottomX - curTopX) * frac + slashOffsets[i] * splitProgress;

                    float len = slashLengths[i] * (0.6f + 0.4f * splitProgress);
                    float angle = slashAngles[i];
                    float dx = (float) Math.cos(angle) * len;
                    float dy = (float) Math.sin(angle) * len;

                    streakPaint.setStrokeWidth(3.5f + (i % 3) * 1.5f);
                    canvas.drawLine(sx, sy, sx + dx, sy + dy, streakPaint);

                    // Outer cyan energy halo on major slashes
                    if (i % 2 == 0) {
                        streakPaint.setColor(Color.argb((int) (90 * slashAlpha), 180, 240, 255));
                        streakPaint.setStrokeWidth(7.5f);
                        canvas.drawLine(sx, sy, sx + dx, sy + dy, streakPaint);
                        streakPaint.setColor(Color.argb((int) (235 * slashAlpha), 255, 255, 255));
                    }
                }
            }
        }

        // 4. White flash overlay on split impact
        if (flashAlpha > 0.01f) {
            flashPaint.setAlpha((int) (255 * flashAlpha));
            canvas.drawRect(0, 0, w, h, flashPaint);
        }
    }
}
