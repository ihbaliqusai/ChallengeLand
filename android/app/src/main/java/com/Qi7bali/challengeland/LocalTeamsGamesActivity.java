package com.qi7bali.landchallengeonline;

import androidx.appcompat.app.AppCompatActivity;

import android.content.Intent;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.os.Bundle;
import android.text.TextUtils;
import android.view.Gravity;
import android.view.View;
import android.view.Window;
import android.view.WindowManager;
import android.widget.Button;
import android.widget.FrameLayout;
import android.widget.HorizontalScrollView;
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
    private static final int GOLD = 0xFFFFD761;
    private static final int BLUE = 0xFF7DD3FC;
    private static final int GREEN = 0xFF67E8A5;
    private static final int TEXT_MUTED = 0xFFC8D6F7;

    private LinearLayout activeList;
    private LinearLayout historyList;
    private TextView activeCountView;
    private TextView historyCountView;
    private TextView summaryView;

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
        scrim.setBackground(pageScrimBg());
        root.addView(scrim, new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT));

        LinearLayout shell = new LinearLayout(this);
        shell.setOrientation(LinearLayout.VERTICAL);
        shell.setPadding(dpx(24), dpx(16), dpx(24), dpx(16));
        root.addView(shell, new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT));

        shell.addView(createHeader(), new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, dpx(112)));

        LinearLayout body = new LinearLayout(this);
        body.setOrientation(LinearLayout.HORIZONTAL);
        body.setGravity(Gravity.CENTER);
        LinearLayout.LayoutParams bodyLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f);
        bodyLp.topMargin = dpx(12);
        shell.addView(body, bodyLp);

        View activeSection = createSection(
                "المباريات القابلة للمتابعة",
                "أكمل اللعب من آخر نقطة حفظ",
                true);
        LinearLayout.LayoutParams activeLp = new LinearLayout.LayoutParams(0,
                LinearLayout.LayoutParams.MATCH_PARENT, 1.08f);
        activeLp.setMargins(0, 0, dpx(8), 0);
        body.addView(activeSection, activeLp);

        View historySection = createSection(
                "السجل",
                "كل المباريات وحالتها والفائز",
                false);
        LinearLayout.LayoutParams historyLp = new LinearLayout.LayoutParams(0,
                LinearLayout.LayoutParams.MATCH_PARENT, 0.92f);
        historyLp.setMargins(dpx(8), 0, 0, 0);
        body.addView(historySection, historyLp);

        setContentView(root);
        refreshList();
    }

    private View createHeader() {
        LinearLayout header = new LinearLayout(this);
        header.setOrientation(LinearLayout.VERTICAL);
        header.setGravity(Gravity.CENTER_VERTICAL);
        header.setPadding(dpx(14), dpx(11), dpx(14), dpx(11));
        header.setBackground(headerBg());

        LinearLayout topRow = new LinearLayout(this);
        topRow.setOrientation(LinearLayout.HORIZONTAL);
        topRow.setGravity(Gravity.CENTER_VERTICAL);
        header.addView(topRow, new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f));

        TextView back = navButton("×");
        back.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                finish();
            }
        });
        topRow.addView(back);

        LinearLayout titleBlock = new LinearLayout(this);
        titleBlock.setOrientation(LinearLayout.VERTICAL);
        titleBlock.setPadding(dpx(14), 0, dpx(14), 0);
        topRow.addView(titleBlock, new LinearLayout.LayoutParams(0,
                LinearLayout.LayoutParams.WRAP_CONTENT, 1f));

        TextView title = label("مباريات التحدي الرئيسي", 24f, Color.WHITE, true);
        title.setGravity(Gravity.RIGHT);
        titleBlock.addView(title);

        summaryView = label("ابدأ مباراة جديدة أو أكمل مباراة محفوظة.", 12.5f, TEXT_MUTED, false);
        LinearLayout.LayoutParams summaryLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        summaryLp.topMargin = dpx(5);
        titleBlock.addView(summaryView, summaryLp);

        Button newGame = actionButton("+ لعبة جديدة", 0xFFFFB62B, 0xFFF97316);
        newGame.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                launchGame(null);
            }
        });
        LinearLayout.LayoutParams newLp = new LinearLayout.LayoutParams(dpx(164), dpx(46));
        newLp.setMargins(dpx(14), 0, 0, 0);
        topRow.addView(newGame, newLp);

        LinearLayout stats = new LinearLayout(this);
        stats.setOrientation(LinearLayout.HORIZONTAL);
        stats.setGravity(Gravity.RIGHT | Gravity.CENTER_VERTICAL);
        activeCountView = statChip("0 متابعة", GREEN);
        historyCountView = statChip("0 سجل", BLUE);
        stats.addView(activeCountView);
        LinearLayout.LayoutParams statGap = new LinearLayout.LayoutParams(dpx(8), 1);
        View gap = new View(this);
        stats.addView(gap, statGap);
        stats.addView(historyCountView);
        LinearLayout.LayoutParams statsLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        statsLp.topMargin = dpx(8);
        header.addView(stats, statsLp);

        return header;
    }

    private View createSection(String title, String subtitle, boolean activeSection) {
        LinearLayout section = new LinearLayout(this);
        section.setOrientation(LinearLayout.VERTICAL);
        section.setPadding(dpx(14), dpx(12), dpx(14), dpx(10));
        section.setBackground(sectionBg(activeSection ? GREEN : BLUE));

        LinearLayout header = new LinearLayout(this);
        header.setGravity(Gravity.CENTER_VERTICAL);
        header.setOrientation(LinearLayout.HORIZONTAL);
        header.setPadding(0, 0, 0, dpx(10));
        section.addView(header, new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT));

        View accent = new View(this);
        accent.setBackground(roundedBg(activeSection ? GREEN : BLUE, activeSection ? GREEN : BLUE, 6, 0));
        LinearLayout.LayoutParams accentLp = new LinearLayout.LayoutParams(dpx(4), dpx(38));
        accentLp.setMargins(dpx(8), 0, 0, 0);
        header.addView(accent, accentLp);

        LinearLayout textBlock = new LinearLayout(this);
        textBlock.setOrientation(LinearLayout.VERTICAL);
        header.addView(textBlock, new LinearLayout.LayoutParams(0,
                LinearLayout.LayoutParams.WRAP_CONTENT, 1f));

        TextView titleView = label(title, 18f, Color.WHITE, true);
        textBlock.addView(titleView);

        TextView subView = label(subtitle, 11.5f, TEXT_MUTED, false);
        LinearLayout.LayoutParams subLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        subLp.topMargin = dpx(4);
        textBlock.addView(subView, subLp);

        ScrollView scroll = new ScrollView(this);
        scroll.setFillViewport(true);
        scroll.setOverScrollMode(View.OVER_SCROLL_NEVER);
        section.addView(scroll, new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f));

        LinearLayout list = new LinearLayout(this);
        list.setOrientation(LinearLayout.VERTICAL);
        list.setPadding(0, dpx(2), 0, dpx(10));
        scroll.addView(list, new ScrollView.LayoutParams(
                ScrollView.LayoutParams.MATCH_PARENT, ScrollView.LayoutParams.WRAP_CONTENT));

        if (activeSection) {
            activeList = list;
        } else {
            historyList = list;
        }
        return section;
    }

    private void refreshList() {
        if (activeList == null || historyList == null) return;
        activeList.removeAllViews();
        historyList.removeAllViews();

        ArrayList<JSONObject> records = LocalTeamsGameStore.all(this);
        ArrayList<JSONObject> active = new ArrayList<>();
        ArrayList<JSONObject> history = new ArrayList<>();
        int finishedCount = 0;
        for (JSONObject record : records) {
            if (LocalTeamsGameStore.STATUS_FINISHED.equals(record.optString("status"))) {
                finishedCount++;
                history.add(record);
            } else {
                active.add(record);
                history.add(record);
            }
        }

        activeCountView.setText(active.size() + " متابعة");
        historyCountView.setText(history.size() + " سجل");
        summaryView.setText("مباريات محفوظة: " + active.size()
                + "  |  مباريات منتهية: " + finishedCount);

        if (active.isEmpty()) {
            activeList.addView(emptyState(
                    "لا توجد مباراة محفوظة الآن.",
                    "ابدأ لعبة جديدة وسيتم حفظها تلقائيا لتكملها لاحقا."));
        } else {
            for (JSONObject record : active) {
                activeList.addView(recordCard(record, true));
            }
        }

        if (history.isEmpty()) {
            historyList.addView(emptyState(
                    "لا يوجد سجل بعد.",
                    "سيظهر هنا تاريخ مباريات الفريقين وحالة كل مباراة."));
        } else {
            for (JSONObject record : history) {
                historyList.addView(recordCard(record, false));
            }
        }
    }

    private View recordCard(final JSONObject record, boolean resumable) {
        boolean finished = LocalTeamsGameStore.STATUS_FINISHED.equals(record.optString("status"));
        int accent = finished ? GOLD : (resumable ? GREEN : BLUE);

        LinearLayout card = new LinearLayout(this);
        card.setOrientation(LinearLayout.VERTICAL);
        card.setGravity(Gravity.CENTER_VERTICAL);
        card.setPadding(dpx(13), dpx(12), dpx(13), dpx(12));
        card.setBackground(cardBg(accent));
        LinearLayout.LayoutParams cardLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        cardLp.setMargins(0, 0, 0, dpx(12));
        card.setLayoutParams(cardLp);

        LinearLayout topMeta = new LinearLayout(this);
        topMeta.setOrientation(LinearLayout.HORIZONTAL);
        topMeta.setGravity(Gravity.CENTER_VERTICAL);
        card.addView(topMeta, new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT));

        topMeta.addView(metaChip(statusText(record), accent));
        View spacer = new View(this);
        topMeta.addView(spacer, new LinearLayout.LayoutParams(0, 1, 1f));
        String date = formatDate(record.optLong("updatedAt", 0L));
        if (!date.isEmpty()) {
            topMeta.addView(metaChip(date, BLUE));
        }

        LinearLayout.LayoutParams scoreLineLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        scoreLineLp.setMargins(0, dpx(12), 0, dpx(9));
        card.addView(scoreLine(record), scoreLineLp);

        String winner = winnerText(record);
        if (!winner.isEmpty()) {
            TextView winnerChip = metaChip(winner, GOLD);
            LinearLayout.LayoutParams winnerLp = new LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT);
            winnerLp.gravity = Gravity.CENTER_HORIZONTAL;
            winnerLp.bottomMargin = dpx(8);
            card.addView(winnerChip, winnerLp);
        }

        LinearLayout progressHeader = new LinearLayout(this);
        progressHeader.setOrientation(LinearLayout.HORIZONTAL);
        progressHeader.setGravity(Gravity.CENTER_VERTICAL);
        TextView progressLabel = label(progressText(record), 11.5f, TEXT_MUTED, false);
        progressHeader.addView(progressLabel, new LinearLayout.LayoutParams(0,
                LinearLayout.LayoutParams.WRAP_CONTENT, 1f));

        if (resumable) {
            Button resume = actionButton("متابعة", 0xFF22C55E, 0xFF15803D);
            resume.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View v) {
                    launchGame(record.optString("id", ""));
                }
            });
            LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(dpx(104), dpx(38));
            lp.setMargins(dpx(12), 0, 0, 0);
            progressHeader.addView(resume, lp);
        }

        card.addView(progressHeader, new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT));

        LinearLayout.LayoutParams progressLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, dpx(6));
        progressLp.setMargins(0, dpx(8), 0, 0);
        card.addView(progressBar(record, accent), progressLp);
        return card;
    }

    private View scoreLine(JSONObject record) {
        LinearLayout row = new LinearLayout(this);
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.setGravity(Gravity.CENTER_VERTICAL);

        TextView teamA = teamName(record.optString("teamAName", "الفريق الأول"), GOLD);
        row.addView(teamA, new LinearLayout.LayoutParams(0,
                LinearLayout.LayoutParams.WRAP_CONTENT, 1f));

        TextView score = label(record.optInt("scoreA", 0)
                + "  -  " + record.optInt("scoreB", 0), 16f, Color.WHITE, true);
        score.setGravity(Gravity.CENTER);
        score.setBackground(scorePillBg());
        score.setPadding(dpx(13), dpx(4), dpx(13), dpx(4));
        LinearLayout.LayoutParams scoreLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        scoreLp.setMargins(dpx(10), 0, dpx(10), 0);
        row.addView(score, scoreLp);

        TextView teamB = teamName(record.optString("teamBName", "الفريق الثاني"), BLUE);
        row.addView(teamB, new LinearLayout.LayoutParams(0,
                LinearLayout.LayoutParams.WRAP_CONTENT, 1f));
        return row;
    }

    private TextView teamName(String name, int color) {
        TextView view = label(name == null || name.trim().isEmpty() ? "فريق" : name.trim(),
                15.5f, color, true);
        view.setSingleLine(true);
        view.setEllipsize(TextUtils.TruncateAt.END);
        view.setGravity(Gravity.RIGHT | Gravity.CENTER_VERTICAL);
        return view;
    }

    private View progressBar(JSONObject record, int color) {
        LinearLayout bar = new LinearLayout(this);
        bar.setOrientation(LinearLayout.HORIZONTAL);
        bar.setBackground(roundedBg(0x33000000, 0x22FFFFFF, 6, 1));
        int turn = Math.max(0, record.optInt("turnIndex", 0));
        int total = Math.max(0, record.optInt("totalTurns", 0));
        int progress = total <= 0 ? 0 : Math.max(0, Math.min(100, (turn * 100) / total));
        if (LocalTeamsGameStore.STATUS_FINISHED.equals(record.optString("status"))) {
            progress = 100;
        }

        View fill = new View(this);
        fill.setBackground(roundedBg(color, color, 6, 0));
        bar.addView(fill, new LinearLayout.LayoutParams(0,
                LinearLayout.LayoutParams.MATCH_PARENT, Math.max(1, progress)));

        View rest = new View(this);
        bar.addView(rest, new LinearLayout.LayoutParams(0,
                LinearLayout.LayoutParams.MATCH_PARENT, Math.max(1, 100 - progress)));
        return bar;
    }

    private TextView metaChip(String text, int color) {
        TextView chip = label(text, 11f, 0xFFEAF2FF, false);
        chip.setSingleLine(true);
        chip.setGravity(Gravity.CENTER);
        chip.setPadding(dpx(9), dpx(4), dpx(9), dpx(4));
        chip.setBackground(chipBg(color));
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        lp.setMargins(dpx(5), 0, 0, 0);
        chip.setLayoutParams(lp);
        return chip;
    }

    private View emptyState(String title, String subtitle) {
        LinearLayout view = new LinearLayout(this);
        view.setOrientation(LinearLayout.VERTICAL);
        view.setGravity(Gravity.CENTER);
        view.setPadding(dpx(18), dpx(26), dpx(18), dpx(26));
        view.setBackground(cardBg(BLUE));

        TextView titleView = label(title, 16f, Color.WHITE, true);
        titleView.setGravity(Gravity.CENTER);
        view.addView(titleView);

        TextView subView = label(subtitle, 12.5f, TEXT_MUTED, false);
        subView.setGravity(Gravity.CENTER);
        subView.setPadding(0, dpx(8), 0, 0);
        view.addView(subView);
        return view;
    }

    private String progressText(JSONObject record) {
        int turn = Math.max(0, record.optInt("turnIndex", 0));
        int total = Math.max(0, record.optInt("totalTurns", 0));
        if (total <= 0) return "لم تبدأ اللوحة";
        if (LocalTeamsGameStore.STATUS_FINISHED.equals(record.optString("status"))) {
            return "اكتملت اللوحة";
        }
        return "الدور " + Math.min(turn + 1, total) + "/" + total;
    }

    private String statusText(JSONObject record) {
        if (!LocalTeamsGameStore.STATUS_FINISHED.equals(record.optString("status"))) {
            return LocalTeamsGameStore.statusLabel(record);
        }
        return record.optInt("winnerSlot", -2) < 0 ? "منتهية - تعادل" : "منتهية";
    }

    private String winnerText(JSONObject record) {
        if (!LocalTeamsGameStore.STATUS_FINISHED.equals(record.optString("status"))) return "";
        int winner = record.optInt("winnerSlot", -2);
        if (winner < 0) return "تعادل";
        String name = record.optString("winnerName", "");
        if (name.trim().isEmpty()) {
            name = winner == 1
                    ? record.optString("teamBName", "الفريق الثاني")
                    : record.optString("teamAName", "الفريق الأول");
        }
        return "الفائز: " + name;
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
        view.setTextDirection(View.TEXT_DIRECTION_RTL);
        view.setIncludeFontPadding(false);
        if (bold) view.setTypeface(Typeface.DEFAULT_BOLD);
        return view;
    }

    private TextView navButton(String text) {
        TextView view = label(text, 24f, Color.WHITE, true);
        view.setGravity(Gravity.CENTER);
        view.setBackground(roundedBg(0x4D1F2D4F, 0x44FFFFFF, 15, 1));
        view.setLayoutParams(new LinearLayout.LayoutParams(dpx(46), dpx(46)));
        return view;
    }

    private TextView statChip(String text, int color) {
        TextView view = label(text, 12f, Color.WHITE, true);
        view.setGravity(Gravity.CENTER);
        view.setMinWidth(dpx(86));
        view.setPadding(dpx(10), dpx(7), dpx(10), dpx(7));
        view.setBackground(chipBg(color));
        return view;
    }

    private Button actionButton(String text, int startColor, int endColor) {
        Button button = new Button(this);
        button.setText(text);
        button.setAllCaps(false);
        button.setTextColor(Color.WHITE);
        button.setTextSize(14.5f);
        button.setTypeface(Typeface.DEFAULT_BOLD);
        button.setMinHeight(0);
        button.setMinWidth(0);
        button.setPadding(dpx(8), 0, dpx(8), 0);
        button.setBackground(buttonBg(startColor, endColor));
        return button;
    }

    private GradientDrawable pageScrimBg() {
        GradientDrawable bg = new GradientDrawable(
                GradientDrawable.Orientation.TOP_BOTTOM,
                new int[]{0xDE061024, 0xF2071026, 0xF20A132E});
        return bg;
    }

    private GradientDrawable headerBg() {
        GradientDrawable bg = new GradientDrawable(
                GradientDrawable.Orientation.LEFT_RIGHT,
                new int[]{0xE60A1734, 0xD9102A4A, 0xDD0B1733});
        bg.setCornerRadius(dpx(18));
        bg.setStroke(dpx(1), 0x5593C5FD);
        return bg;
    }

    private GradientDrawable sectionBg(int accent) {
        GradientDrawable bg = new GradientDrawable(
                GradientDrawable.Orientation.TOP_BOTTOM,
                new int[]{0xB80A1734, 0xC90D1E3C});
        bg.setCornerRadius(dpx(18));
        bg.setStroke(dpx(1), withAlpha(accent, 0x45));
        return bg;
    }

    private GradientDrawable cardBg(int accent) {
        GradientDrawable bg = new GradientDrawable(
                GradientDrawable.Orientation.LEFT_RIGHT,
                new int[]{0xD90B1733, 0xD911243F});
        bg.setCornerRadius(dpx(14));
        bg.setStroke(dpx(1), withAlpha(accent, 0x72));
        return bg;
    }

    private GradientDrawable buttonBg(int startColor, int endColor) {
        GradientDrawable bg = new GradientDrawable(
                GradientDrawable.Orientation.LEFT_RIGHT,
                new int[]{startColor, endColor});
        bg.setCornerRadius(dpx(16));
        bg.setStroke(dpx(1), 0x66FFFFFF);
        return bg;
    }

    private GradientDrawable scorePillBg() {
        GradientDrawable bg = new GradientDrawable(
                GradientDrawable.Orientation.LEFT_RIGHT,
                new int[]{0xFF123A63, 0xFF0F766E});
        bg.setCornerRadius(dpx(14));
        bg.setStroke(dpx(1), 0x668BE7FF);
        return bg;
    }

    private GradientDrawable chipBg(int color) {
        return roundedBg(withAlpha(color, 0x28), withAlpha(color, 0xB0), 13, 1);
    }

    private GradientDrawable roundedBg(int fill, int stroke, int radiusDp, int strokeDp) {
        GradientDrawable bg = new GradientDrawable();
        bg.setColor(fill);
        bg.setCornerRadius(dpx(radiusDp));
        if (strokeDp > 0) {
            bg.setStroke(dpx(strokeDp), stroke);
        }
        return bg;
    }

    private int withAlpha(int color, int alpha) {
        return (color & 0x00FFFFFF) | ((alpha & 0xFF) << 24);
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
