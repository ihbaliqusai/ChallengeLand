package com.qi7bali.landchallengeonline;

import android.content.Context;
import android.util.AttributeSet;
import android.util.TypedValue;
import android.widget.ImageView;

import androidx.appcompat.widget.AppCompatImageButton;
import androidx.appcompat.widget.TooltipCompat;

/** Native counterpart of Flutter's shared page back button. */
public final class GameBackButton extends AppCompatImageButton {
    public GameBackButton(Context context) {
        this(context, null);
    }

    public GameBackButton(Context context, AttributeSet attrs) {
        this(context, attrs, 0);
    }

    public GameBackButton(Context context, AttributeSet attrs, int defStyleAttr) {
        super(context, attrs, defStyleAttr);
        setImageResource(R.drawable.game_back_arrow);
        setScaleType(ImageView.ScaleType.FIT_CENTER);
        setSupportImageTintList(null);
        setSupportBackgroundTintList(null);
        int padding = Math.round(2 * getResources().getDisplayMetrics().density);
        setPadding(padding, padding, padding, padding);
        int size = Math.round(48 * getResources().getDisplayMetrics().density);
        setMinimumWidth(size);
        setMinimumHeight(size);
        TypedValue ripple = new TypedValue();
        if (context.getTheme().resolveAttribute(
                android.R.attr.selectableItemBackgroundBorderless, ripple, true)) {
            setBackgroundResource(ripple.resourceId);
        }
        updateLabel(getLayoutDirection());
        setFocusable(true);
        setSoundEffectsEnabled(false);
    }

    @Override
    public void onRtlPropertiesChanged(int layoutDirection) {
        super.onRtlPropertiesChanged(layoutDirection);
        updateLabel(layoutDirection);
    }

    @Override
    public boolean performClick() {
        AppSoundEffects.click(getContext());
        return super.performClick();
    }

    private void updateLabel(int layoutDirection) {
        String label = layoutDirection == LAYOUT_DIRECTION_RTL ? "رجوع" : "Back";
        setContentDescription(label);
        TooltipCompat.setTooltipText(this, label);
    }
}
