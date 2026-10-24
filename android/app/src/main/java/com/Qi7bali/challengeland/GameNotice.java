package com.qi7bali.landchallengeonline;

import android.app.Activity;
import android.content.Context;
import android.content.ContextWrapper;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.os.Handler;
import android.os.Looper;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.widget.FrameLayout;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;
import android.widget.Toast;
import androidx.core.content.res.ResourcesCompat;

import java.lang.ref.WeakReference;
import java.util.WeakHashMap;

/** Centered in-game feedback with the same frame used by the Flutter shell. */
public final class GameNotice {
    public enum Tone {
        INFO(R.drawable.ic_game_notice_info, 0xFF67D9F5, "تنبيه", "Notice"),
        SUCCESS(R.drawable.ic_game_notice_success, 0xFF6EE7B7, "تم بنجاح", "Success"),
        WARNING(R.drawable.ic_game_notice_warning, 0xFFFBBF24, "انتبه", "Heads up"),
        ERROR(R.drawable.ic_game_notice_error, 0xFFFB7185, "تعذّر إكمال الطلب", "Something went wrong");

        final int icon;
        final int color;
        final String arabicTitle;
        final String englishTitle;

        Tone(int icon, int color, String arabicTitle, String englishTitle) {
            this.icon = icon;
            this.color = color;
            this.arabicTitle = arabicTitle;
            this.englishTitle = englishTitle;
        }
    }

    private static final WeakHashMap<Activity, WeakReference<GameNotice>> ACTIVE = new WeakHashMap<>();
    private final Context context;
    private final CharSequence message;
    private final int duration;
    private Tone tone;
    private final Handler handler = new Handler(Looper.getMainLooper());
    private View card;
    private final Runnable dismiss = this::cancel;

    private GameNotice(Context context, CharSequence message, int duration) {
        this.context = context;
        this.message = message;
        this.duration = duration;
    }

    public static GameNotice makeText(Context context, CharSequence message, int duration) {
        return new GameNotice(context, message, duration);
    }

    public static GameNotice makeText(Context context, int message, int duration) {
        return makeText(context, context.getText(message), duration);
    }

    public GameNotice withTone(Tone tone) {
        this.tone = tone;
        return this;
    }

    public void show() {
        if (Looper.myLooper() != Looper.getMainLooper()) {
            handler.post(this::show);
            return;
        }
        Activity activity = activity(context);
        if (activity == null || activity.isFinishing() || activity.isDestroyed()) return;
        ViewGroup root = activity.findViewById(android.R.id.content);
        if (root == null || !root.isAttachedToWindow()) return;
        WeakReference<GameNotice> previous = ACTIVE.get(activity);
        if (previous != null && previous.get() != null) previous.get().cancel();
        ACTIVE.put(activity, new WeakReference<>(this));

        String text = message == null ? "" : message.toString();
        boolean arabic = text.matches("(?s).*[\\u0600-\\u06ff].*");
        boolean error = text.matches("(?s).*(تعذر|تعذّر|فشل|خطأ|غير صحيح|failed|error).*");
        boolean success = !error && text.matches("(?s).*(بنجاح|تم |مبروك|مرحب|success|copied).*");
        Tone resolvedTone = tone != null ? tone : error ? Tone.ERROR : success ? Tone.SUCCESS : Tone.INFO;
        int accent = resolvedTone.color;

        LinearLayout body = new LinearLayout(context);
        body.setOrientation(LinearLayout.VERTICAL);
        body.setGravity(Gravity.CENTER_HORIZONTAL);
        body.setPadding(dp(24), dp(14), dp(24), dp(22));
        body.setLayoutDirection(arabic ? View.LAYOUT_DIRECTION_RTL : View.LAYOUT_DIRECTION_LTR);

        FrameLayout heading = new FrameLayout(context);
        TextView brand = label(arabic ? "أرض التحدي" : "CHALLENGE LAND", 10, accent, true);
        heading.addView(brand, new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, dp(36), Gravity.CENTER));
        TextView close = label("×", 24, Color.parseColor("#94A3B8"), false);
        close.setContentDescription(arabic ? "إغلاق" : "Close");
        close.setOnClickListener(view -> cancel());
        heading.addView(close, new FrameLayout.LayoutParams(dp(44), dp(44), Gravity.END));
        body.addView(heading, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(44)));

        ImageView badge = new ImageView(context);
        badge.setImageResource(resolvedTone.icon);
        badge.setColorFilter(accent);
        badge.setPadding(dp(14), dp(14), dp(14), dp(14));
        badge.setImportantForAccessibility(View.IMPORTANT_FOR_ACCESSIBILITY_NO);
        badge.setBackground(background(accent & 0x00FFFFFF | 0x24000000,
                accent & 0x00FFFFFF | 0x66000000, 18));
        body.addView(badge, new LinearLayout.LayoutParams(dp(58), dp(58)));
        String title = arabic ? resolvedTone.arabicTitle : resolvedTone.englishTitle;
        TextView titleView = label(title, 21, Color.WHITE, true);
        titleView.setPadding(0, dp(14), 0, dp(8));
        body.addView(titleView);
        TextView content = label(text, 14, Color.parseColor("#CBD5E1"), false);
        content.setLineSpacing(dp(4), 1f);
        content.setAccessibilityLiveRegion(View.ACCESSIBILITY_LIVE_REGION_POLITE);
        body.addView(content, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));

        ScrollView panel = new ScrollView(context);
        panel.setFillViewport(false);
        panel.setClipToOutline(true);
        panel.setBackground(background(Color.parseColor("#10182F"), accent, 24));
        panel.setElevation(dp(18));
        panel.addView(body);
        panel.setClickable(true);
        panel.addOnAttachStateChangeListener(new View.OnAttachStateChangeListener() {
            @Override public void onViewAttachedToWindow(View view) { }
            @Override public void onViewDetachedFromWindow(View view) {
                handler.removeCallbacks(dismiss);
                card = null;
            }
        });
        card = panel;
        int availableWidth = root.getWidth() > 0 ? root.getWidth() : context.getResources().getDisplayMetrics().widthPixels;
        FrameLayout.LayoutParams params = new FrameLayout.LayoutParams(
                Math.max(dp(100), Math.min(dp(440), availableWidth - dp(40))),
                ViewGroup.LayoutParams.WRAP_CONTENT, Gravity.CENTER);
        params.setMargins(dp(20), dp(16), dp(20), dp(16));
        root.addView(panel, params);
        panel.setAlpha(0f);
        panel.setScaleX(0.94f);
        panel.setScaleY(0.94f);
        panel.animate().alpha(1f).scaleX(1f).scaleY(1f).setDuration(240).start();
        handler.postDelayed(dismiss, duration == Toast.LENGTH_LONG ? 5000 : 3200);
    }

    public void cancel() {
        handler.removeCallbacks(dismiss);
        if (card != null) {
            View previous = card;
            card = null;
            previous.animate().cancel();
            if (previous.getParent() instanceof ViewGroup) ((ViewGroup) previous.getParent()).removeView(previous);
        }
    }

    private TextView label(String text, int size, int color, boolean bold) {
        TextView label = new TextView(context);
        label.setText(text);
        label.setTextColor(color);
        label.setTextSize(size);
        label.setGravity(Gravity.CENTER);
        label.setTypeface(ResourcesCompat.getFont(context, R.font.baloo),
                bold ? Typeface.BOLD : Typeface.NORMAL);
        return label;
    }

    private GradientDrawable background(int fill, int stroke, int radius) {
        GradientDrawable drawable = new GradientDrawable(
                GradientDrawable.Orientation.TL_BR,
                new int[]{fill, fill == Color.parseColor("#10182F") ? Color.parseColor("#0C1329") : fill});
        drawable.setCornerRadius(dp(radius));
        drawable.setStroke(dp(1), stroke);
        return drawable;
    }

    private int dp(int value) { return Math.round(value * context.getResources().getDisplayMetrics().density); }

    private static Activity activity(Context context) {
        while (context instanceof ContextWrapper) {
            if (context instanceof Activity) return (Activity) context;
            Context next = ((ContextWrapper) context).getBaseContext();
            if (next == context) return null;
            context = next;
        }
        return null;
    }
}
