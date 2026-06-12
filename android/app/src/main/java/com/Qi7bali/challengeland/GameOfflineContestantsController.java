package net.androidgaming.millionaire2024;

import android.graphics.Color;
import android.graphics.Typeface;
import android.text.TextUtils;
import android.util.DisplayMetrics;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.view.ViewOutlineProvider;
import android.widget.FrameLayout;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.TextView;

import androidx.core.content.res.ResourcesCompat;

import java.util.ArrayList;
import java.util.List;
import java.util.Random;

/**
 * Drives the contestant podiums shown in the offline (single-player) game.
 * Slot 0 is the human player (using the character chosen on the setup screen);
 * the remaining slots are AI bots. The podiums are built dynamically so 2-8
 * players fit in one row, shrinking as the count grows. The podium status is an
 * icon: a clock while waiting, then a green check (correct) or red cross (wrong)
 * once the round is revealed.
 */
final class GameOfflineContestantsController {
    private static final int POINTS_PER_CORRECT = 100;

    /** Number of distinct contestant characters available. */
    private static final int CHARACTER_COUNT = 8;

    // Full-body contestant artwork (988 x 2390), drawn standing behind the podium.
    private static final int[] CONTESTANT_DRAWABLES = {
            R.drawable.contestant_khaled,
            R.drawable.contestant_omar,
            R.drawable.contestant_fahad,
            R.drawable.contestant_mazen,
            R.drawable.contestant_mahmoud,
            R.drawable.contestant_ellen,
            R.drawable.contestant_sarah,
            R.drawable.contestant_talia
    };
    // Matching face avatars (537 x 761) used in the score board (and the setup screen).
    private static final int[] EMOTE_DRAWABLES = {
            R.drawable.emote_khaled,
            R.drawable.emote_omar,
            R.drawable.emote_fahad,
            R.drawable.emote_mazen,
            R.drawable.emote_mahmoud,
            R.drawable.emote_ellen,
            R.drawable.emote_sarah,
            R.drawable.emote_talia
    };
    /** Fixed name for each character; slot 0 (the human) uses the account name instead. */
    private static final String[] CHARACTER_NAMES = {
            "خالد", "عمر", "فهد", "مازن", "محمود", "إيلين", "سارة", "تاليا"
    };

    /** Per-character looping idle clip (res/raw); 0 means fall back to the static image. */
    private static final int[] CONTESTANT_VIDEOS = {
            R.raw.video_khaled,
            R.raw.video_omar,
            R.raw.video_fahad,
            R.raw.video_mazen,
            R.raw.video_mahmoud,
            R.raw.video_ellen,
            R.raw.video_sarah,
            R.raw.video_talia
    };

    // Per-character one-shot reaction clips played when the round is revealed; the
    // figure returns to its idle loop afterwards. 0 = no reaction yet (stays idle).
    // Filled in per character as the clips become available.
    private static final int[] CONTESTANT_VIDEOS_CORRECT = new int[CHARACTER_COUNT];
    private static final int[] CONTESTANT_VIDEOS_WRONG = new int[CHARACTER_COUNT];
    static {
        CONTESTANT_VIDEOS_CORRECT[0] = R.raw.video_khaled_correct;  // Khaled
        CONTESTANT_VIDEOS_WRONG[0]   = R.raw.video_khaled_wrong;
        CONTESTANT_VIDEOS_CORRECT[1] = R.raw.video_omar_correct;    // Omar
        CONTESTANT_VIDEOS_WRONG[1]   = R.raw.video_omar_wrong;
        CONTESTANT_VIDEOS_CORRECT[2] = R.raw.video_fahad_correct;   // Fahad
        CONTESTANT_VIDEOS_WRONG[2]   = R.raw.video_fahad_wrong;
        CONTESTANT_VIDEOS_CORRECT[3] = R.raw.video_mazen_correct;   // Mazen
        CONTESTANT_VIDEOS_WRONG[3]   = R.raw.video_mazen_wrong;
        CONTESTANT_VIDEOS_CORRECT[4] = R.raw.video_mahmoud_correct; // Mahmoud
        CONTESTANT_VIDEOS_WRONG[4]   = R.raw.video_mahmoud_wrong;
        CONTESTANT_VIDEOS_CORRECT[5] = R.raw.video_ellen_correct;   // Ellen
        CONTESTANT_VIDEOS_WRONG[5]   = R.raw.video_ellen_wrong;
        CONTESTANT_VIDEOS_CORRECT[6] = R.raw.video_sarah_correct;   // Sarah
        CONTESTANT_VIDEOS_WRONG[6]   = R.raw.video_sarah_wrong;
        CONTESTANT_VIDEOS_CORRECT[7] = R.raw.video_talia_correct;   // Talia
        CONTESTANT_VIDEOS_WRONG[7]   = R.raw.video_talia_wrong;
    }

    /** Podium artwork aspect (width / height, 1086 x 1448). */
    private static final float PODIUM_ASPECT = 1086f / 1448f;
    /** Contestant artwork aspect (width / height, 988 x 2390). */
    private static final float CONTESTANT_ASPECT = 988f / 2390f;
    /** Animated-clip aspect (width / height, 720 x 1280). */
    private static final float VIDEO_ASPECT = 720f / 1280f;
    /** Contestant rendered height as a multiple of the podium height. */
    private static final float CONTESTANT_SCALE = 1.7f;
    /** Aspect (width / height) of the whole podium+contestant stack, used for fitting. */
    private static final float STACK_ASPECT = PODIUM_ASPECT / CONTESTANT_SCALE;
    /**
     * Trims the bottom of the contestant (as a fraction of podium height) so the
     * legs/feet are clipped behind the podium body instead of poking out beside the
     * narrow podium base. The head and upper body stay at the same height. Tuned to
     * the worst case (feet sitting right at the frame bottom, e.g. Sarah/Mazen).
     */
    private static final float FOOT_CLIP_F = 0.35f;

    // Panel placement on the podium: vertical centre as a fraction of the rendered
    // podium height, measured from the podium bottom (the panels are part of the
    // podium artwork now that the contestant has been split off).
    private static final float SCORE_CENTER_F = 0.674f;
    private static final float SCORE_BOX_H_F = 0.19f;
    private static final float SCORE_TEXT_F = 0.132f;
    private static final float NAME_CENTER_F = 0.48f;
    private static final float NAME_BOX_H_F = 0.13f;
    private static final float NAME_TEXT_F = 0.092f;
    private static final float STATUS_CENTER_F = 0.27f;
    private static final float STATUS_SIZE_F = 0.12f;

    private static final int SCORE_BOARD_ROWS = 4;
    private static final float[] SCORE_BOARD_ROW_CENTER_F = {
            0.292f, 0.477f, 0.662f, 0.847f
    };

    private final GameActivity activity;
    private final Random random = new Random();

    private int count = 4;
    private String[] names;
    private int[] scores;
    private int[] intelligence;
    private boolean[] roundCorrect;

    private TextView[] scoreViews;
    private TextView[] nameViews;
    private ImageView[] statusViews;
    private ChromaVideoView[] slotVideos;
    private final List<ChromaVideoView> videoViews = new ArrayList<>();
    private TextView[] boardNameViews;
    private TextView[] boardScoreViews;
    private ImageView[] boardAvatarViews;
    private FrameLayout scoreBoard;
    private FrameLayout scoreBoardContent;
    private LinearLayout row;
    private Typeface balooFont;
    private int selectedCharacterIndex = 0;
    private boolean active = false;

    GameOfflineContestantsController(GameActivity activity) {
        this.activity = activity;
    }

    boolean isActive() {
        return active;
    }

    /** Builds {@code playerCount} podiums; slot 0 uses {@code characterIndex}. */
    void setup(int playerCount, int characterIndex) {
        setupInternal(playerCount, characterIndex);
    }

    void setupForBoard(int playerCount, int characterIndex) {
        setupInternal(playerCount, characterIndex);
    }

    private void setupInternal(int playerCount, int characterIndex) {
        count = Math.max(2, Math.min(8, playerCount));
        characterIndex = ((characterIndex % CHARACTER_COUNT) + CHARACTER_COUNT) % CHARACTER_COUNT;
        selectedCharacterIndex = characterIndex;

        names = new String[count];
        scores = new int[count];
        intelligence = new int[count];
        roundCorrect = new boolean[count];
        scoreViews = new TextView[count];
        nameViews = new TextView[count];
        statusViews = new ImageView[count];
        slotVideos = new ChromaVideoView[count];

        try {
            balooFont = ResourcesCompat.getFont(activity, R.font.baloo);
        } catch (Exception ignored) {
            balooFont = null;
        }

        // Slot 0 is the human (account name); each bot takes its character's fixed name.
        names[0] = resolvePlayerName();
        for (int i = 1; i < count; i++) {
            intelligence[i] = 48 + random.nextInt(42); // 48..89
            names[i] = CHARACTER_NAMES[(characterIndex + i) % CHARACTER_COUNT];
        }

        buildPodiums(characterIndex);
        buildScoreBoard();

        active = true;
        if (row != null) row.setVisibility(View.VISIBLE);
        View namePlate = activity.findViewById(R.id.hostNamePlate);
        if (namePlate != null) namePlate.setVisibility(View.VISIBLE);
    }

    private void buildPodiums(int characterIndex) {
        row = activity.findViewById(R.id.contestantsRow);
        if (row == null) {
            return;
        }
        releaseVideos();
        row.removeAllViews();

        final DisplayMetrics metrics = activity.getResources().getDisplayMetrics();
        final float density = metrics.density;
        final float screenWidthDp = metrics.widthPixels / density;
        final float screenHeightDp = metrics.heightPixels / density;
        final float paddingStartDp = clamp(screenWidthDp * 0.12f, 58f, 88f); // leave room for the host on the left
        final float paddingEndDp = clamp(screenWidthDp * 0.035f, 14f, 24f);
        row.setPadding(px(paddingStartDp, density), 0, px(paddingEndDp, density), 0);

        final float availableDp = Math.max(120f, screenWidthDp - paddingStartDp - paddingEndDp);
        float podiumWidthDp = (availableDp / count) - 6f;
        // Fit the whole stack (a contestant standing behind the podium) into the space
        // below the question/answers block so it does not overlap the answers
        // (consistent with GameLayoutController sizing).
        final float answersBottomFromTop = GameLayoutController.answersBottomFromTopDp(screenHeightDp);
        final float maxHeightDp = Math.max(48f, screenHeightDp - answersBottomFromTop - 8f);
        final float maxWidthByHeight = maxHeightDp * STACK_ASPECT;
        final float maxPodiumWidthDp = Math.min(78f, maxWidthByHeight);
        final float minPodiumWidthDp = Math.min(screenHeightDp < 340f ? 26f : 32f, maxPodiumWidthDp);
        if (podiumWidthDp > maxWidthByHeight) podiumWidthDp = maxWidthByHeight;
        if (podiumWidthDp > 78f) podiumWidthDp = 78f;
        if (podiumWidthDp < minPodiumWidthDp) podiumWidthDp = minPodiumWidthDp;

        final float podiumHeightDp = podiumWidthDp / PODIUM_ASPECT;
        final float contestantHeightDp = podiumHeightDp * CONTESTANT_SCALE; // the tallest layer

        // Match the row height to the full stack so it anchors to the bottom correctly;
        // the contestant overflows above the podium (clipChildren is false).
        ViewGroup.LayoutParams rowParams = row.getLayoutParams();
        rowParams.height = px(contestantHeightDp, density);
        row.setLayoutParams(rowParams);

        for (int i = 0; i < count; i++) {
            int charIdx = (characterIndex + i) % CHARACTER_COUNT;

            FrameLayout cell = new FrameLayout(activity);
            cell.setLayoutParams(new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.MATCH_PARENT, 1f));
            cell.setClipChildren(false);
            cell.setClipToPadding(false);

            // The contestant stands behind the podium (added first -> drawn underneath).
            // Each character is an animated clip with its black background keyed out at
            // draw time (static artwork is the fallback).
            int videoRes = CONTESTANT_VIDEOS[charIdx];
            View contestant;
            float contestantBoxWidthDp;
            if (videoRes != 0) {
                ChromaVideoView video = new ChromaVideoView(activity, videoRes);
                videoViews.add(video);
                slotVideos[i] = video;
                contestant = video;
                contestantBoxWidthDp = contestantHeightDp * VIDEO_ASPECT;
            } else {
                ImageView image = new ImageView(activity);
                image.setScaleType(ImageView.ScaleType.FIT_CENTER);
                image.setImageResource(CONTESTANT_DRAWABLES[charIdx]);
                contestant = image;
                contestantBoxWidthDp = contestantHeightDp * CONTESTANT_ASPECT;
            }

            // Wrap the figure in a frame that clips its bottom behind the podium body,
            // so the legs/feet are trimmed instead of poking out beside the narrow
            // podium base. The frame is only as wide as the figure (so a raised hand /
            // shoulders are never clipped sideways) and its bottom sits FOOT_CLIP_F
            // above the floor; the figure inside reaches the floor and overflows below,
            // where it gets clipped. The head (top) stays free at the same height.
            final float footClipDp = FOOT_CLIP_F * podiumHeightDp;
            FrameLayout figureClip = new FrameLayout(activity);
            FrameLayout.LayoutParams clipParams = new FrameLayout.LayoutParams(
                    px(contestantBoxWidthDp, density),
                    px(contestantHeightDp - footClipDp, density));
            clipParams.gravity = Gravity.BOTTOM | Gravity.CENTER_HORIZONTAL;
            clipParams.bottomMargin = px(footClipDp, density);
            figureClip.setLayoutParams(clipParams);
            figureClip.setClipChildren(true);
            figureClip.setClipToPadding(true);
            // Outline clip reliably trims the child TextureView (the video) to the
            // frame bounds, which plain clipChildren can miss on some GPUs.
            figureClip.setOutlineProvider(ViewOutlineProvider.BOUNDS);
            figureClip.setClipToOutline(true);

            FrameLayout.LayoutParams contestantParams = new FrameLayout.LayoutParams(
                    px(contestantBoxWidthDp, density), px(contestantHeightDp, density));
            contestantParams.gravity = Gravity.BOTTOM | Gravity.CENTER_HORIZONTAL;
            contestantParams.bottomMargin = -px(footClipDp, density);
            contestant.setLayoutParams(contestantParams);
            figureClip.addView(contestant);
            cell.addView(figureClip);

            // The podium is drawn in front, anchored to the bottom of the cell.
            ImageView podium = new ImageView(activity);
            FrameLayout.LayoutParams podiumParams = new FrameLayout.LayoutParams(
                    px(podiumWidthDp, density), px(podiumHeightDp, density));
            podiumParams.gravity = Gravity.BOTTOM | Gravity.CENTER_HORIZONTAL;
            podium.setLayoutParams(podiumParams);
            podium.setScaleType(ImageView.ScaleType.FIT_CENTER);
            podium.setImageResource(R.drawable.podium);
            cell.addView(podium);

            final float hp = podiumHeightDp; // the panels live on the podium artwork
            TextView score = makeLabel(0.62f * podiumWidthDp, SCORE_BOX_H_F * hp,
                    (SCORE_CENTER_F - SCORE_BOX_H_F / 2f) * hp,
                    "0", SCORE_TEXT_F * hp, "#61FF39", density);
            cell.addView(score);
            scoreViews[i] = score;

            TextView name = makeLabel(0.78f * podiumWidthDp, NAME_BOX_H_F * hp,
                    (NAME_CENTER_F - NAME_BOX_H_F / 2f) * hp,
                    names[i], NAME_TEXT_F * hp, "#060B35", density);
            name.setEllipsize(TextUtils.TruncateAt.END);
            cell.addView(name);
            nameViews[i] = name;

            ImageView status = new ImageView(activity);
            int iconSize = px(STATUS_SIZE_F * hp, density);
            FrameLayout.LayoutParams statusParams = new FrameLayout.LayoutParams(iconSize, iconSize);
            statusParams.gravity = Gravity.BOTTOM | Gravity.CENTER_HORIZONTAL;
            statusParams.bottomMargin = px((STATUS_CENTER_F - STATUS_SIZE_F / 2f) * hp, density);
            status.setLayoutParams(statusParams);
            status.setImageResource(R.drawable.ic_status_waiting);
            cell.addView(status);
            statusViews[i] = status;

            row.addView(cell);
        }
    }

    private TextView makeLabel(float widthDp, float heightDp, float marginBottomDp,
                              String text, float sizeSp, String colorHex, float density) {
        TextView view = new TextView(activity);
        FrameLayout.LayoutParams params =
                new FrameLayout.LayoutParams(px(widthDp, density), px(heightDp, density));
        params.gravity = Gravity.BOTTOM | Gravity.CENTER_HORIZONTAL;
        params.bottomMargin = px(marginBottomDp, density);
        view.setLayoutParams(params);
        view.setText(text);
        view.setTextColor(Color.parseColor(colorHex));
        view.setTextSize(TypedValue.COMPLEX_UNIT_SP, sizeSp);
        view.setGravity(Gravity.CENTER);
        view.setMaxLines(1);
        view.setIncludeFontPadding(false);
        if (balooFont != null) {
            view.setTypeface(balooFont, Typeface.BOLD);
        } else {
            view.setTypeface(Typeface.DEFAULT_BOLD);
        }
        return view;
    }

    /**
     * Begins a new round. Everyone shows the waiting clock; the bots privately
     * lock their (predetermined) answer. {@code rightAnswer} is the displayed index 1-4.
     */
    void startRound(String questionLevel, int rightAnswer) {
        if (!active) return;
        for (int i = 0; i < count; i++) {
            roundCorrect[i] = false;
            setStatusIcon(i, R.drawable.ic_status_waiting);
            if (slotVideos != null && slotVideos[i] != null) {
                slotVideos[i].resetToIdle(); // drop any lingering reaction from last round
            }
        }
        for (int i = 1; i < count; i++) {
            roundCorrect[i] = rollCorrect(questionLevel, intelligence[i]);
        }
    }

    void markPlayerAnswered() {
        // The status icon stays "waiting" until the round is revealed.
    }

    /** Reveals the round: awards points and shows the correct/wrong icon for everyone. */
    void revealRound(boolean playerCorrect) {
        if (!active) return;
        roundCorrect[0] = playerCorrect;
        for (int i = 0; i < count; i++) {
            if (roundCorrect[i]) {
                scores[i] += POINTS_PER_CORRECT;
                if (scoreViews[i] != null) scoreViews[i].setText(String.valueOf(scores[i]));
                setStatusIcon(i, R.drawable.ic_status_correct);
            } else {
                setStatusIcon(i, R.drawable.ic_status_wrong);
            }
            triggerReaction(i, roundCorrect[i]);
        }
        refreshScoreBoard();
    }

    // ---- Board ("سين جيم") mode helpers -------------------------------------

    /** Awards the value of a picked board cell to a single contestant. */
    void awardCell(int slot, int value) {
        if (scores == null || slot < 0 || slot >= count) return;
        scores[slot] += value;
        if (scoreViews != null && slot < scoreViews.length && scoreViews[slot] != null) {
            scoreViews[slot].setText(String.valueOf(scores[slot]));
        }
        refreshScoreBoard();
    }

    /** Shows the correct/wrong status icon on a contestant's podium (board mode). */
    void showSlotResult(int slot, boolean correct) {
        setStatusIcon(slot, correct ? R.drawable.ic_status_correct : R.drawable.ic_status_wrong);
        triggerReaction(slot, correct);
    }

    /** Rolls whether a specific bot answers a board question correctly. */
    boolean rollCorrectForSlot(int slot, String level) {
        if (intelligence == null || slot < 0 || slot >= count) return false;
        return rollCorrect(level, intelligence[slot]);
    }

    /** Display name of a contestant slot (slot 0 is the human). */
    String nameForSlot(int slot) {
        if (names == null || slot < 0 || slot >= names.length) return "";
        return names[slot];
    }

    int scoreForSlot(int slot) {
        if (scores == null || slot < 0 || slot >= scores.length) return 0;
        return scores[slot];
    }

    int contestantCount() {
        return count;
    }

    int playerScore() {
        return scores == null ? 0 : scores[0];
    }

    int playerRank() {
        int rank = 1;
        for (int i = 1; i < count; i++) {
            if (scores[i] > scores[0]) rank++;
        }
        return rank;
    }

    int playerCount() {
        return count;
    }

    boolean playerIsWinner() {
        for (int i = 1; i < count; i++) {
            if (scores[i] > scores[0]) return false;
        }
        return true; // ties resolve in the player's favour
    }

    String leaderName() {
        int best = 0;
        for (int i = 1; i < count; i++) {
            if (scores[i] > scores[best]) best = i;
        }
        return names[best];
    }

    String standingsLine() {
        if (playerIsWinner()) {
            return "أنت في الصدارة الآن";
        }
        return "المتصدّر: " + leaderName();
    }

    void release() {
        active = false;
        releaseVideos();
        if (scoreBoard != null) {
            scoreBoard.setVisibility(View.INVISIBLE);
        }
    }

    private void releaseVideos() {
        for (int i = 0; i < videoViews.size(); i++) {
            videoViews.get(i).release();
        }
        videoViews.clear();
    }

    private void setStatusIcon(int slot, int resId) {
        if (statusViews != null && slot < statusViews.length && statusViews[slot] != null) {
            statusViews[slot].setImageResource(resId);
        }
    }

    /** Plays the slot's correct/wrong reaction clip, if that character has one. */
    private void triggerReaction(int slot, boolean correct) {
        if (slotVideos == null || slot >= slotVideos.length || slotVideos[slot] == null) {
            return;
        }
        int charIdx = (selectedCharacterIndex + slot) % CHARACTER_COUNT;
        int resId = correct ? CONTESTANT_VIDEOS_CORRECT[charIdx] : CONTESTANT_VIDEOS_WRONG[charIdx];
        slotVideos[slot].playReaction(resId); // no-op when resId == 0
    }

    private String resolvePlayerName() {
        String name = activity.myName;
        if (name == null || name.trim().isEmpty()) {
            return "أنت";
        }
        name = name.trim();
        return name.length() > 9 ? name.substring(0, 9) : name;
    }

    private boolean rollCorrect(String level, int intel) {
        // Success odds fall monotonically with question level (data uses 0..8), so the
        // bots are not better on the hard high-value cells than on the easy ones.
        int base;
        switch (level == null ? "" : level) {
            case "0": base = 90; break;
            case "1": base = 78; break;
            case "2": base = 62; break;
            case "3": base = 48; break;
            case "4": base = 40; break;
            case "5": base = 34; break;
            case "6": base = 28; break;
            case "7": base = 24; break;
            case "8": base = 20; break;
            default: base = 60; break; // unknown level
        }
        int chance = base + (intel - 68) / 2;
        if (chance < 18) chance = 18;
        if (chance > 97) chance = 97;
        return random.nextInt(100) < chance;
    }

    private int px(float dp, float density) {
        return Math.round(dp * density);
    }

    private float clamp(float value, float min, float max) {
        if (value < min) return min;
        if (value > max) return max;
        return value;
    }

    private void buildScoreBoard() {
        scoreBoard = activity.findViewById(R.id.offlineScoreBoard);
        scoreBoardContent = activity.findViewById(R.id.offlineScoreBoardContent);
        if (scoreBoard == null || scoreBoardContent == null) {
            return;
        }
        scoreBoard.setVisibility(View.VISIBLE);
        scoreBoard.bringToFront();
        scoreBoardContent.removeAllViews();

        final int visibleRows = getVisibleBoardRowCount();
        boardNameViews = new TextView[visibleRows];
        boardScoreViews = new TextView[visibleRows];
        boardAvatarViews = new ImageView[visibleRows];

        scoreBoardContent.post(new Runnable() {
            @Override
            public void run() {
                populateScoreBoardRows();
                refreshScoreBoard();
            }
        });
    }

    private void populateScoreBoardRows() {
        if (scoreBoard == null || scoreBoardContent == null) {
            return;
        }
        scoreBoardContent.removeAllViews();

        final DisplayMetrics metrics = activity.getResources().getDisplayMetrics();
        final float density = metrics.density;
        final int widthPx = scoreBoardContent.getWidth() > 0
                ? scoreBoardContent.getWidth()
                : scoreBoard.getLayoutParams().width;
        final int heightPx = scoreBoardContent.getHeight() > 0
                ? scoreBoardContent.getHeight()
                : scoreBoard.getLayoutParams().height;
        final float boardWidthDp = widthPx / density;
        final float boardHeightDp = heightPx / density;

        final float rowHeightDp = clamp(boardHeightDp * 0.108f, 20f, 30f);
        final float rowLeftDp = boardWidthDp * 0.08f;
        final float rowWidthDp = boardWidthDp * 0.84f;
        final float avatarSizeDp = clamp(rowHeightDp * 0.88f, 18f, 26f);
        final float scoreWidthDp = boardWidthDp * 0.17f;
        final float nameStartDp = avatarSizeDp + boardWidthDp * 0.035f;
        final float nameEndDp = scoreWidthDp + boardWidthDp * 0.035f;
        final float nameTextSp = clamp(rowHeightDp * 0.42f, 8f, 12f);
        final float scoreTextSp = clamp(rowHeightDp * 0.64f, 12f, 18f);

        final int visibleRows = getVisibleBoardRowCount();
        boardNameViews = new TextView[visibleRows];
        boardScoreViews = new TextView[visibleRows];
        boardAvatarViews = new ImageView[visibleRows];

        for (int i = 0; i < visibleRows; i++) {
            FrameLayout rowFrame = new FrameLayout(activity);
            FrameLayout.LayoutParams rowParams = new FrameLayout.LayoutParams(
                    px(rowWidthDp, density),
                    px(rowHeightDp, density)
            );
            rowParams.leftMargin = px(rowLeftDp, density);
            rowParams.topMargin = px(
                    (boardHeightDp * SCORE_BOARD_ROW_CENTER_F[i]) - (rowHeightDp / 2f),
                    density
            );
            rowFrame.setLayoutParams(rowParams);

            ImageView avatar = new ImageView(activity);
            FrameLayout.LayoutParams avatarParams = new FrameLayout.LayoutParams(
                    px(avatarSizeDp, density),
                    px(avatarSizeDp, density)
            );
            avatarParams.gravity = Gravity.START | Gravity.CENTER_VERTICAL;
            avatarParams.leftMargin = px(boardWidthDp * 0.015f, density);
            avatar.setLayoutParams(avatarParams);
            avatar.setScaleType(ImageView.ScaleType.FIT_CENTER);
            rowFrame.addView(avatar);

            TextView score = makeBoardText(scoreTextSp, "#FFD761", Gravity.CENTER);
            FrameLayout.LayoutParams scoreParams = new FrameLayout.LayoutParams(
                    px(scoreWidthDp, density),
                    FrameLayout.LayoutParams.MATCH_PARENT
            );
            scoreParams.gravity = Gravity.END | Gravity.CENTER_VERTICAL;
            scoreParams.rightMargin = px(boardWidthDp * 0.015f, density);
            score.setLayoutParams(scoreParams);
            rowFrame.addView(score);

            TextView name = makeBoardText(nameTextSp, "#FFFFFF", Gravity.CENTER_VERTICAL | Gravity.END);
            name.setMaxLines(2);
            name.setEllipsize(TextUtils.TruncateAt.END);
            name.setTextDirection(View.TEXT_DIRECTION_RTL);
            FrameLayout.LayoutParams nameParams = new FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.MATCH_PARENT,
                    FrameLayout.LayoutParams.MATCH_PARENT
            );
            nameParams.leftMargin = px(nameStartDp, density);
            nameParams.rightMargin = px(nameEndDp, density);
            name.setLayoutParams(nameParams);
            rowFrame.addView(name);

            scoreBoardContent.addView(rowFrame);
            boardAvatarViews[i] = avatar;
            boardNameViews[i] = name;
            boardScoreViews[i] = score;
        }
    }

    private TextView makeBoardText(float sizeSp, String colorHex, int gravity) {
        TextView view = new TextView(activity);
        view.setTextColor(Color.parseColor(colorHex));
        view.setTextSize(TypedValue.COMPLEX_UNIT_SP, sizeSp);
        view.setGravity(gravity);
        view.setIncludeFontPadding(false);
        if (balooFont != null) {
            view.setTypeface(balooFont, Typeface.BOLD);
        } else {
            view.setTypeface(Typeface.DEFAULT_BOLD);
        }
        return view;
    }

    private void refreshScoreBoard() {
        if (boardNameViews == null || boardScoreViews == null || boardAvatarViews == null
                || names == null || scores == null) {
            return;
        }
        int visibleRows = Math.min(getVisibleBoardRowCount(), boardNameViews.length);
        int[] order = getScoreBoardOrder(visibleRows);
        for (int rowIndex = 0; rowIndex < visibleRows; rowIndex++) {
            int playerIndex = order[rowIndex];
            if (boardNameViews[rowIndex] != null) {
                boardNameViews[rowIndex].setText(names[playerIndex]);
            }
            if (boardScoreViews[rowIndex] != null) {
                boardScoreViews[rowIndex].setText(String.valueOf(scores[playerIndex]));
            }
            if (boardAvatarViews[rowIndex] != null) {
                boardAvatarViews[rowIndex].setImageResource(
                        EMOTE_DRAWABLES[(selectedCharacterIndex + playerIndex) % CHARACTER_COUNT]
                );
            }
        }
    }

    private int getVisibleBoardRowCount() {
        return Math.min(SCORE_BOARD_ROWS, count);
    }

    private int[] getScoreBoardOrder(int visibleRows) {
        int[] order = new int[visibleRows];
        boolean[] used = new boolean[count];
        for (int rowIndex = 0; rowIndex < visibleRows; rowIndex++) {
            int best = -1;
            for (int playerIndex = 0; playerIndex < count; playerIndex++) {
                if (used[playerIndex]) {
                    continue;
                }
                if (best < 0
                        || scores[playerIndex] > scores[best]
                        || (scores[playerIndex] == scores[best] && playerIndex < best)) {
                    best = playerIndex;
                }
            }
            if (best < 0) {
                best = rowIndex;
            }
            used[best] = true;
            order[rowIndex] = best;
        }
        return order;
    }
}
