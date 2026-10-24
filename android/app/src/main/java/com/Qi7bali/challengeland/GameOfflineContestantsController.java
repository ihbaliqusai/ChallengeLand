package com.qi7bali.landchallengeonline;

import android.app.ActivityManager;
import android.content.Context;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.graphics.drawable.LayerDrawable;
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
    private static final int CHARACTER_COUNT = CharacterUnlocks.CHARACTER_COUNT;

    // Full-body contestant artwork (988 x 2390), drawn standing behind the podium.
    private static final int[] CONTESTANT_DRAWABLES = {
            R.drawable.contestant_khaled,
            R.drawable.contestant_omar,
            R.drawable.contestant_fahad,
            R.drawable.contestant_mazen,
            R.drawable.contestant_mahmoud,
            R.drawable.contestant_ellen,
            R.drawable.contestant_sarah,
            R.drawable.contestant_talia,
            R.drawable.contestant_layan,
            R.drawable.contestant_rashid,
            R.drawable.contestant_jana,
            R.drawable.contestant_yazan,
            R.drawable.contestant_nour,
            R.drawable.contestant_zaid,
            R.drawable.contestant_salman,
            R.drawable.contestant_adam
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
            R.drawable.emote_talia,
            R.drawable.emote_layan,
            R.drawable.emote_rashid,
            R.drawable.emote_jana,
            R.drawable.emote_yazan,
            R.drawable.emote_nour,
            R.drawable.emote_zaid,
            R.drawable.emote_salman,
            R.drawable.emote_adam
    };
    /** Fixed name for each character; slot 0 (the human) uses the account name instead. */
    private static final String[] CHARACTER_NAMES = {
            "خالد", "عمر", "فهد", "مازن", "محمود", "إلين", "سارة", "تاليا",
            "ليان", "راشد", "جنى", "يزن", "ريناد", "زيد", "سلمان", "آدم"
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
            R.raw.video_talia,
            R.raw.video_layan,
            R.raw.video_rashid,
            R.raw.video_jana,
            R.raw.video_yazan,
            R.raw.video_nour,
            R.raw.video_zaid,
            R.raw.video_salman,
            R.raw.video_adam
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
        CONTESTANT_VIDEOS_CORRECT[8] = R.raw.video_layan_correct;
        CONTESTANT_VIDEOS_WRONG[8] = R.raw.video_layan_wrong;
        CONTESTANT_VIDEOS_CORRECT[9] = R.raw.video_rashid_correct;
        CONTESTANT_VIDEOS_WRONG[9] = R.raw.video_rashid_wrong;
        CONTESTANT_VIDEOS_CORRECT[10] = R.raw.video_jana_correct;
        CONTESTANT_VIDEOS_WRONG[10] = R.raw.video_jana_wrong;
        CONTESTANT_VIDEOS_CORRECT[11] = R.raw.video_yazan_correct;
        CONTESTANT_VIDEOS_WRONG[11] = R.raw.video_yazan_wrong;
        CONTESTANT_VIDEOS_CORRECT[12] = R.raw.video_nour_correct;
        CONTESTANT_VIDEOS_WRONG[12] = R.raw.video_nour_wrong;
        CONTESTANT_VIDEOS_CORRECT[13] = R.raw.video_zaid_correct;
        CONTESTANT_VIDEOS_WRONG[13] = R.raw.video_zaid_wrong;
        CONTESTANT_VIDEOS_CORRECT[14] = R.raw.video_salman_correct;
        CONTESTANT_VIDEOS_WRONG[14] = R.raw.video_salman_wrong;
        CONTESTANT_VIDEOS_CORRECT[15] = R.raw.video_adam_correct;
        CONTESTANT_VIDEOS_WRONG[15] = R.raw.video_adam_wrong;
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
    private FrameLayout[] boardRowFrames;
    private View[] boardTurnIndicators;
    private FrameLayout scoreBoard;
    private FrameLayout scoreBoardContent;
    private LinearLayout row;
    private Typeface balooFont;
    private int selectedCharacterIndex = 0;
    private boolean active = false;

    // Online room board: the figure (character artwork) chosen per slot, the team of
    // each seat ("A"/"B"/""), and whether this is a team match. For offline/1v1 the
    // figure is the classic cycling order and teamMode stays false.
    private int[] slotCharacter;
    private String[] slotTeam;
    private boolean teamMode = false;
    // التحدي الرئيسي (two teams on one phone): no animated figures, and the scoreboard
    // shows each team's name + live point total instead of avatars + rank ordinals.
    private boolean localTeamsBoard = false;
    private int localTeamsActiveQuestionSlot = -1;

    // Solo stage progress card in تحدي المراحل (replaces empty 4-slot leaderboard)
    private TextView soloStageTitle;
    private TextView soloStageTarget;
    private TextView soloStageScore;
    private TextView soloStageQuestions;
    private final TextView[] soloStageStars = new TextView[3];
    private FrameLayout soloStageProgressTrack;
    private View soloStageProgressFill;
    private LinearLayout soloStageCardLayout;
    private int lastEarnedStars = 0;

    // Match the complete Flutter roster when assigning other players' figures.
    private static final int[] MALE_FIGURES = {0, 1, 2, 3, 4, 9, 11, 13, 14, 15};
    private static final int[] FEMALE_FIGURES = {5, 6, 7, 8, 10, 12};
    private static final java.util.HashSet<String> FEMALE_NAMES = new java.util.HashSet<>(
            java.util.Arrays.asList(
                    "ليلى", "هدى", "منى", "سارة", "رنا", "إلين", "الين", "ايلين", "إيلين", "تاليا", "تالا",
                    "فاطمة", "عائشة", "مريم", "نور", "نوره", "نورة", "ريناد", "سلمى", "رؤى", "دانة",
                    "جنى", "لمى", "رهف", "شهد", "غلا", "أسماء", "اسماء", "هند", "ريم", "ريما",
                    "دلال", "عبير", "حنان", "إيمان", "ايمان", "آلاء", "الاء", "بيان", "جود",
                    "لين", "لينا", "ليان", "دينا", "ميس", "ميساء", "روان", "رغد", "سمر", "رولا", "وعد",
                    "غدير", "أمل", "امل", "رزان", "ربى", "شذى", "علا", "عُلا", "هيا", "جواهر",
                    "لطيفة", "موضي", "العنود", "سديم", "رفيف", "تولين", "بتول", "مزنة", "ندى",
                    "أروى", "اروى", "بشرى", "صفاء", "وفاء", "هبة", "هناء", "رقية", "خديجة",
                    "زينب", "أمنية", "امنية", "ندين", "جوري", "رتاج", "لارا", "ميرا", "سيرين"
            ));

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

    /** Solo board (تحدي المراحل normal stage): a single contestant — the player only,
     *  no bots — so the player accumulates points against a target. */
    void setupForSoloBoard(int characterIndex) {
        count = 1;
        characterIndex = ((characterIndex % CHARACTER_COUNT) + CHARACTER_COUNT) % CHARACTER_COUNT;
        selectedCharacterIndex = characterIndex;
        teamMode = false;
        slotTeam = null;
        localTeamsBoard = false;
        localTeamsActiveQuestionSlot = -1;

        allocateContestantArrays();
        slotCharacter = new int[count];
        names[0] = resolvePlayerName();
        slotCharacter[0] = characterIndex % CHARACTER_COUNT;

        buildPodiums();
        buildScoreBoard();

        active = true;
        if (row != null) row.setVisibility(View.VISIBLE);
        View namePlate = activity.findViewById(R.id.hostNamePlate);
        if (namePlate != null) namePlate.setVisibility(View.VISIBLE);
    }

    /** Overrides every bot's answer skill (used by تحدي المراحل boss stages, which
     *  scale boss strength with the world). Slot 0 (the human) is left untouched. */
    void setBoardBotIntelligence(int value) {
        if (intelligence == null) return;
        int v = Math.max(10, Math.min(99, value));
        for (int i = 1; i < count; i++) {
            intelligence[i] = v;
        }
    }

    /**
     * Online room board: each seat shows a real player/bot name with a figure whose
     * gender matches that name, plus (for team matches) a team tag/colour so the
     * podiums clearly read as a team challenge. {@code seatTeams} entries are "A"/"B"
     * (or "" for the solo competition board).
     */
    void setupForRoomBoard(int playerCount, int characterIndex, String[] seatNames,
                           String[] seatTeams, boolean isTeam) {
        setupRoomInternal(playerCount, characterIndex, seatNames, seatTeams, isTeam);
    }

    private void setupInternal(int playerCount, int characterIndex) {
        count = Math.max(2, Math.min(8, playerCount));
        characterIndex = ((characterIndex % CHARACTER_COUNT) + CHARACTER_COUNT) % CHARACTER_COUNT;
        selectedCharacterIndex = characterIndex;
        teamMode = false;
        slotTeam = null;
        localTeamsBoard = false;
        localTeamsActiveQuestionSlot = -1;

        allocateContestantArrays();
        slotCharacter = new int[count];

        // Slot 0 is the human (account name); each bot takes its character's fixed name.
        names[0] = resolvePlayerName();
        slotCharacter[0] = characterIndex % CHARACTER_COUNT;
        for (int i = 1; i < count; i++) {
            intelligence[i] = 48 + random.nextInt(42); // 48..89
            names[i] = CHARACTER_NAMES[(characterIndex + i) % CHARACTER_COUNT];
            slotCharacter[i] = (characterIndex + i) % CHARACTER_COUNT;
        }

        buildPodiums();
        buildScoreBoard();

        active = true;
        if (row != null) row.setVisibility(View.VISIBLE);
        View namePlate = activity.findViewById(R.id.hostNamePlate);
        if (namePlate != null) namePlate.setVisibility(View.VISIBLE);
    }

    private void setupRoomInternal(int playerCount, int characterIndex, String[] seatNames,
                                   String[] seatTeams, boolean isTeam) {
        count = Math.max(2, Math.min(8, playerCount));
        characterIndex = ((characterIndex % CHARACTER_COUNT) + CHARACTER_COUNT) % CHARACTER_COUNT;
        selectedCharacterIndex = characterIndex;
        teamMode = isTeam;
        localTeamsBoard = false;
        localTeamsActiveQuestionSlot = -1;

        allocateContestantArrays();
        slotCharacter = new int[count];
        slotTeam = new String[count];

        int maleCursor = 0, femaleCursor = 0;
        for (int i = 0; i < count; i++) {
            String rawName = (seatNames != null && i < seatNames.length) ? seatNames[i] : null;
            String team = (seatTeams != null && i < seatTeams.length) ? seatTeams[i] : "";
            slotTeam[i] = team == null ? "" : team.trim().toUpperCase();
            if (i > 0) intelligence[i] = 48 + random.nextInt(42);

            if (i == 0) {
                // Slot 0 is the local player; ALWAYS use the player's chosen character figure:
                slotCharacter[0] = characterIndex % CHARACTER_COUNT;
            } else {
                // Pick a figure whose gender matches the displayed name for opponents/bots.
                if (isFemaleName(rawName)) {
                    slotCharacter[i] = FEMALE_FIGURES[femaleCursor % FEMALE_FIGURES.length];
                    femaleCursor++;
                } else {
                    slotCharacter[i] = MALE_FIGURES[maleCursor % MALE_FIGURES.length];
                    maleCursor++;
                }
            }
            names[i] = decorateSeatName(rawName, i, slotTeam[i]);
        }

        buildPodiums();
        buildScoreBoard();

        active = true;
        if (row != null) row.setVisibility(View.VISIBLE);
        View namePlate = activity.findViewById(R.id.hostNamePlate);
        if (namePlate != null) namePlate.setVisibility(View.VISIBLE);
    }

    private void allocateContestantArrays() {
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
    }

    /** Trims a seat name and, for team matches, prefixes its team letter (أ/ب). */
    private String decorateSeatName(String rawName, int slot, String team) {
        String base = (rawName == null || rawName.trim().isEmpty())
                ? ("لاعب " + (slot + 1)) : rawName.trim();
        if (teamMode && ("A".equals(team) || "B".equals(team))) {
            String tag = "A".equals(team) ? "أ" : "ب";
            if (base.length() > 7) base = base.substring(0, 7);
            return tag + "-" + base;
        }
        if (base.length() > 9) base = base.substring(0, 9);
        return base;
    }

    private boolean isFemaleName(String name) {
        if (name == null) return false;
        String n = name.trim();
        if (n.isEmpty()) return false;
        int space = n.indexOf(' ');
        String first = space > 0 ? n.substring(0, space) : n;
        if (FEMALE_NAMES.contains(first)) return true;
        if (first.endsWith("ة") || first.endsWith("اء")) return true;
        if (first.endsWith("ى")) {
            // A few common male names also end in ى.
            return !(first.equals("يحيى") || first.equals("موسى")
                    || first.equals("عيسى") || first.equals("مصطفى"));
        }
        return false;
    }

    private int teamColor(String team) {
        if ("B".equals(team)) return 0xFF7DD3FC; // team B — blue
        return 0xFFFFD761;                       // team A — gold
    }

    private String teamColorHex(String team) {
        return "B".equals(team) ? "#7DD3FC" : "#FFD761";
    }

    private void buildPodiums() {
        row = activity.findViewById(R.id.contestantsRow);
        if (row == null) {
            return;
        }
        releaseVideos();
        row.removeAllViews();

        final DisplayMetrics metrics = GameViewportActivity.canvasMetrics(activity);
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
            int charIdx = slotCharacter != null ? slotCharacter[i]
                    : (selectedCharacterIndex + i) % CHARACTER_COUNT;

            FrameLayout cell = new FrameLayout(activity);
            cell.setLayoutParams(new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.MATCH_PARENT, 1f));
            cell.setClipChildren(false);
            cell.setClipToPadding(false);

            // The contestant stands behind the podium (added first -> drawn underneath).
            int videoRes = CONTESTANT_VIDEOS[charIdx];
            boolean useVideo = videoRes != 0 && !isLowEndDevice(activity);
            View contestant;
            float contestantBoxWidthDp;
            if (useVideo) {
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
            // Team match: tint each podium's score with its team colour so the
            // contestants at the bottom clearly read as a team challenge.
            String scoreColorHex = (teamMode && slotTeam != null)
                    ? teamColorHex(slotTeam[i]) : "#61FF39";
            TextView score = makeLabel(0.62f * podiumWidthDp, SCORE_BOX_H_F * hp,
                    (SCORE_CENTER_F - SCORE_BOX_H_F / 2f) * hp,
                    "0", SCORE_TEXT_F * hp, scoreColorHex, density);
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

    // ---- Board ("التحدي") mode helpers -------------------------------------

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
        if (activity.boardCampaignMatch) {
            return random.nextInt(100) < CampaignBoardRules.styledBotCorrectChance(
                    level, intelligence[slot], activity.campaignBossStyleForSlot(slot),
                    activity.isCampaignBossSpecialtyCell(slot));
        }
        return rollCorrect(level, intelligence[slot]);
    }

    /** Display name of a contestant slot (slot 0 is the human). */
    String nameForSlot(int slot) {
        if (names == null || slot < 0 || slot >= names.length) return "";
        return names[slot];
    }

    /** Overrides a contestant slot's display name (used to show a real online opponent). */
    void setContestantName(int slot, String name) {
        if (names == null || slot < 0 || slot >= names.length || name == null || name.trim().isEmpty()) {
            return;
        }
        String trimmed = name.trim();
        // The 9-char cap fits the small podium plates; التحدي الرئيسي hides those and
        // shows full team names on the scoreboard + board grid, so don't truncate there.
        if (!localTeamsBoard && trimmed.length() > 9) {
            trimmed = trimmed.substring(0, 9);
        }
        names[slot] = trimmed;
        if (nameViews != null && slot < nameViews.length && nameViews[slot] != null) {
            nameViews[slot].setText(trimmed);
        }
        refreshScoreBoard();
    }

    int scoreForSlot(int slot) {
        if (scores == null || slot < 0 || slot >= scores.length) return 0;
        return scores[slot];
    }

    void setScoreForSlot(int slot, int value) {
        if (scores == null || slot < 0 || slot >= scores.length) return;
        scores[slot] = Math.max(0, value);
        if (scoreViews != null && slot < scoreViews.length && scoreViews[slot] != null) {
            scoreViews[slot].setText(String.valueOf(scores[slot]));
        }
        refreshScoreBoard();
    }

    int intelligenceForSlot(int slot) {
        if (intelligence == null || slot < 0 || slot >= intelligence.length) return 0;
        return intelligence[slot];
    }

    void setIntelligenceForSlot(int slot, int value) {
        if (intelligence == null || slot < 0 || slot >= intelligence.length) return;
        intelligence[slot] = Math.max(10, Math.min(99, value));
    }

    void setLocalTeamsActiveQuestionSlot(int slot) {
        if (!localTeamsBoard) return;
        localTeamsActiveQuestionSlot = (slot >= 0 && slot < count) ? slot : -1;
        refreshScoreBoard();
    }

    /** The character figure index drawn for a slot (used by the results screen). */
    int characterForSlot(int slot) {
        if (slotCharacter != null && slot >= 0 && slot < slotCharacter.length) {
            return slotCharacter[slot];
        }
        return (selectedCharacterIndex + Math.max(0, slot)) % CHARACTER_COUNT;
    }

    /** The team ("A"/"B"/"") a slot belongs to (room board only). */
    String teamForSlot(int slot) {
        if (slotTeam != null && slot >= 0 && slot < slotTeam.length) {
            return slotTeam[slot] == null ? "" : slotTeam[slot];
        }
        return "";
    }

    /** Looping celebration (correct) / sad (wrong) reaction clip for a character figure. */
    static int reactionVideoForCharacter(int charIndex, boolean correct) {
        if (charIndex < 0 || charIndex >= CHARACTER_COUNT) charIndex = 0;
        return correct ? CONTESTANT_VIDEOS_CORRECT[charIndex] : CONTESTANT_VIDEOS_WRONG[charIndex];
    }

    static int drawableForCharacter(int charIndex) {
        if (charIndex < 0 || charIndex >= CHARACTER_COUNT) charIndex = 0;
        return CONTESTANT_DRAWABLES[charIndex];
    }

    static boolean isLowEndDevice(Context context) {
        if (context == null) return false;
        try {
            ActivityManager am = (ActivityManager) context.getSystemService(Context.ACTIVITY_SERVICE);
            if (am != null && am.isLowRamDevice()) {
                return true;
            }
            long maxMemMb = Runtime.getRuntime().maxMemory() / (1024 * 1024);
            return maxMemMb < 256;
        } catch (Exception ignored) {
            return false;
        }
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
        localTeamsActiveQuestionSlot = -1;
        releaseVideos();
        if (scoreBoard != null) {
            scoreBoard.setVisibility(View.INVISIBLE);
        }
    }

    /** التحدي الرئيسي (two teams on one phone): hide the animated contestant figures
     *  (podium row) but KEEP the scoreboard panel — rendered avatar-less, showing each
     *  team's name + live point total instead of an avatar + rank ordinal. */
    void enableLocalTeamsScoreboard() {
        localTeamsBoard = true;
        localTeamsActiveQuestionSlot = -1;
        releaseVideos();
        if (row != null) row.setVisibility(View.GONE);
        // Use the dedicated two-team "قائمة النتائج" board artwork for this mode.
        View bg = activity.findViewById(R.id.offlineScoreBoardBg);
        if (bg instanceof ImageView) {
            ((ImageView) bg).setImageResource(R.drawable.board1);
        }
        if (scoreBoardContent != null && scoreBoardContent.getChildCount() > 0) {
            populateScoreBoardRows();
        }
        refreshScoreBoard();
    }

    private void releaseVideos() {
        for (int i = 0; i < videoViews.size(); i++) {
            videoViews.get(i).release();
        }
        videoViews.clear();
    }

    void setVideosPaused(boolean paused) {
        for (ChromaVideoView video : videoViews) video.setPaused(paused);
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
        int charIdx = slotCharacter != null ? slotCharacter[slot]
                : (selectedCharacterIndex + slot) % CHARACTER_COUNT;
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

    boolean isSoloCampaignBoard() {
        return activity.campaignBoard && !"boss".equals(activity.boardCampaignKind) && count == 1;
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

        ImageView bg = activity.findViewById(R.id.offlineScoreBoardBg);
        if (isSoloCampaignBoard()) {
            if (bg != null) bg.setVisibility(View.INVISIBLE);
        } else {
            if (bg != null) bg.setVisibility(View.VISIBLE);
        }

        final int visibleRows = getVisibleBoardRowCount();
        boardNameViews = new TextView[visibleRows];
        boardScoreViews = new TextView[visibleRows];
        boardAvatarViews = new ImageView[visibleRows];
        boardRowFrames = new FrameLayout[visibleRows];
        boardTurnIndicators = new View[visibleRows];

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

        if (isSoloCampaignBoard()) {
            populateSoloStageCard();
            return;
        }

        final DisplayMetrics metrics = GameViewportActivity.canvasMetrics(activity);
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
        // Wide enough for multi-thousand board scores (200/400/600 cells add up); the
        // old 0.17 width clipped anything past two digits.
        final float scoreWidthDp = boardWidthDp * 0.30f;
        // التحدي الرئيسي hides the avatar, so give that space back to the (longer) name.
        final float nameStartDp = (localTeamsBoard ? 0f : avatarSizeDp) + boardWidthDp * 0.035f;
        final float nameEndDp = scoreWidthDp + boardWidthDp * 0.035f;
        final float nameTextSp = clamp(rowHeightDp * 0.42f, 8f, 12f);
        final float scoreTextSp = clamp(rowHeightDp * 0.55f, 10f, 15f);

        final int visibleRows = getVisibleBoardRowCount();
        boardNameViews = new TextView[visibleRows];
        boardScoreViews = new TextView[visibleRows];
        boardAvatarViews = new ImageView[visibleRows];
        boardRowFrames = new FrameLayout[visibleRows];
        boardTurnIndicators = new View[visibleRows];

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
            rowFrame.setClipChildren(false);
            rowFrame.setClipToPadding(false);

            View turnIndicator = new View(activity);
            float indicatorSizeDp = clamp(rowHeightDp * 0.42f, 8f, 13f);
            FrameLayout.LayoutParams indicatorParams = new FrameLayout.LayoutParams(
                    px(indicatorSizeDp, density),
                    px(indicatorSizeDp, density)
            );
            indicatorParams.gravity = Gravity.TOP | Gravity.CENTER_HORIZONTAL;
            turnIndicator.setLayoutParams(indicatorParams);
            turnIndicator.setTranslationY(-px(6f, density));
            turnIndicator.setVisibility(View.INVISIBLE);
            turnIndicator.setAlpha(0f);
            rowFrame.addView(turnIndicator);

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
            score.setSingleLine(true);
            // Nudge the rank a hair to the right (screen-space, RTL-independent).
            score.setTranslationX(px(4f, density));
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
            boardRowFrames[i] = rowFrame;
            boardTurnIndicators[i] = turnIndicator;
            boardAvatarViews[i] = avatar;
            boardNameViews[i] = name;
            boardScoreViews[i] = score;
        }
    }

    private void populateSoloStageCard() {
        if (scoreBoard == null || scoreBoardContent == null) {
            return;
        }
        scoreBoardContent.removeAllViews();

        final DisplayMetrics metrics = GameViewportActivity.canvasMetrics(activity);
        final float density = metrics.density;

        ImageView bg = activity.findViewById(R.id.offlineScoreBoardBg);
        if (bg != null) bg.setVisibility(View.INVISIBLE);

        GradientDrawable glow = new GradientDrawable(GradientDrawable.Orientation.TL_BR,
                new int[]{Color.argb(75, 56, 189, 248), Color.argb(45, 255, 216, 74)});
        glow.setCornerRadius(activity.dp(16));
        GradientDrawable glass = new GradientDrawable(GradientDrawable.Orientation.TOP_BOTTOM,
                new int[]{Color.argb(238, 6, 16, 44), Color.argb(230, 4, 10, 30)});
        glass.setCornerRadius(activity.dp(16));
        glass.setStroke(px(1.5f, density), Color.argb(195, 255, 215, 75));
        LayerDrawable cardBg = new LayerDrawable(new android.graphics.drawable.Drawable[]{glow, glass});
        cardBg.setLayerInset(1, activity.dp(2), activity.dp(2), activity.dp(2), activity.dp(2));
        scoreBoardContent.setBackground(cardBg);

        LinearLayout cardLayout = new LinearLayout(activity);
        soloStageCardLayout = cardLayout;
        cardLayout.setOrientation(LinearLayout.VERTICAL);
        cardLayout.setGravity(Gravity.CENTER_HORIZONTAL);
        cardLayout.setLayoutDirection(View.LAYOUT_DIRECTION_RTL);
        int padH = activity.dp(6);
        int padV = activity.dp(8);
        cardLayout.setPadding(padH, padV, padH, padV);
        FrameLayout.LayoutParams cardParams = new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT);
        scoreBoardContent.addView(cardLayout, cardParams);

        // 1. Stage Title Badge
        soloStageTitle = new TextView(activity);
        soloStageTitle.setTextColor(Color.WHITE);
        soloStageTitle.setTextSize(TypedValue.COMPLEX_UNIT_SP, 12.5f);
        soloStageTitle.setGravity(Gravity.CENTER);
        soloStageTitle.setIncludeFontPadding(false);
        if (balooFont != null) soloStageTitle.setTypeface(balooFont, Typeface.BOLD);
        else soloStageTitle.setTypeface(Typeface.DEFAULT_BOLD);

        GradientDrawable titleBadge = new GradientDrawable(GradientDrawable.Orientation.LEFT_RIGHT,
                new int[]{Color.argb(190, 255, 193, 7), Color.argb(150, 217, 119, 6)});
        titleBadge.setCornerRadius(activity.dp(12));
        titleBadge.setStroke(activity.dp(1), Color.argb(230, 255, 235, 150));
        soloStageTitle.setBackground(titleBadge);
        soloStageTitle.setPadding(activity.dp(10), activity.dp(3), activity.dp(10), activity.dp(3));
        LinearLayout.LayoutParams titleParams = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        titleParams.setMargins(0, 0, 0, activity.dp(6));
        cardLayout.addView(soloStageTitle, titleParams);

        // 2. Target Goal
        soloStageTarget = new TextView(activity);
        soloStageTarget.setTextColor(Color.parseColor("#38BDF8"));
        soloStageTarget.setTextSize(TypedValue.COMPLEX_UNIT_SP, 11f);
        soloStageTarget.setGravity(Gravity.CENTER);
        soloStageTarget.setIncludeFontPadding(false);
        if (balooFont != null) soloStageTarget.setTypeface(balooFont, Typeface.BOLD);
        else soloStageTarget.setTypeface(Typeface.DEFAULT_BOLD);
        LinearLayout.LayoutParams targetParams = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        targetParams.setMargins(0, 0, 0, activity.dp(3));
        cardLayout.addView(soloStageTarget, targetParams);

        // 3. Current Live Score
        soloStageScore = new TextView(activity);
        soloStageScore.setTextColor(Color.parseColor("#FFD700"));
        soloStageScore.setTextSize(TypedValue.COMPLEX_UNIT_SP, 12.5f);
        soloStageScore.setGravity(Gravity.CENTER);
        soloStageScore.setIncludeFontPadding(false);
        if (balooFont != null) soloStageScore.setTypeface(balooFont, Typeface.BOLD);
        else soloStageScore.setTypeface(Typeface.DEFAULT_BOLD);
        LinearLayout.LayoutParams scoreParams = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        scoreParams.setMargins(0, 0, 0, activity.dp(3));
        cardLayout.addView(soloStageScore, scoreParams);

        // 4. Questions Counter
        soloStageQuestions = new TextView(activity);
        soloStageQuestions.setTextColor(Color.parseColor("#E2E8F0"));
        soloStageQuestions.setTextSize(TypedValue.COMPLEX_UNIT_SP, 10f);
        soloStageQuestions.setGravity(Gravity.CENTER);
        soloStageQuestions.setIncludeFontPadding(false);
        if (balooFont != null) soloStageQuestions.setTypeface(balooFont, Typeface.BOLD);
        else soloStageQuestions.setTypeface(Typeface.DEFAULT_BOLD);
        LinearLayout.LayoutParams qParams = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        qParams.setMargins(0, 0, 0, activity.dp(4));
        cardLayout.addView(soloStageQuestions, qParams);

        // 5. Stars Row
        LinearLayout starsRow = new LinearLayout(activity);
        starsRow.setOrientation(LinearLayout.HORIZONTAL);
        starsRow.setGravity(Gravity.CENTER);
        starsRow.setLayoutDirection(View.LAYOUT_DIRECTION_RTL);
        LinearLayout.LayoutParams starsParams = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        starsParams.setMargins(0, 0, 0, activity.dp(4));
        cardLayout.addView(starsRow, starsParams);

        for (int i = 0; i < 3; i++) {
            TextView star = new TextView(activity);
            star.setText("★");
            star.setTextSize(TypedValue.COMPLEX_UNIT_SP, 18f);
            star.setTextColor(Color.argb(120, 255, 255, 255));
            star.setGravity(Gravity.CENTER);
            star.setIncludeFontPadding(false);
            if (balooFont != null) star.setTypeface(balooFont, Typeface.BOLD);
            LinearLayout.LayoutParams starItemParams = new LinearLayout.LayoutParams(
                    activity.dp(22), activity.dp(22));
            starItemParams.setMargins(activity.dp(2), 0, activity.dp(2), 0);
            starsRow.addView(star, starItemParams);
            soloStageStars[i] = star;
        }

        // 6. Progress Track and Fill
        soloStageProgressTrack = new FrameLayout(activity);
        GradientDrawable trackBg = new GradientDrawable();
        trackBg.setColor(Color.argb(80, 255, 255, 255));
        trackBg.setCornerRadius(activity.dp(4));
        soloStageProgressTrack.setBackground(trackBg);
        LinearLayout.LayoutParams trackParams = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, activity.dp(5));
        trackParams.setMargins(activity.dp(6), 0, activity.dp(6), 0);
        cardLayout.addView(soloStageProgressTrack, trackParams);

        soloStageProgressFill = new View(activity);
        GradientDrawable fillBg = new GradientDrawable(GradientDrawable.Orientation.LEFT_RIGHT,
                new int[]{Color.rgb(255, 244, 170), Color.rgb(255, 193, 7)});
        fillBg.setCornerRadius(activity.dp(4));
        soloStageProgressFill.setBackground(fillBg);
        soloStageProgressTrack.addView(soloStageProgressFill, new FrameLayout.LayoutParams(0, activity.dp(5)));

        // 7. Stage Timer: Place below the stars and progress bar
        attachCampaignTimerToCard(cardLayout);

        refreshSoloStageCard();
    }

    void attachCampaignTimerToSoloCard() {
        if (soloStageCardLayout != null) {
            attachCampaignTimerToCard(soloStageCardLayout);
        }
    }

    void attachCampaignTimerToCard(LinearLayout cardLayout) {
        if (!activity.campaignMode || activity.campaignTimeLimitSeconds <= 0 || cardLayout == null) {
            return;
        }
        if (activity.txtCampaignTimer == null) {
            activity.createCampaignTimerViewIfNeeded();
        }
        if (activity.txtCampaignTimer != null) {
            if (activity.txtCampaignTimer.getParent() instanceof ViewGroup) {
                ((ViewGroup) activity.txtCampaignTimer.getParent()).removeView(activity.txtCampaignTimer);
            }
            LinearLayout.LayoutParams timerParams = new LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT);
            timerParams.setMargins(0, activity.dp(8), 0, 0);
            timerParams.gravity = Gravity.CENTER_HORIZONTAL;
            activity.txtCampaignTimer.setTextSize(TypedValue.COMPLEX_UNIT_SP, 12.5f);
            activity.txtCampaignTimer.setPadding(activity.dp(10), activity.dp(4), activity.dp(10), activity.dp(4));
            activity.txtCampaignTimer.setGravity(Gravity.CENTER);
            activity.txtCampaignTimer.setIncludeFontPadding(false);
            if (balooFont != null) {
                activity.txtCampaignTimer.setTypeface(balooFont, Typeface.BOLD);
            } else {
                activity.txtCampaignTimer.setTypeface(Typeface.DEFAULT_BOLD);
            }
            cardLayout.addView(activity.txtCampaignTimer, timerParams);
        }
    }

    private void refreshSoloStageCard() {
        if (soloStageScore == null || soloStageTarget == null) {
            return;
        }
        int target = activity.boardTargetScore > 0 ? activity.boardTargetScore : 500;
        int currentScore = scores != null && scores.length > 0 ? scores[0] : 0;
        int totalPicks = activity.boardTotalTurns > 0 ? activity.boardTotalTurns : (activity.boardSoloPicks > 0 ? activity.boardSoloPicks : 6);
        int currentPick = Math.min(totalPicks, activity.boardTurnIndex + 1);
        if (currentPick < 1) currentPick = 1;

        String stageTitle = activity.campaignStageId != null && !activity.campaignStageId.isEmpty()
                ? "المرحلة " + extractStageNumber(activity.campaignStageId)
                : "المرحلة 1";

        if (soloStageTitle != null) soloStageTitle.setText(stageTitle);
        soloStageTarget.setText("🎯 الهدف: " + target);
        soloStageScore.setText("⭐ مجموعك: " + currentScore);
        if (soloStageQuestions != null) {
            soloStageQuestions.setText("📝 الأسئلة: " + currentPick + " / " + totalPicks);
        }

        int earnedStars = activity.getCampaignBoardEarnedStars(currentScore);

        for (int i = 0; i < 3; i++) {
            if (soloStageStars[i] != null) {
                boolean earned = i < earnedStars;
                soloStageStars[i].setTextColor(earned ? Color.rgb(255, 216, 74) : Color.argb(110, 255, 255, 255));
                soloStageStars[i].setShadowLayer(
                        earned ? activity.dp(5) : activity.dp(2),
                        0,
                        earned ? 0 : activity.dp(1),
                        earned ? Color.argb(220, 255, 200, 50) : Color.argb(120, 0, 0, 0)
                );
                if (earned && i >= lastEarnedStars) {
                    animateStar(soloStageStars[i]);
                }
            }
        }
        lastEarnedStars = earnedStars;

        if (soloStageProgressTrack != null && soloStageProgressFill != null) {
            final int scoreForProgress = currentScore;
            final int maxGoal = Math.max(1, activity.boardThreeStarScore);
            soloStageProgressTrack.post(new Runnable() {
                @Override
                public void run() {
                    int trackWidth = soloStageProgressTrack.getWidth();
                    if (trackWidth <= 0) return;
                    float ratio = Math.max(0f, Math.min(1f, (float) scoreForProgress / (float) maxGoal));
                    ViewGroup.LayoutParams params = soloStageProgressFill.getLayoutParams();
                    params.width = Math.round(trackWidth * ratio);
                    soloStageProgressFill.setLayoutParams(params);
                }
            });
        }
    }

    private String extractStageNumber(String stageId) {
        if (stageId == null) return "1";
        String digits = stageId.replaceAll("[^0-9]", "");
        if (digits.isEmpty()) return "1";
        try {
            return String.valueOf(Integer.parseInt(digits));
        } catch (Exception e) {
            return digits;
        }
    }

    private void animateStar(final TextView star) {
        if (star == null) return;
        star.setScaleX(0.6f);
        star.setScaleY(0.6f);
        star.animate().scaleX(1.3f).scaleY(1.3f).setDuration(160).withEndAction(new Runnable() {
            @Override
            public void run() {
                star.animate().scaleX(1f).scaleY(1f).setDuration(160).start();
            }
        }).start();
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

    void refreshScoreBoard() {
        if (isSoloCampaignBoard()) {
            refreshSoloStageCard();
            return;
        }
        if (boardNameViews == null || boardScoreViews == null || boardAvatarViews == null
                || names == null || scores == null) {
            return;
        }
        // التحدي الرئيسي: two fixed rows (team A gold, team B blue) showing the team
        // name + live point total, no avatar.
        if (localTeamsBoard) {
            int rows = Math.min(getVisibleBoardRowCount(), boardNameViews.length);
            for (int rowIndex = 0; rowIndex < rows && rowIndex < count; rowIndex++) {
                int color = rowIndex == 1 ? 0xFF7DD3FC : 0xFFFFD761;
                if (boardNameViews[rowIndex] != null) {
                    boardNameViews[rowIndex].setText(names[rowIndex]);
                    boardNameViews[rowIndex].setTextColor(color);
                }
                if (boardScoreViews[rowIndex] != null) {
                    boardScoreViews[rowIndex].setText(String.valueOf(scores[rowIndex]));
                    boardScoreViews[rowIndex].setTextColor(color);
                }
                if (boardAvatarViews[rowIndex] != null) {
                    boardAvatarViews[rowIndex].setVisibility(View.INVISIBLE);
                }
                setLocalTeamQuestionIndicator(rowIndex, rowIndex == localTeamsActiveQuestionSlot, color);
            }
            return;
        }
        // Team match: the results list shows the two team totals (with team colours)
        // so it clearly reads as a team challenge instead of individual ranks.
        if (teamMode && slotTeam != null) {
            int teamA = 0, teamB = 0;
            for (int g = 0; g < count; g++) {
                if ("B".equals(slotTeam[g])) teamB += scores[g]; else teamA += scores[g];
            }
            setTeamScoreRow(0, "الفريق أ", teamA, teamColor("A"));
            setTeamScoreRow(1, "الفريق ب", teamB, teamColor("B"));
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
                // Rows are already ordered best-first, so the rank is the row position.
                boardScoreViews[rowIndex].setText(ordinal(rowIndex + 1));
            }
            if (boardAvatarViews[rowIndex] != null) {
                int figure = slotCharacter != null ? slotCharacter[playerIndex]
                        : (selectedCharacterIndex + playerIndex) % CHARACTER_COUNT;
                boardAvatarViews[rowIndex].setImageResource(EMOTE_DRAWABLES[figure]);
            }
        }
    }

    private void setTeamScoreRow(int rowIndex, String label, int total, int color) {
        if (rowIndex < 0 || boardNameViews == null || rowIndex >= boardNameViews.length) return;
        if (boardNameViews[rowIndex] != null) {
            boardNameViews[rowIndex].setText(label);
            boardNameViews[rowIndex].setTextColor(color);
        }
        if (boardScoreViews != null && rowIndex < boardScoreViews.length
                && boardScoreViews[rowIndex] != null) {
            boardScoreViews[rowIndex].setText(String.valueOf(total));
            boardScoreViews[rowIndex].setTextColor(color);
        }
        if (boardAvatarViews != null && rowIndex < boardAvatarViews.length
                && boardAvatarViews[rowIndex] != null) {
            boardAvatarViews[rowIndex].setVisibility(View.INVISIBLE);
        }
    }

    private void setLocalTeamQuestionIndicator(int rowIndex, boolean active, int color) {
        if (boardRowFrames != null && rowIndex >= 0 && rowIndex < boardRowFrames.length
                && boardRowFrames[rowIndex] != null) {
            boardRowFrames[rowIndex].setBackground(active ? localTeamActiveRowBg(color) : null);
        }
        if (boardTurnIndicators != null && rowIndex >= 0 && rowIndex < boardTurnIndicators.length
                && boardTurnIndicators[rowIndex] != null) {
            View indicator = boardTurnIndicators[rowIndex];
            if (active) {
                indicator.setBackground(localTeamTurnIndicatorBg(color));
                indicator.setVisibility(View.VISIBLE);
                indicator.setAlpha(1f);
                indicator.setElevation(px(3f, activity.getResources().getDisplayMetrics().density));
            } else {
                indicator.setVisibility(View.INVISIBLE);
                indicator.setAlpha(0f);
                indicator.setElevation(0f);
            }
        }
    }

    private GradientDrawable localTeamActiveRowBg(int color) {
        float density = activity.getResources().getDisplayMetrics().density;
        GradientDrawable drawable = new GradientDrawable();
        drawable.setColor(withAlpha(color, 0x24));
        drawable.setCornerRadius(px(6f, density));
        drawable.setStroke(px(1.5f, density), withAlpha(color, 0xEE));
        return drawable;
    }

    private GradientDrawable localTeamTurnIndicatorBg(int color) {
        float density = activity.getResources().getDisplayMetrics().density;
        GradientDrawable drawable = new GradientDrawable();
        drawable.setShape(GradientDrawable.OVAL);
        drawable.setColor(withAlpha(color, 0xF2));
        drawable.setStroke(px(1f, density), 0xFFFFFFFF);
        return drawable;
    }

    private int withAlpha(int color, int alpha) {
        return (color & 0x00FFFFFF) | ((alpha & 0xFF) << 24);
    }

    /** English ordinal for a rank: 1->"1st", 2->"2nd", 3->"3rd", 4->"4th", 11->"11th"... */
    private static String ordinal(int n) {
        int mod100 = n % 100;
        String suffix;
        if (mod100 >= 11 && mod100 <= 13) {
            suffix = "th";
        } else {
            switch (n % 10) {
                case 1: suffix = "st"; break;
                case 2: suffix = "nd"; break;
                case 3: suffix = "rd"; break;
                default: suffix = "th"; break;
            }
        }
        return n + suffix;
    }

    private int getVisibleBoardRowCount() {
        // Team match: exactly two rows — one per team total.
        if (teamMode) return Math.min(SCORE_BOARD_ROWS, 2);
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
