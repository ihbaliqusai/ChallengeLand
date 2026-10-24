package com.qi7bali.landchallengeonline;

import android.app.Activity;
import android.graphics.RectF;
import android.text.Layout;
import android.text.StaticLayout;
import android.text.TextPaint;
import android.text.method.ScrollingMovementMethod;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.ImageView;
import android.widget.RelativeLayout;
import android.widget.TextView;

/** Positions the presenter's callout using the visible head, including mirroring. */
final class PresenterBubbleController {
    private final RelativeLayout bubble;
    private final ViewGroup scene;
    private final View head;
    private final View question;
    private final View home;
    private final View volume;
    private final TextView text;
    private final float density;
    private final PresenterBubbleDrawable background;
    private String message = "";
    private boolean confirmation;

    PresenterBubbleController(Activity activity, RelativeLayout bubble) {
        this.bubble = bubble;
        scene = (ViewGroup) bubble.getParent();
        head = activity.findViewById(R.id.rlyHead);
        question = activity.findViewById(R.id.llyQA);
        home = activity.findViewById(R.id.imgHome);
        volume = activity.findViewById(R.id.imgVolume);
        text = activity.findViewById(R.id.txtDialog);
        density = activity.getResources().getDisplayMetrics().density;
        background = new PresenterBubbleDrawable(density);
        // The legacy image has a fixed tail which cannot follow the character.
        for (int index = 0; index < bubble.getChildCount(); index++) {
            if (bubble.getChildAt(index) instanceof ImageView) {
                bubble.getChildAt(index).setVisibility(View.GONE);
            }
        }
        bubble.setBackground(background);
        bubble.setLayoutDirection(View.LAYOUT_DIRECTION_LTR);
        text.setTextDirection(View.TEXT_DIRECTION_RTL);
        text.setGravity(Gravity.CENTER);
        text.setIncludeFontPadding(false);
        text.setMovementMethod(ScrollingMovementMethod.getInstance());
        text.setVerticalScrollBarEnabled(true);
        arrangeButton(activity.findViewById(R.id.btnDialogYes), true);
        arrangeButton(activity.findViewById(R.id.btnDialogNo), false);
        scene.addOnLayoutChangeListener((view, l, t, r, b, oldL, oldT, oldR, oldB) -> position());
    }

    void prepare(String message, boolean confirmation) {
        this.message = message;
        this.confirmation = confirmation;
        text.scrollTo(0, 0);
        position();
    }

    void show() {
        bubble.clearAnimation();
        bubble.animate().cancel();
        bubble.setAlpha(0f);
        bubble.animate().alpha(1f).setDuration(150).start();
    }

    private void arrangeButton(Button button, boolean yes) {
        if (button == null) return;
        RelativeLayout.LayoutParams params = new RelativeLayout.LayoutParams(dp(58), dp(24));
        params.addRule(RelativeLayout.ALIGN_PARENT_BOTTOM);
        params.addRule(yes ? RelativeLayout.ALIGN_PARENT_RIGHT : RelativeLayout.ALIGN_PARENT_LEFT);
        params.leftMargin = dp(12);
        params.rightMargin = dp(12);
        params.bottomMargin = dp(18);
        button.setLayoutParams(params);
        button.setPadding(0, 0, 0, 0);
        button.setMinHeight(0);
        button.setMinimumHeight(0);
        button.setTextSize(TypedValue.COMPLEX_UNIT_SP, 11);
    }

    private void position() {
        if (head == null || head.getWidth() == 0 || scene.getWidth() == 0) return;
        RectF face = sceneBounds(head);
        RectF questionBounds = question == null
                ? new RectF(dp(226), 0, scene.getWidth() - dp(226), scene.getHeight())
                : sceneBounds(question);
        boolean leftRail = face.centerX() < questionBounds.centerX();
        float railLeft = leftRail ? 0 : questionBounds.right + dp(10);
        float railRight = leftRail ? questionBounds.left - dp(10) : scene.getWidth() - dp(8);
        int width = Math.round(Math.min(dp(208), Math.max(dp(120),
                railRight - railLeft - (leftRail ? dp(8) : 0))));
        float left = Math.max(railLeft, Math.min(face.centerX() - width / 2f, railRight - width));
        float minimumTop = dp(12);
        // Navigation now occupies the opposite rail; only reserve vertical
        // space when a navigation button actually shares the callout's column.
        for (View navigation : new View[]{home, volume}) {
            if (navigation == null) continue;
            RectF bounds = sceneBounds(navigation);
            if (bounds.left < left + width && bounds.right > left) {
                minimumTop = Math.max(minimumTop, bounds.bottom + dp(8));
            }
        }
        float tipY = face.top + dp(4);
        int height = Math.round(Math.max(dp(56), Math.min(dp(confirmation ? 116 : 92), tipY - minimumTop)));
        int top = Math.round(Math.max(dp(8), tipY - height));

        RelativeLayout.LayoutParams params = (RelativeLayout.LayoutParams) bubble.getLayoutParams();
        if (params.width != width || params.height != height
                || params.leftMargin != Math.round(left) || params.topMargin != top
                || params.getRules()[RelativeLayout.ALIGN_PARENT_LEFT] != RelativeLayout.TRUE
                || params.getRules()[RelativeLayout.ALIGN_PARENT_TOP] != RelativeLayout.TRUE) {
            params = new RelativeLayout.LayoutParams(width, height);
            params.addRule(RelativeLayout.ALIGN_PARENT_LEFT);
            params.addRule(RelativeLayout.ALIGN_PARENT_TOP);
            params.leftMargin = Math.round(left);
            params.topMargin = top;
            bubble.setLayoutParams(params);
        }
        background.setTailX(face.centerX() - left);
        int bottom = dp(confirmation ? 48 : 22);
        text.setPadding(dp(12), dp(8), dp(12), bottom);
        fitText(width - dp(24), height - dp(8) - bottom);
    }

    private void fitText(int width, int height) {
        if (width <= 0 || height <= 0) return;
        TextPaint paint = new TextPaint(text.getPaint());
        float size = 14;
        for (; size > 10.5f; size -= .5f) {
            paint.setTextSize(TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_SP, size,
                    text.getResources().getDisplayMetrics()));
            StaticLayout layout = StaticLayout.Builder.obtain(message, 0, message.length(), paint, width)
                    .setAlignment(Layout.Alignment.ALIGN_CENTER).setIncludePad(false).build();
            if (layout.getHeight() <= height) break;
        }
        if (text.getTextSize() != paint.getTextSize() || size == 10.5f) {
            text.setTextSize(TypedValue.COMPLEX_UNIT_SP, size);
        }
    }

    private RectF sceneBounds(View descendant) {
        RectF bounds = new RectF(0, 0, descendant.getWidth(), descendant.getHeight());
        View current = descendant;
        while (current != scene && current.getParent() instanceof View) {
            current.getMatrix().mapRect(bounds);
            View parent = (View) current.getParent();
            bounds.offset(current.getLeft() - parent.getScrollX(), current.getTop() - parent.getScrollY());
            current = parent;
        }
        return bounds;
    }

    private int dp(float value) {
        return Math.round(value * density);
    }
}
