package com.qi7bali.landchallengeonline;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Path;
import android.graphics.drawable.Drawable;
import android.util.AttributeSet;
import android.widget.FrameLayout;

import androidx.core.graphics.Insets;

/** Extends modal shading to the window edges while its controls stay safe. */
public final class GameOverlayLayout extends FrameLayout {
    private Insets bleed = Insets.NONE;
    private final Path outside = new Path();

    public GameOverlayLayout(Context context, AttributeSet attributes) {
        super(context, attributes);
    }

    void setBleedInsets(Insets insets) {
        if (bleed.equals(insets)) return;
        bleed = insets;
        invalidate();
    }

    @Override
    public void draw(Canvas canvas) {
        Drawable background = getBackground();
        int width = getWidth(), height = getHeight();
        if (background != null && width > 0 && height > 0 && !bleed.equals(Insets.NONE)) {
            background.setBounds(0, 0, width, height);
            // Draw only the region outside the safe scene. The ordinary draw
            // paints its interior once, preserving translucent modal opacity.
            outside.reset();
            outside.setFillType(Path.FillType.EVEN_ODD);
            outside.addRect(-bleed.left, -bleed.top, width + bleed.right,
                    height + bleed.bottom, Path.Direction.CW);
            outside.addRect(0, 0, width, height, Path.Direction.CW);
            int saved = canvas.save();
            canvas.clipPath(outside);
            canvas.translate(-bleed.left, -bleed.top);
            canvas.scale((width + bleed.left + bleed.right) / (float) width,
                    (height + bleed.top + bleed.bottom) / (float) height);
            background.draw(canvas);
            canvas.restoreToCount(saved);
        }
        super.draw(canvas);
    }
}
