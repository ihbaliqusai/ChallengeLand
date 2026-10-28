package com.qi7bali.landchallengeonline;

import android.app.Dialog;
import android.content.Context;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.view.Gravity;
import android.view.View;
import android.view.Window;
import android.view.WindowManager;
import android.widget.TextView;
import androidx.core.content.res.ResourcesCompat;

/** Preserves the existing dialog callbacks and content with a common game frame. */
public final class GameNoticeDialogs {
    private GameNoticeDialogs() { }

    public static androidx.appcompat.app.AlertDialog.Builder builder(Context context) {
        return new androidx.appcompat.app.AlertDialog.Builder(context) {
            @Override public androidx.appcompat.app.AlertDialog create() {
                androidx.appcompat.app.AlertDialog dialog = super.create();
                dialog.setOnShowListener(ignored -> style(dialog));
                return dialog;
            }
            @Override public androidx.appcompat.app.AlertDialog show() {
                androidx.appcompat.app.AlertDialog dialog = super.show();
                style(dialog);
                return dialog;
            }
        };
    }

    public static android.app.AlertDialog.Builder platformBuilder(Context context) {
        return new android.app.AlertDialog.Builder(context) {
            @Override public android.app.AlertDialog create() {
                android.app.AlertDialog dialog = super.create();
                dialog.setOnShowListener(ignored -> style(dialog));
                return dialog;
            }
            @Override public android.app.AlertDialog show() {
                android.app.AlertDialog dialog = super.show();
                style(dialog);
                return dialog;
            }
        };
    }

    private static void style(Dialog dialog) {
        Window window = dialog.getWindow();
        if (window == null) return;
        Context context = dialog.getContext();
        float density = context.getResources().getDisplayMetrics().density;
        int accent = Color.parseColor("#67D9F5");
        GradientDrawable background = new GradientDrawable(
                GradientDrawable.Orientation.TL_BR,
                new int[]{Color.parseColor("#172341"), Color.parseColor("#0C1329")});
        background.setCornerRadius(24 * density);
        background.setStroke(Math.max(1, Math.round(density)), accent);
        window.setBackgroundDrawable(background);
        window.addFlags(WindowManager.LayoutParams.FLAG_DIM_BEHIND);
        window.setDimAmount(0.65f);
        window.setGravity(Gravity.CENTER);
        int width = context.getResources().getDisplayMetrics().widthPixels;
        window.setLayout(Math.min(Math.round(440 * density), width - Math.round(40 * density)),
                WindowManager.LayoutParams.WRAP_CONTENT);
        TextView message = dialog.findViewById(android.R.id.message);
        if (message != null) {
            message.setTextColor(Color.parseColor("#CBD5E1"));
            message.setTextSize(14);
            message.setTypeface(ResourcesCompat.getFont(context, R.font.baloo));
            message.setGravity(Gravity.CENTER);
            message.setLineSpacing(4 * density, 1f);
        }
        int titleId = context.getResources().getIdentifier("alertTitle", "id", context.getPackageName());
        if (titleId == 0) titleId = context.getResources().getIdentifier("alertTitle", "id", "android");
        TextView title = titleId == 0 ? null : dialog.findViewById(titleId);
        if (title != null) {
            title.setTextColor(Color.WHITE);
            title.setTextSize(21);
            title.setTypeface(ResourcesCompat.getFont(context, R.font.baloo), Typeface.BOLD);
            title.setGravity(Gravity.CENTER);
        }
        for (int id : new int[]{android.R.id.button1, android.R.id.button2, android.R.id.button3}) {
            TextView button = dialog.findViewById(id);
            if (button == null || button.getVisibility() != View.VISIBLE) continue;
            button.setSoundEffectsEnabled(false);
            button.setOnTouchListener((v, event) -> {
                if (event.getAction() == android.view.MotionEvent.ACTION_DOWN) {
                    AppSoundEffects.click(v.getContext());
                }
                return false;
            });
            boolean primary = id == android.R.id.button1;
            GradientDrawable buttonBackground = new GradientDrawable();
            buttonBackground.setCornerRadius(12 * density);
            buttonBackground.setColor(primary ? accent : Color.TRANSPARENT);
            if (!primary) buttonBackground.setStroke(Math.max(1, Math.round(density)), Color.parseColor("#3B4562"));
            button.setBackground(buttonBackground);
            button.setTextColor(primary ? Color.parseColor("#0B1328") : Color.WHITE);
            button.setAllCaps(false);
            button.setTypeface(ResourcesCompat.getFont(context, R.font.baloo), Typeface.BOLD);
            button.setTextSize(14);
            button.setMinHeight(Math.round(46 * density));
            button.setPadding(Math.round(18 * density), 0, Math.round(18 * density), 0);
        }
    }
}
