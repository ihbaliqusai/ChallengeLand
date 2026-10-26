package com.qi7bali.landchallengeonline;

import android.animation.ValueAnimator;
import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.LinearGradient;
import android.graphics.Paint;
import android.graphics.RadialGradient;
import android.graphics.Rect;
import android.graphics.RectF;
import android.graphics.Shader;
import android.graphics.Typeface;
import android.util.AttributeSet;
import android.view.View;
import android.view.animation.LinearInterpolator;
import android.view.animation.OvershootInterpolator;

/**
 * Animated Versus Badge:
 * - In searching mode: Authentic 3D Metallic Lavender/Purple "VS" emblem (vs.png)
 *   with physical floating bobbing, harmonic breathing scale, and dynamic 3D tilt.
 * - In versus transition: Explodes into a giant 3D Comic Action Golden "VS" with dark comic outline,
 *   3D bevel shadow, specular shine highlights, star sparkles, and an expanding shockwave ring.
 */
public class MatchmakingVersusBadgeView extends View {

    private final Paint circleBgPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint circleBorderPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint vsTextPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint vsStrokePaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint vsShadowPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint shockwavePaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint sparklePaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint bitmapPaint = new Paint(Paint.ANTI_ALIAS_FLAG | Paint.FILTER_BITMAP_FLAG);

    private Bitmap vsSearchBitmap;
    private Bitmap vsExplodedBitmap;
    private final RectF dstRect = new RectF();

    private boolean isExploded = false;
    private float shockwaveRadius = 0f;
    private float shockwaveAlpha = 0f;

    private ValueAnimator breatheAnim;

    public MatchmakingVersusBadgeView(Context context) {
        super(context);
        init();
    }

    public MatchmakingVersusBadgeView(Context context, AttributeSet attrs) {
        super(context, attrs);
        init();
    }

    public MatchmakingVersusBadgeView(Context context, AttributeSet attrs, int defStyleAttr) {
        super(context, attrs, defStyleAttr);
        init();
    }

    private void init() {
        circleBorderPaint.setStyle(Paint.Style.STROKE);
        circleBorderPaint.setStrokeWidth(3.5f);
        circleBorderPaint.setColor(0xFF9D67FF);

        vsTextPaint.setTextAlign(Paint.Align.CENTER);
        vsTextPaint.setTypeface(Typeface.create(Typeface.DEFAULT, Typeface.BOLD));

        vsStrokePaint.setTextAlign(Paint.Align.CENTER);
        vsStrokePaint.setStyle(Paint.Style.STROKE);
        vsStrokePaint.setTypeface(Typeface.create(Typeface.DEFAULT, Typeface.BOLD));

        vsShadowPaint.setTextAlign(Paint.Align.CENTER);
        vsShadowPaint.setStyle(Paint.Style.FILL_AND_STROKE);
        vsShadowPaint.setColor(0xFF2B0A00);
        vsShadowPaint.setTypeface(Typeface.create(Typeface.DEFAULT, Typeface.BOLD));

        shockwavePaint.setStyle(Paint.Style.STROKE);
        shockwavePaint.setColor(Color.WHITE);

        sparklePaint.setColor(Color.WHITE);
        sparklePaint.setStyle(Paint.Style.FILL);

        try {
            vsSearchBitmap = BitmapFactory.decodeResource(getResources(), R.drawable.ic_match_vs_badge);
        } catch (Exception ignored) {}
        try {
            vsExplodedBitmap = BitmapFactory.decodeResource(getResources(), R.drawable.img_vs_golden_exploded);
        } catch (Exception ignored) {}

        startBreathingAnimation();
    }

    private void startBreathingAnimation() {
        breatheAnim = ValueAnimator.ofFloat(0f, (float) (Math.PI * 2));
        breatheAnim.setDuration(2600);
        breatheAnim.setRepeatCount(ValueAnimator.INFINITE);
        breatheAnim.setInterpolator(new LinearInterpolator());
        breatheAnim.addUpdateListener(animation -> {
            if (!isExploded) {
                float angle = (float) animation.getAnimatedValue();
                // 1. Smooth physical 3D vertical bobbing (±6px)
                setTranslationY((float) Math.sin(angle) * 6f);
                // 2. Harmonic breathing scale (0.96 to 1.04)
                float s = 1.0f + 0.04f * (float) Math.sin(angle * 2);
                setScaleX(s);
                setScaleY(s);
                // 3. Subtle floating tilt rotation (-3° to +3°)
                setRotation((float) Math.sin(angle) * 3f);
            }
        });
        breatheAnim.start();
    }

    /**
     * Triggers the comic golden explosion of the "VS" emblem when the opponent is matched.
     */
    public void explodeToGoldenVersus() {
        if (isExploded) return;
        isExploded = true;
        if (breatheAnim != null) {
            breatheAnim.cancel();
        }
        setTranslationY(0f);
        setRotation(0f);
        invalidate();

        // Punchy spring scale on View (expands unclipped into layoutArena)
        ValueAnimator scaleAnim = ValueAnimator.ofFloat(0.40f, 1.25f, 1.08f);
        scaleAnim.setDuration(550);
        scaleAnim.setInterpolator(new OvershootInterpolator(3.0f));
        scaleAnim.addUpdateListener(animation -> {
            float s = (float) animation.getAnimatedValue();
            setScaleX(s);
            setScaleY(s);
        });
        scaleAnim.start();

        // Expanding shockwave ring
        ValueAnimator shockAnim = ValueAnimator.ofFloat(0f, 1f);
        shockAnim.setDuration(600);
        shockAnim.addUpdateListener(animation -> {
            float frac = animation.getAnimatedFraction();
            shockwaveRadius = frac * Math.min(getWidth(), getHeight()) * 0.48f;
            shockwaveAlpha = (1f - frac);
            invalidate();
        });
        shockAnim.start();
    }

    @Override
    protected void onDraw(Canvas canvas) {
        super.onDraw(canvas);
        final int w = getWidth();
        final int h = getHeight();
        if (w <= 0 || h <= 0) return;

        final float cx = w * 0.5f;
        final float cy = h * 0.5f;

        if (!isExploded) {
            // 1. Searching Mode: High-Res 3D Metallic Lavender/Purple VS Emblem (vs.png)
            if (vsSearchBitmap != null && !vsSearchBitmap.isRecycled()) {
                // Soft glowing radial purple aura behind the floating emblem
                float r = Math.min(cx, cy) * 0.52f;
                circleBgPaint.setStyle(Paint.Style.FILL);
                circleBgPaint.setShader(new RadialGradient(
                        cx, cy, r * 1.3f,
                        new int[]{0x55B388FF, 0x1A8B5CF6, 0x00000000},
                        new float[]{0f, 0.60f, 1f},
                        Shader.TileMode.CLAMP
                ));
                canvas.drawCircle(cx, cy, r * 1.3f, circleBgPaint);

                // Draw vsSearchBitmap fitted to View with safe margin
                final float bmpAspect = vsSearchBitmap.getWidth() / (float) vsSearchBitmap.getHeight();
                final float viewAspect = w / (float) h;
                float targetW, targetH;
                if (bmpAspect > viewAspect) {
                    targetW = w * 0.92f;
                    targetH = targetW / bmpAspect;
                } else {
                    targetH = h * 0.92f;
                    targetW = targetH * bmpAspect;
                }
                dstRect.set(cx - targetW * 0.5f, cy - targetH * 0.5f, cx + targetW * 0.5f, cy + targetH * 0.5f);
                canvas.drawBitmap(vsSearchBitmap, null, dstRect, bitmapPaint);
            } else {
                // Vector fallback if bitmap decoding fails
                float r = Math.min(cx, cy) * 0.48f;
                circleBgPaint.setStyle(Paint.Style.FILL);
                circleBgPaint.setShader(new RadialGradient(
                        cx, cy, r * 1.4f,
                        new int[]{0x669D67FF, 0x228B5CF6, 0x00000000},
                        new float[]{0f, 0.55f, 1f},
                        Shader.TileMode.CLAMP
                ));
                canvas.drawCircle(cx, cy, r * 1.4f, circleBgPaint);

                circleBgPaint.setShader(null);
                circleBgPaint.setColor(0x551E0E38);
                canvas.drawCircle(cx, cy, r * 0.9f, circleBgPaint);

                circleBorderPaint.setColor(0x88B388FF);
                circleBorderPaint.setStrokeWidth(2.5f);
                canvas.drawCircle(cx, cy, r * 0.9f, circleBorderPaint);

                vsTextPaint.setTextSize(r * 1.05f);
                vsTextPaint.setColor(Color.WHITE);
                vsTextPaint.setShader(new LinearGradient(
                        cx, cy - r * 0.45f, cx, cy + r * 0.45f,
                        new int[]{0xFFFFFFFF, 0xFFDDD6FE, 0xFFB388FF},
                        new float[]{0f, 0.5f, 1f},
                        Shader.TileMode.CLAMP
                ));
                Paint.FontMetrics fm = vsTextPaint.getFontMetrics();
                float textY = cy - (fm.ascent + fm.descent) * 0.5f;

                vsStrokePaint.setTextSize(r * 1.05f);
                vsStrokePaint.setStrokeWidth(4.5f);
                vsStrokePaint.setColor(0xAA3B136E);
                canvas.drawText("Vs", cx, textY, vsStrokePaint);

                canvas.drawText("Vs", cx, textY, vsTextPaint);
            }

        } else {
            // 2. Exploded Mode: Dynamic Comic 3D Action Golden "VS"
            // Draw expanding shockwave ring
            if (shockwaveAlpha > 0.01f && shockwaveRadius > 0f) {
                shockwavePaint.setStrokeWidth(5f * shockwaveAlpha);
                shockwavePaint.setColor(Color.argb((int) (220 * shockwaveAlpha), 255, 230, 100));
                canvas.drawCircle(cx, cy, shockwaveRadius, shockwavePaint);
            }

            if (vsExplodedBitmap != null && !vsExplodedBitmap.isRecycled()) {
                final float bmpAspect = vsExplodedBitmap.getWidth() / (float) vsExplodedBitmap.getHeight();
                final float viewAspect = w / (float) h;
                float targetW, targetH;
                if (bmpAspect > viewAspect) {
                    targetW = w * 0.94f;
                    targetH = targetW / bmpAspect;
                } else {
                    targetH = h * 0.94f;
                    targetW = targetH * bmpAspect;
                }
                dstRect.set(cx - targetW * 0.5f, cy - targetH * 0.5f, cx + targetW * 0.5f, cy + targetH * 0.5f);
                canvas.drawBitmap(vsExplodedBitmap, null, dstRect, bitmapPaint);
            } else {
                canvas.save();
                canvas.rotate(-8f, cx, cy);

                final float fontSize = Math.min(w, h) * 0.65f;
                vsTextPaint.setTextSize(fontSize);
                vsStrokePaint.setTextSize(fontSize);
                vsShadowPaint.setTextSize(fontSize);

                Paint.FontMetrics fm = vsTextPaint.getFontMetrics();
                float textY = cy - (fm.ascent + fm.descent) * 0.5f;

                final String text = "VS";

                // A. Deep 3D Shadow extrusion (draw layered offset shadows)
                vsShadowPaint.setColor(0xFF2A0E00);
                vsShadowPaint.setStrokeWidth(12f);
                for (int off = 8; off >= 1; off--) {
                    canvas.drawText(text, cx + off * 0.7f, textY + off * 0.9f, vsShadowPaint);
                }

                // B. Thick Dark Comic Outline
                vsStrokePaint.setStrokeWidth(11f);
                vsStrokePaint.setColor(0xFF150400);
                canvas.drawText(text, cx, textY, vsStrokePaint);

                // C. Secondary accent stroke (Deep Red/Orange)
                vsStrokePaint.setStrokeWidth(5.5f);
                vsStrokePaint.setColor(0xFFD9480F);
                canvas.drawText(text, cx, textY, vsStrokePaint);

                // D. Bright Golden Gradient Fill (Yellow to Rich Orange)
                vsTextPaint.setShader(new LinearGradient(
                        cx, textY + fm.ascent, cx, textY + fm.descent,
                        new int[]{0xFFFFFDE7, 0xFFFFE600, 0xFFFF8800},
                        new float[]{0f, 0.45f, 1f},
                        Shader.TileMode.CLAMP
                ));
                canvas.drawText(text, cx, textY, vsTextPaint);

                // E. Sparkle Stars
                drawSparkle(canvas, cx - fontSize * 0.38f, textY - fontSize * 0.35f, 10f);
                drawSparkle(canvas, cx + fontSize * 0.42f, textY - fontSize * 0.28f, 11f);
                drawSparkle(canvas, cx + fontSize * 0.12f, textY + fontSize * 0.32f, 8f);
                canvas.restore();
            }
        }
    }

    private void drawSparkle(Canvas canvas, float x, float y, float size) {
        sparklePaint.setColor(Color.WHITE);
        canvas.drawCircle(x, y, size * 0.25f, sparklePaint);
        // Horizontal ray
        canvas.drawRect(x - size, y - size * 0.18f, x + size, y + size * 0.18f, sparklePaint);
        // Vertical ray
        canvas.drawRect(x - size * 0.18f, y - size, x + size * 0.18f, y + size, sparklePaint);
    }

    @Override
    protected void onDetachedFromWindow() {
        super.onDetachedFromWindow();
        if (breatheAnim != null) {
            breatheAnim.cancel();
        }
    }
}
