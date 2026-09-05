package com.qi7bali.landchallengeonline;

import android.content.Context;
import android.util.AttributeSet;
import android.view.KeyEvent;
import androidx.appcompat.widget.AppCompatEditText;

/**
 * Custom EditText for typing answers on board challenge questions.
 * Intercepts the BACK key via onKeyPreIme while the soft keyboard is active,
 * allowing the game to dismiss the keyboard cleanly and restore immersive fullscreen
 * without accidentally showing the exit confirmation dialog or quitting the match.
 */
public class BoardAnswerEditText extends AppCompatEditText {

    public interface OnKeyBackPressedListener {
        void onKeyBackPressed();
    }

    private OnKeyBackPressedListener onKeyBackPressedListener;

    public BoardAnswerEditText(Context context) {
        super(context);
    }

    public BoardAnswerEditText(Context context, AttributeSet attrs) {
        super(context, attrs);
    }

    public BoardAnswerEditText(Context context, AttributeSet attrs, int defStyleAttr) {
        super(context, attrs, defStyleAttr);
    }

    public void setOnKeyBackPressedListener(OnKeyBackPressedListener listener) {
        this.onKeyBackPressedListener = listener;
    }

    @Override
    public boolean onKeyPreIme(int keyCode, KeyEvent event) {
        if (keyCode == KeyEvent.KEYCODE_BACK && event.getAction() == KeyEvent.ACTION_UP) {
            if (onKeyBackPressedListener != null) {
                onKeyBackPressedListener.onKeyBackPressed();
                return true;
            }
        }
        return super.onKeyPreIme(keyCode, event);
    }
}
