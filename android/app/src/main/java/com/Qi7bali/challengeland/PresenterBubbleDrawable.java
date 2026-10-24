package com.qi7bali.landchallengeonline;

import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.ColorFilter;
import android.graphics.Paint;
import android.graphics.Path;
import android.graphics.PixelFormat;
import android.graphics.drawable.Drawable;

/** A single continuous outline whose tail points at the presenter's head. */
final class PresenterBubbleDrawable extends Drawable {
    private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Path path = new Path();
    private final float density;
    private float tailX;

    PresenterBubbleDrawable(float density) {
        this.density = density;
    }

    void setTailX(float tailX) {
        if (this.tailX == tailX) return;
        this.tailX = tailX;
        invalidateSelf();
    }

    @Override
    public void draw(Canvas canvas) {
        float inset = density;
        float right = getBounds().width() - inset;
        float bottom = getBounds().height() - inset;
        float radius = 10 * density;
        float bodyBottom = bottom - 12 * density;
        float tip = Math.max(radius + 9 * density, Math.min(right - radius - 9 * density, tailX));
        float halfTail = 7 * density;
        path.reset();
        path.moveTo(inset + radius, inset);
        path.lineTo(right - radius, inset);
        path.quadTo(right, inset, right, inset + radius);
        path.lineTo(right, bodyBottom - radius);
        path.quadTo(right, bodyBottom, right - radius, bodyBottom);
        path.lineTo(tip + halfTail, bodyBottom);
        path.lineTo(tip, bottom);
        path.lineTo(tip - halfTail, bodyBottom);
        path.lineTo(inset + radius, bodyBottom);
        path.quadTo(inset, bodyBottom, inset, bodyBottom - radius);
        path.lineTo(inset, inset + radius);
        path.quadTo(inset, inset, inset + radius, inset);
        path.close();
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(255, 253, 248));
        canvas.drawPath(path, paint);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(1.5f * density);
        paint.setColor(Color.rgb(38, 55, 84));
        canvas.drawPath(path, paint);
    }

    @Override public void setAlpha(int alpha) { paint.setAlpha(alpha); invalidateSelf(); }
    @Override public void setColorFilter(ColorFilter filter) { paint.setColorFilter(filter); invalidateSelf(); }
    @Override public int getOpacity() { return PixelFormat.TRANSLUCENT; }
}
