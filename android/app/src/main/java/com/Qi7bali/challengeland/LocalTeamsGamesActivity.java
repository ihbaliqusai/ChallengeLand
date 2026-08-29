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
    private static final int GOLD = 0xFFFFD761;
    private static final int BLUE = 0xFF7DD3FC;
    private static final int GREEN = 0xFF67E8A5;
    private static final int RED = 0xFFEF4444;
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
        shell.setPadding(dpx(20), dpx(14), dpx(20), dpx(14));
        root.addView(shell, new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT));

        shell.addView(createHeader(), new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, dpx(108)));

        LinearLayout body = new LinearLayout(this);
        body.setOrientation(LinearLayout.HORIZONTAL);
        LinearLayout.LayoutParams bodyLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f);
        bodyLp.topMargin = dpx(10);
        shell.addView(body, bodyLp);

        View activeSection = createSection("المباريات القابلة للمتابعة",
                "أكمل تحدي الفرق من آخر نقطة حفظ", true);
        LinearLayout.LayoutParams activeLp = new LinearLayout.LayoutParams(0,
                LinearLayout.LayoutParams.MATCH_PARENT, 1.05f);
        activeLp.setMargins(0, 0, dpx(8), 0);
        body.addView(activeSection, activeLp);

        View historySection = createSection("سجل المباريات والأرشيف",
                "المباريات المنتهية والنتائج النهائية", false);
        LinearLayout.LayoutParams historyLp = new LinearLayout.LayoutParams(0,
                LinearLayout.LayoutParams.MATCH_PARENT, 0.95f);
        historyLp.setMargins(dpx(8), 0, 0, 0);
        body.addView(historySection, historyLp);

        setContentView(root);
    }

    private View createHeader() {
        LinearLayout header = new LinearLayout(this);
        header.setOrientation(LinearLayout.VERTICAL);
        header.setBackground(cardBg(0xDA081738, 0x8838BDF8, 16, 1));
        header.setPadding(dpx(18), dpx(10), dpx(18), dpx(10));

        LinearLayout topRow = new LinearLayout(this);
        topRow.setOrientation(LinearLayout.HORIZONTAL);
        topRow.setGravity(Gravity.CENTER_VERTICAL);

        Button backBtn = new Button(this);
        backBtn.setText("←");
        backBtn.setTextColor(Color.WHITE);
        backBtn.setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f);
        backBtn.setTypeface(Typeface.DEFAULT_BOLD);
        backBtn.setBackground(pillBg(0x33000000, 0x55FFFFFF, 1));
        backBtn.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                finish();
            }
        });
        topRow.addView(backBtn, new LinearLayout.LayoutParams(dpx(40), dpx(40)));

        LinearLayout titleCol = new LinearLayout(this);
        titleCol.setOrientation(LinearLayout.VERTICAL);
        LinearLayout.LayoutParams titleLp = new LinearLayout.LayoutParams(0,
                LinearLayout.LayoutParams.WRAP_CONTENT, 1f);
        titleLp.setMargins(dpx(12), 0, dpx(12), 0);
        titleCol.setLayoutParams(titleLp);

        TextView tag = new TextView(this);
        tag.setText("⚔️ التحدي الرئيسي • مواجهة فريقين");
        tag.setTextColor(GOLD);
        tag.setTextSize(TypedValue.COMPLEX_UNIT_SP, 11f);
        tag.setTypeface(Typeface.DEFAULT_BOLD);
        titleCol.addView(tag);

        TextView title = new TextView(this);
        title.setText("إدارة مباريات التحدي الرئيسي");
        title.setTextColor(Color.WHITE);
        title.setTextSize(TypedValue.COMPLEX_UNIT_SP, 17f);
        title.setTypeface(Typeface.DEFAULT_BOLD);
        titleCol.addView(title);

        topRow.addView(titleCol);

        Button newBtn = new Button(this);
        newBtn.setText("＋ مباراة جديدة");
        newBtn.setTextColor(0xFF031024);
        newBtn.setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f);
        newBtn.setTypeface(Typeface.DEFAULT_BOLD);
        newBtn.setAllCaps(false);
        newBtn.setBackground(pillBg(0xFFFFC727, 0xFFFFF1A8, 1));
        newBtn.setPadding(dpx(14), 0, dpx(14), 0);
        newBtn.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                startNewMatch();
            }
        });
        topRow.addView(newBtn, new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT, dpx(40)));

        header.addView(topRow);

        LinearLayout statsRow = new LinearLayout(this);
        statsRow.setOrientation(LinearLayout.HORIZONTAL);
        statsRow.setGravity(Gravity.CENTER_VERTICAL);
        LinearLayout.LayoutParams statsLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        statsLp.topMargin = dpx(6);
        statsRow.setLayoutParams(statsLp);

        activeCountView = createChip(GOLD, "⚡ 0 جارية");
        statsRow.addView(activeCountView);

        historyCountView = createChip(BLUE, "🏆 0 بالسجل");
        LinearLayout.LayoutParams hcLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        hcLp.setMargins(dpx(8), 0, dpx(8), 0);
        historyCountView.setLayoutParams(hcLp);
        statsRow.addView(historyCountView);

        summaryView = new TextView(this);
        summaryView.setTextColor(TEXT_MUTED);
        summaryView.setTextSize(TypedValue.COMPLEX_UNIT_SP, 11f);
        summaryView.setSingleLine(true);
        summaryView.setEllipsize(TextUtils.TruncateAt.END);
        statsRow.addView(summaryView, new LinearLayout.LayoutParams(0,
                LinearLayout.LayoutParams.WRAP_CONTENT, 1f));

        header.addView(statsRow);

        return header;
    }

    private TextView createChip(int color, String text) {
        TextView tv = new TextView(this);
        tv.setText(text);
        tv.setTextColor(color);
        tv.setTextSize(TypedValue.COMPLEX_UNIT_SP, 10.5f);
        tv.setTypeface(Typeface.DEFAULT_BOLD);
        tv.setPadding(dpx(8), dpx(3), dpx(8), dpx(3));
        tv.setBackground(pillBg(0x44000000, color, 1));
        return tv;
    }

    private View createSection(String title, String subtitle, boolean active) {
        LinearLayout section = new LinearLayout(this);
        section.setOrientation(LinearLayout.VERTICAL);
        section.setBackground(cardBg(0xD0050D24, active ? 0x6638BDF8 : 0x441E293B, 14, 1));
        section.setPadding(dpx(12), dpx(10), dpx(12), dpx(10));

        LinearLayout head = new LinearLayout(this);
        head.setOrientation(LinearLayout.HORIZONTAL);
        head.setGravity(Gravity.CENTER_VERTICAL);

        TextView titleView = new TextView(this);
        titleView.setText(title);
        titleView.setTextColor(active ? GOLD : BLUE);
        titleView.setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f);
        titleView.setTypeface(Typeface.DEFAULT_BOLD);
        head.addView(titleView, new LinearLayout.LayoutParams(0,
                LinearLayout.LayoutParams.WRAP_CONTENT, 1f));

        if (!active) {
            Button clearBtn = new Button(this);
            clearBtn.setText("تنظيف السجل");
            clearBtn.setTextColor(0xFFCBD5E1);
            clearBtn.setTextSize(TypedValue.COMPLEX_UNIT_SP, 10f);
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
                    LinearLayout.LayoutParams.WRAP_CONTENT, dpx(28)));
        }

        section.addView(head);

        TextView subView = new TextView(this);
        subView.setText(subtitle);
        subView.setTextColor(TEXT_MUTED);
        subView.setTextSize(TypedValue.COMPLEX_UNIT_SP, 10f);
        LinearLayout.LayoutParams subLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        subLp.topMargin = dpx(2);
        subLp.bottomMargin = dpx(6);
        section.addView(subView, subLp);

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
                    "ابدأ مباراة جديدة وتحدى أصدقاءك في مواجهة فريقين!",
                    true
            ));
        }

        if (finishedCount == 0) {
            historyList.addView(createEmptyView(
                    "السجل فارغ",
                    "المباريات المنتهية ستظهر هنا لتتبع الفائزين والأرشيف.",
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
            summaryView.setText("إجمالي المباريات المسجلة: " + all.size());
        }
    }

    private View createEmptyView(String title, String subtitle, boolean canCreate) {
        LinearLayout empty = new LinearLayout(this);
        empty.setOrientation(LinearLayout.VERTICAL);
        empty.setGravity(Gravity.CENTER);
        empty.setPadding(dpx(16), dpx(28), dpx(16), dpx(28));
        empty.setBackground(cardBg(0x40030712, 0x20FFFFFF, 12, 1));
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        lp.topMargin = dpx(8);
        empty.setLayoutParams(lp);

        TextView tvTitle = new TextView(this);
        tvTitle.setText(title);
        tvTitle.setTextColor(Color.WHITE);
        tvTitle.setTextSize(TypedValue.COMPLEX_UNIT_SP, 12.5f);
        tvTitle.setTypeface(Typeface.DEFAULT_BOLD);
        tvTitle.setGravity(Gravity.CENTER);
        empty.addView(tvTitle);

        TextView tvSub = new TextView(this);
        tvSub.setText(subtitle);
        tvSub.setTextColor(TEXT_MUTED);
        tvSub.setTextSize(TypedValue.COMPLEX_UNIT_SP, 10.5f);
        tvSub.setGravity(Gravity.CENTER);
        LinearLayout.LayoutParams subLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        subLp.topMargin = dpx(4);
        empty.addView(tvSub, subLp);

        if (canCreate) {
            Button quickBtn = new Button(this);
            quickBtn.setText("＋ ابدأ مباراة جديدة");
            quickBtn.setTextColor(0xFF031024);
            quickBtn.setTextSize(TypedValue.COMPLEX_UNIT_SP, 11f);
            quickBtn.setTypeface(Typeface.DEFAULT_BOLD);
            quickBtn.setAllCaps(false);
            quickBtn.setBackground(pillBg(GOLD, 0xFFFFFFFF, 1));
            quickBtn.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View v) {
                    startNewMatch();
                }
            });
            LinearLayout.LayoutParams btnLp = new LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.WRAP_CONTENT, dpx(34));
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
        card.setBackground(cardBg(
                active ? 0xF00B1838 : 0xE0060F26,
                active ? 0x8838BDF8 : 0x44334155,
                14, 1));
        card.setPadding(dpx(12), dpx(10), dpx(12), dpx(10));
        LinearLayout.LayoutParams cardLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        cardLp.bottomMargin = dpx(8);
        card.setLayoutParams(cardLp);

        LinearLayout topRow = new LinearLayout(this);
        topRow.setOrientation(LinearLayout.HORIZONTAL);
        topRow.setGravity(Gravity.CENTER_VERTICAL);

        TextView timeView = new TextView(this);
        timeView.setText("🕒 " + dateFormat.format(new Date(updated)));
        timeView.setTextColor(TEXT_MUTED);
        timeView.setTextSize(TypedValue.COMPLEX_UNIT_SP, 9.5f);
        topRow.addView(timeView, new LinearLayout.LayoutParams(0,
                LinearLayout.LayoutParams.WRAP_CONTENT, 1f));

        TextView statusBadge = new TextView(this);
        if (active) {
            String phaseText = "لوحة التحدي";
            if (LocalTeamsGameStore.PHASE_CATEGORY_SELECT.equals(phase)) phaseText = "اختيار الفئات";
            else if (LocalTeamsGameStore.PHASE_QUESTION.equals(phase)) phaseText = "سؤال جاري";
            statusBadge.setText("⚡ " + phaseText);
            statusBadge.setTextColor(GREEN);
            statusBadge.setBackground(pillBg(0x33059669, GREEN, 1));
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
            statusBadge.setBackground(pillBg(0x33000000, badgeColor, 1));
        }
        statusBadge.setTextSize(TypedValue.COMPLEX_UNIT_SP, 9.5f);
        statusBadge.setTypeface(Typeface.DEFAULT_BOLD);
        statusBadge.setPadding(dpx(6), dpx(2), dpx(6), dpx(2));
        topRow.addView(statusBadge);

        card.addView(topRow);

        LinearLayout duelRow = new LinearLayout(this);
        duelRow.setOrientation(LinearLayout.HORIZONTAL);
        duelRow.setGravity(Gravity.CENTER_VERTICAL);
        LinearLayout.LayoutParams duelLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        duelLp.topMargin = dpx(6);
        duelLp.bottomMargin = dpx(6);
        duelRow.setLayoutParams(duelLp);

        TextView aName = new TextView(this);
        aName.setText(teamA);
        aName.setTextColor(GOLD);
        aName.setTextSize(TypedValue.COMPLEX_UNIT_SP, 12.5f);
        aName.setTypeface(Typeface.DEFAULT_BOLD);
        aName.setSingleLine(true);
        aName.setEllipsize(TextUtils.TruncateAt.END);
        duelRow.addView(aName, new LinearLayout.LayoutParams(0,
                LinearLayout.LayoutParams.WRAP_CONTENT, 1f));

        TextView scorePill = new TextView(this);
        scorePill.setText(scoreA + "  -  " + scoreB);
        scorePill.setTextColor(Color.WHITE);
        scorePill.setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f);
        scorePill.setTypeface(Typeface.DEFAULT_BOLD);
        scorePill.setPadding(dpx(10), dpx(3), dpx(10), dpx(3));
        scorePill.setBackground(pillBg(0x44000000, 0x66FFFFFF, 1));
        duelRow.addView(scorePill);

        TextView bName = new TextView(this);
        bName.setText(teamB);
        bName.setTextColor(BLUE);
        bName.setTextSize(TypedValue.COMPLEX_UNIT_SP, 12.5f);
        bName.setTypeface(Typeface.DEFAULT_BOLD);
        bName.setGravity(Gravity.LEFT);
        bName.setSingleLine(true);
        bName.setEllipsize(TextUtils.TruncateAt.END);
        duelRow.addView(bName, new LinearLayout.LayoutParams(0,
                LinearLayout.LayoutParams.WRAP_CONTENT, 1f));

        card.addView(duelRow);

        LinearLayout progressRow = new LinearLayout(this);
        progressRow.setOrientation(LinearLayout.HORIZONTAL);
        progressRow.setGravity(Gravity.CENTER_VERTICAL);

        TextView turnInfo = new TextView(this);
        turnInfo.setText("الدور: " + turn + " من " + totalTurns);
        turnInfo.setTextColor(TEXT_MUTED);
        turnInfo.setTextSize(TypedValue.COMPLEX_UNIT_SP, 10f);
        progressRow.addView(turnInfo, new LinearLayout.LayoutParams(0,
                LinearLayout.LayoutParams.WRAP_CONTENT, 1f));

        if (active) {
            Button resumeBtn = new Button(this);
            resumeBtn.setText("▶ متابعة اللعب");
            resumeBtn.setTextColor(0xFF031024);
            resumeBtn.setTextSize(TypedValue.COMPLEX_UNIT_SP, 11f);
            resumeBtn.setTypeface(Typeface.DEFAULT_BOLD);
            resumeBtn.setAllCaps(false);
            resumeBtn.setBackground(pillBg(GREEN, 0xFFFFFFFF, 1));
            resumeBtn.setPadding(dpx(10), 0, dpx(10), 0);
            resumeBtn.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View v) {
                    resumeMatch(id);
                }
            });
            progressRow.addView(resumeBtn, new LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.WRAP_CONTENT, dpx(32)));
        }

        Button deleteBtn = new Button(this);
        deleteBtn.setText("🗑️");
        deleteBtn.setTextColor(RED);
        deleteBtn.setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f);
        deleteBtn.setBackground(pillBg(0x33EF4444, 0x66EF4444, 1));
        deleteBtn.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                confirmDelete(id, teamA + " ضد " + teamB);
            }
        });
        LinearLayout.LayoutParams delLp = new LinearLayout.LayoutParams(dpx(34), dpx(32));
        delLp.setMargins(dpx(6), 0, 0, 0);
        progressRow.addView(deleteBtn, delLp);

        card.addView(progressRow);

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
        dialogView.setBackground(cardBg(0xF008132B, 0x8838BDF8, 16, 1));
        dialogView.setLayoutDirection(View.LAYOUT_DIRECTION_RTL);

        TextView tvTitle = new TextView(this);
        tvTitle.setText(title);
        tvTitle.setTextColor(GOLD);
        tvTitle.setTextSize(TypedValue.COMPLEX_UNIT_SP, 16.5f);
        tvTitle.setTypeface(Typeface.DEFAULT_BOLD);
        dialogView.addView(tvTitle);

        TextView tvMsg = new TextView(this);
        tvMsg.setText(message);
        tvMsg.setTextColor(Color.WHITE);
        tvMsg.setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f);
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
        confirmBtn.setTextColor(Color.WHITE);
        confirmBtn.setTypeface(Typeface.DEFAULT_BOLD);
        confirmBtn.setTextSize(TypedValue.COMPLEX_UNIT_SP, 12.5f);
        confirmBtn.setBackground(pillBg(RED, 0xFFFF7777, 1));
        confirmBtn.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                dialog.dismiss();
                if (onConfirm != null) onConfirm.run();
            }
        });
        LinearLayout.LayoutParams confLp = new LinearLayout.LayoutParams(0, dpx(40), 1f);
        confLp.setMargins(0, 0, dpx(8), 0);
        btnRow.addView(confirmBtn, confLp);

        Button cancelBtn = new Button(this);
        cancelBtn.setText("إلغاء");
        cancelBtn.setAllCaps(false);
        cancelBtn.setTextColor(0xFFCBD5E1);
        cancelBtn.setTextSize(TypedValue.COMPLEX_UNIT_SP, 12.5f);
        cancelBtn.setBackground(pillBg(0x33FFFFFF, 0x44FFFFFF, 1));
        cancelBtn.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                dialog.dismiss();
            }
        });
        LinearLayout.LayoutParams canLp = new LinearLayout.LayoutParams(dpx(80), dpx(40));
        btnRow.addView(cancelBtn, canLp);

        dialogView.addView(btnRow, new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT));

        dialog.show();
    }

    private GradientDrawable pageScrimBg() {
        GradientDrawable gd = new GradientDrawable(
                GradientDrawable.Orientation.TOP_BOTTOM,
                new int[]{0xEE03091A, 0xF506112C, 0xFC040816});
        return gd;
    }

    private GradientDrawable cardBg(int fillColor, int strokeColor, int radiusDp, int strokeDp) {
        GradientDrawable gd = new GradientDrawable();
        gd.setColor(fillColor);
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

    private int dpx(float dp) {
        return (int) (dp * getResources().getDisplayMetrics().density + 0.5f);
    }
}
