package net.androidgaming.millionaire2024;

import androidx.appcompat.app.AppCompatActivity;

import android.content.Intent;
import android.graphics.Color;
import android.graphics.drawable.GradientDrawable;
import android.os.Bundle;
import android.view.View;
import android.view.Window;
import android.view.WindowManager;
import android.widget.FrameLayout;
import android.widget.TextView;

/**
 * Pre-game setup for the offline ("mono") mode: choose the number of players
 * (2-8) and the character the human player will use, then launch the game.
 */
public class OfflineSetupActivity extends AppCompatActivity {
    static final int MIN_PLAYERS = 2;
    static final int MAX_PLAYERS = 8;

    private int playerCount = 4;
    private int characterIndex = 0;
    private TextView txtPlayerCount;
    private final int[] charSlotIds = {
            R.id.charSlot0, R.id.charSlot1, R.id.charSlot2, R.id.charSlot3,
            R.id.charSlot4, R.id.charSlot5, R.id.charSlot6, R.id.charSlot7
    };
    private final FrameLayout[] charSlots = new FrameLayout[charSlotIds.length];

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        supportRequestWindowFeature(Window.FEATURE_NO_TITLE);
        super.onCreate(savedInstanceState);
        getWindow().setFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN,
                WindowManager.LayoutParams.FLAG_FULLSCREEN);
        getWindow().getDecorView().setSystemUiVisibility(View.SYSTEM_UI_FLAG_HIDE_NAVIGATION);
        setContentView(R.layout.activity_offline_setup);
        if (getSupportActionBar() != null) getSupportActionBar().hide();

        txtPlayerCount = findViewById(R.id.txtPlayerCount);
        updateCountLabel();

        findViewById(R.id.btnMinus).setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                if (playerCount > MIN_PLAYERS) {
                    playerCount--;
                    updateCountLabel();
                }
            }
        });
        findViewById(R.id.btnPlus).setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                if (playerCount < MAX_PLAYERS) {
                    playerCount++;
                    updateCountLabel();
                }
            }
        });

        for (int i = 0; i < charSlots.length; i++) {
            final int idx = i;
            charSlots[i] = findViewById(charSlotIds[i]);
            charSlots[i].setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View v) {
                    selectCharacter(idx);
                }
            });
        }
        selectCharacter(characterIndex);

        findViewById(R.id.btnStartOffline).setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                Intent intent = new Intent(OfflineSetupActivity.this, GameActivity.class);
                intent.putExtra("mode", "mono");
                intent.putExtra("playerCount", playerCount);
                intent.putExtra("characterIndex", characterIndex);
                startActivity(intent);
                finish();
            }
        });
    }

    private void updateCountLabel() {
        if (txtPlayerCount != null) {
            txtPlayerCount.setText(String.valueOf(playerCount));
        }
    }

    private void selectCharacter(int index) {
        characterIndex = index;
        for (int i = 0; i < charSlots.length; i++) {
            if (charSlots[i] == null) {
                continue;
            }
            charSlots[i].setBackground(i == index ? selectedBorder() : null);
        }
    }

    private GradientDrawable selectedBorder() {
        GradientDrawable drawable = new GradientDrawable();
        drawable.setColor(0x3329B6F6);
        drawable.setCornerRadius(dp(12));
        drawable.setStroke(dp(3), Color.parseColor("#FFC107"));
        return drawable;
    }

    private int dp(int value) {
        return Math.round(getResources().getDisplayMetrics().density * value);
    }

    @Override
    public void onWindowFocusChanged(boolean hasFocus) {
        super.onWindowFocusChanged(hasFocus);
        if (hasFocus) {
            getWindow().getDecorView().setSystemUiVisibility(
                    View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                            | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                            | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                            | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                            | View.SYSTEM_UI_FLAG_FULLSCREEN
                            | View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY);
        }
    }
}
