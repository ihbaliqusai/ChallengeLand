package com.qi7bali.landchallengeonline;

import androidx.appcompat.app.AlertDialog;
import androidx.appcompat.app.AppCompatActivity;

import android.content.Context;
import android.content.Intent;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.os.Bundle;
import android.text.TextUtils;
import android.util.TypedValue;
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
import android.widget.Toast;

import org.json.JSONArray;
import org.json.JSONObject;

import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.Locale;

public class LocalTeamsGamesActivity extends AppCompatActivity {
    // ---- Luxury Esports Palette ----
    private static final int GOLD = 0xFFFFD700;
    private static final int GOLD_ACCENT = 0xFFFFC107;
    private static final int GOLD_LIGHT = 0xFFFFF1A8;
    private static final int BLUE = 0xFF38BDF8;
    private static final int BLUE_ACCENT = 0xFF0284C7;
    private static final int BLUE_LIGHT = 0xFFBAE6FD;
    private static final int GREEN = 0xFF10B981;
    private static final int GREEN_LIGHT = 0xFF6EE7B7;
    private static final int RED = 0xFFEF4444;
    private static final int TEXT_WHITE = 0xFFF8FAFC;
    private static final int TEXT_MUTED = 0xFF94A3B8;

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
        getWindow().getDecorView().setSystemUiVisibility(
                View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                        | View.SYSTEM_UI_FLAG_FULLSCREEN
                        | View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY);
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
        shell.setPadding(dpx(16), dpx(10), dpx(16), dpx(10));
        root.addView(shell, new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT));

        // 4. Luxury Header (Height ~98dp)
        shell.addView(createHeader(), new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, dpx(98)));

        // 5. Duel Lists Arena (Body columns)
        LinearLayout body = new LinearLayout(this);
        body.setOrientation(LinearLayout.HORIZONTAL);
        LinearLayout.LayoutParams bodyLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f);
        bodyLp.topMargin = dpx(8);
        shell.addView(body, bodyLp);

        // Active matches section
        View activeSection = createSection("المواجهات الجارية",
                "استأنف مباريات الفرق المحتدمة من آخر سؤال", true);
        LinearLayout.LayoutParams activeLp = new LinearLayout.LayoutParams(0,
                LinearLayout.LayoutParams.MATCH_PARENT, 1.05f);
        activeLp.setMargins(0, 0, dpx(6), 0);
        body.addView(activeSection, activeLp);

        // History archive section
        View historySection = createSection("سجل الأبطال والأرشيف",
                "سجل المباريات المنتهية ونتائج الفائزين", false);
        LinearLayout.LayoutParams historyLp = new LinearLayout.LayoutParams(0,
                LinearLayout.LayoutParams.MATCH_PARENT, 0.95f);
        historyLp.setMargins(dpx(6), 0, 0, 0);
        body.addView(historySection, historyLp);

        setContentView(root);
    }

    private View createHeader() {
        LinearLayout header = new LinearLayout(this);
        header.setOrientation(LinearLayout.VERTICAL);
        header.setBackground(gradientCardBg(0xEE09142C, 0xF8050C1F, 0x66FFD700, 16, 1));
        header.setPadding(dpx(14), dpx(8), dpx(14), dpx(8));

        // Top Row: Navigation + Identity + Primary CTA
        LinearLayout topRow = new LinearLayout(this);
        topRow.setOrientation(LinearLayout.HORIZONTAL);
        topRow.setGravity(Gravity.CENTER_VERTICAL);

        // Back button with refined frosted glass
        Button backBtn = new Button(this);
        backBtn.setText("‹");
        backBtn.setTextColor(TEXT_WHITE);
        backBtn.setTextSize(TypedValue.COMPLEX_UNIT_SP, 20f);
        backBtn.setTypeface(Typeface.DEFAULT_BOLD);
        backBtn.setBackground(pillBg(0x33FFFFFF, 0x55FFFFFF, 1));
        backBtn.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                finish();
            }
        });
        topRow.addView(backBtn, new LinearLayout.LayoutParams(dpx(38), dpx(38)));

        // Title Column
        LinearLayout titleCol = new LinearLayout(this);
        titleCol.setOrientation(LinearLayout.VERTICAL);
        LinearLayout.LayoutParams titleLp = new LinearLayout.LayoutParams(0,
                LinearLayout.LayoutParams.WRAP_CONTENT, 1f);
        titleLp.setMargins(dpx(10), 0, dpx(10), 0);
        titleCol.setLayoutParams(titleLp);

        TextView tag = new TextView(this);
        tag.setText("👑 بطولة التحدي الرئيسي • مواجهة الفرق المحلية");
        tag.setTextColor(GOLD);
        tag.setTextSize(TypedValue.COMPLEX_UNIT_SP, 10.5f);
        tag.setTypeface(Typeface.DEFAULT_BOLD);
        titleCol.addView(tag);

        TextView title = new TextView(this);
        title.setText("إدارة مباريات التحدي الرئيسي");
        title.setTextColor(TEXT_WHITE);
        title.setTextSize(TypedValue.COMPLEX_UNIT_SP, 16.5f);
        title.setTypeface(Typeface.DEFAULT_BOLD);
        titleCol.addView(title);

        topRow.addView(titleCol);

        // Hero Action Button (+ New Match)
        Button newBtn = new Button(this);
        newBtn.setText("＋ مباراة جديدة ⚔️");
        newBtn.setTextColor(0xFF030D1C);
        newBtn.setTextSize(TypedValue.COMPLEX_UNIT_SP, 12.5f);
        newBtn.setTypeface(Typeface.DEFAULT_BOLD);
        newBtn.setAllCaps(false);
        newBtn.setBackground(gradientPillBg(0xFFFFC727, 0xFFFFA000, 0xFFFFF1A8, 1));
        newBtn.setPadding(dpx(16), 0, dpx(16), 0);
        newBtn.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                startNewMatch();
            }
        });
        topRow.addView(newBtn, new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT, dpx(38)));

        header.addView(topRow);

        // Bottom Stats Telemetry Strip
        LinearLayout statsRow = new LinearLayout(this);
        statsRow.setOrientation(LinearLayout.HORIZONTAL);
        statsRow.setGravity(Gravity.CENTER_VERTICAL);
        LinearLayout.LayoutParams statsLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        statsLp.topMargin = dpx(6);
        statsRow.setLayoutParams(statsLp);

        activeCountView = createChip(GOLD, 0x2BFFD700, 0x88FFD700, "⚡ 0 جارية");
        statsRow.addView(activeCountView);

        historyCountView = createChip(BLUE, 0x2B38BDF8, 0x8838BDF8, "🏆 0 بالسجل");
        LinearLayout.LayoutParams hcLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        hcLp.setMargins(dpx(6), 0, dpx(6), 0);
        historyCountView.setLayoutParams(hcLp);
        statsRow.addView(historyCountView);

        summaryView = new TextView(this);
        summaryView.setTextColor(TEXT_MUTED);
        summaryView.setTextSize(TypedValue.COMPLEX_UNIT_SP, 10.5f);
        summaryView.setSingleLine(true);
        summaryView.setEllipsize(TextUtils.TruncateAt.END);
        statsRow.addView(summaryView, new LinearLayout.LayoutParams(0,
                LinearLayout.LayoutParams.WRAP_CONTENT, 1f));

        header.addView(statsRow);

        return header;
    }

    private TextView createChip(int textColor, int bgColor, int strokeColor, String text) {
        TextView tv = new TextView(this);
        tv.setText(text);
        tv.setTextColor(textColor);
        tv.setTextSize(TypedValue.COMPLEX_UNIT_SP, 10f);
        tv.setTypeface(Typeface.DEFAULT_BOLD);
        tv.setPadding(dpx(10), dpx(2), dpx(10), dpx(2));
        tv.setBackground(cardBg(bgColor, strokeColor, 999, 1));
        return tv;
    }

    private View createSection(String title, String subtitle, boolean active) {
        LinearLayout section = new LinearLayout(this);
        section.setOrientation(LinearLayout.VERTICAL);
        section.setBackground(gradientCardBg(
                active ? 0xEA0B1939 : 0xDE071128,
                active ? 0xF5061129 : 0xEB040A1A,
                active ? 0x66FFD700 : 0x4438BDF8,
                14, 1));
        section.setPadding(dpx(12), dpx(8), dpx(12), dpx(8));

        // Section Header Row
        LinearLayout head = new LinearLayout(this);
        head.setOrientation(LinearLayout.HORIZONTAL);
        head.setGravity(Gravity.CENTER_VERTICAL);

        TextView titleView = new TextView(this);
        titleView.setText((active ? "⚡ " : "🏆 ") + title);
        titleView.setTextColor(active ? GOLD : BLUE);
        titleView.setTextSize(TypedValue.COMPLEX_UNIT_SP, 12.5f);
        titleView.setTypeface(Typeface.DEFAULT_BOLD);
        head.addView(titleView, new LinearLayout.LayoutParams(0,
                LinearLayout.LayoutParams.WRAP_CONTENT, 1f));

        if (!active) {
            Button clearBtn = new Button(this);
            clearBtn.setText("🧹 تنظيف السجل");
            clearBtn.setTextColor(TEXT_MUTED);
            clearBtn.setTextSize(TypedValue.COMPLEX_UNIT_SP, 9.5f);
            clearBtn.setTypeface(Typeface.DEFAULT_BOLD);
            clearBtn.setAllCaps(false);
            clearBtn.setBackground(pillBg(0x22FFFFFF, 0x44FFFFFF, 1));
            clearBtn.setPadding(dpx(8), 0, dpx(8), 0);
            clearBtn.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View v) {
                    confirmClearHistory();
                }
            });
            head.addView(clearBtn, new LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.WRAP_CONTENT, dpx(26)));
        }

        section.addView(head);

        TextView subView = new TextView(this);
        subView.setText(subtitle);
        subView.setTextColor(TEXT_MUTED);
        subView.setTextSize(TypedValue.COMPLEX_UNIT_SP, 9.5f);
        LinearLayout.LayoutParams subLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        subLp.topMargin = dpx(2);
        subLp.bottomMargin = dpx(6);
        section.addView(subView, subLp);

        // Thin accent glowing line under section head
        View accentBar = new View(this);
        accentBar.setBackground(gradientPillBg(
                active ? 0x88FFD700 : 0x8838BDF8,
                0x00000000, 0x00000000, 0));
        LinearLayout.LayoutParams barLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, dpx(2));
        barLp.bottomMargin = dpx(6);
        accentBar.setLayoutParams(barLp);
        section.addView(accentBar);

        // Scroller container
        ScrollView scroller = new ScrollView(this);
        scroller.setVerticalScrollBarEnabled(false);
        LinearLayout list = new LinearLayout(this);
        list.setOrientation(LinearLayout.VERTICAL);
        scroller.addView(list, new ScrollView.LayoutParams(
                ScrollView.LayoutParams.MATCH_PARENT,
                ScrollView.LayoutParams.WRAP_CONTENT));

        if (active) {
            activeList = list;
        } else {
            historyList = list;
        }

        section.addView(scroller, new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f));

        return section;
    }

    private void refreshList() {
        if (activeList == null || historyList == null) return;
        activeList.removeAllViews();
        historyList.removeAllViews();

        ArrayList<JSONObject> all = LocalTeamsGameStore.all(this);
        int activeCount = 0;
        int finishedCount = 0;

        for (final JSONObject record : all) {
            boolean finished = LocalTeamsGameStore.isFinished(record);
            if (finished) {
                finishedCount++;
                historyList.addView(createCard(record, false));
            } else {
                activeCount++;
                activeList.addView(createCard(record, true));
            }
        }

        if (activeCount == 0) {
            activeList.addView(createEmptyView(
                    "لا توجد مباريات جارية حالياً",
                    "ابدأ مباراة جديدة واشعل المنافسة بين فريقين على جهاز واحد!",
                    true
            ));
        }

        if (finishedCount == 0) {
            historyList.addView(createEmptyView(
                    "السجل فارغ حتى الآن",
                    "المباريات المنتهية ونتائج تتويج الأبطال ستظهر هنا.",
                    false
            ));
        }

        if (activeCountView != null) {
            activeCountView.setText("⚡ " + activeCount + " جارية");
        }
        if (historyCountView != null) {
            historyCountView.setText("🏆 " + finishedCount + " بالسجل");
        }
        if (summaryView != null) {
            summaryView.setText("إجمالي المواجهات المسجلة: " + all.size());
        }
    }

    private View createEmptyView(String title, String subtitle, boolean canCreate) {
        LinearLayout empty = new LinearLayout(this);
        empty.setOrientation(LinearLayout.VERTICAL);
        empty.setGravity(Gravity.CENTER);
        empty.setPadding(dpx(16), dpx(20), dpx(16), dpx(20));
        empty.setBackground(cardBg(0x35030816, 0x22FFFFFF, 12, 1));
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        lp.topMargin = dpx(6);
        empty.setLayoutParams(lp);

        // Circular Icon Badge
        TextView iconView = new TextView(this);
        iconView.setText(canCreate ? "⚔️" : "🏆");
        iconView.setTextSize(TypedValue.COMPLEX_UNIT_SP, 22f);
        iconView.setGravity(Gravity.CENTER);
        iconView.setBackground(pillBg(0x22FFFFFF, canCreate ? 0x44FFD700 : 0x4438BDF8, 1));
        LinearLayout.LayoutParams iconLp = new LinearLayout.LayoutParams(dpx(46), dpx(46));
        iconLp.bottomMargin = dpx(8);
        iconView.setLayoutParams(iconLp);
        empty.addView(iconView);

        TextView tvTitle = new TextView(this);
        tvTitle.setText(title);
        tvTitle.setTextColor(TEXT_WHITE);
        tvTitle.setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f);
        tvTitle.setTypeface(Typeface.DEFAULT_BOLD);
        tvTitle.setGravity(Gravity.CENTER);
        empty.addView(tvTitle);

        TextView tvSub = new TextView(this);
        tvSub.setText(subtitle);
        tvSub.setTextColor(TEXT_MUTED);
        tvSub.setTextSize(TypedValue.COMPLEX_UNIT_SP, 10f);
        tvSub.setGravity(Gravity.CENTER);
        LinearLayout.LayoutParams subLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        subLp.topMargin = dpx(3);
        empty.addView(tvSub, subLp);

        if (canCreate) {
            Button quickBtn = new Button(this);
            quickBtn.setText("＋ بدء التحدي الآن ⚡");
            quickBtn.setTextColor(0xFF030D1C);
            quickBtn.setTextSize(TypedValue.COMPLEX_UNIT_SP, 10.5f);
            quickBtn.setTypeface(Typeface.DEFAULT_BOLD);
            quickBtn.setAllCaps(false);
            quickBtn.setBackground(gradientPillBg(GOLD, 0xFFFFA000, 0xFFFFFFFF, 1));
            quickBtn.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View v) {
                    startNewMatch();
                }
            });
            LinearLayout.LayoutParams btnLp = new LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.WRAP_CONTENT, dpx(32));
            btnLp.topMargin = dpx(10);
            empty.addView(quickBtn, btnLp);
        }

        return empty;
    }

    private View createCard(final JSONObject record, final boolean active) {
        final String id = record.optString("id", "");
        final String teamA = record.optString("teamAName", "الفريق الأول");
        final String teamB = record.optString("teamBName", "الفريق الثاني");
        final int scoreA = record.optInt("scoreA", 0);
        final int scoreB = record.optInt("scoreB", 0);
        final int turn = record.optInt("turnIndex", 0);
        final int totalTurns = record.optInt("totalTurns", 30);
        final String phase = record.optString("phase", LocalTeamsGameStore.PHASE_BOARD);
        final long updated = record.optLong("updatedAt", System.currentTimeMillis());

        LinearLayout card = new LinearLayout(this);
        card.setOrientation(LinearLayout.VERTICAL);
        card.setBackground(gradientCardBg(
                active ? 0xF20B1C40 : 0xE606122C,
                active ? 0xF0050D24 : 0xDF030919,
                active ? 0x88FFD700 : 0x4438BDF8,
                14, 1));
        card.setPadding(dpx(12), dpx(8), dpx(12), dpx(8));
        LinearLayout.LayoutParams cardLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        cardLp.bottomMargin = dpx(8);
        card.setLayoutParams(cardLp);

        // 1. Top status line (Timestamp + Phase Badge)
        LinearLayout topRow = new LinearLayout(this);
        topRow.setOrientation(LinearLayout.HORIZONTAL);
        topRow.setGravity(Gravity.CENTER_VERTICAL);

        TextView timeView = new TextView(this);
        timeView.setText("🕒 " + dateFormat.format(new Date(updated)));
        timeView.setTextColor(TEXT_MUTED);
        timeView.setTextSize(TypedValue.COMPLEX_UNIT_SP, 9f);
        topRow.addView(timeView, new LinearLayout.LayoutParams(0,
                LinearLayout.LayoutParams.WRAP_CONTENT, 1f));

        TextView statusBadge = new TextView(this);
        if (active) {
            String phaseText = "لوحة التحدي";
            if (LocalTeamsGameStore.PHASE_CATEGORY_SELECT.equals(phase)) phaseText = "اختيار الفئات";
            else if (LocalTeamsGameStore.PHASE_QUESTION.equals(phase)) phaseText = "سؤال جاري";
            statusBadge.setText("⚡ " + phaseText);
            statusBadge.setTextColor(GREEN_LIGHT);
            statusBadge.setBackground(cardBg(0x3310B981, GREEN, 999, 1));
        } else {
            String winnerText = "تعادل";
            int badgeColor = 0xFF94A3B8;
            if (scoreA > scoreB) {
                winnerText = "فوز " + teamA;
                badgeColor = GOLD;
            } else if (scoreB > scoreA) {
                winnerText = "فوز " + teamB;
                badgeColor = BLUE;
            }
            statusBadge.setText("🏆 " + winnerText);
            statusBadge.setTextColor(badgeColor);
            statusBadge.setBackground(cardBg(0x33000000, badgeColor, 999, 1));
        }
        statusBadge.setTextSize(TypedValue.COMPLEX_UNIT_SP, 9f);
        statusBadge.setTypeface(Typeface.DEFAULT_BOLD);
        statusBadge.setPadding(dpx(8), dpx(2), dpx(8), dpx(2));
        topRow.addView(statusBadge);

        card.addView(topRow);

        // 2. Esports "VS" Arena Row
        LinearLayout duelRow = new LinearLayout(this);
        duelRow.setOrientation(LinearLayout.HORIZONTAL);
        duelRow.setGravity(Gravity.CENTER_VERTICAL);
        LinearLayout.LayoutParams duelLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        duelLp.topMargin = dpx(6);
        duelLp.bottomMargin = dpx(6);
        duelRow.setLayoutParams(duelLp);

        // Team A Block
        LinearLayout teamABox = new LinearLayout(this);
        teamABox.setOrientation(LinearLayout.VERTICAL);
        teamABox.setGravity(Gravity.RIGHT);
        LinearLayout.LayoutParams tabLp = new LinearLayout.LayoutParams(0,
                LinearLayout.LayoutParams.WRAP_CONTENT, 1f);
        teamABox.setLayoutParams(tabLp);

        TextView aTag = new TextView(this);
        aTag.setText("🛡️ الفريق الأول");
        aTag.setTextColor(0xFFE2B852);
        aTag.setTextSize(TypedValue.COMPLEX_UNIT_SP, 8.5f);
        teamABox.addView(aTag);

        TextView aName = new TextView(this);
        aName.setText(teamA);
        aName.setTextColor(GOLD);
        aName.setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f);
        aName.setTypeface(Typeface.DEFAULT_BOLD);
        aName.setSingleLine(true);
        aName.setEllipsize(TextUtils.TruncateAt.END);
        teamABox.addView(aName);

        TextView aScore = new TextView(this);
        aScore.setText(scoreA + " نقطة");
        aScore.setTextColor(TEXT_WHITE);
        aScore.setTextSize(TypedValue.COMPLEX_UNIT_SP, 10.5f);
        aScore.setTypeface(Typeface.DEFAULT_BOLD);
        teamABox.addView(aScore);

        duelRow.addView(teamABox);

        // Center VS Badge
        TextView vsBadge = new TextView(this);
        vsBadge.setText("VS");
        vsBadge.setTextColor(0xFFFFE082);
        vsBadge.setTextSize(TypedValue.COMPLEX_UNIT_SP, 10f);
        vsBadge.setTypeface(Typeface.DEFAULT_BOLD);
        vsBadge.setGravity(Gravity.CENTER);
        vsBadge.setBackground(gradientPillBg(0x66020617, 0x991E293B, 0x88FFD700, 1));
        LinearLayout.LayoutParams vsLp = new LinearLayout.LayoutParams(dpx(32), dpx(32));
        vsLp.setMargins(dpx(6), 0, dpx(6), 0);
        vsBadge.setLayoutParams(vsLp);
        duelRow.addView(vsBadge);

        // Team B Block
        LinearLayout teamBBox = new LinearLayout(this);
        teamBBox.setOrientation(LinearLayout.VERTICAL);
        teamBBox.setGravity(Gravity.LEFT);
        LinearLayout.LayoutParams tbbLp = new LinearLayout.LayoutParams(0,
                LinearLayout.LayoutParams.WRAP_CONTENT, 1f);
        teamBBox.setLayoutParams(tbbLp);

        TextView bTag = new TextView(this);
        bTag.setText("الفريق الثاني ⚔️");
        bTag.setTextColor(0xFF7DD3FC);
        bTag.setTextSize(TypedValue.COMPLEX_UNIT_SP, 8.5f);
        teamBBox.addView(bTag);

        TextView bName = new TextView(this);
        bName.setText(teamB);
        bName.setTextColor(BLUE);
        bName.setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f);
        bName.setTypeface(Typeface.DEFAULT_BOLD);
        bName.setGravity(Gravity.LEFT);
        bName.setSingleLine(true);
        bName.setEllipsize(TextUtils.TruncateAt.END);
        teamBBox.addView(bName);

        TextView bScore = new TextView(this);
        bScore.setText(scoreB + " نقطة");
        bScore.setTextColor(TEXT_WHITE);
        bScore.setTextSize(TypedValue.COMPLEX_UNIT_SP, 10.5f);
        bScore.setTypeface(Typeface.DEFAULT_BOLD);
        bScore.setGravity(Gravity.LEFT);
        teamBBox.addView(bScore);

        duelRow.addView(teamBBox);

        card.addView(duelRow);

        // 3. Progress Bar & Telemetry Row
        LinearLayout progressRow = new LinearLayout(this);
        progressRow.setOrientation(LinearLayout.VERTICAL);
        LinearLayout.LayoutParams prLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        prLp.topMargin = dpx(2);
        prLp.bottomMargin = dpx(6);
        progressRow.setLayoutParams(prLp);

        LinearLayout progressInfo = new LinearLayout(this);
        progressInfo.setOrientation(LinearLayout.HORIZONTAL);
        TextView turnInfo = new TextView(this);
        turnInfo.setText("التقدم: الدور " + turn + " من " + totalTurns);
        turnInfo.setTextColor(TEXT_MUTED);
        turnInfo.setTextSize(TypedValue.COMPLEX_UNIT_SP, 9f);
        progressInfo.addView(turnInfo, new LinearLayout.LayoutParams(0,
                LinearLayout.LayoutParams.WRAP_CONTENT, 1f));

        int percent = (int) Math.min(100, Math.max(0, (turn * 100.0f) / Math.max(1, totalTurns)));
        TextView percentInfo = new TextView(this);
        percentInfo.setText(percent + "%");
        percentInfo.setTextColor(active ? GOLD : BLUE);
        percentInfo.setTextSize(TypedValue.COMPLEX_UNIT_SP, 9f);
        percentInfo.setTypeface(Typeface.DEFAULT_BOLD);
        progressInfo.addView(percentInfo);
        progressRow.addView(progressInfo);

        // Visual Progress Track
        FrameLayout progressTrack = new FrameLayout(this);
        progressTrack.setBackground(cardBg(0x331E293B, 0x22FFFFFF, 999, 1));
        LinearLayout.LayoutParams trackLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, dpx(5));
        trackLp.topMargin = dpx(3);
        progressTrack.setLayoutParams(trackLp);

        View progressFill = new View(this);
        progressFill.setBackground(gradientPillBg(
                GOLD, active ? 0xFF10B981 : BLUE, 0x00000000, 0));
        FrameLayout.LayoutParams fillLp = new FrameLayout.LayoutParams(
                Math.max(dpx(6), (int) (dpx(180) * (percent / 100.0f))),
                FrameLayout.LayoutParams.MATCH_PARENT);
        fillLp.gravity = Gravity.RIGHT;
        progressFill.setLayoutParams(fillLp);
        progressTrack.addView(progressFill);

        progressRow.addView(progressTrack);
        card.addView(progressRow);

        // 4. Action Footer Row
        LinearLayout actionRow = new LinearLayout(this);
        actionRow.setOrientation(LinearLayout.HORIZONTAL);
        actionRow.setGravity(Gravity.CENTER_VERTICAL);
        LinearLayout.LayoutParams arLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        arLp.topMargin = dpx(2);
        actionRow.setLayoutParams(arLp);

        if (active) {
            Button resumeBtn = new Button(this);
            resumeBtn.setText("⚔️ متابعة التحدي");
            resumeBtn.setTextColor(TEXT_WHITE);
            resumeBtn.setTextSize(TypedValue.COMPLEX_UNIT_SP, 11f);
            resumeBtn.setTypeface(Typeface.DEFAULT_BOLD);
            resumeBtn.setAllCaps(false);
            resumeBtn.setBackground(gradientPillBg(0xFF059669, 0xFF10B981, 0xFF6EE7B7, 1));
            resumeBtn.setPadding(dpx(14), 0, dpx(14), 0);
            resumeBtn.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View v) {
                    resumeMatch(id);
                }
            });
            LinearLayout.LayoutParams resLp = new LinearLayout.LayoutParams(0, dpx(32), 1f);
            resLp.setMargins(dpx(6), 0, 0, 0);
            actionRow.addView(resumeBtn, resLp);
        } else {
            TextView archInfo = new TextView(this);
            archInfo.setText("📁 مباراة مكتملة ومؤرشفة");
            archInfo.setTextColor(TEXT_MUTED);
            archInfo.setTextSize(TypedValue.COMPLEX_UNIT_SP, 9.5f);
            actionRow.addView(archInfo, new LinearLayout.LayoutParams(0,
                    LinearLayout.LayoutParams.WRAP_CONTENT, 1f));
        }

        Button deleteBtn = new Button(this);
        deleteBtn.setText("🗑️");
        deleteBtn.setTextColor(RED);
        deleteBtn.setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f);
        deleteBtn.setBackground(pillBg(0x2BEE4444, 0x66EE4444, 1));
        deleteBtn.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                confirmDelete(id, teamA + " ضد " + teamB);
            }
        });
        LinearLayout.LayoutParams delLp = new LinearLayout.LayoutParams(dpx(34), dpx(32));
        actionRow.addView(deleteBtn, delLp);

        card.addView(actionRow);

        return card;
    }

    private void startNewMatch() {
        Intent intent = new Intent(this, GameActivity.class);
        intent.putExtra("mode", "mono");
        intent.putExtra("localTeams", true);
        intent.putExtra("characterIndex", AppPrefs.getEffectiveCharacter(this));
        startActivity(intent);
    }

    private void resumeMatch(String saveId) {
        if (TextUtils.isEmpty(saveId)) return;
        Intent intent = new Intent(this, GameActivity.class);
        intent.putExtra("mode", "mono");
        intent.putExtra("localTeams", true);
        intent.putExtra("resumeLocalTeams", true);
        intent.putExtra("localTeamsSaveId", saveId);
        intent.putExtra("characterIndex", AppPrefs.getEffectiveCharacter(this));
        startActivity(intent);
    }

    private void confirmDelete(final String id, String matchLabel) {
        showCustomConfirmDialog(
                "⚠️ تأكيد حذف المباراة",
                "هل أنت متأكد من رغبتك في حذف مباراة «" + matchLabel + "» نهائياً؟",
                "نعم، حذف",
                new Runnable() {
                    @Override
                    public void run() {
                        boolean ok = LocalTeamsGameStore.delete(LocalTeamsGamesActivity.this, id);
                        if (ok) {
                            Toast.makeText(LocalTeamsGamesActivity.this, "تم حذف المباراة بنجاح", Toast.LENGTH_SHORT).show();
                            refreshList();
                        }
                    }
                }
        );
    }

    private void confirmClearHistory() {
        showCustomConfirmDialog(
                "🧹 تنظيف سجل المباريات",
                "هل تريد حذف جميع المباريات المنتهية من السجل؟",
                "نعم، تنظيف",
                new Runnable() {
                    @Override
                    public void run() {
                        int count = LocalTeamsGameStore.clearFinished(LocalTeamsGamesActivity.this);
                        Toast.makeText(LocalTeamsGamesActivity.this, "تم تنظيف " + count + " مباراة من السجل", Toast.LENGTH_SHORT).show();
                        refreshList();
                    }
                }
        );
    }

    private void showCustomConfirmDialog(String title, String message, String confirmText, final Runnable onConfirm) {
        LinearLayout dialogView = new LinearLayout(this);
        dialogView.setOrientation(LinearLayout.VERTICAL);
        dialogView.setPadding(dpx(22), dpx(20), dpx(22), dpx(20));
        dialogView.setBackground(gradientCardBg(0xF50A183C, 0xF5050C1F, 0x88FFD700, 18, 1));
        dialogView.setLayoutDirection(View.LAYOUT_DIRECTION_RTL);

        TextView tvTitle = new TextView(this);
        tvTitle.setText(title);
        tvTitle.setTextColor(GOLD);
        tvTitle.setTextSize(TypedValue.COMPLEX_UNIT_SP, 15.5f);
        tvTitle.setTypeface(Typeface.DEFAULT_BOLD);
        dialogView.addView(tvTitle);

        TextView tvMsg = new TextView(this);
        tvMsg.setText(message);
        tvMsg.setTextColor(TEXT_WHITE);
        tvMsg.setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f);
        LinearLayout.LayoutParams msgLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        msgLp.topMargin = dpx(8);
        msgLp.bottomMargin = dpx(16);
        dialogView.addView(tvMsg, msgLp);

        LinearLayout btnRow = new LinearLayout(this);
        btnRow.setOrientation(LinearLayout.HORIZONTAL);
        btnRow.setGravity(Gravity.CENTER_VERTICAL);

        final AlertDialog dialog = new AlertDialog.Builder(this)
                .setView(dialogView)
                .create();

        if (dialog.getWindow() != null) {
            dialog.getWindow().setBackgroundDrawableResource(android.R.color.transparent);
        }

        Button confirmBtn = new Button(this);
        confirmBtn.setText(confirmText);
        confirmBtn.setAllCaps(false);
        confirmBtn.setTextColor(TEXT_WHITE);
        confirmBtn.setTypeface(Typeface.DEFAULT_BOLD);
        confirmBtn.setTextSize(TypedValue.COMPLEX_UNIT_SP, 11.5f);
        confirmBtn.setBackground(gradientPillBg(RED, 0xFFDC2626, 0xFFFF7777, 1));
        confirmBtn.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                dialog.dismiss();
                if (onConfirm != null) onConfirm.run();
            }
        });
        LinearLayout.LayoutParams confLp = new LinearLayout.LayoutParams(0, dpx(38), 1f);
        confLp.setMargins(0, 0, dpx(8), 0);
        btnRow.addView(confirmBtn, confLp);

        Button cancelBtn = new Button(this);
        cancelBtn.setText("إلغاء");
        cancelBtn.setAllCaps(false);
        cancelBtn.setTextColor(TEXT_MUTED);
        cancelBtn.setTextSize(TypedValue.COMPLEX_UNIT_SP, 11.5f);
        cancelBtn.setBackground(pillBg(0x33FFFFFF, 0x55FFFFFF, 1));
        cancelBtn.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                dialog.dismiss();
            }
        });
        LinearLayout.LayoutParams canLp = new LinearLayout.LayoutParams(dpx(75), dpx(38));
        btnRow.addView(cancelBtn, canLp);

        dialogView.addView(btnRow, new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT));

        dialog.show();
    }

    private GradientDrawable pageScrimBg() {
        return new GradientDrawable(
                GradientDrawable.Orientation.TOP_BOTTOM,
                new int[]{0xF2030818, 0xF506132F, 0xFA02050E});
    }

    private GradientDrawable cardBg(int fillColor, int strokeColor, int radiusDp, int strokeDp) {
        GradientDrawable gd = new GradientDrawable();
        gd.setColor(fillColor);
        gd.setCornerRadius(dpx(radiusDp));
        if (strokeDp > 0) gd.setStroke(dpx(strokeDp), strokeColor);
        return gd;
    }

    private GradientDrawable gradientCardBg(int startColor, int endColor, int strokeColor, int radiusDp, int strokeDp) {
        GradientDrawable gd = new GradientDrawable(
                GradientDrawable.Orientation.TOP_BOTTOM,
                new int[]{startColor, endColor});
        gd.setCornerRadius(dpx(radiusDp));
        if (strokeDp > 0) gd.setStroke(dpx(strokeDp), strokeColor);
        return gd;
    }

    private GradientDrawable pillBg(int fillColor, int strokeColor, int strokeDp) {
        GradientDrawable gd = new GradientDrawable();
        gd.setColor(fillColor);
        gd.setCornerRadius(dpx(999));
        if (strokeDp > 0) gd.setStroke(dpx(strokeDp), strokeColor);
        return gd;
    }

    private GradientDrawable gradientPillBg(int startColor, int endColor, int strokeColor, int strokeDp) {
        GradientDrawable gd = new GradientDrawable(
                GradientDrawable.Orientation.LEFT_RIGHT,
                new int[]{startColor, endColor});
        gd.setCornerRadius(dpx(999));
        if (strokeDp > 0) gd.setStroke(dpx(strokeDp), strokeColor);
        return gd;
    }

    private int dpx(float dp) {
        return (int) (dp * getResources().getDisplayMetrics().density + 0.5f);
    }
}
