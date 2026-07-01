package net.androidgaming.millionaire2024;

import androidx.appcompat.app.AppCompatActivity;

import android.content.Intent;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.os.Bundle;
import android.view.Gravity;
import android.view.View;
import android.view.Window;
import android.view.WindowManager;
import android.widget.Button;
import android.widget.FrameLayout;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;

import org.json.JSONObject;

import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.Locale;

public class LocalTeamsGamesActivity extends AppCompatActivity {
    private LinearLayout content;
    private final SimpleDateFormat dateFormat =
            new SimpleDateFormat("yyyy/MM/dd HH:mm", Locale.getDefault());

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        supportRequestWindowFeature(Window.FEATURE_NO_TITLE);
        super.onCreate(savedInstanceState);
        getWindow().setFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN,
                WindowManager.LayoutParams.FLAG_FULLSCREEN);
        getWindow().getDecorView().setSystemUiVisibility(View.SYSTEM_UI_FLAG_HIDE_NAVIGATION);
        if (getSupportActionBar() != null) getSupportActionBar().hide();
        buildLayout();
    }

    @Override
    protected void onResume() {
        super.onResume();
        refreshList();
    }

    private void buildLayout() {
        FrameLayout root = new FrameLayout(this);
        root.setLayoutDirection(View.LAYOUT_DIRECTION_RTL);

        ImageView bg = new ImageView(this);
        bg.setImageResource(R.drawable.bg_game2);
        bg.setScaleType(ImageView.ScaleType.CENTER_CROP);
        root.addView(bg, new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT));

        View scrim = new View(this);
        scrim.setBackgroundColor(0xD9071026);
        root.addView(scrim, new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT));

        LinearLayout shell = new LinearLayout(this);
        shell.setOrientation(LinearLayout.VERTICAL);
        shell.setPadding(dpx(20), dpx(14), dpx(20), dpx(14));
        root.addView(shell, new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT));

        LinearLayout top = new LinearLayout(this);
        top.setGravity(Gravity.CENTER_VERTICAL);
        top.setOrientation(LinearLayout.HORIZONTAL);
        shell.addView(top, new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, dpx(50)));

        TextView back = navButton("×");
        back.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                finish();
            }
        });
        top.addView(back);

        TextView title = label("مباريات التحدي الرئيسي", 23f, Color.WHITE, true);
        title.setGravity(Gravity.CENTER);
        top.addView(title, new LinearLayout.LayoutParams(0,
                LinearLayout.LayoutParams.WRAP_CONTENT, 1f));

        Button newGame = actionButton("لعبة جديدة", 0xFF29B6F6);
        newGame.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                launchGame(null);
            }
        });
        top.addView(newGame, new LinearLayout.LayoutParams(dpx(150), dpx(44)));

        ScrollView scroll = new ScrollView(this);
        scroll.setFillViewport(true);
        scroll.setScrollBarStyle(View.SCROLLBARS_INSIDE_INSET);
        shell.addView(scroll, new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f));

        content = new LinearLayout(this);
        content.setOrientation(LinearLayout.VERTICAL);
        content.setPadding(0, dpx(8), 0, dpx(6));
        scroll.addView(content);

        setContentView(root);
        refreshList();
    }

    private void refreshList() {
        if (content == null) return;
        content.removeAllViews();
        ArrayList<JSONObject> records = LocalTeamsGameStore.all(this);
        ArrayList<JSONObject> active = new ArrayList<>();
        ArrayList<JSONObject> history = new ArrayList<>();
        for (JSONObject record : records) {
            if (LocalTeamsGameStore.STATUS_FINISHED.equals(record.optString("status"))) {
                history.add(record);
            } else {
                active.add(record);
                history.add(record);
            }
        }

        addSectionTitle("المباريات القابلة للمتابعة");
        if (active.isEmpty()) {
            content.addView(emptyState("لا توجد مباراة محفوظة الآن."));
        } else {
            for (JSONObject record : active) {
                content.addView(recordRow(record, true));
            }
        }

        addSectionTitle("السجل");
        if (history.isEmpty()) {
            content.addView(emptyState("سيظهر هنا سجل مباريات الفريقين بعد بدء اللعب."));
        } else {
            for (JSONObject record : history) {
                content.addView(recordRow(record, false));
            }
        }
    }

    private void addSectionTitle(String text) {
        TextView view = label(text, 17f, 0xFFFFD761, true);
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT);
        lp.setMargins(0, dpx(12), 0, dpx(6));
        view.setLayoutParams(lp);
        content.addView(view);
    }

    private View recordRow(final JSONObject record, boolean resumable) {
        LinearLayout row = new LinearLayout(this);
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.setGravity(Gravity.CENTER_VERTICAL);
        row.setPadding(dpx(14), dpx(10), dpx(14), dpx(10));
        row.setBackground(panelBg());
        LinearLayout.LayoutParams rowLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT);
        rowLp.setMargins(0, 0, 0, dpx(8));
        row.setLayoutParams(rowLp);

        LinearLayout info = new LinearLayout(this);
        info.setOrientation(LinearLayout.VERTICAL);
        row.addView(info, new LinearLayout.LayoutParams(0,
                LinearLayout.LayoutParams.WRAP_CONTENT, 1f));

        String names = record.optString("teamAName", "الفريق الأول")
                + "  " + record.optInt("scoreA", 0)
                + " - "
                + record.optInt("scoreB", 0)
                + "  " + record.optString("teamBName", "الفريق الثاني");
        info.addView(label(names, 16f, Color.WHITE, true));

        String details = LocalTeamsGameStore.statusLabel(record)
                + "  |  " + progressText(record)
                + "  |  " + formatDate(record.optLong("updatedAt", 0L));
        TextView sub = label(details, 12f, 0xFFBFD7FF, false);
        LinearLayout.LayoutParams subLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT);
        subLp.topMargin = dpx(4);
        info.addView(sub, subLp);

        if (resumable) {
            Button resume = actionButton("متابعة", 0xFF2E9E2E);
            resume.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View v) {
                    launchGame(record.optString("id", ""));
                }
            });
            LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(dpx(118), dpx(44));
            lp.setMargins(dpx(10), 0, 0, 0);
            row.addView(resume, lp);
        }
        return row;
    }

    private String progressText(JSONObject record) {
        int turn = Math.max(0, record.optInt("turnIndex", 0));
        int total = Math.max(0, record.optInt("totalTurns", 0));
        if (total <= 0) return "لم تبدأ اللوحة";
        return "الدور " + Math.min(turn + 1, total) + "/" + total;
    }

    private TextView emptyState(String text) {
        TextView view = label(text, 14f, 0xFFBFD7FF, false);
        view.setGravity(Gravity.CENTER);
        view.setPadding(dpx(14), dpx(16), dpx(14), dpx(16));
        view.setBackground(panelBg());
        return view;
    }

    private void launchGame(String saveId) {
        Intent intent = new Intent(this, GameActivity.class);
        intent.putExtra("mode", "mono");
        intent.putExtra("localTeams", true);
        intent.putExtra("characterIndex", AppPrefs.getEffectiveCharacter(this));
        if (saveId != null && !saveId.trim().isEmpty()) {
            intent.putExtra("resumeLocalTeams", true);
            intent.putExtra("localTeamsSaveId", saveId.trim());
        }
        startActivity(intent);
    }

    private String formatDate(long millis) {
        if (millis <= 0L) return "";
        return dateFormat.format(new Date(millis));
    }

    private TextView label(String text, float sp, int color, boolean bold) {
        TextView view = new TextView(this);
        view.setText(text);
        view.setTextColor(color);
        view.setTextSize(sp);
        view.setGravity(Gravity.RIGHT | Gravity.CENTER_VERTICAL);
        view.setIncludeFontPadding(false);
        if (bold) view.setTypeface(Typeface.DEFAULT_BOLD);
        return view;
    }

    private TextView navButton(String text) {
        TextView view = label(text, 24f, Color.WHITE, true);
        view.setGravity(Gravity.CENTER);
        view.setBackground(pillBg(0x661B2B4D));
        view.setLayoutParams(new LinearLayout.LayoutParams(dpx(44), dpx(44)));
        return view;
    }

    private Button actionButton(String text, int color) {
        Button button = new Button(this);
        button.setText(text);
        button.setAllCaps(false);
        button.setTextColor(Color.WHITE);
        button.setTextSize(15f);
        button.setTypeface(Typeface.DEFAULT_BOLD);
        button.setBackground(pillBg(color));
        return button;
    }

    private GradientDrawable panelBg() {
        GradientDrawable bg = new GradientDrawable();
        bg.setColor(0xCC0E2347);
        bg.setCornerRadius(dpx(12));
        bg.setStroke(dpx(1), 0x33FFFFFF);
        return bg;
    }

    private GradientDrawable pillBg(int color) {
        GradientDrawable bg = new GradientDrawable();
        bg.setColor(color);
        bg.setCornerRadius(dpx(18));
        bg.setStroke(dpx(1), 0x55FFFFFF);
        return bg;
    }

    private int dpx(int value) {
        return Math.round(value * getResources().getDisplayMetrics().density);
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
