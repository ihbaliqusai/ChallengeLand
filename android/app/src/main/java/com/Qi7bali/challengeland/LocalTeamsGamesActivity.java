package com.qi7bali.landchallengeonline;

import androidx.appcompat.app.AlertDialog;

import android.content.ClipData;
import android.content.ClipboardManager;
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
import android.view.MotionEvent;
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
 * شاشة إدارة مباريات التحدي الرئيسي (المواجهات المحلية بين فريقين على جهاز واحد).
 * تم إعادة تصميمها بالكامل بهوية Esports Championship فخمة وعصرية،
 * مع دعم البث للشاشة الكبيرة (TV Mode)، وإحصائيات فورية للمواجهات.
 */
public class LocalTeamsGamesActivity extends GameViewportActivity {

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

        // 1. خلفية الفضاء النجمي الكوني الأصلية بجودة فائقة
        ImageView bg = new ImageView(this);
        bg.setImageResource(R.drawable.bg_challenge_cosmic);
        bg.setScaleType(ImageView.ScaleType.CENTER_CROP);
        root.addView(bg, new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT));

        // 2. طبقة حماية لونية رقيقة لتنعيم النجوم وتعزيز التباين
        View scrim = new View(this);
        scrim.setBackground(pageScrimBg());
        root.addView(scrim, new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT));

        // 3. الحاوية الرئيسية (Shell)
        LinearLayout shell = new LinearLayout(this);
        shell.setOrientation(LinearLayout.VERTICAL);
        shell.setPadding(dpx(20), dpx(12), dpx(20), dpx(12));
        root.addView(shell, new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT));

        // 4. رأس الصفحة الفخم العائم (Grand Championship Header)
        shell.addView(createHeader(), new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT));

        // 5. ساحة المواجهات الثنائية (Dual Esports Columns)
        LinearLayout body = new LinearLayout(this);
        body.setOrientation(LinearLayout.HORIZONTAL);
        LinearLayout.LayoutParams bodyLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f);
        bodyLp.topMargin = dpx(10);
        shell.addView(body, bodyLp);

        // العمود الأول في RTL: المواجهات الجارية (Active Duels - يمين)
        View activeSection = createSection(
                "المواجهات الجارية",
                "مباريات مشتعلة جاهزة للاستئناف فوراً من آخر سؤال",
                true
        );
        LinearLayout.LayoutParams activeLp = new LinearLayout.LayoutParams(0,
                LinearLayout.LayoutParams.MATCH_PARENT, 1f);
        activeLp.setMargins(0, 0, dpx(8), 0);
        body.addView(activeSection, activeLp);

        // العمود الثاني في RTL: سجل الأبطال والتتويج (Champions Archive - يسار)
        View historySection = createSection(
                "سجل الأبطال والتتويج",
                "أرشيف المواجهات المنتهية ونتائج الفائزين",
                false
        );
        LinearLayout.LayoutParams historyLp = new LinearLayout.LayoutParams(0,
                LinearLayout.LayoutParams.MATCH_PARENT, 1f);
        historyLp.setMargins(dpx(8), 0, 0, 0);
        body.addView(historySection, historyLp);

        setContentView(root);
    }

    // ==========================================
    // رأس الصفحة (Championship Header)
    // ==========================================
    private View createHeader() {
        LinearLayout header = new LinearLayout(this);
        header.setOrientation(LinearLayout.HORIZONTAL);
        header.setGravity(Gravity.CENTER_VERTICAL);
        header.setPadding(0, dpx(2), 0, dpx(2));

        GameBackButton backBtn = new GameBackButton(this);
        applyPressEffect(backBtn, new Runnable() {
            @Override
            public void run() {
                finish();
            }
        });
        header.addView(backBtn, new LinearLayout.LayoutParams(dpx(48), dpx(48)));

        // 2. ميدالية التاج الذهبية الفخمة
        ImageView crownEmblem = new ImageView(this);
        crownEmblem.setImageResource(R.drawable.ic_main_challenge_crown);
        crownEmblem.setScaleType(ImageView.ScaleType.FIT_CENTER);
        LinearLayout.LayoutParams emblemLp = new LinearLayout.LayoutParams(dpx(44), dpx(44));
        emblemLp.setMargins(dpx(10), 0, dpx(12), 0);
        crownEmblem.setLayoutParams(emblemLp);
        header.addView(crownEmblem);

        // 3. عمود العنوان والهوية والإحصائيات
        LinearLayout titleCol = new LinearLayout(this);
        titleCol.setOrientation(LinearLayout.VERTICAL);
        LinearLayout.LayoutParams titleLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT);
        titleCol.setLayoutParams(titleLp);

        TextView tag = new TextView(this);
        tag.setText("بطولة التحدي الرئيسي • مواجهة فريقين محلياً على جهاز واحد");
        tag.setTextColor(GOLD_LIGHT);
        tag.setTextSize(TypedValue.COMPLEX_UNIT_SP, 10.5f);
        tag.setTypeface(Typeface.DEFAULT_BOLD);
        tag.setSingleLine(true);
        tag.setEllipsize(TextUtils.TruncateAt.END);
        titleCol.addView(tag);

        TextView title = new TextView(this);
        title.setText("إدارة مباريات التحدي الرئيسي");
        title.setTextColor(TEXT_WHITE);
        title.setTextSize(TypedValue.COMPLEX_UNIT_SP, 19f);
        title.setTypeface(Typeface.DEFAULT_BOLD);
        LinearLayout.LayoutParams ttlLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        ttlLp.topMargin = dpx(1);
        ttlLp.bottomMargin = dpx(3);
        title.setLayoutParams(ttlLp);
        titleCol.addView(title);

        // شريط الإحصائيات الفورية (Telemetry Strip) تحت العنوان مباشرة
        LinearLayout statsRow = new LinearLayout(this);
        statsRow.setOrientation(LinearLayout.HORIZONTAL);
        statsRow.setGravity(Gravity.CENTER_VERTICAL);

        activeCountBadge = createChip(0xFFFFD700, 0x33B45309, 0xFFFFB300, "0 جارية ⚡");
        statsRow.addView(activeCountBadge);

        historyCountBadge = createChip(0xFF38BDF8, 0x330284C7, 0xFF38BDF8, "0 بالسجل 🏆");
        LinearLayout.LayoutParams hcLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        hcLp.setMargins(dpx(7), 0, dpx(7), 0);
        historyCountBadge.setLayoutParams(hcLp);
        statsRow.addView(historyCountBadge);

        totalStatsBadge = new TextView(this);
        totalStatsBadge.setTextColor(TEXT_MUTED);
        totalStatsBadge.setTextSize(TypedValue.COMPLEX_UNIT_SP, 9.5f);
        totalStatsBadge.setSingleLine(true);
        totalStatsBadge.setEllipsize(TextUtils.TruncateAt.END);
        statsRow.addView(totalStatsBadge);

        titleCol.addView(statsRow);
        header.addView(titleCol);

        // مسافة مرنة بين العنوان والأزرار
        View spacer = new View(this);
        header.addView(spacer, new LinearLayout.LayoutParams(0, 0, 1f));

        // 4. زر التلفزيون ("ربط الشاشة")
        ImageView tvGuideBtn = new ImageView(this);
        tvGuideBtn.setImageResource(R.drawable.btn_main_tv_guide);
        tvGuideBtn.setScaleType(ImageView.ScaleType.FIT_CENTER);
        applyPressEffect(tvGuideBtn, new Runnable() {
            @Override
            public void run() {
                showTvCodeDialog("", "بث مباريات التحدي المباشرة");
            }
        });
        LinearLayout.LayoutParams tvLp = new LinearLayout.LayoutParams(dpx(124), dpx(42));
        tvLp.setMargins(0, 0, dpx(12), 0);
        header.addView(tvGuideBtn, tvLp);

        // 5. زر النزال الرئيسي ("+ مواجهة جديدة")
        ImageView newMatchBtn = new ImageView(this);
        newMatchBtn.setImageResource(R.drawable.btn_main_new_match);
        newMatchBtn.setScaleType(ImageView.ScaleType.FIT_CENTER);
        applyPressEffect(newMatchBtn, new Runnable() {
            @Override
            public void run() {
                startNewMatch();
            }
        });
        header.addView(newMatchBtn, new LinearLayout.LayoutParams(dpx(180), dpx(42)));

        return header;
    }

    // ==========================================
    // بناء قسم (عامود) المواجهات
    // ==========================================
    private View createSection(String title, String subtitle, boolean active) {
        LinearLayout section = new LinearLayout(this);
        section.setOrientation(LinearLayout.VERTICAL);
        section.setBackgroundResource(R.drawable.bg_main_challenge_card);
        section.setPadding(dpx(16), dpx(12), dpx(16), dpx(12));

        // رأس القسم
        LinearLayout head = new LinearLayout(this);
        head.setOrientation(LinearLayout.HORIZONTAL);
        head.setGravity(Gravity.CENTER_VERTICAL);

        // أيقونة القسم
        ImageView secIcon = new ImageView(this);
        secIcon.setImageResource(active ?
                R.drawable.ic_main_challenge_lightning :
                R.drawable.ic_main_challenge_mini_trophy);
        secIcon.setScaleType(ImageView.ScaleType.FIT_CENTER);
        head.addView(secIcon, new LinearLayout.LayoutParams(dpx(36), dpx(36)));

        // عنوان القسم
        LinearLayout secTitleBox = new LinearLayout(this);
        secTitleBox.setOrientation(LinearLayout.VERTICAL);
        LinearLayout.LayoutParams stbLp = new LinearLayout.LayoutParams(0,
                LinearLayout.LayoutParams.WRAP_CONTENT, 1f);
        stbLp.setMargins(dpx(8), 0, dpx(8), 0);
        secTitleBox.setLayoutParams(stbLp);

        TextView titleView = new TextView(this);
        titleView.setText(title);
        titleView.setTextColor(active ? 0xFFFFC727 : 0xFF38BDF8);
        titleView.setTextSize(TypedValue.COMPLEX_UNIT_SP, 15f);
        titleView.setTypeface(Typeface.DEFAULT_BOLD);
        secTitleBox.addView(titleView);

        TextView subView = new TextView(this);
        subView.setText(subtitle);
        subView.setTextColor(TEXT_MUTED);
        subView.setTextSize(TypedValue.COMPLEX_UNIT_SP, 9.5f);
        subView.setSingleLine(true);
        subView.setEllipsize(TextUtils.TruncateAt.END);
        secTitleBox.addView(subView);

        head.addView(secTitleBox);

        // زر تنظيف السجل (في قسم الأرشيف فقط)
        if (!active) {
            ImageView clearBtn = new ImageView(this);
            clearBtn.setImageResource(R.drawable.btn_main_clear_history);
            clearBtn.setScaleType(ImageView.ScaleType.FIT_CENTER);
            applyPressEffect(clearBtn, new Runnable() {
                @Override
                public void run() {
                    confirmClearHistory();
                }
            });
            head.addView(clearBtn, new LinearLayout.LayoutParams(dpx(110), dpx(31)));
        }

        section.addView(head);

        // حاوية التمرير
        ScrollView scroller = new ScrollView(this);
        scroller.setVerticalScrollBarEnabled(false);
        scroller.setFillViewport(true);
        LinearLayout.LayoutParams scrollerLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f);
        scrollerLp.topMargin = dpx(6);
        scroller.setLayoutParams(scrollerLp);

        LinearLayout list = new LinearLayout(this);
        list.setOrientation(LinearLayout.VERTICAL);
        scroller.addView(list, new ScrollView.LayoutParams(
                ScrollView.LayoutParams.MATCH_PARENT,
                ScrollView.LayoutParams.MATCH_PARENT));

        if (active) {
            activeList = list;
        } else {
            historyList = list;
        }

        section.addView(scroller);

        return section;
    }

    // ==========================================
    // تحديث بيانات القوائم
    // ==========================================
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
            activeList.setGravity(Gravity.CENTER);
            activeList.addView(createEmptyView(
                    "لا توجد مواجهات نشطة حالياً",
                    "شكّل فريقين من أصدقائك أو عائلتك وابدأ معركة التحدي على جهاز واحد!",
                    true
            ));
        } else {
            activeList.setGravity(Gravity.TOP);
        }

        if (finishedCount == 0) {
            historyList.setGravity(Gravity.CENTER);
            historyList.addView(createEmptyView(
                    "سجل الأبطال فارغ حتى الآن",
                    "المباريات المنتهية ونتائج تتويج الفرق الفائزة ستسجل هنا كذكرى للبطولة.",
                    false
            ));
        } else {
            historyList.setGravity(Gravity.TOP);
        }

        if (activeCountBadge != null) {
            activeCountBadge.setText(activeCount + " جارية ⚡");
        }
        if (historyCountBadge != null) {
            historyCountBadge.setText(finishedCount + " بالسجل 🏆");
        }
        if (totalStatsBadge != null) {
            totalStatsBadge.setText("إجمالي المواجهات: " + all.size() + " مواجهة");
        }
    }

    // ==========================================
    // بطاقة الحالة الفارغة (Empty State)
    // ==========================================
    private View createEmptyView(String title, String subtitle, boolean canCreate) {
        LinearLayout empty = new LinearLayout(this);
        empty.setOrientation(LinearLayout.VERTICAL);
        empty.setGravity(Gravity.CENTER);
        empty.setPadding(dpx(16), dpx(10), dpx(16), dpx(10));
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.MATCH_PARENT);
        empty.setLayoutParams(lp);

        ImageView graphic = new ImageView(this);
        graphic.setImageResource(canCreate ?
                R.drawable.img_empty_swords :
                R.drawable.img_empty_trophy);
        graphic.setScaleType(ImageView.ScaleType.FIT_CENTER);
        LinearLayout.LayoutParams gLp = new LinearLayout.LayoutParams(dpx(165), dpx(165));
        empty.addView(graphic, gLp);

        TextView tvTitle = new TextView(this);
        tvTitle.setText(title);
        tvTitle.setTextColor(TEXT_WHITE);
        tvTitle.setTextSize(TypedValue.COMPLEX_UNIT_SP, 16.5f);
        tvTitle.setTypeface(Typeface.DEFAULT_BOLD);
        tvTitle.setGravity(Gravity.CENTER);
        LinearLayout.LayoutParams tLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        tLp.topMargin = dpx(12);
        empty.addView(tvTitle, tLp);

        TextView tvSub = new TextView(this);
        tvSub.setText(subtitle);
        tvSub.setTextColor(TEXT_MUTED);
        tvSub.setTextSize(TypedValue.COMPLEX_UNIT_SP, 10.5f);
        tvSub.setGravity(Gravity.CENTER);
        LinearLayout.LayoutParams subLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        subLp.topMargin = dpx(5);
        empty.addView(tvSub, subLp);

        if (canCreate) {
            ImageView quickBtn = new ImageView(this);
            quickBtn.setImageResource(R.drawable.btn_main_start_first);
            quickBtn.setScaleType(ImageView.ScaleType.FIT_CENTER);
            applyPressEffect(quickBtn, new Runnable() {
                @Override
                public void run() {
                    startNewMatch();
                }
            });
            LinearLayout.LayoutParams btnLp = new LinearLayout.LayoutParams(dpx(195), dpx(42));
            btnLp.topMargin = dpx(16);
            empty.addView(quickBtn, btnLp);
        }

        return empty;
    }

    // ==========================================
    // بطاقة المباراة الفخمة (Match Arena Card)
    // ==========================================
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
        final String tvCode = LocalTeamsGameStore.getOrAssignTvCode(this, record);

        LinearLayout card = new LinearLayout(this);
        card.setOrientation(LinearLayout.VERTICAL);
        card.setBackground(gradientCardBg(
                active ? 0xF0081836 : 0xEE0A1835,
                active ? 0xF6040F24 : 0xF5050C1F,
                active ? 0x8838BDF8 : 0x4438BDF8,
                18, 1));
        card.setPadding(dpx(14), dpx(11), dpx(14), dpx(11));
        LinearLayout.LayoutParams cardLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        cardLp.bottomMargin = dpx(8);
        card.setLayoutParams(cardLp);

        // 1. الشريط العلوي للبطاقة: الوقت + مرحلة اللعب + كود الشاشة
        LinearLayout topRow = new LinearLayout(this);
        topRow.setOrientation(LinearLayout.HORIZONTAL);
        topRow.setGravity(Gravity.CENTER_VERTICAL);

        // الوقت (على اليمين في RTL)
        TextView timeView = new TextView(this);
        timeView.setText(formatRelativeTime(updated) + " 🕒");
        timeView.setTextColor(TEXT_MUTED);
        timeView.setTextSize(TypedValue.COMPLEX_UNIT_SP, 9.5f);
        topRow.addView(timeView);

        // مسافة تدفع الشارات إلى اليسار
        View topSpacer = new View(this);
        topRow.addView(topSpacer, new LinearLayout.LayoutParams(0, 0, 1f));

        // شارة مرحلة اللعب أو شارة الفائز
        TextView statusBadge = new TextView(this);
        if (active) {
            String phaseText = "لوحة التحدي";
            int badgeColor = GOLD;
            int bgBadge = 0x2BFFD700;
            int strokeColor = GOLD;
            if (LocalTeamsGameStore.PHASE_CATEGORY_SELECT.equals(phase)) {
                phaseText = "اختيار الفئات ⚡";
                badgeColor = PURPLE_LIGHT;
                bgBadge = 0x337C3AED;
                strokeColor = PURPLE;
            } else if (LocalTeamsGameStore.PHASE_QUESTION.equals(phase)) {
                phaseText = "سؤال جاري ⚡";
                badgeColor = EMERALD_LIGHT;
                bgBadge = 0x3310B981;
                strokeColor = EMERALD;
            } else {
                phaseText = "لوحة التحدي ⚡";
            }
            statusBadge.setText(phaseText);
            statusBadge.setTextColor(badgeColor);
            statusBadge.setBackground(cardBg(bgBadge, strokeColor, 999, 1));
        } else {
            String winnerText = "تعادل ملحمي";
            int badgeColor = TEXT_MUTED_LIGHT;
            if (scoreA > scoreB) {
                winnerText = "فوز " + teamA;
                badgeColor = GOLD;
            } else if (scoreB > scoreA) {
                winnerText = "فوز " + teamB;
                badgeColor = CYAN;
            }
            statusBadge.setText("🏆 " + winnerText);
            statusBadge.setTextColor(badgeColor);
            statusBadge.setBackground(cardBg(0x33000000, badgeColor, 999, 1));
        }
        statusBadge.setTextSize(TypedValue.COMPLEX_UNIT_SP, 9f);
        statusBadge.setTypeface(Typeface.DEFAULT_BOLD);
        statusBadge.setPadding(dpx(9), dpx(2), dpx(9), dpx(2));
        topRow.addView(statusBadge);

        // شارة كود التلفزيون السريع (قابلة للنقر)
        if (!TextUtils.isEmpty(tvCode)) {
            TextView tvCodeChip = new TextView(this);
            tvCodeChip.setText("PIN: " + tvCode + " 📺");
            tvCodeChip.setTextColor(CYAN_LIGHT);
            tvCodeChip.setTextSize(TypedValue.COMPLEX_UNIT_SP, 9f);
            tvCodeChip.setTypeface(Typeface.DEFAULT_BOLD);
            tvCodeChip.setPadding(dpx(8), dpx(2), dpx(8), dpx(2));
            tvCodeChip.setBackground(cardBg(0x28075985, 0xFF38BDF8, 999, 1));
            LinearLayout.LayoutParams tvChipLp = new LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT);
            tvChipLp.setMargins(dpx(7), 0, 0, 0);
            tvCodeChip.setLayoutParams(tvChipLp);
            tvCodeChip.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View v) {
                    AppSoundEffects.click(v.getContext());
                    showTvCodeDialog(tvCode, teamA + " ضد " + teamB);
                }
            });
            topRow.addView(tvCodeChip);
        }

        card.addView(topRow);

        // 2. ساحة النزال (Esports Arena: Team A vs Team B)
        LinearLayout duelRow = new LinearLayout(this);
        duelRow.setOrientation(LinearLayout.HORIZONTAL);
        duelRow.setGravity(Gravity.CENTER_VERTICAL);
        LinearLayout.LayoutParams duelLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        duelLp.topMargin = dpx(8);
        duelLp.bottomMargin = dpx(8);
        duelRow.setLayoutParams(duelLp);

        // بوكس الفريق الأول (A - يمين في RTL)
        boolean aIsLeading = scoreA > scoreB;
        LinearLayout teamABox = createTeamBox(
                teamA,
                scoreA,
                "🛡️ الفريق الأول",
                0xFF86EFAC,
                0xFF22C55E,
                0x28059669,
                aIsLeading,
                Gravity.RIGHT
        );
        duelRow.addView(teamABox, new LinearLayout.LayoutParams(0,
                LinearLayout.LayoutParams.WRAP_CONTENT, 1f));

        // شعار المواجهة المركزي (Center VS Emblem)
        LinearLayout centerVsBox = new LinearLayout(this);
        centerVsBox.setOrientation(LinearLayout.VERTICAL);
        centerVsBox.setGravity(Gravity.CENTER);
        LinearLayout.LayoutParams cvsLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        cvsLp.setMargins(dpx(10), 0, dpx(10), 0);
        centerVsBox.setLayoutParams(cvsLp);

        TextView vsBadge = new TextView(this);
        vsBadge.setText("VS");
        vsBadge.setTextColor(0xFFFDE68A);
        vsBadge.setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f);
        vsBadge.setTypeface(Typeface.DEFAULT_BOLD);
        vsBadge.setGravity(Gravity.CENTER);
        vsBadge.setBackground(cardBg(0xFF09142C, 0xFFF59E0B, 999, 2));
        vsBadge.setLayoutParams(new LinearLayout.LayoutParams(dpx(40), dpx(40)));
        centerVsBox.addView(vsBadge);

        TextView turnSub = new TextView(this);
        turnSub.setText(turn + "/" + totalTurns);
        turnSub.setTextColor(TEXT_MUTED);
        turnSub.setTextSize(TypedValue.COMPLEX_UNIT_SP, 9f);
        turnSub.setTypeface(Typeface.DEFAULT_BOLD);
        turnSub.setGravity(Gravity.CENTER);
        LinearLayout.LayoutParams tsLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        tsLp.topMargin = dpx(3);
        turnSub.setLayoutParams(tsLp);
        centerVsBox.addView(turnSub);

        duelRow.addView(centerVsBox);

        // بوكس الفريق الثاني (B - يسار في RTL)
        boolean bIsLeading = scoreB > scoreA;
        LinearLayout teamBBox = createTeamBox(
                teamB,
                scoreB,
                "الفريق الثاني ⚔️",
                0xFF7DD3FC,
                0xFF38BDF8,
                0x280284C7,
                bIsLeading,
                Gravity.LEFT
        );
        duelRow.addView(teamBBox, new LinearLayout.LayoutParams(0,
                LinearLayout.LayoutParams.WRAP_CONTENT, 1f));

        card.addView(duelRow);

        // 3. شريط التقدم في المباراة (Progress Track)
        if (active) {
            LinearLayout progressRow = new LinearLayout(this);
            progressRow.setOrientation(LinearLayout.VERTICAL);
            LinearLayout.LayoutParams prLp = new LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
            prLp.bottomMargin = dpx(8);
            progressRow.setLayoutParams(prLp);

            LinearLayout progressInfo = new LinearLayout(this);
            progressInfo.setOrientation(LinearLayout.HORIZONTAL);
            progressInfo.setGravity(Gravity.CENTER_VERTICAL);

            TextView turnInfo = new TextView(this);
            turnInfo.setText("التقدم: الجولة " + turn + " من إجمالي " + totalTurns);
            turnInfo.setTextColor(TEXT_MUTED);
            turnInfo.setTextSize(TypedValue.COMPLEX_UNIT_SP, 9.5f);
            progressInfo.addView(turnInfo, new LinearLayout.LayoutParams(0,
                    LinearLayout.LayoutParams.WRAP_CONTENT, 1f));

            int percent = (int) Math.min(100, Math.max(0, (turn * 100.0f) / Math.max(1, totalTurns)));
            TextView percentInfo = new TextView(this);
            percentInfo.setText(percent + "%");
            percentInfo.setTextColor(TEXT_WHITE);
            percentInfo.setTextSize(TypedValue.COMPLEX_UNIT_SP, 10f);
            percentInfo.setTypeface(Typeface.DEFAULT_BOLD);
            progressInfo.addView(percentInfo);

            progressRow.addView(progressInfo);

            // مسار التقدم البصري مع مؤشر نقطي مضيء
            FrameLayout progressTrack = new FrameLayout(this);
            progressTrack.setBackground(cardBg(0x331E293B, 0x22FFFFFF, 999, 1));
            LinearLayout.LayoutParams trackLp = new LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT, dpx(5));
            trackLp.topMargin = dpx(3);
            progressTrack.setLayoutParams(trackLp);

            View progressFill = new View(this);
            progressFill.setBackground(gradientPillBg(CYAN, EMERALD, 0x00000000, 0));
            FrameLayout.LayoutParams fillLp = new FrameLayout.LayoutParams(
                    Math.max(dpx(8), (int) (dpx(280) * (percent / 100.0f))),
                    FrameLayout.LayoutParams.MATCH_PARENT);
            fillLp.gravity = Gravity.RIGHT;
            progressFill.setLayoutParams(fillLp);
            progressTrack.addView(progressFill);

            // النقطة النيون المضيئة عند نهاية المسار
            View dot = new View(this);
            dot.setBackground(cardBg(0xFF4ADE80, 0xFFFFFFFF, 999, 1));
            FrameLayout.LayoutParams dotLp = new FrameLayout.LayoutParams(dpx(8), dpx(8));
            dotLp.gravity = Gravity.RIGHT | Gravity.CENTER_VERTICAL;
            dot.setLayoutParams(dotLp);
            progressTrack.addView(dot);

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
            if (scoreA > scoreB) {
                outcome = "تُوّج " + teamA + " بطلاً للمواجهة بنتيجة " + scoreA + " نقطة!";
            } else if (scoreB > scoreA) {
                outcome = "تُوّج " + teamB + " بطلاً للمواجهة بنتيجة " + scoreB + " نقطة!";
            } else {
                outcome = "انتهت المواجهة بالتعادل العادل (" + scoreA + " - " + scoreB + ")";
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

        // 4. أزرار التحكم والإجراءات ثلاثية الأبعاد الفاخرة (Action Footer)
        LinearLayout actionRow = new LinearLayout(this);
        actionRow.setOrientation(LinearLayout.HORIZONTAL);
        actionRow.setGravity(Gravity.CENTER_VERTICAL);
        LinearLayout.LayoutParams arLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        arLp.topMargin = dpx(4);
        actionRow.setLayoutParams(arLp);

        if (active) {
            // 1. زر استئناف اللعب ثلاثي الأبعاد الأخضر (متابعة التحدي ⚔️)
            ImageView resumeBtn = new ImageView(this);
            resumeBtn.setImageResource(R.drawable.btn_match_resume);
            resumeBtn.setScaleType(ImageView.ScaleType.FIT_CENTER);
            applyPressEffect(resumeBtn, new Runnable() {
                @Override
                public void run() {
                    resumeMatch(id);
                }
            });
            LinearLayout.LayoutParams resLp = new LinearLayout.LayoutParams(dpx(195), dpx(40));
            actionRow.addView(resumeBtn, resLp);

            // 2. زر البث للشاشة ("للشاشة")
            ImageView tvBtn = new ImageView(this);
            tvBtn.setImageResource(R.drawable.btn_match_tv);
            tvBtn.setScaleType(ImageView.ScaleType.FIT_CENTER);
            applyPressEffect(tvBtn, new Runnable() {
                @Override
                public void run() {
                    showTvCodeDialog(tvCode, teamA + " ضد " + teamB);
                }
            });
            LinearLayout.LayoutParams tvActLp = new LinearLayout.LayoutParams(dpx(88), dpx(40));
            tvActLp.setMargins(dpx(8), 0, 0, 0);
            actionRow.addView(tvBtn, tvActLp);
        } else {
            TextView archInfo = new TextView(this);
            archInfo.setText("📁 مواجهة مكتملة ومحفوظة بالسجل");
            archInfo.setTextColor(TEXT_MUTED);
            archInfo.setTextSize(TypedValue.COMPLEX_UNIT_SP, 9.5f);
            actionRow.addView(archInfo, new LinearLayout.LayoutParams(0,
                    LinearLayout.LayoutParams.WRAP_CONTENT, 1f));
        }

        // مسافة مرنة لدفع زر الحذف لليسار
        View btnSpacer = new View(this);
        actionRow.addView(btnSpacer, new LinearLayout.LayoutParams(0, 0, 1f));

        // 3. زر الحذف الدائري الياقوتي ثلاثي الأبعاد
        ImageView deleteBtn = new ImageView(this);
        deleteBtn.setImageResource(R.drawable.btn_match_delete);
        deleteBtn.setScaleType(ImageView.ScaleType.FIT_CENTER);
        applyPressEffect(deleteBtn, new Runnable() {
            @Override
            public void run() {
                confirmDelete(id, teamA + " ضد " + teamB);
            }
        });
        actionRow.addView(deleteBtn, new LinearLayout.LayoutParams(dpx(40), dpx(40)));

        card.addView(actionRow);

        return card;
    }

    // ==========================================
    // بوكس معلومات الفريق داخل البطاقة
    // ==========================================
    private LinearLayout createTeamBox(
            String teamName,
            int score,
            String subTag,
            int themeColor,
            int strokeColor,
            int bgFill,
            boolean isLeading,
            int gravity
    ) {
        LinearLayout box = new LinearLayout(this);
        box.setOrientation(LinearLayout.VERTICAL);
        box.setGravity(gravity);
        box.setBackground(cardBg(bgFill, strokeColor, 14, 2));
        box.setPadding(dpx(12), dpx(8), dpx(12), dpx(8));

        // سطر التاج (الفريق الأول / الفريق الثاني)
        LinearLayout tagRow = new LinearLayout(this);
        tagRow.setOrientation(LinearLayout.HORIZONTAL);
        tagRow.setGravity(gravity | Gravity.CENTER_VERTICAL);

        if (isLeading) {
            TextView crown = new TextView(this);
            crown.setText("👑 ");
            crown.setTextSize(TypedValue.COMPLEX_UNIT_SP, 9f);
            tagRow.addView(crown);
        }

        TextView tagView = new TextView(this);
        tagView.setText(subTag);
        tagView.setTextColor(themeColor);
        tagView.setTextSize(TypedValue.COMPLEX_UNIT_SP, 9f);
        tagView.setTypeface(Typeface.DEFAULT_BOLD);
        tagRow.addView(tagView);

        box.addView(tagRow);

        // اسم الفريق
        TextView nameView = new TextView(this);
        nameView.setText(teamName);
        nameView.setTextColor(TEXT_WHITE);
        nameView.setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f);
        nameView.setTypeface(Typeface.DEFAULT_BOLD);
        nameView.setSingleLine(true);
        nameView.setEllipsize(TextUtils.TruncateAt.END);
        nameView.setGravity(gravity);
        LinearLayout.LayoutParams nLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        nLp.topMargin = dpx(2);
        nLp.bottomMargin = dpx(2);
        nameView.setLayoutParams(nLp);
        box.addView(nameView);

        // نتيجة الفريق
        TextView scoreView = new TextView(this);
        scoreView.setText(score + " نقطة");
        scoreView.setTextColor(isLeading ? GOLD_LIGHT : TEXT_MUTED_LIGHT);
        scoreView.setTextSize(TypedValue.COMPLEX_UNIT_SP, 11.5f);
        scoreView.setTypeface(Typeface.DEFAULT_BOLD);
        scoreView.setGravity(gravity);
        box.addView(scoreView);

        return box;
    }

    // ==========================================
    // بدء واستئناف المباريات
    // ==========================================
    private void startNewMatch() {
        PlayerProgress.recordLocalTeamsPlayed(this);
        Intent intent = new Intent(this, GameActivity.class);
        intent.putExtra("mode", "mono");
        intent.putExtra("localTeams", true);
        intent.putExtra("characterIndex", AppPrefs.getEffectiveCharacter(this));
        startActivity(intent);
    }

    private void resumeMatch(final String saveId) {
        if (TextUtils.isEmpty(saveId)) return;
        JSONObject record = LocalTeamsGameStore.get(this, saveId);
        String tvCode = record != null ? record.optString("tvCode", "") : "";
        if (!TextUtils.isEmpty(tvCode)) {
            LocalTeamsGameStore.fetchFromCloud(this, tvCode, new LocalTeamsGameStore.OnCloudSyncListener() {
                @Override
                public void onSync(JSONObject updated) {
                    launchResumeIntent(saveId);
                }
            });
        } else {
            launchResumeIntent(saveId);
        }
    }

    private void launchResumeIntent(String saveId) {
        PlayerProgress.recordLocalTeamsPlayed(this);
        Intent intent = new Intent(this, GameActivity.class);
        intent.putExtra("mode", "mono");
        intent.putExtra("localTeams", true);
        intent.putExtra("resumeLocalTeams", true);
        intent.putExtra("localTeamsSaveId", saveId);
        intent.putExtra("characterIndex", AppPrefs.getEffectiveCharacter(this));
        startActivity(intent);
    }

    // ==========================================
    // نافذة بث المباراة للتلفزيون (TV Casting Dialog)
    // ==========================================
    private void showTvCodeDialog(final String tvCode, String matchTitle) {
        PlayerProgress.recordTvCast(this);
        LinearLayout dialogView = new LinearLayout(this);
        dialogView.setOrientation(LinearLayout.VERTICAL);
        dialogView.setPadding(dpx(22), dpx(18), dpx(22), dpx(18));
        dialogView.setBackground(gradientCardBg(0xF80A183C, 0xF8040A1A, 0xAAFFD700, 18, 1));
        dialogView.setLayoutDirection(View.LAYOUT_DIRECTION_RTL);

        TextView tvTitle = new TextView(this);
        tvTitle.setText("📺 بث المباراة على الشاشة أو اللابتوب");
        tvTitle.setTextColor(GOLD);
        tvTitle.setTextSize(TypedValue.COMPLEX_UNIT_SP, 15f);
        tvTitle.setTypeface(Typeface.DEFAULT_BOLD);
        tvTitle.setGravity(Gravity.CENTER);
        dialogView.addView(tvTitle);

        TextView subTitle = new TextView(this);
        subTitle.setText(matchTitle);
        subTitle.setTextColor(TEXT_MUTED);
        subTitle.setTextSize(TypedValue.COMPLEX_UNIT_SP, 11f);
        subTitle.setGravity(Gravity.CENTER);
        LinearLayout.LayoutParams stLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        stLp.topMargin = dpx(2);
        stLp.bottomMargin = dpx(12);
        dialogView.addView(subTitle, stLp);

        // صندوق الرمز الرقمي الفخم
        LinearLayout codeBox = new LinearLayout(this);
        codeBox.setOrientation(LinearLayout.VERTICAL);
        codeBox.setGravity(Gravity.CENTER);
        codeBox.setBackground(gradientCardBg(0x33FFD700, 0x1A000000, 0x88FFD700, 14, 2));
        codeBox.setPadding(dpx(16), dpx(8), dpx(16), dpx(8));
        LinearLayout.LayoutParams cbLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        cbLp.bottomMargin = dpx(12);
        codeBox.setLayoutParams(cbLp);

        TextView labelCode = new TextView(this);
        labelCode.setText("رمز الشاشة السريع (TV PIN)");
        labelCode.setTextColor(GOLD_LIGHT);
        labelCode.setTextSize(TypedValue.COMPLEX_UNIT_SP, 10f);
        labelCode.setGravity(Gravity.CENTER);
        codeBox.addView(labelCode);

        TextView codeView = new TextView(this);
        codeView.setText(TextUtils.isEmpty(tvCode) ? "----" : tvCode);
        codeView.setTextColor(TEXT_WHITE);
        codeView.setTextSize(TypedValue.COMPLEX_UNIT_SP, 34f);
        codeView.setTypeface(Typeface.DEFAULT_BOLD);
        codeView.setLetterSpacing(0.25f);
        codeView.setGravity(Gravity.CENTER);
        codeBox.addView(codeView);

        dialogView.addView(codeBox);

        // صندوق خطوات التشغيل المبسطة
        LinearLayout guideBox = new LinearLayout(this);
        guideBox.setOrientation(LinearLayout.VERTICAL);
        guideBox.setBackground(cardBg(0x221E293B, 0x3338BDF8, 10, 1));
        guideBox.setPadding(dpx(12), dpx(8), dpx(12), dpx(8));
        LinearLayout.LayoutParams gbLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        gbLp.bottomMargin = dpx(14);
        guideBox.setLayoutParams(gbLp);

        TextView step1 = new TextView(this);
        step1.setText("1️⃣ افتح متصفح التلفزيون أو الكمبيوتر على الرابط:");
        step1.setTextColor(TEXT_MUTED);
        step1.setTextSize(TypedValue.COMPLEX_UNIT_SP, 10f);
        guideBox.addView(step1);

        final String webUrl = "https://challengeland.web.app/play";
        TextView urlView = new TextView(this);
        urlView.setText(webUrl);
        urlView.setTextColor(CYAN);
        urlView.setTextSize(TypedValue.COMPLEX_UNIT_SP, 11.5f);
        urlView.setTypeface(Typeface.DEFAULT_BOLD);
        urlView.setGravity(Gravity.CENTER);
        LinearLayout.LayoutParams uvLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        uvLp.topMargin = dpx(3);
        uvLp.bottomMargin = dpx(4);
        urlView.setLayoutParams(uvLp);
        guideBox.addView(urlView);

        TextView step2 = new TextView(this);
        if (!TextUtils.isEmpty(tvCode)) {
            step2.setText("2️⃣ أدخل الرمز « " + tvCode + " » لتظهر لوحة اللعبة ونقاط الفرق فوراً!");
        } else {
            step2.setText("2️⃣ أدخل رمز أي مباراة جارية من القائمة لتشاهد التحدي على الشاشة.");
        }
        step2.setTextColor(TEXT_WHITE);
        step2.setTextSize(TypedValue.COMPLEX_UNIT_SP, 10f);
        guideBox.addView(step2);

        dialogView.addView(guideBox);

        // صف أزرار النافذة
        LinearLayout btnRow = new LinearLayout(this);
        btnRow.setOrientation(LinearLayout.HORIZONTAL);
        btnRow.setGravity(Gravity.CENTER);

        final AlertDialog dialog = GameNoticeDialogs.builder(this)
                .setView(dialogView)
                .create();
        if (dialog.getWindow() != null) {
            dialog.getWindow().setBackgroundDrawableResource(android.R.color.transparent);
        }

        if (!TextUtils.isEmpty(tvCode)) {
            Button copyBtn = new Button(this);
            copyBtn.setText("📋 نسخ الرابط والرمز");
            copyBtn.setTextColor(TEXT_WHITE);
            copyBtn.setTextSize(TypedValue.COMPLEX_UNIT_SP, 11f);
            copyBtn.setTypeface(Typeface.DEFAULT_BOLD);
            copyBtn.setAllCaps(false);
            copyBtn.setBackground(withRipple(
                    gradientPillBg(CYAN_DARK, 0xFF0369A1, CYAN, 1),
                    0x33FFFFFF
            ));
            copyBtn.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View v) {
                    AppSoundEffects.click(v.getContext());
                    ClipboardManager clipboard = (ClipboardManager) getSystemService(Context.CLIPBOARD_SERVICE);
                    if (clipboard != null) {
                        ClipData clip = ClipData.newPlainText(
                                "ChallengeLand TV Link",
                                "رابط شاشة التحدي: " + webUrl + " | رمز الدخول: " + tvCode);
                        clipboard.setPrimaryClip(clip);
                        GameNotice.makeText(LocalTeamsGamesActivity.this, "تم نسخ الرابط والرمز بنجاح 📋", Toast.LENGTH_SHORT).show();
                    }
                }
            });
            LinearLayout.LayoutParams cpLp = new LinearLayout.LayoutParams(0, dpx(36), 1f);
            cpLp.setMargins(dpx(6), 0, 0, 0);
            btnRow.addView(copyBtn, cpLp);
        }

        Button closeBtn = new Button(this);
        closeBtn.setText("إغلاق");
        closeBtn.setTextColor(TEXT_MUTED_LIGHT);
        closeBtn.setTextSize(TypedValue.COMPLEX_UNIT_SP, 11f);
        closeBtn.setBackground(withRipple(cardBg(0x331E293B, 0x66475569, 999, 1), 0x44FFFFFF));
        closeBtn.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                AppSoundEffects.click(v.getContext());
                dialog.dismiss();
            }
        });
        btnRow.addView(closeBtn, new LinearLayout.LayoutParams(dpx(75), dpx(36)));

        dialogView.addView(btnRow);
        dialog.show();
    }

    // ==========================================
    // حوارات التأكيد (Confirmation Dialogs)
    // ==========================================
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
                            GameNotice.makeText(LocalTeamsGamesActivity.this, "تم حذف المباراة بنجاح", Toast.LENGTH_SHORT).show();
                            refreshList();
                        }
                    }
                }
        );
    }

    private void confirmClearHistory() {
        ArrayList<JSONObject> all = LocalTeamsGameStore.all(this);
        int finished = 0;
        for (JSONObject record : all) {
            if (LocalTeamsGameStore.isFinished(record)) finished++;
        }
        if (finished == 0) {
            GameNotice.makeText(this, "سجل الأبطال فارغ بالفعل!", Toast.LENGTH_SHORT).show();
            return;
        }
        showCustomConfirmDialog(
                "🧹 تنظيف سجل المباريات",
                "هل تريد حذف جميع المباريات المنتهية (" + finished + " مباراة) من السجل؟",
                "نعم، تنظيف",
                new Runnable() {
                    @Override
                    public void run() {
                        int count = LocalTeamsGameStore.clearFinished(LocalTeamsGamesActivity.this);
                        GameNotice.makeText(LocalTeamsGamesActivity.this, "تم تنظيف " + count + " مباراة من السجل", Toast.LENGTH_SHORT).show();
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
                AppSoundEffects.click(v.getContext());
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
                AppSoundEffects.click(v.getContext());
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

    private void applyPressEffect(View view, final Runnable onClick) {
        view.setClickable(true);
        view.setOnTouchListener(new View.OnTouchListener() {
            @Override
            public boolean onTouch(final View v, MotionEvent event) {
                switch (event.getAction()) {
                    case MotionEvent.ACTION_DOWN:
                        v.animate().scaleX(0.94f).scaleY(0.94f).setDuration(70).start();
                        return true;
                    case MotionEvent.ACTION_UP:
                        v.animate().scaleX(1.0f).scaleY(1.0f).setDuration(80).withEndAction(new Runnable() {
                            @Override
                            public void run() {
                                if (onClick != null) onClick.run();
                            }
                        }).start();
                        return true;
                    case MotionEvent.ACTION_CANCEL:
                        v.animate().scaleX(1.0f).scaleY(1.0f).setDuration(80).start();
                        return true;
                }
                return false;
            }
        });
    }

    private GradientDrawable pageScrimBg() {
        return new GradientDrawable(
                GradientDrawable.Orientation.TOP_BOTTOM,
                new int[]{0x88040816, 0x99060C1F, 0xBB040814});
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
}
