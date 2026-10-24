package com.qi7bali.landchallengeonline;

import android.content.Context;
import android.os.Handler;
import android.util.AttributeSet;

public class Typewriter extends androidx.appcompat.widget.AppCompatTextView {

    private CharSequence mText;
    private int mIndex;
    private long mDelay = 500; //Default 500ms delay
    private Runnable onTextComplete;


    public Typewriter(Context context) {
        super(context);
    }

    public Typewriter(Context context, AttributeSet attrs) {
        super(context, attrs);
    }

    private Handler mHandler = new Handler();
    private Runnable characterAdder = new Runnable() {
        @Override
        public void run() {
            mIndex = Character.offsetByCodePoints(mText, mIndex, 1);
            setText(mText.subSequence(0, mIndex));
            if (mIndex < mText.length()) {
                mHandler.postDelayed(characterAdder, mDelay);
            } else if (onTextComplete != null) {
                Runnable completed = onTextComplete;
                onTextComplete = null;
                completed.run();
            }
        }
    };

    public void animateText(CharSequence text) {
        animateText(text, null);
    }

    public void animateText(CharSequence text, Runnable completed) {
        stopAnimation();
        mText = text == null ? "" : text;
        mIndex = 0;
        onTextComplete = completed;

        setText("");
        if (mText.length() == 0) {
            onTextComplete = null;
            if (completed != null) completed.run();
        } else {
            mHandler.postDelayed(characterAdder, mDelay);
        }
    }

    public void setCharacterDelay(long millis) {
        mDelay = Math.max(1, millis);
    }

    public void stopAnimation() {
        mHandler.removeCallbacks(characterAdder);
        onTextComplete = null;
    }

    @Override
    protected void onDetachedFromWindow() {
        stopAnimation();
        super.onDetachedFromWindow();
    }
}
