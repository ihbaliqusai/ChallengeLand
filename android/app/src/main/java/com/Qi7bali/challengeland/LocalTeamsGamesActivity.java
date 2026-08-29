package com.qi7bali.landchallengeonline;

import androidx.appcompat.app.AlertDialog;
import androidx.appcompat.app.AppCompatActivity;

import android.content.DialogInterface;
import android.content.Intent;
import android.content.res.ColorStateList;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.graphics.drawable.RippleDrawable;
import android.graphics.drawable.StateListDrawable;
import android.os.Build;
import android.os.Bundle;
import android.text.TextUtils;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.view.Window;
import android.view.WindowManager;
import android.widget.Button;
import android.widget.FrameLayout;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;
import android.widget.Toast;

import org.json.JSONObject;

import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.Locale;

public class LocalTeamsGamesActivity extends AppCompatActivity {
    // ---- Luxury Gaming Palette ----
    private static final int GOLD_PRIMARY = 0xFFFFC727;
    private static final int GOLD_SECONDARY = 0xFFF59E0B;
    private static final int BLUE_PRIMARY = 0xFF38BDF8;
    private static final int BLUE_SECONDARY = 0xFF0284C7;
    private static final int GREEN_PRIMARY = 0xFF10B981;
    private static final int GREEN_SECONDARY = 0xFF059669;
    private static final int RED_PRIMARY = 0xFFEF4444;
    private static final int RED_SECONDARY = 0xFFB91C1C;
    private static final int PURPLE_ACCENT = 0xFFA855F7;
    private static final int TEXT_LIGHT = 0xFFF8FAFC;
    private static final int TEXT_MUTED = 0xFF94A3B8;
    private static final int TEXT_MUTED_LIGHT = 0xFFCBD5E1;

    private LinearLayout activeList;
    private LinearLayout historyList;
    private TextView activeCountView;
    private TextView historyCountView;
    private TextView summaryView;

    private final SimpleDateFormat dateFormat =
            new SimpleDateFormat("yyyy/MM/dd  HH:mm", Locale.getDefault());

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

        // Background wallpaper
        ImageView bg = new ImageView(this);
        bg.setImageResource(R.drawable.bg_game2);
        bg.setScaleType(ImageView.ScaleType.CENTER_CROP);
        root.addView(bg, new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT));

        // Atmospheric Dark Glass Scrim
        View scrim = new View(this);
        scrim.setBackground(pageScrimBg());
        root.addView(scrim, new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT));

        // Main Container Shell
        LinearLayout shell = new LinearLayout(this);
        shell.setOrientation(LinearLayout.VERTICAL);
        shell.setPadding(dpx(20), dpx(14), dpx(20), dpx(14));
        root.addView(shell, new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT));

        // Header Section
        shell.addView(createHeader(), new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, dpx(108)));

        // Body with two responsive columns
        LinearLayout body = new LinearLayout(this);
        body.setOrientation(LinearLayout.HORIZONTAL);
        body.setGravity(Gravity.CENTER);
        LinearLayout.LayoutParams bodyLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f);
        bodyLp.topMargin = dpx(12);
        shell.addView(body, bodyLp);

        // Section 1: Active / Resumable Games (Right in RTL)
        View activeSection = createSection(
                "المباريات القابلة للمتابعة",
                "أكمل اللعب من آخر نقطة حفظ في اللوحة",
                "⚡",
                GREEN_PRIMARY,
                true);
        LinearLayout.LayoutParams activeLp = new LinearLayout.LayoutParams(0,
                LinearLayout.LayoutParams.MATCH_PARENT, 1.05f);
        activeLp.setMargins(0, 0, dpx(8), 0);
        body.addView(activeSection, activeLp);

        // Section 2: Match History & Records (Left in RTL)
        View historySection = createSection(
                "سجل المباريات والأرشيف",
                "نتائج التحديات السابقة والفائزين",
                "📜",
                BLUE_PRIMARY,
                false);
        LinearLayout.LayoutParams historyLp = new LinearLayout.LayoutParams(0,
                LinearLayout.LayoutParams.MATCH_PARENT, 0.95f);
        historyLp.setMargins(dpx(8), 0, 0, 0);
        body.addView(historySection, historyLp);

        setContentView(root);
        refreshList();
    }

    private View createHeader() {
        LinearLayout header = new LinearLayout(this);
        header.setOrientation(LinearLayout.VERTICAL);
        header.setGravity(Gravity.CENTER_VERTICAL);
        header.setPadding(dpx(16), dpx(10), dpx(16), dpx(10));
        header.setBackground(headerBg());

        // Top Row: Back Button + Title Block + New Game CTA
        LinearLayout topRow = new LinearLayout(this);
        topRow.setOrientation(LinearLayout.HORIZONTAL);
        topRow.setGravity(Gravity.CENTER_VERTICAL);
        header.addView(topRow, new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f));

        // Modern Back / Close Button
        TextView back = navButton("✕");
        back.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                finish();
            }
        });
        topRow.addView(back);

        // Title and Subtitle Info
        LinearLayout titleBlock = new LinearLayout(this);
        titleBlock.setOrientation(LinearLayout.VERTICAL);
        titleBlock.setPadding(dpx(14), 0, dpx(14), 0);
        topRow.addView(titleBlock, new LinearLayout.LayoutParams(0,
                LinearLayout.LayoutParams.WRAP_CONTENT, 1f));

        LinearLayout titleBadgeRow = new LinearLayout(this);
        titleBadgeRow.setOrientation(LinearLayout.HORIZONTAL);
        titleBadgeRow.setGravity(Gravity.RIGHT | Gravity.CENTER_VERTICAL);

        TextView title = label("⚔️ التحدي الرئيسي", 21.5f, Color.WHITE, true);
        title.setGravity(Gravity.RIGHT);
        titleBadgeRow.addView(title);

        TextView modeBadge = label("فريقان على جهاز واحد", 10.5f, GOLD_PRIMARY, true);
        modeBadge.setBackground(chipBg(GOLD_PRIMARY, 0x22));
        modeBadge.setPadding(dpx(8), dpx(3), dpx(8), dpx(3));
        LinearLayout.LayoutParams modeBadgeLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        modeBadgeLp.setMargins(dpx(10), 0, 0, 0);
        titleBadgeRow.addView(modeBadge, modeBadgeLp);

        titleBlock.addView(titleBadgeRow);

        summaryView = label("ابدأ مباراة جديدة أو أكمل مباراة محفوظة بين الفريقين.", 11.5f, TEXT_MUTED_LIGHT, false);
        LinearLayout.LayoutParams summaryLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        summaryLp.topMargin = dpx(3);
        titleBlock.addView(summaryView, summaryLp);

        // Action Buttons: "+ مباراة جديدة"
        Button newGame = actionButton("＋ مباراة جديدة", GOLD_PRIMARY, GOLD_SECONDARY, 0xFF0F172A);
        newGame.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                launchGame(null);
            }
        });
        LinearLayout.LayoutParams newLp = new LinearLayout.LayoutParams(dpx(168), dpx(44));
        newLp.setMargins(dpx(12), 0, 0, 0);
        topRow.addView(newGame, newLp);

        // Bottom Row: Live Stats Chips
        LinearLayout stats = new LinearLayout(this);
        stats.setOrientation(LinearLayout.HORIZONTAL);
        stats.setGravity(Gravity.RIGHT | Gravity.CENTER_VERTICAL);
        activeCountView = statChip("0 جارية", GREEN_PRIMARY);
        historyCountView = statChip("0 بالسجل", BLUE_PRIMARY);
        stats.addView(activeCountView);
        View gap = new View(this);
        stats.addView(gap, new LinearLayout.LayoutParams(dpx(8), 1));
        stats.addView(historyCountView);

        LinearLayout.LayoutParams statsLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        statsLp.topMargin = dpx(6);
        header.addView(stats, statsLp);

        return header;
    }

    private View createSection(String title, String subtitle, String icon, int accentColor, boolean activeSection) {
        LinearLayout section = new LinearLayout(this);
        section.setOrientation(LinearLayout.VERTICAL);
        section.setPadding(dpx(14), dpx(12), dpx(14), dpx(10));
        section.setBackground(sectionBg(accentColor));

        // Section Title Bar
        LinearLayout header = new LinearLayout(this);
        header.setGravity(Gravity.CENTER_VERTICAL);
        header.setOrientation(LinearLayout.HORIZONTAL);
        header.setPadding(0, 0, 0, dpx(8));
        section.addView(header, new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT));

        // Accent Icon Indicator
        TextView iconView = label(icon, 16f, accentColor, true);
        iconView.setBackground(roundedBg(withAlpha(accentColor, 0x24), withAlpha(accentColor, 0x88), 10, 1));
        iconView.setGravity(Gravity.CENTER);
        LinearLayout.LayoutParams iconLp = new LinearLayout.LayoutParams(dpx(32), dpx(32));
        iconLp.setMargins(dpx(8), 0, 0, 0);
        header.addView(iconView, iconLp);

        LinearLayout textBlock = new LinearLayout(this);
        textBlock.setOrientation(LinearLayout.VERTICAL);
        header.addView(textBlock, new LinearLayout.LayoutParams(0,
                LinearLayout.LayoutParams.WRAP_CONTENT, 1f));

        TextView titleView = label(title, 16.5f, Color.WHITE, true);
        textBlock.addView(titleView);

        TextView subView = label(subtitle, 11f, TEXT_MUTED, false);
        LinearLayout.LayoutParams subLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        subLp.topMargin = dpx(2);
        textBlock.addView(subView, subLp);

        // Scrollable List
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

        activeCountView.setText(active.size() + " جارية");
        historyCountView.setText(history.size() + " بالسجل");
        summaryView.setText("مباريات محفوظة: " + active.size()
                + "  •  مباريات منتهية: " + finishedCount
                + "  •  إجمالي التحديات: " + history.size());

        if (active.isEmpty()) {
            activeList.addView(emptyState(
                    "لا توجد مباريات جارية حالياً",
                    "ابدأ لعبة جديدة بين فريقين وسيتم حفظها تلقائياً لتكملها بأي وقت.",
                    true));
        } else {
            for (JSONObject record : active) {
                activeList.addView(recordCard(record, true));
            }
        }

        if (history.isEmpty()) {
            historyList.addView(emptyState(
                    "السجل فارغ بعد",
                    "سيظهر هنا أرشيف مباريات الفريقين والنتائج وتفاصيل الفائزين.",
                    false));
        } else {
            for (JSONObject record : history) {
                historyList.addView(recordCard(record, false));
            }
        }
    }

    private View recordCard(final JSONObject record, final boolean resumable) {
        final boolean finished = LocalTeamsGameStore.STATUS_FINISHED.equals(record.optString("status"));
        final String gameId = record.optString("id", "");
        final int accent = finished ? GOLD_PRIMARY : (resumable ? GREEN_PRIMARY : BLUE_PRIMARY);

        LinearLayout card = new LinearLayout(this);
        card.setOrientation(LinearLayout.VERTICAL);
        card.setGravity(Gravity.CENTER_VERTICAL);
        card.setPadding(dpx(13), dpx(12), dpx(13), dpx(12));
        card.setBackground(cardBg(accent));
        LinearLayout.LayoutParams cardLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        cardLp.setMargins(0, 0, 0, dpx(11));
        card.setLayoutParams(cardLp);

        // Top Metadata Row: Status Chip + Date
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
            topMeta.addView(metaChip(date, BLUE_PRIMARY));
        }

        // Teams and Score Duel View
        LinearLayout.LayoutParams scoreLineLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        scoreLineLp.setMargins(0, dpx(10), 0, dpx(8));
        card.addView(scoreLine(record), scoreLineLp);

        // Winner Banner (if finished)
        String winner = winnerText(record);
        if (!winner.isEmpty()) {
            TextView winnerChip = label("🏆 " + winner, 12f, GOLD_PRIMARY, true);
            winnerChip.setGravity(Gravity.CENTER);
            winnerChip.setPadding(dpx(12), dpx(4), dpx(12), dpx(4));
            winnerChip.setBackground(roundedBg(0x33F59E0B, 0x88F59E0B, 12, 1));
            LinearLayout.LayoutParams winnerLp = new LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT);
            winnerLp.gravity = Gravity.CENTER_HORIZONTAL;
            winnerLp.bottomMargin = dpx(7);
            card.addView(winnerChip, winnerLp);
        }

        // Progress Details Bar
        LinearLayout progressHeader = new LinearLayout(this);
        progressHeader.setOrientation(LinearLayout.HORIZONTAL);
        progressHeader.setGravity(Gravity.CENTER_VERTICAL);
        TextView progressLabel = label(progressText(record), 11f, TEXT_MUTED_LIGHT, false);
        progressHeader.addView(progressLabel, new LinearLayout.LayoutParams(0,
                LinearLayout.LayoutParams.WRAP_CONTENT, 1f));
        card.addView(progressHeader, new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT));

        // Animated / Smooth Progress Bar
        LinearLayout.LayoutParams progressLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, dpx(6));
        progressLp.setMargins(0, dpx(6), 0, dpx(10));
        card.addView(progressBar(record, accent), progressLp);

        // Action Buttons Row (Resume + Delete)
        LinearLayout actionsRow = new LinearLayout(this);
        actionsRow.setOrientation(LinearLayout.HORIZONTAL);
        actionsRow.setGravity(Gravity.CENTER_VERTICAL);

        if (resumable) {
            // Resume Button
            Button resume = actionButton("▶ متابعة", GREEN_PRIMARY, GREEN_SECONDARY, Color.WHITE);
            resume.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View v) {
                    launchGame(gameId);
                }
            });
            LinearLayout.LayoutParams resumeLp = new LinearLayout.LayoutParams(0, dpx(38), 1f);
            resumeLp.setMargins(0, 0, dpx(8), 0);
            actionsRow.addView(resume, resumeLp);
        }

        // Delete Button (Available for both resumable & history cards)
        Button deleteBtn = deleteActionButton("🗑️ حذف", new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                confirmDeleteGame(record);
            }
        });
        LinearLayout.LayoutParams delLp = new LinearLayout.LayoutParams(
                resumable ? dpx(92) : LinearLayout.LayoutParams.MATCH_PARENT, dpx(36));
        actionsRow.addView(deleteBtn, delLp);

        card.addView(actionsRow, new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT));

        return card;
    }

    private View scoreLine(JSONObject record) {
        LinearLayout row = new LinearLayout(this);
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.setGravity(Gravity.CENTER_VERTICAL);

        // Team A (Gold)
        String nameA = record.optString("teamAName", "الفريق الأول");
        View teamABox = teamPill(nameA, GOLD_PRIMARY, 0x22F59E0B);
        row.addView(teamABox, new LinearLayout.LayoutParams(0,
                LinearLayout.LayoutParams.WRAP_CONTENT, 1f));

        // Score Pill in the middle
        TextView score = label(record.optInt("scoreA", 0)
                + "   -   " + record.optInt("scoreB", 0), 16f, Color.WHITE, true);
        score.setGravity(Gravity.CENTER);
        score.setBackground(scorePillBg());
        score.setPadding(dpx(14), dpx(5), dpx(14), dpx(5));
        LinearLayout.LayoutParams scoreLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        scoreLp.setMargins(dpx(8), 0, dpx(8), 0);
        row.addView(score, scoreLp);

        // Team B (Sky Blue)
        String nameB = record.optString("teamBName", "الفريق الثاني");
        View teamBBox = teamPill(nameB, BLUE_PRIMARY, 0x220284C7);
        row.addView(teamBBox, new LinearLayout.LayoutParams(0,
                LinearLayout.LayoutParams.WRAP_CONTENT, 1f));

        return row;
    }

    private View teamPill(String name, int color, int fill) {
        LinearLayout pill = new LinearLayout(this);
        pill.setOrientation(LinearLayout.HORIZONTAL);
        pill.setGravity(Gravity.CENTER);
        pill.setPadding(dpx(10), dpx(7), dpx(10), dpx(7));
        pill.setBackground(roundedBg(fill, withAlpha(color, 0x77), 12, 1));

        TextView text = label(name == null || name.trim().isEmpty() ? "فريق" : name.trim(),
                14.5f, color, true);
        text.setSingleLine(true);
        text.setEllipsize(TextUtils.TruncateAt.END);
        text.setGravity(Gravity.CENTER);
        pill.addView(text, new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT));
        return pill;
    }

    private View progressBar(JSONObject record, int color) {
        LinearLayout bar = new LinearLayout(this);
        bar.setOrientation(LinearLayout.HORIZONTAL);
        bar.setBackground(roundedBg(0x44000000, 0x22FFFFFF, 6, 1));
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
        TextView chip = label(text, 11f, 0xFFF1F5F9, false);
        chip.setSingleLine(true);
        chip.setGravity(Gravity.CENTER);
        chip.setPadding(dpx(9), dpx(3), dpx(9), dpx(3));
        chip.setBackground(chipBg(color, 0x25));
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        lp.setMargins(dpx(5), 0, 0, 0);
        chip.setLayoutParams(lp);
        return chip;
    }

    private View emptyState(String title, String subtitle, boolean showStartButton) {
        LinearLayout view = new LinearLayout(this);
        view.setOrientation(LinearLayout.VERTICAL);
        view.setGravity(Gravity.CENTER);
        view.setPadding(dpx(18), dpx(28), dpx(18), dpx(28));
        view.setBackground(roundedBg(0x330B1733, 0x33475569, 14, 1));

        TextView icon = label("🎮", 30f, Color.WHITE, false);
        icon.setGravity(Gravity.CENTER);
        view.addView(icon);

        TextView titleView = label(title, 15.5f, Color.WHITE, true);
        titleView.setGravity(Gravity.CENTER);
        LinearLayout.LayoutParams titleLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        titleLp.topMargin = dpx(8);
        view.addView(titleView, titleLp);

        TextView subView = label(subtitle, 12f, TEXT_MUTED, false);
        subView.setGravity(Gravity.CENTER);
        LinearLayout.LayoutParams subLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        subLp.topMargin = dpx(5);
        view.addView(subView, subLp);

        if (showStartButton) {
            Button startBtn = actionButton("＋ ابدأ مباراة جديدة", GOLD_PRIMARY, GOLD_SECONDARY, 0xFF0F172A);
            startBtn.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View v) {
                    launchGame(null);
                }
            });
            LinearLayout.LayoutParams btnLp = new LinearLayout.LayoutParams(dpx(170), dpx(40));
            btnLp.topMargin = dpx(16);
            view.addView(startBtn, btnLp);
        }
        return view;
    }

    private void confirmDeleteGame(final JSONObject record) {
        if (record == null) return;
        final String gameId = record.optString("id", "").trim();
        if (gameId.isEmpty()) return;

        String teamA = record.optString("teamAName", "الفريق الأول");
        String teamB = record.optString("teamBName", "الفريق الثاني");

        // Custom Elegant Dialog Layout
        LinearLayout dialogView = new LinearLayout(this);
        dialogView.setOrientation(LinearLayout.VERTICAL);
        dialogView.setPadding(dpx(22), dpx(20), dpx(22), dpx(20));
        dialogView.setBackground(roundedBg(0xF008132B, 0x66EF4444, 18, 1));
        dialogView.setLayoutDirection(View.LAYOUT_DIRECTION_RTL);

        TextView title = label("⚠️ تأكيد حذف المباراة", 18f, RED_PRIMARY, true);
        title.setGravity(Gravity.RIGHT);
        dialogView.addView(title);

        TextView message = label(
                "هل أنت متأكد من حذف مباراة:\n« " + teamA + " » ضد « " + teamB + " »؟\nلن يمكنك استعادة تقدم هذه المباراة بعد حذفها.",
                13.5f, TEXT_LIGHT, false);
        message.setGravity(Gravity.RIGHT);
        LinearLayout.LayoutParams msgLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        msgLp.topMargin = dpx(10);
        msgLp.bottomMargin = dpx(20);
        dialogView.addView(message, msgLp);

        LinearLayout btnRow = new LinearLayout(this);
        btnRow.setOrientation(LinearLayout.HORIZONTAL);
        btnRow.setGravity(Gravity.CENTER_VERTICAL);

        final AlertDialog dialog = new AlertDialog.Builder(this)
                .setView(dialogView)
                .create();

        if (dialog.getWindow() != null) {
            dialog.getWindow().setBackgroundDrawableResource(android.R.color.transparent);
        }

        Button confirmDelete = actionButton("حذف المباراة", RED_PRIMARY, RED_SECONDARY, Color.WHITE);
        confirmDelete.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                dialog.dismiss();
                boolean removed = LocalTeamsGameStore.delete(LocalTeamsGamesActivity.this, gameId);
                if (removed) {
                    Toast.makeText(LocalTeamsGamesActivity.this, "تم حذف المباراة بنجاح", Toast.LENGTH_SHORT).show();
                    refreshList();
                }
            }
        });
        LinearLayout.LayoutParams confirmLp = new LinearLayout.LayoutParams(0, dpx(42), 1f);
        confirmLp.setMargins(0, 0, dpx(8), 0);
        btnRow.addView(confirmDelete, confirmLp);

        Button cancel = deleteActionButton("إلغاء", new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                dialog.dismiss();
            }
        });
        LinearLayout.LayoutParams cancelLp = new LinearLayout.LayoutParams(dpx(100), dpx(42));
        btnRow.addView(cancel, cancelLp);

        dialogView.addView(btnRow, new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT));

        dialog.show();
    }

    private String progressText(JSONObject record) {
        int turn = Math.max(0, record.optInt("turnIndex", 0));
        int total = Math.max(0, record.optInt("totalTurns", 0));
        if (total <= 0) return "لم تبدأ اللوحة بعد";
        if (LocalTeamsGameStore.STATUS_FINISHED.equals(record.optString("status"))) {
            return "اكتملت جميع جولات اللوحة";
        }
        return "الدور " + Math.min(turn + 1, total) + " من " + total;
    }

    private String statusText(JSONObject record) {
        if (!LocalTeamsGameStore.STATUS_FINISHED.equals(record.optString("status"))) {
            String label = LocalTeamsGameStore.statusLabel(record);
            return "⏳ " + label;
        }
        return record.optInt("winnerSlot", -2) < 0 ? "منتهية • تعادل" : "منتهية";
    }

    private String winnerText(JSONObject record) {
        if (!LocalTeamsGameStore.STATUS_FINISHED.equals(record.optString("status"))) return "";
        int winner = record.optInt("winnerSlot", -2);
        if (winner < 0) return "تعادل بين الفريقين";
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
        TextView view = label(text, 19f, Color.WHITE, true);
        view.setGravity(Gravity.CENTER);
        view.setBackground(roundedBg(0x441F2D4F, 0x5593C5FD, 14, 1));
        view.setLayoutParams(new LinearLayout.LayoutParams(dpx(42), dpx(42)));
        return view;
    }

    private TextView statChip(String text, int color) {
        TextView view = label(text, 11.5f, Color.WHITE, true);
        view.setGravity(Gravity.CENTER);
        view.setMinWidth(dpx(82));
        view.setPadding(dpx(10), dpx(5), dpx(10), dpx(5));
        view.setBackground(chipBg(color, 0x28));
        return view;
    }

    private Button actionButton(String text, int startColor, int endColor, int textColor) {
        Button button = new Button(this);
        button.setText(text);
        button.setAllCaps(false);
        button.setTextColor(textColor);
        button.setTextSize(14f);
        button.setTypeface(Typeface.DEFAULT_BOLD);
        button.setMinHeight(0);
        button.setMinWidth(0);
        button.setPadding(dpx(12), 0, dpx(12), 0);
        button.setBackground(buttonBg(startColor, endColor));
        return button;
    }

    private Button deleteActionButton(String text, View.OnClickListener listener) {
        Button button = new Button(this);
        button.setText(text);
        button.setAllCaps(false);
        button.setTextColor(0xFFFCA5A5);
        button.setTextSize(13f);
        button.setTypeface(Typeface.DEFAULT_BOLD);
        button.setMinHeight(0);
        button.setMinWidth(0);
        button.setPadding(dpx(10), 0, dpx(10), 0);
        button.setBackground(roundedBg(0x28EF4444, 0x77EF4444, 12, 1));
        button.setOnClickListener(listener);
        return button;
    }

    private GradientDrawable pageScrimBg() {
        GradientDrawable bg = new GradientDrawable(
                GradientDrawable.Orientation.TOP_BOTTOM,
                new int[]{0xE6050B1A, 0xF5071128, 0xFA091632});
        return bg;
    }

    private GradientDrawable headerBg() {
        GradientDrawable bg = new GradientDrawable(
                GradientDrawable.Orientation.LEFT_RIGHT,
                new int[]{0xF0081634, 0xEE0F2448, 0xF0091838});
        bg.setCornerRadius(dpx(18));
        bg.setStroke(dpx(1), 0x5560A5FA);
        return bg;
    }

    private GradientDrawable sectionBg(int accent) {
        GradientDrawable bg = new GradientDrawable(
                GradientDrawable.Orientation.TOP_BOTTOM,
                new int[]{0xD007132B, 0xE00A1A38});
        bg.setCornerRadius(dpx(18));
        bg.setStroke(dpx(1), withAlpha(accent, 0x55));
        return bg;
    }

    private GradientDrawable cardBg(int accent) {
        GradientDrawable bg = new GradientDrawable(
                GradientDrawable.Orientation.LEFT_RIGHT,
                new int[]{0xF00B1836, 0xEB112547});
        bg.setCornerRadius(dpx(16));
        bg.setStroke(dpx(1), withAlpha(accent, 0x88));
        return bg;
    }

    private GradientDrawable buttonBg(int startColor, int endColor) {
        GradientDrawable bg = new GradientDrawable(
                GradientDrawable.Orientation.LEFT_RIGHT,
                new int[]{startColor, endColor});
        bg.setCornerRadius(dpx(14));
        bg.setStroke(dpx(1), 0x77FFFFFF);
        return bg;
    }

    private GradientDrawable scorePillBg() {
        GradientDrawable bg = new GradientDrawable(
                GradientDrawable.Orientation.LEFT_RIGHT,
                new int[]{0xFF0E294A, 0xFF0D435C});
        bg.setCornerRadius(dpx(14));
        bg.setStroke(dpx(1), 0x887DD3FC);
        return bg;
    }

    private GradientDrawable chipBg(int color, int fillAlpha) {
        return roundedBg(withAlpha(color, fillAlpha), withAlpha(color, 0xBB), 12, 1);
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
