package com.qi7bali.landchallengeonline;

import android.util.DisplayMetrics;
import android.util.TypedValue;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;

import androidx.core.widget.TextViewCompat;

final class GameLayoutController {
    private final GameActivity activity;

    GameLayoutController(GameActivity activity) {
        this.activity = activity;
    }

    void configureAnswerTextSizing() {
        for (TextView answerView : new TextView[]{
                activity.txtA1,
                activity.txtA2,
                activity.txtA3,
                activity.txtA4
        }) {
            if (answerView == null) {
                continue;
            }
            TextViewCompat.setAutoSizeTextTypeWithDefaults(
                    answerView,
                    TextViewCompat.AUTO_SIZE_TEXT_TYPE_NONE
            );
            answerView.setHorizontallyScrolling(false);
            answerView.setSingleLine(false);
            answerView.setMaxLines(1);
            answerView.setIncludeFontPadding(false);
        }
    }

    void configureGameSurfaceLayout() {
        final DisplayMetrics metrics = GameViewportActivity.canvasMetrics(activity);
        final float screenWidthDp = metrics.widthPixels / metrics.density;
        final float screenHeightDp = metrics.heightPixels / metrics.density;
        final boolean shortScreen = screenHeightDp < 390f;
        final boolean narrowScreen = screenWidthDp < 760f;

        if (activity.llyQA != null) {
            int targetWidthDp = activity.modeOnline
                    ? Math.round(screenWidthDp * (shortScreen ? 0.50f : 0.54f))
                    : Math.round(screenWidthDp * (shortScreen ? 0.56f : 0.58f));
            targetWidthDp = Math.max(shortScreen ? 430 : 480, Math.min(560, targetWidthDp));
            targetWidthDp = Math.min(targetWidthDp, Math.max(360, Math.round(screenWidthDp - 112f)));
            if (activity.isOfflineContestantMode() || activity.boardMode || activity.campaignMode) {
                int boardWidthDp = scoreBoardWidthDp(screenHeightDp);
                int boardLeftDp = Math.round(screenWidthDp - scoreBoardEndMarginDp(screenWidthDp) - boardWidthDp);
                int maxWidthBesideBoardDp = Math.round(2f * (boardLeftDp - 10f - (screenWidthDp / 2f)));
                targetWidthDp = Math.min(targetWidthDp, Math.max(shortScreen ? 340 : 380, maxWidthBesideBoardDp));
            }
            ViewGroup.LayoutParams params = activity.llyQA.getLayoutParams();
            params.width = activity.dp(targetWidthDp);
            activity.llyQA.setLayoutParams(params);
        }

        if (activity.txtQ != null) {
            activity.txtQ.setSingleLine(false);
            activity.txtQ.setMaxLines(2);
            activity.txtQ.setIncludeFontPadding(false);
            TextViewCompat.setAutoSizeTextTypeUniformWithConfiguration(
                    activity.txtQ,
                    10,
                    shortScreen ? 16 : 18,
                    1,
                    TypedValue.COMPLEX_UNIT_SP
            );
        }

        final int toolSizeDp = shortScreen || narrowScreen ? 50 : 58;
        resizeSquareView(activity.imgHelp5050, toolSizeDp);
        resizeSquareView(activity.imgHelpCall, toolSizeDp);
        resizeSquareView(activity.imgHelpAudience, toolSizeDp);
        resizeSquareView(activity.imgVolume, toolSizeDp);
        resizeSquareView(activity.imgHome, toolSizeDp);
        resizeSquareView(activity.rlyProgress, shortScreen ? 44 : 50);

        if (activity.txtProgress != null) {
            activity.txtProgress.setTextSize(TypedValue.COMPLEX_UNIT_SP, shortScreen ? 17 : 20);
            activity.txtProgress.setIncludeFontPadding(false);
        }

        // Compress the question/answer block vertically on short landscape
        // screens so the contestant podiums below it have room (no overlap).
        // Online match screens reuse the same tuned geometry as offline play.
        if (!activity.isOfflineContestantMode() && !activity.modeOnline && !activity.boardMode && !activity.campaignMode) {
            return;
        }
        final int qaTopMarginDp = qaTopMarginDp(screenHeightDp);
        final int questionHeightDp = questionPanelHeightDp(screenHeightDp);
        final int questionGapDp = questionGapDp(screenHeightDp);
        final int rowHeightDp = answerRowHeightDp(screenHeightDp);
        final int rowGapDp = answerRowGapDp(screenHeightDp);
        setTopMargin(activity.llyQA, qaTopMarginDp);
        setViewHeight(activity.findViewById(R.id.frameQ), questionHeightDp);
        setBottomMargin(activity.findViewById(R.id.frameQ), questionGapDp);
        setViewHeight(activity.findViewById(R.id.llyA1), rowHeightDp);
        setViewHeight(activity.findViewById(R.id.llyA2), rowHeightDp);
        setViewHeight(activity.findViewById(R.id.frameA1), rowHeightDp);
        setViewHeight(activity.findViewById(R.id.frameA2), rowHeightDp);
        setViewHeight(activity.findViewById(R.id.frameA3), rowHeightDp);
        setViewHeight(activity.findViewById(R.id.frameA4), rowHeightDp);
        setViewHeight(activity.findViewById(R.id.imgA1), rowHeightDp);
        setViewHeight(activity.findViewById(R.id.imgA2), rowHeightDp);
        setViewHeight(activity.findViewById(R.id.imgA3), rowHeightDp);
        setViewHeight(activity.findViewById(R.id.imgA4), rowHeightDp);
        setTopMargin(activity.findViewById(R.id.llyA2), rowGapDp);
        configureAnswerInnerControls(rowHeightDp, shortScreen);
        configureQuestionCounter(screenHeightDp);
        configureScoreBoard(screenWidthDp, screenHeightDp);
        configureHostAndPlate(screenHeightDp);
    }

    // Base (XML) dimensions of the presenter + name plate, tuned for a standard
    // (~480dp tall) landscape screen.
    private static final int HOST_WIDTH_DP = 208;
    private static final int HOST_HEIGHT_DP = 141;
    private static final int HOST_BOTTOM_MARGIN_DP = 288;
    private static final int PLATE_WIDTH_DP = 152;
    private static final int PLATE_HEIGHT_DP = 64;
    private static final int PLATE_BOTTOM_MARGIN_DP = 230;
    private static final float PLATE_TEXT_SP = 19f;

    /**
     * The presenter and his name plate use fixed-size art sized for a standard
     * (~480dp tall) landscape screen. On shorter screens the presenter's head would
     * clip off the top, so scale the whole unit down proportionally. Normal and large
     * screens (>= 400dp tall) keep the XML-tuned placement untouched.
     */
    private void configureHostAndPlate(float screenHeightDp) {
        final float scale = Math.min(1f, screenHeightDp / 400f);
        if (scale > 0.995f) {
            return;
        }

        View host = activity.findViewById(R.id.rlyPerson);
        if (host != null) {
            host.setPivotX(activity.dp(HOST_WIDTH_DP) / 2f);   // shrink about the bottom-centre
            host.setPivotY(activity.dp(HOST_HEIGHT_DP));
            host.setScaleX(-scale);                            // keep the mirrored facing
            host.setScaleY(scale);
            setBottomMargin(host, Math.round(HOST_BOTTOM_MARGIN_DP * scale));
        }

        View plate = activity.findViewById(R.id.hostNamePlate);
        if (plate != null) {
            ViewGroup.LayoutParams params = plate.getLayoutParams();
            if (params != null) {
                params.width = activity.dp(Math.round(PLATE_WIDTH_DP * scale));
                params.height = activity.dp(Math.round(PLATE_HEIGHT_DP * scale));
                plate.setLayoutParams(params);
            }
            setBottomMargin(plate, Math.round(PLATE_BOTTOM_MARGIN_DP * scale));
            TextView plateText = plate.findViewById(R.id.txtHostNamePlate);
            if (plateText != null) {
                plateText.setTextSize(TypedValue.COMPLEX_UNIT_SP, PLATE_TEXT_SP * scale);
            }
        }
    }

    // ---- Shared question/answer vertical metrics (used by the contestants controller too) ----

    private static final float COMPACT_HEIGHT_DP = 430f;
    private static final float STANDARD_HEIGHT_DP = 480f;
    private static final float TINY_HEIGHT_DP = 320f;
    private static final float SCORE_BOARD_ASPECT = 505f / 843f;

    static int qaTopMarginDp(float screenHeightDp) {
        return interpolateTinyToCompact(screenHeightDp, 50, 70);
    }

    static int questionPanelHeightDp(float screenHeightDp) {
        if (screenHeightDp < COMPACT_HEIGHT_DP) {
            return Math.max(68, Math.round(screenHeightDp * 0.21f));
        }
        return interpolateCompactToStandard(screenHeightDp, 96, 140);
    }

    static int questionGapDp(float screenHeightDp) {
        return interpolateTinyToCompact(screenHeightDp, 8, 12);
    }

    static int answerRowHeightDp(float screenHeightDp) {
        if (screenHeightDp < COMPACT_HEIGHT_DP) {
            return interpolateTinyToCompact(screenHeightDp, 32, 40);
        }
        return interpolateCompactToStandard(screenHeightDp, 40, 44);
    }

    static int answerRowGapDp(float screenHeightDp) {
        return interpolateTinyToCompact(screenHeightDp, 4, 8);
    }

    /** Distance in dp from the screen top to the bottom of the answers block. */
    static float answersBottomFromTopDp(float screenHeightDp) {
        return qaTopMarginDp(screenHeightDp)
                + questionPanelHeightDp(screenHeightDp)
                + questionGapDp(screenHeightDp)
                + answerRowHeightDp(screenHeightDp)
                + answerRowGapDp(screenHeightDp)
                + answerRowHeightDp(screenHeightDp);
    }

    static int scoreBoardHeightDp(float screenHeightDp) {
        if (screenHeightDp < COMPACT_HEIGHT_DP) {
            return interpolateTinyToCompact(screenHeightDp, 160, 205);
        }
        return interpolateCompactToStandard(screenHeightDp, 205, 228);
    }

    static int scoreBoardWidthDp(float screenHeightDp) {
        return Math.round(scoreBoardHeightDp(screenHeightDp) * SCORE_BOARD_ASPECT);
    }

    static int scoreBoardTopMarginDp(float screenHeightDp) {
        if (screenHeightDp < COMPACT_HEIGHT_DP) {
            return interpolateTinyToCompact(screenHeightDp, 70, 86);
        }
        return interpolateCompactToStandard(screenHeightDp, 86, 92);
    }

    static int scoreBoardEndMarginDp(float screenWidthDp) {
        return Math.round(Math.max(8f, Math.min(14f, screenWidthDp * 0.014f)));
    }

    private static int interpolateTinyToCompact(float screenHeightDp, int tinyValue, int compactValue) {
        if (screenHeightDp <= TINY_HEIGHT_DP) {
            return tinyValue;
        }
        if (screenHeightDp >= COMPACT_HEIGHT_DP) {
            return compactValue;
        }
        float progress = (screenHeightDp - TINY_HEIGHT_DP) / (COMPACT_HEIGHT_DP - TINY_HEIGHT_DP);
        return Math.round(tinyValue + ((compactValue - tinyValue) * progress));
    }

    private static int interpolateCompactToStandard(float screenHeightDp, int compactValue, int standardValue) {
        if (screenHeightDp <= COMPACT_HEIGHT_DP) {
            return compactValue;
        }
        if (screenHeightDp >= STANDARD_HEIGHT_DP) {
            return standardValue;
        }
        float progress = (screenHeightDp - COMPACT_HEIGHT_DP) / (STANDARD_HEIGHT_DP - COMPACT_HEIGHT_DP);
        return Math.round(compactValue + ((standardValue - compactValue) * progress));
    }

    private void setViewHeight(View view, int heightDp) {
        if (view == null) {
            return;
        }
        ViewGroup.LayoutParams params = view.getLayoutParams();
        if (params == null) {
            return;
        }
        params.height = activity.dp(heightDp);
        view.setLayoutParams(params);
    }

    private void setTopMargin(View view, int marginDp) {
        if (view == null || !(view.getLayoutParams() instanceof ViewGroup.MarginLayoutParams)) {
            return;
        }
        ((ViewGroup.MarginLayoutParams) view.getLayoutParams()).topMargin = activity.dp(marginDp);
        view.requestLayout();
    }

    private void setBottomMargin(View view, int marginDp) {
        if (view == null || !(view.getLayoutParams() instanceof ViewGroup.MarginLayoutParams)) {
            return;
        }
        ((ViewGroup.MarginLayoutParams) view.getLayoutParams()).bottomMargin = activity.dp(marginDp);
        view.requestLayout();
    }

    private void setStartMargin(View view, int marginDp) {
        if (view == null || !(view.getLayoutParams() instanceof ViewGroup.MarginLayoutParams)) {
            return;
        }
        ((ViewGroup.MarginLayoutParams) view.getLayoutParams()).setMarginStart(activity.dp(marginDp));
        view.requestLayout();
    }

    private void setHorizontalMargins(View view, int startDp, int endDp) {
        if (view == null || !(view.getLayoutParams() instanceof ViewGroup.MarginLayoutParams)) {
            return;
        }
        ViewGroup.MarginLayoutParams params = (ViewGroup.MarginLayoutParams) view.getLayoutParams();
        params.setMarginStart(activity.dp(startDp));
        params.setMarginEnd(activity.dp(endDp));
        view.requestLayout();
    }

    private void resizeSquareView(View view, int sizeDp) {
        if (view == null) {
            return;
        }
        ViewGroup.LayoutParams params = view.getLayoutParams();
        params.width = activity.dp(sizeDp);
        params.height = activity.dp(sizeDp);
        view.setLayoutParams(params);
    }

    private void configureAnswerInnerControls(int rowHeightDp, boolean shortScreen) {
        final int letterSizeDp = Math.max(24, Math.min(32, rowHeightDp - 4));
        final int playerThumbSizeDp = Math.max(18, Math.min(22, rowHeightDp - 10));
        final int answerStartMarginDp = shortScreen ? 28 : 38;
        final int answerEndMarginDp = shortScreen ? 46 : 58;
        final int letterEndMarginDp = shortScreen ? 13 : 17;

        for (int id : new int[]{
                R.id.txtA1Letter,
                R.id.txtA2Letter,
                R.id.txtA3Letter,
                R.id.txtA4Letter
        }) {
            View letter = activity.findViewById(id);
            resizeSquareView(letter, letterSizeDp);
            setHorizontalMargins(letter, 0, letterEndMarginDp);
        }

        for (int id : new int[]{
                R.id.imgAnswer1Player1,
                R.id.imgAnswer2Player1,
                R.id.imgAnswer3Player1,
                R.id.imgAnswer4Player1
        }) {
            resizeSquareView(activity.findViewById(id), playerThumbSizeDp);
        }

        for (TextView answerView : new TextView[]{
                activity.txtA1,
                activity.txtA2,
                activity.txtA3,
                activity.txtA4
        }) {
            setHorizontalMargins(answerView, answerStartMarginDp, answerEndMarginDp);
        }

        setHorizontalMargins(activity.txtQ, shortScreen ? 34 : 46, shortScreen ? 34 : 46);
    }

    private void configureQuestionCounter(float screenHeightDp) {
        View panel = activity.findViewById(R.id.questionCounterPanel);
        final int panelWidthDp = interpolateTinyToCompact(screenHeightDp, 166, 198);
        final int panelHeightDp = interpolateTinyToCompact(screenHeightDp, 42, 52);
        final int topMarginDp = interpolateTinyToCompact(screenHeightDp, 17, 24);
        ViewGroup.LayoutParams params = panel == null ? null : panel.getLayoutParams();
        if (params != null) {
            params.width = activity.dp(panelWidthDp);
            params.height = activity.dp(panelHeightDp);
            panel.setLayoutParams(params);
            setTopMargin(panel, topMarginDp);
        }
        if (activity.txtQuestionCounter != null) {
            activity.txtQuestionCounter.setTextSize(
                    TypedValue.COMPLEX_UNIT_SP,
                    interpolateTinyToCompact(screenHeightDp, 20, 25)
            );
            activity.txtQuestionCounter.setIncludeFontPadding(false);
        }
    }

    private void configureScoreBoard(float screenWidthDp, float screenHeightDp) {
        View board = activity.findViewById(R.id.offlineScoreBoard);
        if (board == null) {
            return;
        }
        ViewGroup.LayoutParams params = board.getLayoutParams();
        if (params == null) {
            return;
        }
        params.width = activity.dp(scoreBoardWidthDp(screenHeightDp));
        params.height = activity.dp(scoreBoardHeightDp(screenHeightDp));
        board.setLayoutParams(params);
        setTopMargin(board, scoreBoardTopMarginDp(screenHeightDp));
        if (board.getLayoutParams() instanceof ViewGroup.MarginLayoutParams) {
            ViewGroup.MarginLayoutParams marginParams =
                    (ViewGroup.MarginLayoutParams) board.getLayoutParams();
            marginParams.setMarginEnd(activity.dp(scoreBoardEndMarginDp(screenWidthDp)));
            board.requestLayout();
        }
    }
}
