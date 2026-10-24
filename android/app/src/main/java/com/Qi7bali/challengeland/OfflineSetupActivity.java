package com.qi7bali.landchallengeonline;


import android.content.Intent;
import android.os.Bundle;
import android.view.View;
import android.view.Window;
import android.view.WindowManager;
import android.widget.TextView;

/**
 * Pre-game setup for the offline ("mono") mode: choose the number of players
 * (2-8), then launch the game. The human player's character is no longer picked
 * here — it comes from the app-wide character selection
 * ({@link AppPrefs#getEffectiveCharacter(android.content.Context)}).
 */
public class OfflineSetupActivity extends GameViewportActivity {
    static final int MIN_PLAYERS = 2;
    static final int MAX_PLAYERS = 8;

    private int playerCount = 4;
    private TextView txtPlayerCount;
    private TextView txtPlayersHint;

    private final int[] chipIds = {R.id.chip2, R.id.chip4, R.id.chip6, R.id.chip8};
    private final int[] chipValues = {2, 4, 6, 8};
    private final TextView[] chips = new TextView[chipIds.length];

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
        txtPlayersHint = findViewById(R.id.txtPlayersHint);

        findViewById(R.id.btnBack).setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                finish();
            }
        });

        findViewById(R.id.btnMinus).setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                setPlayerCount(playerCount - 1);
            }
        });
        findViewById(R.id.btnPlus).setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                setPlayerCount(playerCount + 1);
            }
        });

        for (int i = 0; i < chips.length; i++) {
            final int value = chipValues[i];
            chips[i] = findViewById(chipIds[i]);
            chips[i].setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View v) {
                    setPlayerCount(value);
                }
            });
        }

        findViewById(R.id.btnStartOffline).setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                Intent intent = new Intent(OfflineSetupActivity.this, GameActivity.class);
                intent.putExtra("mode", "mono");
                intent.putExtra("playerCount", playerCount);
                if (getIntent().getBooleanExtra("localTeams", false)) {
                    intent.putExtra("localTeams", true);
                }
                intent.putExtra("characterIndex",
                        AppPrefs.getEffectiveCharacter(OfflineSetupActivity.this));
                startActivity(intent);
                finish();
            }
        });

        updateUi();
    }

    private void setPlayerCount(int value) {
        playerCount = Math.max(MIN_PLAYERS, Math.min(MAX_PLAYERS, value));
        updateUi();
    }

    private void updateUi() {
        if (txtPlayerCount != null) {
            txtPlayerCount.setText(String.valueOf(playerCount));
        }
        if (txtPlayersHint != null) {
            txtPlayersHint.setText("أنت + " + (playerCount - 1));
        }
        for (int i = 0; i < chips.length; i++) {
            if (chips[i] == null) continue;
            boolean selected = chipValues[i] == playerCount;
            chips[i].setBackgroundResource(
                    selected ? R.drawable.setup_chip_selected : R.drawable.setup_chip);
            chips[i].setTextColor(selected ? 0xFF06112E : 0xFFFFFFFF);
        }
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
