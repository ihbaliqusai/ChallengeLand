package com.qi7bali.landchallengeonline;

import androidx.appcompat.app.AlertDialog;

import android.content.Context;
import android.content.Intent;
import android.content.res.ColorStateList;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.Drawable;
import android.graphics.drawable.GradientDrawable;
import android.graphics.drawable.RippleDrawable;
import android.os.Build;
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

/**
 * شاشة إدارة مباريات الأوف لاين (تحدي اللوحة الفردي والتنافسي بدون إنترنت).
 * تم إعادة تصميمها بالكامل بهوية Esports Championship فخمة وعصرية،
 * مع دعم شريط القياسات الحية، وإحصائيات المنافسين، وسجل الأبطال.
 */
public class OfflineGamesActivity extends GameViewportActivity {

    // ==========================================
    // لوحة الألوان الفاخرة (Esports Luxury Theme)
    // ==========================================
    private static final int GOLD = 0xFFFFD700;
    private static final int GOLD_LIGHT = 0xFFFFF1A8;
    private static final int GOLD_WARM = 0xFFFFB300;
    private static final int GOLD_ACCENT = 0xFFFFA000;
    private static final int GOLD_DARK = 0xFFB45309;

    private static final int CYAN = 0xFF38BDF8;
    private static final int CYAN_LIGHT = 0xFFBAE6FD;
    private static final int CYAN_DARK = 0xFF0284C7;

    private static final int EMERALD = 0xFF10B981;
    private static final int EMERALD_LIGHT = 0xFF6EE7B7;
    private static final int EMERALD_DARK = 0xFF059669;

    private static final int PURPLE = 0xFFA855F7;
    private static final int PURPLE_LIGHT = 0xFFE9D5FF;

    private static final int RED = 0xFFEF4444;
    private static final int RED_DARK = 0xFFDC2626;

    private static final int TEXT_WHITE = 0xFFF8FAFC;
    private static final int TEXT_GOLD = 0xFFFFF0B3;
    private static final int TEXT_CYAN = 0xFFBAE6FD;
    private static final int TEXT_MUTED = 0xFF94A3B8;
    private static final int TEXT_MUTED_LIGHT = 0xFFCBD5E1;
    private static final int TEXT_DARK = 0xFF030D1C;

    private LinearLayout activeList;
    private LinearLayout historyList;
    private TextView activeCountBadge;
    private TextView historyCountBadge;
    private TextView totalStatsBadge;

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

    // ==========================================
    // بناء الهيكل العام للصفحة (Architecture)
    // ==========================================
    private void buildLayout() {
        FrameLayout root = new FrameLayout(this);
        root.setLayoutDirection(View.LAYOUT_DIRECTION_RTL);

        // 1. خلفية اللعبة الأصلية بجودة عالية
        ImageView bg = new ImageView(this);
        bg.setImageResource(R.drawable.bg_game2);
        bg.setScaleType(ImageView.ScaleType.CENTER_CROP);
        root.addView(bg, new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT));

        // 2. طبقة حماية لونية بتدرج ملكي داكن وعميق
        View scrim = new View(this);
        scrim.setBackground(pageScrimBg());
        root.addView(scrim, new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT));

        // 3. الحاوية الرئيسية (Shell)
        LinearLayout shell = new LinearLayout(this);
        shell.setOrientation(LinearLayout.VERTICAL);
        shell.setPadding(dpx(16), dpx(10), dpx(16), dpx(10));
        root.addView(shell, new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT));

        // 4. رأس الصفحة الفخم (Grand Championship Header)
        shell.addView(createHeader(), new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT));

        // 5. ساحة المواجهات الثنائية (Dual Esports Columns)
        LinearLayout body = new LinearLayout(this);
        body.setOrientation(LinearLayout.HORIZONTAL);
        LinearLayout.LayoutParams bodyLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f);
        bodyLp.topMargin = dpx(8);
        shell.addView(body, bodyLp);

        // العمود الأول: المباريات القابلة للمتابعة (Active Offline Games)
        View activeSection = createSection(
                "المباريات القابلة للمتابعة",
                "أكمل مواجهات اللوحة من آخر نقطة حفظ فوراً",
                true
        );
        LinearLayout.LayoutParams activeLp = new LinearLayout.LayoutParams(0,
                LinearLayout.LayoutParams.MATCH_PARENT, 1.08f);
        activeLp.setMargins(0, 0, dpx(7), 0);
        body.addView(activeSection, activeLp);

        // العمود الثاني: سجل الأبطال والتتويج (Archive & Records)
        View historySection = createSection(
                "سجل الأبطال والتتويج",
                "أرشيف اللوحات المكتملة ونتائج الفائزين",
                false
        );
        LinearLayout.LayoutParams historyLp = new LinearLayout.LayoutParams(0,
                LinearLayout.LayoutParams.MATCH_PARENT, 0.92f);
        historyLp.setMargins(dpx(7), 0, 0, 0);
        body.addView(historySection, historyLp);

        setContentView(root);
    }

    // ==========================================
    // رأس الصفحة (Championship Header)
    // ==========================================
    private View createHeader() {
        LinearLayout header = new LinearLayout(this);
        header.setOrientation(LinearLayout.VERTICAL);
        header.setBackground(gradientCardBg(0xF40A1838, 0xFA040A1C, 0x66FFD700, 16, 1));
        header.setPadding(dpx(14), dpx(8), dpx(14), dpx(8));

        // الصف العلوي: زر الرجوع + العنوان الفخم + الأزرار الرئيسية
        LinearLayout topRow = new LinearLayout(this);
        topRow.setOrientation(LinearLayout.HORIZONTAL);
        topRow.setGravity(Gravity.CENTER_VERTICAL);

        // زر العودة بتصميم زجاجي ملكي
        Button backBtn = new Button(this);
        backBtn.setText("‹");
        backBtn.setTextColor(TEXT_WHITE);
        backBtn.setTextSize(TypedValue.COMPLEX_UNIT_SP, 22f);
        backBtn.setTypeface(Typeface.DEFAULT_BOLD);
        backBtn.setPadding(0, 0, 0, dpx(2));
        backBtn.setBackground(withRipple(cardBg(0x33FFFFFF, 0x66FFD700, 999, 1), 0x44FFFFFF));
        backBtn.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                finish();
            }
        });
        topRow.addView(backBtn, new LinearLayout.LayoutParams(dpx(40), dpx(40)));

        // أيقونة التحدي الفردي النردية
        TextView diceEmblem = new TextView(this);
        diceEmblem.setText("🎲");
        diceEmblem.setTextSize(TypedValue.COMPLEX_UNIT_SP, 20f);
        diceEmblem.setGravity(Gravity.CENTER);
        diceEmblem.setBackground(cardBg(0x2BFFD700, 0x77FFD700, 999, 1));
        LinearLayout.LayoutParams emblemLp = new LinearLayout.LayoutParams(dpx(40), dpx(40));
        emblemLp.setMargins(dpx(10), 0, dpx(10), 0);
        diceEmblem.setLayoutParams(emblemLp);
        topRow.addView(diceEmblem);

        // عامود العنوان والهوية
        LinearLayout titleCol = new LinearLayout(this);
        titleCol.setOrientation(LinearLayout.VERTICAL);
        LinearLayout.LayoutParams titleLp = new LinearLayout.LayoutParams(0,
                LinearLayout.LayoutParams.WRAP_CONTENT, 1f);
        titleCol.setLayoutParams(titleLp);

        TextView tag = new TextView(this);
        tag.setText("بطولة التحدي الفردي • لوحة الأوف لاين التنافسية بدون إنترنت");
        tag.setTextColor(GOLD_LIGHT);
        tag.setTextSize(TypedValue.COMPLEX_UNIT_SP, 10f);
        tag.setTypeface(Typeface.DEFAULT_BOLD);
        tag.setSingleLine(true);
        tag.setEllipsize(TextUtils.TruncateAt.END);
        titleCol.addView(tag);

        TextView title = new TextView(this);
        title.setText("إدارة مباريات الأوف لاين");
        title.setTextColor(TEXT_WHITE);
        title.setTextSize(TypedValue.COMPLEX_UNIT_SP, 16.5f);
        title.setTypeface(Typeface.DEFAULT_BOLD);
        titleCol.addView(title);

        topRow.addView(titleCol);

        // الزر البطل: بدء لعبة جديدة 🎲
        Button newGameBtn = new Button(this);
        newGameBtn.setText("＋ لعبة جديدة 🎲");
        newGameBtn.setTextColor(TEXT_DARK);
        newGameBtn.setTextSize(TypedValue.COMPLEX_UNIT_SP, 12.5f);
        newGameBtn.setTypeface(Typeface.DEFAULT_BOLD);
        newGameBtn.setAllCaps(false);
        newGameBtn.setBackground(withRipple(
                gradientPillBg(0xFFFFC727, 0xFFFF8F00, 0xFFFFF1A8, 1),
                0x33000000
        ));
        newGameBtn.setPadding(dpx(18), 0, dpx(18), 0);
        newGameBtn.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                startActivity(new Intent(OfflineGamesActivity.this, OfflineSetupActivity.class));
            }
        });
        topRow.addView(newGameBtn, new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT, dpx(38)));

        header.addView(topRow);

        // شريط القياسات والإحصائيات السريعة (Telemetry Strip)
        LinearLayout statsRow = new LinearLayout(this);
        statsRow.setOrientation(LinearLayout.HORIZONTAL);
        statsRow.setGravity(Gravity.CENTER_VERTICAL);
        LinearLayout.LayoutParams statsLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        statsLp.topMargin = dpx(6);
        statsRow.setLayoutParams(statsLp);

        activeCountBadge = createChip(GOLD, 0x2BFFD700, 0x88FFD700, "⚡ 0 متابعة");
        statsRow.addView(activeCountBadge);

        historyCountBadge = createChip(CYAN, 0x2B38BDF8, 0x8838BDF8, "🏆 0 بالسجل");
        LinearLayout.LayoutParams hcLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        hcLp.setMargins(dpx(6), 0, dpx(6), 0);
        historyCountBadge.setLayoutParams(hcLp);
        statsRow.addView(historyCountBadge);

        totalStatsBadge = new TextView(this);
        totalStatsBadge.setTextColor(TEXT_MUTED);
        totalStatsBadge.setTextSize(TypedValue.COMPLEX_UNIT_SP, 10f);
        totalStatsBadge.setSingleLine(true);
        totalStatsBadge.setEllipsize(TextUtils.TruncateAt.END);
        statsRow.addView(totalStatsBadge, new LinearLayout.LayoutParams(0,
                LinearLayout.LayoutParams.WRAP_CONTENT, 1f));

        header.addView(statsRow);

        return header;
    }

    // ==========================================
    // بناء قسم (عامود) المواجهات
    // ==========================================
    private View createSection(String title, String subtitle, boolean active) {
        LinearLayout section = new LinearLayout(this);
        section.setOrientation(LinearLayout.VERTICAL);
        section.setBackground(gradientCardBg(
                active ? 0xEE09183B : 0xEA07132D,
                active ? 0xF7040C22 : 0xF3030818,
                active ? 0x66FFD700 : 0x4438BDF8,
                16, 1));
        section.setPadding(dpx(12), dpx(8), dpx(12), dpx(8));

        // رأس القسم
        LinearLayout head = new LinearLayout(this);
        head.setOrientation(LinearLayout.HORIZONTAL);
        head.setGravity(Gravity.CENTER_VERTICAL);

        // أيقونة القسم الدائرية
        TextView secIcon = new TextView(this);
        secIcon.setText(active ? "⚡" : "🏆");
        secIcon.setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f);
        secIcon.setGravity(Gravity.CENTER);
        secIcon.setBackground(cardBg(
                active ? 0x33FFD700 : 0x3338BDF8,
                active ? 0x88FFD700 : 0x8838BDF8,
                999, 1));
        head.addView(secIcon, new LinearLayout.LayoutParams(dpx(28), dpx(28)));

        // عنوان القسم
        LinearLayout secTitleBox = new LinearLayout(this);
        secTitleBox.setOrientation(LinearLayout.VERTICAL);
        LinearLayout.LayoutParams stbLp = new LinearLayout.LayoutParams(0,
                LinearLayout.LayoutParams.WRAP_CONTENT, 1f);
        stbLp.setMargins(dpx(8), 0, dpx(8), 0);
        secTitleBox.setLayoutParams(stbLp);

        TextView titleView = new TextView(this);
        titleView.setText(title);
        titleView.setTextColor(active ? GOLD : CYAN);
        titleView.setTextSize(TypedValue.COMPLEX_UNIT_SP, 12.5f);
        titleView.setTypeface(Typeface.DEFAULT_BOLD);
        secTitleBox.addView(titleView);

        TextView subView = new TextView(this);
        subView.setText(subtitle);
        subView.setTextColor(TEXT_MUTED);
        subView.setTextSize(TypedValue.COMPLEX_UNIT_SP, 9f);
        subView.setSingleLine(true);
        subView.setEllipsize(TextUtils.TruncateAt.END);
        secTitleBox.addView(subView);

        head.addView(secTitleBox);

        // زر تنظيف السجل (في قسم الأرشيف فقط)
        if (!active) {
            Button clearBtn = new Button(this);
            clearBtn.setText("🧹 تنظيف السجل");
            clearBtn.setTextColor(TEXT_MUTED_LIGHT);
            clearBtn.setTextSize(TypedValue.COMPLEX_UNIT_SP, 9.5f);
            clearBtn.setTypeface(Typeface.DEFAULT_BOLD);
            clearBtn.setAllCaps(false);
            clearBtn.setBackground(withRipple(cardBg(0x22FFFFFF, 0x44FFFFFF, 999, 1), 0x44FFFFFF));
            clearBtn.setPadding(dpx(10), 0, dpx(10), 0);
            clearBtn.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View v) {
                    confirmClearHistory();
                }
            });
            head.addView(clearBtn, new LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.WRAP_CONTENT, dpx(28)));
        }

        section.addView(head);

        // خط إضاءة جمالي فاصل
        View accentBar = new View(this);
        accentBar.setBackground(gradientPillBg(
                active ? 0xAAFFD700 : 0xAA38BDF8,
                0x00000000, 0x00000000, 0));
        LinearLayout.LayoutParams barLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, dpx(2));
        barLp.topMargin = dpx(6);
        barLp.bottomMargin = dpx(6);
        accentBar.setLayoutParams(barLp);
        section.addView(accentBar);

        // حاوية التمرير
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

    // ==========================================
    // تحديث بيانات القوائم
    // ==========================================
    private void refreshList() {
        if (activeList == null || historyList == null) return;
        activeList.removeAllViews();
        historyList.removeAllViews();

        ArrayList<JSONObject> records = OfflineBoardGameStore.all(this);
        ArrayList<JSONObject> active = new ArrayList<>();
        ArrayList<JSONObject> history = new ArrayList<>();
        int finishedCount = 0;

        for (JSONObject record : records) {
            if (OfflineBoardGameStore.STATUS_FINISHED.equals(record.optString("status"))) {
                finishedCount++;
                history.add(record);
            } else {
                active.add(record);
                history.add(record);
            }
        }

        if (active.isEmpty()) {
            activeList.addView(createEmptyView(
                    "لا توجد مواجهات محفوظة للمتابعة",
                    "ابدأ لعبة أوف لاين جديدة وسيتم حفظ تقدمك تلقائياً بعد كل سؤال لتكمله في أي وقت!",
                    true
            ));
        } else {
            for (JSONObject record : active) {
                activeList.addView(createCard(record, true));
            }
        }

        if (history.isEmpty()) {
            historyList.addView(createEmptyView(
                    "سجل الأبطال فارغ حتى الآن",
                    "المباريات المنتهية ونتائج تتويج الفائزين على اللوحة ستسجل هنا كذكرى للبطولة.",
                    false
            ));
        } else {
            for (JSONObject record : history) {
                historyList.addView(createCard(record, false));
            }
        }

        if (activeCountBadge != null) {
            activeCountBadge.setText("⚡ " + active.size() + " متابعة");
        }
        if (historyCountBadge != null) {
            historyCountBadge.setText("🏆 " + history.size() + " بالسجل");
        }
        if (totalStatsBadge != null) {
            totalStatsBadge.setText("المباريات المحفوظة: " + active.size() + "  |  المنتهية: " + finishedCount);
        }
    }

    // ==========================================
    // بطاقة الحالة الفارغة (Empty State)
    // ==========================================
    private View createEmptyView(String title, String subtitle, boolean canCreate) {
        LinearLayout empty = new LinearLayout(this);
        empty.setOrientation(LinearLayout.VERTICAL);
        empty.setGravity(Gravity.CENTER);
        empty.setPadding(dpx(16), dpx(24), dpx(16), dpx(24));
        empty.setBackground(cardBg(0x35030816, 0x22FFFFFF, 14, 1));
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        lp.topMargin = dpx(6);
        empty.setLayoutParams(lp);

        TextView iconView = new TextView(this);
        iconView.setText(canCreate ? "🎲" : "🏆");
        iconView.setTextSize(TypedValue.COMPLEX_UNIT_SP, 26f);
        iconView.setGravity(Gravity.CENTER);
        iconView.setBackground(cardBg(
                0x22FFFFFF,
                canCreate ? 0x55FFD700 : 0x5538BDF8,
                999, 1));
        LinearLayout.LayoutParams iconLp = new LinearLayout.LayoutParams(dpx(54), dpx(54));
        iconLp.bottomMargin = dpx(10);
        iconView.setLayoutParams(iconLp);
        empty.addView(iconView);

        TextView tvTitle = new TextView(this);
        tvTitle.setText(title);
        tvTitle.setTextColor(TEXT_WHITE);
        tvTitle.setTextSize(TypedValue.COMPLEX_UNIT_SP, 12.5f);
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
        subLp.topMargin = dpx(4);
        empty.addView(tvSub, subLp);

        if (canCreate) {
            Button quickBtn = new Button(this);
            quickBtn.setText("＋ بدء لعبة أوف لاين جديدة ⚡");
            quickBtn.setTextColor(TEXT_DARK);
            quickBtn.setTextSize(TypedValue.COMPLEX_UNIT_SP, 11f);
            quickBtn.setTypeface(Typeface.DEFAULT_BOLD);
            quickBtn.setAllCaps(false);
            quickBtn.setBackground(withRipple(
                    gradientPillBg(GOLD, GOLD_WARM, 0xFFFFF1A8, 1),
                    0x33000000
            ));
            quickBtn.setPadding(dpx(18), 0, dpx(18), 0);
            quickBtn.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View v) {
                    startActivity(new Intent(OfflineGamesActivity.this, OfflineSetupActivity.class));
                }
            });
            LinearLayout.LayoutParams btnLp = new LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.WRAP_CONTENT, dpx(34));
            btnLp.topMargin = dpx(12);
            empty.addView(quickBtn, btnLp);
        }

        return empty;
    }

    // ==========================================
    // بطاقة المباراة الفخمة (Match Arena Card)
    // ==========================================
    private View createCard(final JSONObject record, final boolean resumable) {
        final String id = record.optString("id", "");
        final boolean finished = OfflineBoardGameStore.STATUS_FINISHED.equals(record.optString("status"));
        final int playerScore = record.optInt("playerScore", 0);
        final int leaderScore = record.optInt("leaderScore", 0);
        final String leader = leaderName(record);
        final int turn = Math.max(0, record.optInt("turnIndex", 0));
        final int totalTurns = Math.max(0, record.optInt("totalTurns", 30));
        final int players = Math.max(2, record.optInt("playerCount", 4));
        final String phase = record.optString("phase", OfflineBoardGameStore.PHASE_BOARD);
        final long updated = record.optLong("updatedAt", System.currentTimeMillis());

        LinearLayout card = new LinearLayout(this);
        card.setOrientation(LinearLayout.VERTICAL);
        card.setBackground(gradientCardBg(
                resumable ? 0xF20F224D : 0xEE0A1835,
                resumable ? 0xF607132D : 0xF5050C1F,
                resumable ? 0x88FFD700 : 0x4438BDF8,
                15, 1));
        card.setPadding(dpx(12), dpx(9), dpx(12), dpx(9));
        LinearLayout.LayoutParams cardLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        cardLp.bottomMargin = dpx(8);
        card.setLayoutParams(cardLp);

        // 1. الشريط العلوي: الوقت + مرحلة اللعب + عدد اللاعبين
        LinearLayout topRow = new LinearLayout(this);
        topRow.setOrientation(LinearLayout.HORIZONTAL);
        topRow.setGravity(Gravity.CENTER_VERTICAL);

        TextView timeView = new TextView(this);
        timeView.setText("🕒 " + formatRelativeTime(updated));
        timeView.setTextColor(TEXT_MUTED);
        timeView.setTextSize(TypedValue.COMPLEX_UNIT_SP, 9f);
        topRow.addView(timeView, new LinearLayout.LayoutParams(0,
                LinearLayout.LayoutParams.WRAP_CONTENT, 1f));

        // شارة مرحلة اللعب أو شارة الفائز
        TextView statusBadge = new TextView(this);
        if (!finished) {
            String phaseText = "لوحة التحدي";
            int badgeColor = GOLD;
            int bgBadge = 0x2BFFD700;
            if (OfflineBoardGameStore.PHASE_CATEGORY_SELECT.equals(phase)) {
                phaseText = "اختيار الفئات";
                badgeColor = PURPLE_LIGHT;
                bgBadge = 0x33A855F7;
            } else if (OfflineBoardGameStore.PHASE_QUESTION.equals(phase)) {
                phaseText = "سؤال جاري";
                badgeColor = EMERALD_LIGHT;
                bgBadge = 0x3310B981;
            }
            statusBadge.setText("⚡ " + phaseText);
            statusBadge.setTextColor(badgeColor);
            statusBadge.setBackground(cardBg(bgBadge, badgeColor, 999, 1));
        } else {
            String winnerText = "تعادل";
            int badgeColor = TEXT_MUTED_LIGHT;
            int winnerSlot = record.optInt("winnerSlot", -2);
            if (winnerSlot == 0) {
                winnerText = "فوزك أنت 👑";
                badgeColor = GOLD;
            } else if (winnerSlot > 0) {
                String wName = record.optString("winnerName", leader);
                winnerText = "فوز " + wName;
                badgeColor = CYAN;
            }
            statusBadge.setText("🏆 " + winnerText);
            statusBadge.setTextColor(badgeColor);
            statusBadge.setBackground(cardBg(0x33000000, badgeColor, 999, 1));
        }
        statusBadge.setTextSize(TypedValue.COMPLEX_UNIT_SP, 8.5f);
        statusBadge.setTypeface(Typeface.DEFAULT_BOLD);
        statusBadge.setPadding(dpx(8), dpx(2), dpx(8), dpx(2));
        topRow.addView(statusBadge);

        // شارة عدد المتنافسين
        TextView countBadge = new TextView(this);
        countBadge.setText("👥 " + players + " لاعبين");
        countBadge.setTextColor(CYAN_LIGHT);
        countBadge.setTextSize(TypedValue.COMPLEX_UNIT_SP, 8.5f);
        countBadge.setTypeface(Typeface.DEFAULT_BOLD);
        countBadge.setPadding(dpx(7), dpx(2), dpx(7), dpx(2));
        countBadge.setBackground(cardBg(0x250284C7, 0x6638BDF8, 999, 1));
        LinearLayout.LayoutParams countLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        countLp.setMargins(dpx(5), 0, 0, 0);
        countBadge.setLayoutParams(countLp);
        topRow.addView(countBadge);

        card.addView(topRow);

        // 2. ساحة التنافس (Esports Arena: Player vs Leader/Rivals)
        LinearLayout duelRow = new LinearLayout(this);
        duelRow.setOrientation(LinearLayout.HORIZONTAL);
        duelRow.setGravity(Gravity.CENTER_VERTICAL);
        LinearLayout.LayoutParams duelLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        duelLp.topMargin = dpx(6);
        duelLp.bottomMargin = dpx(6);
        duelRow.setLayoutParams(duelLp);

        // بوكس اللاعب ("أنت")
        boolean userIsLeading = playerScore >= leaderScore && playerScore > 0;
        LinearLayout playerBox = createPlayerBox(
                "أنت (اللاعب)",
                playerScore,
                "🛡️ بطل التحدي",
                GOLD,
                0x22FFD700,
                userIsLeading,
                Gravity.RIGHT
        );
        duelRow.addView(playerBox, new LinearLayout.LayoutParams(0,
                LinearLayout.LayoutParams.WRAP_CONTENT, 1f));

        // شعار التنافس المركزي (Center VS Hub)
        LinearLayout centerVsBox = new LinearLayout(this);
        centerVsBox.setOrientation(LinearLayout.VERTICAL);
        centerVsBox.setGravity(Gravity.CENTER);
        LinearLayout.LayoutParams cvsLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        cvsLp.setMargins(dpx(8), 0, dpx(8), 0);
        centerVsBox.setLayoutParams(cvsLp);

        TextView vsBadge = new TextView(this);
        vsBadge.setText("VS");
        vsBadge.setTextColor(GOLD_LIGHT);
        vsBadge.setTextSize(TypedValue.COMPLEX_UNIT_SP, 10f);
        vsBadge.setTypeface(Typeface.DEFAULT_BOLD);
        vsBadge.setGravity(Gravity.CENTER);
        vsBadge.setBackground(gradientPillBg(0x66020617, 0x991E293B, 0x88FFD700, 1));
        vsBadge.setLayoutParams(new LinearLayout.LayoutParams(dpx(32), dpx(32)));
        centerVsBox.addView(vsBadge);

        TextView turnSub = new TextView(this);
        turnSub.setText(turn + "/" + totalTurns);
        turnSub.setTextColor(TEXT_MUTED);
        turnSub.setTextSize(TypedValue.COMPLEX_UNIT_SP, 8f);
        turnSub.setTypeface(Typeface.DEFAULT_BOLD);
        turnSub.setGravity(Gravity.CENTER);
        LinearLayout.LayoutParams tsLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        tsLp.topMargin = dpx(2);
        turnSub.setLayoutParams(tsLp);
        centerVsBox.addView(turnSub);

        duelRow.addView(centerVsBox);

        // بوكس المنافس الأقوى (Leader / Rival)
        boolean rivalIsLeading = leaderScore > playerScore;
        LinearLayout leaderBox = createPlayerBox(
                leader,
                leaderScore,
                "المنافس الأقوى ⚔️",
                CYAN,
                0x2238BDF8,
                rivalIsLeading,
                Gravity.LEFT
        );
        duelRow.addView(leaderBox, new LinearLayout.LayoutParams(0,
                LinearLayout.LayoutParams.WRAP_CONTENT, 1f));

        card.addView(duelRow);

        // 3. شريط استعراض كافة المتنافسين (إذا وُجدوا)
        JSONArray namesArr = record.optJSONArray("names");
        JSONArray scoresArr = record.optJSONArray("scores");
        if (namesArr != null && namesArr.length() > 2) {
            LinearLayout contestantsRow = new LinearLayout(this);
            contestantsRow.setOrientation(LinearLayout.HORIZONTAL);
            contestantsRow.setGravity(Gravity.CENTER_VERTICAL);
            contestantsRow.setBackground(cardBg(0x22020617, 0x33FFFFFF, 8, 1));
            contestantsRow.setPadding(dpx(8), dpx(3), dpx(8), dpx(3));
            LinearLayout.LayoutParams crLp = new LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
            crLp.bottomMargin = dpx(6);
            contestantsRow.setLayoutParams(crLp);

            TextView cLabel = new TextView(this);
            cLabel.setText("الترتيب: ");
            cLabel.setTextColor(GOLD_LIGHT);
            cLabel.setTextSize(TypedValue.COMPLEX_UNIT_SP, 8.5f);
            cLabel.setTypeface(Typeface.DEFAULT_BOLD);
            contestantsRow.addView(cLabel);

            StringBuilder sb = new StringBuilder();
            for (int i = 0; i < namesArr.length(); i++) {
                String n = namesArr.optString(i, "لاعب " + (i + 1));
                int sc = scoresArr != null && i < scoresArr.length() ? scoresArr.optInt(i, 0) : 0;
                sb.append(n).append(" (").append(sc).append(")");
                if (i < namesArr.length() - 1) sb.append("  •  ");
            }
            TextView cText = new TextView(this);
            cText.setText(sb.toString());
            cText.setTextColor(TEXT_MUTED_LIGHT);
            cText.setTextSize(TypedValue.COMPLEX_UNIT_SP, 8.5f);
            cText.setSingleLine(true);
            cText.setEllipsize(TextUtils.TruncateAt.END);
            contestantsRow.addView(cText, new LinearLayout.LayoutParams(0,
                    LinearLayout.LayoutParams.WRAP_CONTENT, 1f));

            card.addView(contestantsRow);
        }

        // 4. شريط التقدم في المباراة (Progress Track)
        if (!finished) {
            LinearLayout progressRow = new LinearLayout(this);
            progressRow.setOrientation(LinearLayout.VERTICAL);
            LinearLayout.LayoutParams prLp = new LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
            prLp.bottomMargin = dpx(6);
            progressRow.setLayoutParams(prLp);

            LinearLayout progressInfo = new LinearLayout(this);
            progressInfo.setOrientation(LinearLayout.HORIZONTAL);

            TextView turnInfo = new TextView(this);
            turnInfo.setText("التقدم: الجولة " + turn + " من إجمالي " + totalTurns);
            turnInfo.setTextColor(TEXT_MUTED);
            turnInfo.setTextSize(TypedValue.COMPLEX_UNIT_SP, 8.5f);
            progressInfo.addView(turnInfo, new LinearLayout.LayoutParams(0,
                    LinearLayout.LayoutParams.WRAP_CONTENT, 1f));

            int percent = totalTurns <= 0 ? 0 : (int) Math.min(100, Math.max(0, (turn * 100.0f) / totalTurns));
            TextView percentInfo = new TextView(this);
            percentInfo.setText(percent + "%");
            percentInfo.setTextColor(GOLD_LIGHT);
            percentInfo.setTextSize(TypedValue.COMPLEX_UNIT_SP, 8.5f);
            percentInfo.setTypeface(Typeface.DEFAULT_BOLD);
            progressInfo.addView(percentInfo);

            progressRow.addView(progressInfo);

            // مسار التقدم البصري
            FrameLayout progressTrack = new FrameLayout(this);
            progressTrack.setBackground(cardBg(0x331E293B, 0x22FFFFFF, 999, 1));
            LinearLayout.LayoutParams trackLp = new LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT, dpx(4));
            trackLp.topMargin = dpx(2);
            progressTrack.setLayoutParams(trackLp);

            View progressFill = new View(this);
            progressFill.setBackground(gradientPillBg(GOLD, EMERALD, 0x00000000, 0));
            FrameLayout.LayoutParams fillLp = new FrameLayout.LayoutParams(
                    Math.max(dpx(6), (int) (dpx(220) * (percent / 100.0f))),
                    FrameLayout.LayoutParams.MATCH_PARENT);
            fillLp.gravity = Gravity.RIGHT;
            progressFill.setLayoutParams(fillLp);
            progressTrack.addView(progressFill);

            progressRow.addView(progressTrack);
            card.addView(progressRow);
        } else {
            // شريط إشعار النتيجة النهائية للمباراة المؤرشفة
            LinearLayout bannerRow = new LinearLayout(this);
            bannerRow.setOrientation(LinearLayout.HORIZONTAL);
            bannerRow.setGravity(Gravity.CENTER_VERTICAL);
            bannerRow.setBackground(cardBg(0x22020617, 0x3338BDF8, 8, 1));
            bannerRow.setPadding(dpx(8), dpx(3), dpx(8), dpx(3));
            LinearLayout.LayoutParams brLp = new LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
            brLp.bottomMargin = dpx(6);
            bannerRow.setLayoutParams(brLp);

            TextView bannerIcon = new TextView(this);
            bannerIcon.setText("🏅");
            bannerIcon.setTextSize(TypedValue.COMPLEX_UNIT_SP, 10f);
            bannerRow.addView(bannerIcon);

            TextView bannerText = new TextView(this);
            String outcome;
            int winSlot = record.optInt("winnerSlot", -2);
            if (winSlot == 0) {
                outcome = "تُوّجت أنت بطلاً للمواجهة بنتيجة " + playerScore + " نقطة!";
            } else if (winSlot > 0) {
                String wName = record.optString("winnerName", leader);
                outcome = "تُوّج " + wName + " بطلاً للمواجهة بنتيجة " + leaderScore + " نقطة!";
            } else {
                outcome = "انتهت المواجهة بالتعادل العادل بين المتنافسين (" + playerScore + " نقطة)";
            }
            bannerText.setText(" " + outcome);
            bannerText.setTextColor(TEXT_MUTED_LIGHT);
            bannerText.setTextSize(TypedValue.COMPLEX_UNIT_SP, 9f);
            bannerText.setSingleLine(true);
            bannerText.setEllipsize(TextUtils.TruncateAt.END);
            bannerRow.addView(bannerText, new LinearLayout.LayoutParams(0,
                    LinearLayout.LayoutParams.WRAP_CONTENT, 1f));

            card.addView(bannerRow);
        }

        // 5. أزرار التحكم والإجراءات (Action Footer)
        LinearLayout actionRow = new LinearLayout(this);
        actionRow.setOrientation(LinearLayout.HORIZONTAL);
        actionRow.setGravity(Gravity.CENTER_VERTICAL);
        LinearLayout.LayoutParams arLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        actionRow.setLayoutParams(arLp);

        if (resumable) {
            // زر استئناف اللعب (Primary Action)
            Button resumeBtn = new Button(this);
            resumeBtn.setText("🎲 متابعة التحدي");
            resumeBtn.setTextColor(TEXT_WHITE);
            resumeBtn.setTextSize(TypedValue.COMPLEX_UNIT_SP, 11f);
            resumeBtn.setTypeface(Typeface.DEFAULT_BOLD);
            resumeBtn.setAllCaps(false);
            resumeBtn.setBackground(withRipple(
                    gradientPillBg(EMERALD_DARK, EMERALD, EMERALD_LIGHT, 1),
                    0x33FFFFFF
            ));
            resumeBtn.setPadding(dpx(14), 0, dpx(14), 0);
            resumeBtn.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View v) {
                    launchGame(record);
                }
            });
            LinearLayout.LayoutParams resLp = new LinearLayout.LayoutParams(0, dpx(34), 1f);
            resLp.setMargins(dpx(6), 0, 0, 0);
            actionRow.addView(resumeBtn, resLp);
        } else {
            TextView archInfo = new TextView(this);
            archInfo.setText("📁 مواجهة مكتملة ومحفوظة بالسجل");
            archInfo.setTextColor(TEXT_MUTED);
            archInfo.setTextSize(TypedValue.COMPLEX_UNIT_SP, 9f);
            actionRow.addView(archInfo, new LinearLayout.LayoutParams(0,
                    LinearLayout.LayoutParams.WRAP_CONTENT, 1f));
        }

        // زر الحذف
        Button deleteBtn = new Button(this);
        deleteBtn.setText("🗑️");
        deleteBtn.setTextColor(RED);
        deleteBtn.setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f);
        deleteBtn.setBackground(withRipple(cardBg(0x2BEE4444, 0x66EE4444, 999, 1), 0x44EF4444));
        deleteBtn.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                confirmDelete(id, "المواجهة ضد " + leader);
            }
        });
        actionRow.addView(deleteBtn, new LinearLayout.LayoutParams(dpx(36), dpx(34)));

        card.addView(actionRow);

        return card;
    }

    // ==========================================
    // بوكس معلومات اللاعب داخل البطاقة
    // ==========================================
    private LinearLayout createPlayerBox(
            String playerName,
            int score,
            String subTag,
            int themeColor,
            int bgFill,
            boolean isLeading,
            int gravity
    ) {
        LinearLayout box = new LinearLayout(this);
        box.setOrientation(LinearLayout.VERTICAL);
        box.setGravity(gravity);
        box.setBackground(cardBg(bgFill, 0x33FFFFFF, 10, 1));
        box.setPadding(dpx(8), dpx(6), dpx(8), dpx(6));

        // سطر اللقب مع تاج الصدارة
        LinearLayout tagRow = new LinearLayout(this);
        tagRow.setOrientation(LinearLayout.HORIZONTAL);
        tagRow.setGravity(gravity | Gravity.CENTER_VERTICAL);

        if (isLeading) {
            TextView crown = new TextView(this);
            crown.setText("👑 ");
            crown.setTextSize(TypedValue.COMPLEX_UNIT_SP, 8.5f);
            tagRow.addView(crown);
        }

        TextView tagView = new TextView(this);
        tagView.setText(subTag);
        tagView.setTextColor(themeColor);
        tagView.setTextSize(TypedValue.COMPLEX_UNIT_SP, 8f);
        tagRow.addView(tagView);

        box.addView(tagRow);

        // اسم اللاعب
        TextView nameView = new TextView(this);
        nameView.setText(playerName);
        nameView.setTextColor(TEXT_WHITE);
        nameView.setTextSize(TypedValue.COMPLEX_UNIT_SP, 11.5f);
        nameView.setTypeface(Typeface.DEFAULT_BOLD);
        nameView.setSingleLine(true);
        nameView.setEllipsize(TextUtils.TruncateAt.END);
        nameView.setGravity(gravity);
        box.addView(nameView);

        // نتيجة اللاعب (Score)
        TextView scoreView = new TextView(this);
        scoreView.setText(score + " نقطة");
        scoreView.setTextColor(isLeading ? GOLD_LIGHT : TEXT_MUTED_LIGHT);
        scoreView.setTextSize(TypedValue.COMPLEX_UNIT_SP, 10f);
        scoreView.setTypeface(Typeface.DEFAULT_BOLD);
        scoreView.setGravity(gravity);
        box.addView(scoreView);

        return box;
    }

    // ==========================================
    // استخراج اسم المنافس الأبرز
    // ==========================================
    private String leaderName(JSONObject record) {
        String leader = record.optString("leaderName", "");
        if (!leader.trim().isEmpty()) return leader;
        JSONArray names = record.optJSONArray("names");
        if (names != null && names.length() > 1) {
            return names.optString(1, "المنافس");
        }
        return "المنافس";
    }

    // ==========================================
    // استئناف اللعبة
    // ==========================================
    private void launchGame(JSONObject record) {
        PlayerProgress.recordOfflineBoardPlayed(this);
        Intent intent = new Intent(this, GameActivity.class);
        intent.putExtra("mode", "mono");
        intent.putExtra("resumeOfflineBoard", true);
        intent.putExtra("offlineBoardSaveId", record.optString("id", ""));
        intent.putExtra("playerCount", Math.max(2, record.optInt("playerCount", 4)));
        intent.putExtra("characterIndex",
                record.optInt("characterIndex", AppPrefs.getEffectiveCharacter(this)));
        startActivity(intent);
    }

    // ==========================================
    // حوارات التأكيد (Confirmation Dialogs)
    // ==========================================
    private void confirmDelete(final String id, String matchLabel) {
        showCustomConfirmDialog(
                "⚠️ تأكيد حذف اللعبة",
                "هل أنت متأكد من رغبتك في حذف «" + matchLabel + "» نهائياً من الحفظ؟",
                "نعم، حذف",
                new Runnable() {
                    @Override
                    public void run() {
                        boolean ok = OfflineBoardGameStore.delete(OfflineGamesActivity.this, id);
                        if (ok) {
                            GameNotice.makeText(OfflineGamesActivity.this, "تم حذف اللعبة بنجاح", Toast.LENGTH_SHORT).show();
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
                        int count = OfflineBoardGameStore.clearFinished(OfflineGamesActivity.this);
                        GameNotice.makeText(OfflineGamesActivity.this, "تم تنظيف " + count + " مباراة من السجل", Toast.LENGTH_SHORT).show();
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

        final AlertDialog dialog = GameNoticeDialogs.builder(this)
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
        confirmBtn.setBackground(withRipple(
                gradientPillBg(RED, RED_DARK, 0xFFFF7777, 1),
                0x33FFFFFF
        ));
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
        cancelBtn.setBackground(withRipple(cardBg(0x33FFFFFF, 0x55FFFFFF, 999, 1), 0x44FFFFFF));
        cancelBtn.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                dialog.dismiss();
            }
        });
        btnRow.addView(cancelBtn, new LinearLayout.LayoutParams(dpx(75), dpx(38)));

        dialogView.addView(btnRow, new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT));

        dialog.show();
    }

    // ==========================================
    // دوال مساعدة لإنشاء الخلفيات والرسوم
    // ==========================================
    private TextView createChip(int textColor, int bgColor, int strokeColor, String text) {
        TextView tv = new TextView(this);
        tv.setText(text);
        tv.setTextColor(textColor);
        tv.setTextSize(TypedValue.COMPLEX_UNIT_SP, 9.5f);
        tv.setTypeface(Typeface.DEFAULT_BOLD);
        tv.setPadding(dpx(9), dpx(2), dpx(9), dpx(2));
        tv.setBackground(cardBg(bgColor, strokeColor, 999, 1));
        return tv;
    }

    private String formatRelativeTime(long timeMs) {
        if (timeMs <= 0) return "الآن";
        long diff = System.currentTimeMillis() - timeMs;
        if (diff < 60 * 1000) return "الآن";
        if (diff < 60 * 60 * 1000) {
            int mins = (int) (diff / (60 * 1000));
            return "منذ " + mins + (mins == 1 ? " دقيقة" : (mins <= 10 ? " دقائق" : " دقيقة"));
        }
        if (diff < 24 * 60 * 60 * 1000) {
            int hours = (int) (diff / (60 * 60 * 1000));
            return "منذ " + hours + (hours == 1 ? " ساعة" : (hours <= 10 ? " ساعات" : " ساعة"));
        }
        return dateFormat.format(new Date(timeMs));
    }

    private GradientDrawable pageScrimBg() {
        return new GradientDrawable(
                GradientDrawable.Orientation.TOP_BOTTOM,
                new int[]{0xF2070E22, 0xF6040816, 0xFA02040B});
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

    private GradientDrawable gradientPillBg(int startColor, int endColor, int strokeColor, int strokeDp) {
        GradientDrawable gd = new GradientDrawable(
                GradientDrawable.Orientation.LEFT_RIGHT,
                new int[]{startColor, endColor});
        gd.setCornerRadius(dpx(999));
        if (strokeDp > 0) gd.setStroke(dpx(strokeDp), strokeColor);
        return gd;
    }

    private Drawable withRipple(GradientDrawable content, int rippleColor) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            return new RippleDrawable(
                    ColorStateList.valueOf(rippleColor),
                    content,
                    null
            );
        }
        return content;
    }

    private int dpx(float dp) {
        return (int) (dp * getResources().getDisplayMetrics().density + 0.5f);
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
