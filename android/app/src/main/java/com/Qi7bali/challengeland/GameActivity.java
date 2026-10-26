package com.qi7bali.landchallengeonline;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.appcompat.app.AlertDialog;
import android.content.Intent;
import android.graphics.Color;
import android.graphics.drawable.GradientDrawable;
import android.media.MediaPlayer;
import android.animation.Animator;
import android.animation.AnimatorListenerAdapter;
import android.animation.ObjectAnimator;
import android.animation.ValueAnimator;
import android.view.animation.AccelerateDecelerateInterpolator;
import android.view.animation.AccelerateInterpolator;
import android.view.animation.DecelerateInterpolator;
import android.view.animation.OvershootInterpolator;
import android.os.Bundle;
import android.os.CountDownTimer;
import android.os.Handler;
import android.os.SystemClock;
import android.text.TextPaint;
import android.text.TextUtils;
import android.util.DisplayMetrics;
import android.util.Log;
import android.util.TypedValue;
import android.view.View;
import android.view.ViewGroup;
import android.view.Window;
import android.view.WindowManager;
import android.view.MotionEvent;
import android.view.ViewTreeObserver;
import android.graphics.Rect;
import android.content.Context;
import android.text.InputType;
import android.view.inputmethod.EditorInfo;
import android.view.inputmethod.InputMethodManager;
import android.widget.Button;
import android.widget.EditText;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.FrameLayout;
import android.widget.RelativeLayout;
import android.widget.TextView;
import android.widget.Toast;
import android.widget.ScrollView;
import android.app.Dialog;
import android.graphics.drawable.ColorDrawable;
import com.google.firebase.database.DataSnapshot;
import com.google.firebase.database.DatabaseError;
import com.google.firebase.database.DatabaseReference;
import com.google.firebase.database.ValueEventListener;

import com.squareup.picasso.Picasso;

import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Random;
import java.util.Set;

import android.graphics.Typeface;
import android.view.Gravity;
import android.widget.ScrollView;
import androidx.core.content.res.ResourcesCompat;

import de.hdodenhof.circleimageview.CircleImageView;
import io.netopen.hotbitmapgg.library.view.RingProgressBar;
import com.google.firebase.database.FirebaseDatabase;
import com.google.firebase.database.MutableData;
import com.google.firebase.database.Query;
import com.google.firebase.database.Transaction;

import org.json.JSONArray;
import org.json.JSONObject;

import java.util.Locale;

import static com.qi7bali.landchallengeonline.GameRules.ANSWER_KEY_RIGHT;
import static com.qi7bali.landchallengeonline.GameRules.ANSWER_KEY_WRONG_1;
import static com.qi7bali.landchallengeonline.GameRules.ANSWER_KEY_WRONG_2;
import static com.qi7bali.landchallengeonline.GameRules.ANSWER_KEY_WRONG_3;
import static com.qi7bali.landchallengeonline.GameRules.FIRST_QUESTION_SYNC_BUFFER_MS;
import static com.qi7bali.landchallengeonline.GameRules.MAX_TIMEOUT_STREAK;
import static com.qi7bali.landchallengeonline.GameRules.NEXT_QUESTION_SYNC_BUFFER_MS;
import static com.qi7bali.landchallengeonline.GameRules.ONLINE_SPEED_POINTS;
import static com.qi7bali.landchallengeonline.GameRules.QUESTION_TIMEOUT_MS;

public class GameActivity extends GameViewportActivity implements ProgressionMatchHost, GameBackgroundGuard.Host {
    private final GameBackgroundGuard backgroundGuard = new GameBackgroundGuard(this, this);
    private boolean backgroundPenaltyRequestPending;
    private long backgroundPenaltyRetryAt;
    private boolean backgroundParticipationEnded;

    private String currentBackgroundQuestionKey() {
        if (paidDuel != null) return "paid:" + PaidDuelController.number(paidDuelState.get("currentTurn"), -1);
        if (boardOnline && !boardRoomMatch) return "duel:" + boardOnlineTurn;
        return progressionAnswerId();
    }

    @Override public String backgroundQuestionKey() {
        if (EXITING || isFinishing() || campaignResultPersisted || boardDuelFinished
                || backgroundParticipationEnded || (!isQuestionTimerRunning && !wasTimerRunningBeforePause)) return "";
        if (boardMode) {
            if (!boardPickerIsHuman || boardCurrentQuestion == null) return "";
            if (paidDuel != null) {
                long turn = PaidDuelController.number(paidDuelState.get("currentTurn"), -1);
                Map<String, Object> state = PaidDuelController.map(PaidDuelController.map(paidDuelState.get("turns")).get("t" + turn));
                if (!"answering".equals(paidDuelState.get("phase")) || !myID.equals(state.get("playerId"))
                        || Boolean.TRUE.equals(state.get("done"))) return "";
            }
        } else if (currentQuestion < 0 || myAnswerSubmitted || localPlayerEliminated || spectatorEliminationRound) return "";
        return currentBackgroundQuestionKey();
    }

    @Override public boolean applyBackgroundPenalty(String question, int violations) {
        if (duelActivityDestroyed) return false;
        if (EXITING || isFinishing() || campaignResultPersisted || boardDuelFinished) {
            backgroundGuard.acknowledge();
            return false;
        }
        if (ACTIVITY_PAUSED && !boardOnline) return false;
        if (ACTIVITY_PAUSED && boardRoomMatch) return false;
        boolean disqualified = violations >= BackgroundAnswerPolicy.MAX_VIOLATIONS;
        if (!safeIntentString("stakeMatchId", "").isEmpty()) {
            if (paidDuel == null || paidDuelState.isEmpty()) return false;
            if ("settled".equals(paidDuelState.get("status"))) {
                backgroundGuard.acknowledge();
                return false;
            }
            int turn = (int) PaidDuelController.number(paidDuelState.get("currentTurn"), -1);
            if (!disqualified && !question.equals("paid:" + turn)) {
                backgroundGuard.acknowledge(); // The server already closed this question.
                return false;
            }
            CAN_PLAY = false;
            boardAwaitingTypedInput = false;
            stopTimer(false);
            if (!ACTIVITY_PAUSED) {
                hideKeyboard();
                showBoardWaitingOverlay(disqualified ? "انتهت مشاركتك بعد 3 مخالفات. جارٍ تثبيت النتيجة…"
                        : "جارٍ مزامنة المباراة…");
                paidDuel.resume();
            }
            if (!paidDuel.isPending()) {
                long delay = backgroundPenaltyRetryAt - SystemClock.elapsedRealtime();
                if (delay > 0L) {
                    duelConnectionHandler.postDelayed(() -> backgroundGuard.enforce(), delay);
                } else {
                    backgroundPenaltyRetryAt = SystemClock.elapsedRealtime() + 1500L;
                    paidDuel.call(disqualified ? "forfeit" : "skipAnswer",
                            disqualified ? Collections.emptyMap() : paidDuelTurnArgs());
                }
            }
            return true;
        }
        if (boardOnline && !boardRoomMatch) {
            if (gameID == null || gameID.isEmpty()) return false;
            if (backgroundPenaltyRequestPending) return true;
            if (!disqualified && !question.startsWith("duel:")) return false;
            final int turn = disqualified ? -1 : Integer.parseInt(question.substring(5));
            CAN_PLAY = false;
            boardAwaitingTypedInput = false;
            stopTimer(false);
            cancelPendingBoardReveal();
            if (!ACTIVITY_PAUSED) {
                hideKeyboard();
                showBoardWaitingOverlay(disqualified ? "انتهت مشاركتك بعد 3 مخالفات. جارٍ تثبيت النتيجة…"
                        : "جارٍ مزامنة المباراة…");
            }
            backgroundPenaltyRequestPending = true;
            boardRef().runTransaction(new Transaction.Handler() {
                @Override public Transaction.Result doTransaction(MutableData data) {
                    if (!NativeProgression.activeAccount(GameActivity.this)) return Transaction.abort();
                    Map<String, Object> state = OnlineDuelState.map(data.getValue());
                    if (state.isEmpty() || "finished".equals(state.get("phase"))) return Transaction.abort();
                    if (disqualified) {
                        String owner = String.valueOf(state.get("ownerId"));
                        String joiner = String.valueOf(state.get("joinerId"));
                        if (!myID.equals(owner) && !myID.equals(joiner)) return Transaction.abort();
                        OnlineDuelState.forfeit(state, myID.equals(owner) ? joiner : owner);
                    } else if (!OnlineDuelState.complete(state, myID, turn, false, 0)) return Transaction.abort();
                    data.setValue(state);
                    return Transaction.success(data);
                }
                @Override public void onComplete(DatabaseError error, boolean committed, DataSnapshot snapshot) {
                    backgroundPenaltyRequestPending = false;
                    if (duelActivityDestroyed || EXITING) return;
                    if (error != null || snapshot == null || !snapshot.exists()) {
                        duelConnectionHandler.postDelayed(() -> backgroundGuard.enforce(), 1500L);
                        return;
                    }
                    boolean terminal = "finished".equals(snapshot.child("phase").getValue(String.class));
                    boolean closed = committed || terminal || (!disqualified
                            && (OnlineDuelState.number(snapshot.child("currentTurn").getValue(), -1) > turn
                            || Boolean.TRUE.equals(snapshot.child("turns").child("t" + turn).child("done").getValue(Boolean.class))));
                    if (!closed) {
                        duelConnectionHandler.postDelayed(() -> backgroundGuard.enforce(), 1500L);
                        return;
                    }
                    backgroundGuard.acknowledge();
                    duelNeedsBoardResync = true;
                    if (ACTIVITY_PAUSED) return;
                    markMyGameState("active");
                    if ("forfeit".equals(snapshot.child("finishReason").getValue(String.class)))
                        showDuelForfeitResult(snapshot);
                    else {
                        applyDuelScores(snapshot);
                        beginOnlineBoardTurn(OnlineDuelState.number(snapshot.child("currentTurn").getValue(), turn + 1));
                    }
                }
            }, false);
            return true;
        }
        if (disqualified) {
            if (!settleRandomStake(false, false, () -> backgroundGuard.enforce())) return true;
            CAN_PLAY = false;
            boardAwaitingTypedInput = false;
            stopTimer(false);
            cancelBoardSelectTimer();
            cancelPendingBoardReveal();
            hideKeyboard();
            leaveOnlineMatchIfNeeded();
            OnlineMatchRecovery.complete(this, "انتهت مشاركتك بسبب مغادرة اللعبة ثلاث مرات أثناء الإجابة.", false);
            if (campaignMode) {
                campaignFailureReason = "background_limit";
                persistPendingCampaignStageResult(false, 0, campaignWrongAnswers);
            } else PlayerStats.recordGameEnd(this, ProgressionRules.ABANDON, 0);
            if (boardLocalTeams) LocalTeamsGameStore.delete(this, localTeamsSaveId);
            if (shouldSaveOfflineBoard() && !isRecoverableBotBoard()) OfflineBoardGameStore.delete(this, offlineBoardSaveId);
            EXITING = true;
            backgroundParticipationEnded = true;
            backgroundGuard.acknowledge();
            GameNoticeDialogs.builder(this).setTitle("انتهت مشاركتك")
                    .setMessage("انتهت مشاركتك لتكرار مغادرة اللعبة أكثر من 10 ثوانٍ أثناء الإجابة ثلاث مرات.")
                    .setCancelable(false).setPositiveButton("العودة", (dialog, which) -> {
                        if (campaignMode) finishCampaignAndReturnToFlutter();
                        else finish();
                    }).show();
            return true;
        }
        if ((boardMode && boardCurrentQuestion == null) || (!boardMode && currentQuestion < 0)) return false;
        backgroundGuard.acknowledge();
        if (!question.equals(currentBackgroundQuestionKey()) || (!boardMode && myAnswerSubmitted)) return false;
        CAN_PLAY = false;
        boardAwaitingTypedInput = false;
        myAnswer = 0;
        hideKeyboard();
        handleQuestionTimeout();
        return true;
    }
    private Set<String> questionExclusions = new HashSet<>();
    private boolean questionSelectionPending;
    private Runnable retryQuestionSelection;
    private boolean roomQuestionHistoryAdmitted;
    private boolean roomQuestionHistoryAdmissionPending;

    private void questionSelectionFailed(Exception error) {
        questionSelectionPending = false;
        if (EXITING || isFinishing()) return;
        String message = error.getMessage() == null ? "تعذر اختيار أسئلة جديدة. حاول مجددًا." : error.getMessage();
        GameNotice.makeText(this, message, Toast.LENGTH_LONG).show();
        if (retryQuestionSelection != null) GameNoticeDialogs.builder(this).setMessage(message)
                .setPositiveButton("إعادة المحاولة", (dialog, which) -> retryQuestionSelection.run())
                .setNegativeButton("رجوع", (dialog, which) -> finish()).show();
    }

    private void prepareQuestionSelection(Runnable ready) {
        if (questionSelectionPending || EXITING || isFinishing()) return;
        questionSelectionPending = true;
        QuestionHistory.prepare(this, boardOnline && !boardRoomMatch ? gameID : "",
                boardRoomMatch ? roomId : "", excluded -> {
                    questionSelectionPending = false;
                    if (EXITING || isFinishing()) return;
                    questionExclusions = excluded;
                    ready.run();
                }, this::questionSelectionFailed);
    }

    private void reserveBoardQuestions(Runnable ready) {
        ArrayList<Question> selected = new ArrayList<>();
        if (boardCellQuestion != null) for (Question[] column : boardCellQuestion) {
            for (Question q : column) {
                if (q == null) { boardCellQuestion = null; questionSelectionFailed(new IllegalStateException(QuestionHistory.EXHAUSTED)); return; }
                selected.add(q);
            }
        }
        questionSelectionPending = true;
        QuestionHistory.reserve(this, boardOnline && !boardRoomMatch ? gameID : "", boardRoomMatch ? roomId : "",
                selected, () -> {
                    questionSelectionPending = false;
                    if (!EXITING && !isFinishing()) ready.run();
                }, error -> {
                    boardCellQuestion = null;
                    questionSelectionFailed(error);
                    if (!boardOnline && !EXITING && !isFinishing()) showCategorySelect();
                });
    }
    @Override public String progressionMatchId() {
        if (boardOnline && !boardRoomMatch && gameID != null && !gameID.isEmpty()) return "duel:" + gameID;
        if (campaignMode) return "campaign:" + campaignId + ":" + campaignAttemptId;
        if (boardLocalTeams && !localTeamsSaveId.isEmpty()) return "local:" + localTeamsSaveId;
        if (!offlineBoardSaveId.isEmpty()) return "offline:" + offlineBoardSaveId;
        if (roomId != null && !roomId.isEmpty()) return "room:" + roomId + ":"
                + progressionMode() + ":" + Math.max(1, getIntent().getIntExtra("roomRoundNumber", 1));
        return NativeProgression.fallbackId(this);
    }
    @Override public String progressionMode() {
        if (campaignMode) return "campaign";
        if (boardLocalTeams) return "local_teams";
        if (boardRoomMatch) return boardTeamMatch ? "team_battle" : "battle";
        if (boardMode) return "board";
        if (modeOnline) return eliminationMode ? "elimination" : "battle";
        return "offline";
    }
    @Override public String progressionAnswerId() {
        if (boardMode) return "cell:" + boardPickedCol + ":" + boardPickedRow + ":" + boardPickerSlot;
        return "question:" + currentQuestion;
    }
    @Override public boolean progressionOnline() { return modeOnline && !campaignMode; }
    @Override public boolean progressionHumanOpponents() {
        if (boardRoomMatch && boardSeatIsBot != null) {
            for (int i = 0; i < boardSeatIsBot.length; i++) {
                if (i != mySeat && !boardSeatIsBot[i]
                        && (!boardTeamMatch || !myTeam.equals(boardSeatTeam[i]))) return true;
            }
        }
        for (MatchOpponent opponent : opponents) if (!opponent.bot) return true;
        return false;
    }
    private static final int DIALOG_EXTRA_VISIBLE_MS = 1000;
    private final Handler presenterHandler = new Handler();
    private final PresenterDialogue presenterDialogue = new PresenterDialogue(
            android.os.SystemClock::uptimeMillis, presenterHandler::postDelayed);

    private static final int CAMPAIGN_FEEDBACK_TALK_MS = 900;
    private static final int CAMPAIGN_FEEDBACK_MIN_READ_MS = 2200;
    private static final int CAMPAIGN_FEEDBACK_TRANSITION_GAP_MS = 450;

    ArrayList<Question> questions = new ArrayList<>();
    ArrayList<TextView> listAnswerViews = new ArrayList<>();
    ArrayList<LinearLayout> steps = new ArrayList<>();
    ArrayList<Integer> currentAnswerOrder = new ArrayList<>();
    TextView txtQ, txtA1, txtA2, txtA3, txtA4, txtSelected, txtRight, txtAmount,
            txtProgress, txtQuestionCounter, txtPlayer1, txtPlayer2, txtScoreMe, txtSetsMe, txtScoreGameMe,
            txtScoreOpponent, txtSetsOpponent, txtScoreGameOpponent;
    ImageView imgA1, imgA2, imgA3, imgA4, imgVote1, imgVote2, imgVote3, imgVote4, btnCloseVote,
            imgCallerBody, imgCallerFace, imgCallerMouth,
            imgSelected, imgRight, imgHelp5050, imgHelpCall, imgHelpAudience, imgHome, imgVolume,
            imgAnswer1Player1, imgAnswer1Player2, imgAnswer2Player1, imgAnswer2Player2,
            imgAnswer3Player1, imgAnswer3Player2, imgAnswer4Player1, imgAnswer4Player2;
    RelativeLayout rlySelected, rlyRight, rlyDialog, rlyVotes, rlyCall, rlyProgress;
    LinearLayout rlyScore;
    LinearLayout llyQA, llySteps, llySolde, llyPlayer1, llyPlayer2;
    Typewriter txtDialog, txtCallAnswer;
    Button btnDialogYes, btnDialogNo, btnGetMoney;
    RingProgressBar pbTime;
    GameBackgroundVideoController backgroundVideoController;
    GameSoundController soundController;
    GameInterstitialAdController interstitialAdController;
    GameRewardedAdController rewardedAdController;
    GameLifelineController lifelineController;
    GameLayoutController layoutController;
    private PresenterBubbleController presenterBubble;
    GameOpponentHudController opponentHudController;
    GameOfflineContestantsController offlineContestants;
    GameCampaignHudController campaignHudController;
    GameCampaignResultStore campaignResultStore;
    CountDownTimer cdtProgress;
    private boolean isQuestionTimerRunning = false;
    private boolean wasTimerRunningBeforePause = false;
    private long timerPauseElapsedRealtime = 0L;
    private boolean wasCampaignStageTimerRunningBeforePause = false;
    private boolean wasBoardSelectTimerRunningBeforePause = false;
    private long boardSelectRemainingMs = 0L;
    private long boardSelectPauseElapsedRealtime = 0L;
    MediaPlayer mpBeep, mpBeep1;
    CircleImageView imgPlayer1, imgPlayer2, imgMe, imgOpponent;
    boolean FAST_LIGHTS,
            CAN_PLAY = false,
            CAN_CLICK = false,
            CAN_HOME = false,
            EXITING = false,
            ACTIVITY_PAUSED = false,
            SOUND_ON = true,
            MUSIC_ON = false,
            campaignMode = false,
            campaignResultPersisted = false,
            modeOnline = false,
            eliminationMode = false,
            meOwner;
    Person person;
    Data dataAnswer;
    String myID, opponentID, myName, opponentName, myPhoto, opponentPhoto,
            currentDialog, gameID;
    int myLevel = 1, opponentLevel = 1, myScore = 0, opponentScore = 0,
            currentQuestion, currentStep, PROGRESS_VALUE, T_LIGHTS = 0,
            setMe = 0, setOpponent = 0,
            setScoreMe = 0, setScoreOpponent = 0,
            gameScoreMe = 0, gameScoreOpponent = 0,
            rightAnswer, myAnswer, opponentAnswer, myResult;
    boolean usedHelp5050 = false, usedHelpAudience = false, usedHelpCall = false;
    String campaignId = "main_campaign";
    String campaignStageId = "";
    String campaignStageType = "classic";
    String campaignStageMode = "classic";
    String campaignWinCondition = "completeQuestions";
    int campaignQuestionCount = 15;
    int campaignTimeLimitSeconds = 0;
    boolean campaignAllow5050 = true;
    boolean campaignAllowAudience = true;
    boolean campaignAllowCall = true;
    int campaignLives = 0;
    int campaignLivesRemaining = 0;
    int campaignMaxWrongAnswers = 0;
    int campaignTargetScore = 0;
    String campaignOpponentName = "";
    int campaignOpponentAccuracy = 0;
    int campaignOpponentStartScore = 0;
    int campaignOpponentScore = 0;
    int campaignOpponentCorrectAnswers = 0;
    int campaignOpponentWrongAnswers = 0;
    int campaignSeriesRounds = 0;
    int campaignSeriesWinsRequired = 0;
    int campaignPlayerSeriesWins = 0;
    int campaignOpponentSeriesWins = 0;
    String campaignTeamAllyName = "";
    String campaignTeamEnemyName = "";
    int campaignAllyScore = 0;
    int campaignTeamScore = 0;
    int campaignEnemyTeamScore = 0;
    String campaignFailureReason = "";
    String campaignBossBotName = "";
    int campaignBossBotIntelligence = 0;
    long campaignStartedAtMs = 0L;
    final ArrayList<Integer> campaignQuestionIds = new ArrayList<>();
    final ArrayList<String> campaignAllowedLevels = new ArrayList<>();
    CountDownTimer campaignStageTimer;
    TextView txtCampaignTimer;
    LinearLayout campaignHudPanel;
    TextView txtCampaignHudQuestion;
    TextView txtCampaignHudCorrect;
    TextView txtCampaignHudBattle;
    TextView txtCampaignHudBadge;
    FrameLayout campaignHudProgressTrack;
    View campaignHudProgressFill;
    final ArrayList<TextView> campaignHudStars = new ArrayList<>();
    int campaignCorrectAnswers = 0;
    int campaignWrongAnswers = 0;
    int campaignAnsweredQuestions = 0;
    int campaignUsed5050 = 0;
    int campaignUsedAudience = 0;
    int campaignUsedCall = 0;
    int campaignLastCorrectQuestion = -1;
    int campaignLastWrongQuestion = -1;
    int campaignLastDisplayedStars = 0;

    // ---- Offline board ("التحدي") mode ----
    boolean boardMode = false;
    static final int[] BOARD_VALUES = {200, 400, 600};
    // Classic التحدي card: every category carries two questions per value — rows 0..2
    // are the pills left of the artwork card, rows 3..5 the ones right of it.
    static final int BOARD_ROWS = 6;
    // The question pool is bucketed into 3 difficulty tiers (200=easy/400=medium/600=hard).
    static final int BOARD_POOL_TIERS = 3;
    private LinkedHashMap<String, ArrayList<ArrayList<Question>>> boardPool;
    private LinkedHashMap<String, ArrayList<ArrayList<Question>>> campaignEligibleQuestionPool;
    private final ArrayList<String> boardAllCategories = new ArrayList<>();
    private final ArrayList<String> boardSelectedCategories = new ArrayList<>();
    private Question[][] boardCellQuestion;     // [col][row]
    private boolean[][] boardCellConsumed;      // [col][row]
    private int boardCols;                      // category count = number of players, so the
                                                // board holds exactly 6 cells per player
    private int boardCellsRemaining;
    int boardTurnIndex;                 // 0-based turn counter
    int boardTotalTurns;                // turns actually played: largest multiple of
                                                // the player count <= total cells, so everyone
                                                // answers the exact same number of questions
    private int boardPickerSlot;                // current picker (contestant slot)
    private boolean boardPickerIsHuman;
    private Question boardCurrentQuestion;
    private int boardPickedCol, boardPickedRow;
    private final Random boardRandom = new Random();
    private Typeface boardFont;
    private HashMap<String, String> categoryAssetIndex;   // normalized name -> asset path
    static final int BOARD_SELECT_SECONDS = 30;
    // How long to linger on the answer reveal (status icon + reaction clip) before the
    // board overlay covers it again for the next turn. Kept generous so the reaction
    // videos have time to play out.
    static final int BOARD_REVEAL_HOLD_MS = 5000;
    private CountDownTimer boardSelectTimer;
    private TextView boardSelectCountdownView;
    private boolean categorySelectMusicPlaying = false;

    // ---- Board typed-answer mode (human turn) ----
    // The human types the answer for full value; revealing the four options first
    // halves the reward. A wrong answer never deducts points (loses only the turn).
    private LinearLayout llyA1, llyA2;                 // the two answer-option rows
    private View boardTypedAnswerPanel;                // text box + submit/reveal buttons
    private BoardAnswerEditText boardAnswerInput;
    private Button btnBoardSubmitAnswer, btnBoardRevealOptions, btnBoardConcedeSteal;
    private View btnBoardHideKeyboard;
    private boolean isBoardKeyboardShowing = false;
    private ViewTreeObserver.OnGlobalLayoutListener boardKeyboardLayoutListener;
    private View boardRefereePanel;
    private Button btnBoardRefereeOverride;
    private boolean boardRefereeOverrideApplied = false;
    private Handler boardRevealHandler;
    private Runnable boardRevealRunnable;
    private boolean boardOptionsRevealed = false;      // options currently shown (multiple-choice)
    private boolean boardAwaitingTypedInput = false;   // panel is live and not yet acted upon
    // How many times the options have been revealed for the CURRENT cell. Each reveal
    // halves the award (full → ½ → ¼). Persists across a التحدي الرئيسي steal, so the
    // value carries over: 600 → reveal 300 → steal reveal 150. Reset per fresh pick.
    private int boardRevealCount = 0;

    // ---- Local two-team board ("التحدي الرئيسي", hot-seat on one phone) ----
    // Two teams take turns on the same device on a 6-category  board. Every turn
    // is a HUMAN typed turn (no bots): slot 0 = team A, slot 1 = team B, alternating by
    // boardTurnIndex. On a wrong answer the OTHER team gets a steal attempt at the same
    // question (boardStealActive) before the answer is revealed. Highest team total wins.
    boolean boardLocalTeams = false;
    private boolean boardStealActive = false;          // a steal attempt is in progress
    private String boardTeamAName = "الفريق الأول";
    private String boardTeamBName = "الفريق الثاني";
    private String localTeamsSaveId = "";
    private JSONObject pendingLocalTeamsRestore;
    private boolean localTeamsRestoreConsumed = false;
    private boolean localTeamsFinished = false;
    private String offlineBoardSaveId = "";
    private JSONObject pendingOfflineBoardRestore;
    private boolean recreatedGameSession;
    private boolean offlineBoardRestoreConsumed = false;
    private final ImageObservationController imageObservationController = new ImageObservationController();
    private boolean offlineBoardFinished = false;
    private int boardCharacterIndex = 0;

    // ---- Online board (two real players on one synced التحدي board) ----
    // Reaches this path via OpponentActivity matchmaking (matchMode "board"). Turn
    // order is deterministic (owner picks on even turns); each turn's cell + answer
    // result is exchanged under Games/{gameID}/board. A bot fallback (no human found)
    // plays the plain offline board instead — boardOnline stays false there.
    boolean boardOnline = false;
    private int roomResumeTurn = -1;
    private int roomResumeCol = -1;
    private int roomResumeRow = -1;
    private long restoredBotQuestionDeadline;
    // Paid friend duels share this exact board, host and typed-answer UI. Only the
    // transport and scoring authority differ from the legacy free duel.
    private PaidDuelController paidDuel;
    private Map<String, Object> paidDuelState = Collections.emptyMap();
    private Map<String, Object> paidDuelQuestion = Collections.emptyMap();
    private String paidDuelRenderKey = "";
    private boolean paidDuelCategoryShown;
    private boolean paidDuelShowingResult;
    private boolean paidDuelExiting;
    private int paidDuelQuestionTurn = -1;
    private int paidDuelLastResultTurn = -1;
    private String paidDuelTypedAnswer;
    private boolean paidDuelInputReady;
    private boolean boardOpponentLeft = false;
    private boolean boardStarted = false;
    private int boardOnlineTurn = 0;
    private boolean boardWatchEntered = false;          // opponent's pick has been shown this turn
    private boolean boardWatchQuestionShown = false;    // watcher question screen is up
    private boolean boardWatchResultApplied = false;    // opponent's result has been revealed
    private boolean boardOpponentResultReady = false;
    private boolean boardOpponentCorrect = false;
    private boolean boardOpponentHalf = false;
    private int boardOpponentPoints = 0;
    private boolean boardPickPending = false;
    private boolean boardAdvancePending = false;
    private boolean boardDuelFinished = false;
    private int boardResultCurrencyDelta;
    private Integer paidResultCoins;
    private final Handler duelConnectionHandler = new Handler();
    private Runnable duelDisconnectTick;
    private TextView duelDisconnectCountdown;
    private boolean duelLocallyConnected;
    private boolean duelServerClockReady;
    private boolean duelDisconnectTransactionPending;
    private boolean duelNeedsBoardResync;
    private boolean duelActivityDestroyed;
    private Map<String, Object> duelSessionSnapshot = new HashMap<>();
    private DatabaseReference duelTerminalRef;
    private ValueEventListener duelTerminalListener;
    private DatabaseReference duelConnectionRef;
    private ValueEventListener duelConnectionListener;
    private Map<String, Object> duelTurnLedger = new HashMap<>();
    private Runnable stopDuelSessionListener;
    private DatabaseReference boardPicksRef;
    private ValueEventListener boardPicksListener;
    private DatabaseReference boardReadyRef;
    private ValueEventListener boardReadyListener;
    private DatabaseReference boardTurnRef;
    private ValueEventListener boardTurnListener;
    // Which contestant slot we are currently watching (the picker of the watched turn).
    // 1 for the 1v1 online board; the picker seat for the team board.
    private int boardWatchSeat = 1;

    // ---- Online TEAM board (N players in two teams, launched from a room) ----
    // The group ("تحدي جماعي") room match plays the same التحدي board but with N
    // contestants split into team A / team B. A deterministic global seat order
    // (interleaved A,B,A,B…) is shared by every device, so turns rotate seat-by-seat
    // and naturally alternate teams. The host (meOwner) builds/pushes the NxBOARD_ROWS
    // board and drives every bot/abandoned seat; the rest watch via the turn listener.
    // Synced under Games/{roomId}/board (gameID == roomId). Each cell's value is added
    // to the picker's team total; the higher team total wins.
    // boardRoomMatch covers BOTH room board variants launched from the rooms lobby:
    //   • competition ("نظام التنافس"): 2-8 solo players, highest individual score wins.
    //   • team ("نظام الفرق"): N players in team A/B, highest team total wins (boardTeamMatch).
    boolean boardRoomMatch = false;
    boolean boardTeamMatch = false;
    String roomId = "";
    String myTeam = "";
    private int boardSeatCount = 0;
    private int mySeat = 0;
    private String[] boardSeatId;
    private String[] boardSeatName;
    private String[] boardSeatTeam;
    private boolean[] boardSeatIsBot;
    private boolean[] boardSeatLeft;
    private int boardMyCorrectCount = 0;
    // Celebration/sad result screen shown after a room board match ends.
    private final ArrayList<ChromaVideoView> resultVideoViews = new ArrayList<>();
    private final ArrayList<Animator> resultMotionAnimators = new ArrayList<>();
    private boolean boardResultProceeded = false;

    // ---- Campaign board ("تحدي المراحل" stage on the التحدي board) ----
    // Each Million-Journey stage now plays the التحدي board. Solo stages (order not a
    // multiple of 10): count == 1, the player takes boardSoloPicks turns and must reach
    // boardTargetScore. Boss stages (every 10th): count == 1 + boardBotCount competitive
    // board, win = finish strictly first (beat every boss). Categories are chosen per
    // boardCategoryPolicy. The result bridges into the existing campaign pipeline
    // (persistPendingCampaignStageResult -> Flutter stars/rewards/progress).
    // These are package-private so GameCampaignLaunchConfig can populate them.
    boolean campaignBoard = false;
    String campaignAttemptId = "";
    String campaignEntry = "stage";
    boolean boardCampaignMatch = false;
    String boardCampaignKind = "solo";          // "solo" | "boss"
    int boardTargetScore = 0;
    int boardSoloPicks = 6;
    int boardSoloCols = 4;
    int boardTwoStarScore = 0;
    int boardThreeStarScore = 0;
    int boardBotCount = 0;
    int boardBotIntelligence = 0;
    int boardRequiredCategoryCount = 0;
    String boardBossStyle = "balanced";
    boolean boardAllowRevealOptions = true;
    int boardDesignVersion = 0;
    private final Set<String> boardCorrectCategories = new HashSet<>();
    private long boardCampaignDeadlineMs = 0L;
    private TextView boardCampaignRuleView;
    String boardCategoryPolicy = "playerPick";  // playerPick | curated | random | worldThemed
    final ArrayList<String> boardWorldCategories = new ArrayList<>();

    private JSONObject pendingCampaignBoardRestore = null;
    private boolean campaignBoardRestoreConsumed = false;
    private int pendingCampaignResumeQuestion = -1;
    private String savedCampaignAmount = null;

    private boolean questionsReady = false;
    private boolean startPending = false;
    private boolean questionsLoadFailed = false;
    private DatabaseReference myStatusRef;
    private DatabaseReference serverOffsetRef;
    private DatabaseReference questionSyncRef;
    private DatabaseReference opponentStatusRef;
    private ValueEventListener opponentStatusListener;
    private ValueEventListener serverOffsetListener;
    private ValueEventListener questionSyncListener;
    private boolean opponentExitHandled = false;
    private boolean matchStateCommitted = false;
    private final Handler fictitiousAnswerHandler = new Handler();
    private final Handler questionSyncHandler = new Handler();
    private Runnable pendingFictitiousAnswerRunnable;
    private Runnable pendingQuestionStartRunnable;
    private DatabaseReference roundSyncRef;
    private ValueEventListener roundSyncListener;
    private ValueEventListener opponentRoundListener;
    private boolean myAnswerSubmitted = false;
    private boolean opponentAnswerSubmitted = false;
    private boolean resolvingRound = false;
    private boolean roundResolved = false;
    private boolean resolvingFinal = false;  // guard: only one Firebase read in-flight
    private int mySubmittedAnswerKey = 0;
    private int opponentSubmittedAnswerKey = 0;
    private int myRoundPoints = 0;
    private int opponentRoundPoints = 0;
    private int myTimeoutStreak = 0;
    private int myTotalCorrectAnswers = 0;
    private int mySetCorrectAnswers = 0;
    private long myAnswerElapsedMs = QUESTION_TIMEOUT_MS;
    private long myTotalAnswerTimeMs = 0L;
    private long mySetAnswerTimeMs = 0L;
    private long serverTimeOffsetMs = 0L;
    private long questionStartTimeMs = 0L;
    boolean localPlayerRemoved = false;
    boolean localPlayerEliminated = false;
    boolean spectatorEliminationRound = false;
    boolean campaignBossBattle = false;
    MatchOpponent campaignBossOpponent;
    private int pendingQuestionIndex = -1;
    private long scheduledQuestionStartAt = 0L;
    final ArrayList<MatchOpponent> opponents = new ArrayList<>();
    final ArrayList<LinearLayout> opponentAnswerContainers = new ArrayList<>();
    private final HashMap<String, Runnable> pendingBotAnswerRunnables = new HashMap<>();
    LinearLayout llyOpponents;
    LinearLayout llyOpponentScores;
    LinearLayout scoreHeaderRow;
    LinearLayout scoreMeRow;
    TextView txtMeName;
    TextView labScore;
    TextView labSets;
    TextView labScoreGame;
    int scoreboardPanelWidthDp = 270;
    int scoreboardHeaderHeightDp = 28;
    int scoreboardRowHeightDp = 48;
    int scoreboardAvatarColumnWidthDp = 44;
    int scoreboardAvatarSizeDp = 28;
    int scoreboardAvatarBorderDp = 2;
    int scoreboardHorizontalPaddingDp = 6;
    float scoreboardHeaderTextSp = 11f;
    float scoreboardNameTextSp = 8f;
    float scoreboardValueTextSp = 14f;

    private void setupMatchSplitDoorsEntranceTransition() {
        if (!getIntent().getBooleanExtra("openSplitDoorsTransition", false)) {
            return;
        }

        try {
            final ViewGroup decor = (ViewGroup) getWindow().getDecorView();
            final FrameLayout wipeOverlay = new FrameLayout(this);
            wipeOverlay.setLayoutParams(new ViewGroup.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
            wipeOverlay.setClickable(true);
            wipeOverlay.setFocusable(false);

            final ImageView splitLeft = new ImageView(this);
            splitLeft.setLayoutParams(new FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
            splitLeft.setScaleType(ImageView.ScaleType.FIT_XY);
            splitLeft.setImageResource(R.drawable.bg_split_left_purple);

            final ImageView splitRight = new ImageView(this);
            splitRight.setLayoutParams(new FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
            splitRight.setScaleType(ImageView.ScaleType.FIT_XY);
            splitRight.setImageResource(R.drawable.bg_split_right_orange);

            wipeOverlay.addView(splitLeft);
            wipeOverlay.addView(splitRight);
            decor.addView(wipeOverlay);

            final Runnable safetyCleanup = () -> {
                try {
                    decor.removeView(wipeOverlay);
                } catch (Exception ignored) {}
            };
            decor.postDelayed(safetyCleanup, 2500);

            decor.post(() -> {
                if (isFinishing() || isDestroyed()) {
                    decor.removeView(wipeOverlay);
                    return;
                }
                decor.postDelayed(() -> {
                    if (isFinishing() || isDestroyed()) {
                        decor.removeView(wipeOverlay);
                        return;
                    }
                    final int screenW = Math.max(1200, getResources().getDisplayMetrics().widthPixels) + 160;
                    splitLeft.animate()
                            .translationX(-screenW)
                            .setDuration(400)
                            .setInterpolator(new AccelerateInterpolator(2.0f))
                            .start();

                    splitRight.animate()
                            .translationX(screenW)
                            .setDuration(400)
                            .setInterpolator(new AccelerateInterpolator(2.0f))
                            .withEndAction(() -> {
                                decor.removeCallbacks(safetyCleanup);
                                decor.removeView(wipeOverlay);
                            })
                            .start();
                }, 80);
            });
        } catch (Exception ignored) {}
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        supportRequestWindowFeature(Window.FEATURE_NO_TITLE);
        super.onCreate(savedInstanceState);
        recreatedGameSession = savedInstanceState != null;
        NativeProgression.restore(this, savedInstanceState);
        if (OnlineMatchRecovery.isFinished(this)) {
            startActivity(new Intent(this, MainActivity.class)
                    .addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP | Intent.FLAG_ACTIVITY_SINGLE_TOP));
            finish();
            return;
        }
        if (getIntent().getIntExtra("stakeCoins", 0) > 0
                && safeIntentString("stakeMatchId", "").isEmpty()) {
            try {
                if (!NativeProgression.activeAccount(this)
                        || !RandomStakeLedger.activate(this, safeIntentString("randomStakeId", ""))) {
                    finish(); return;
                }
            } catch (RuntimeException failure) {
                GameNotice.makeText(this, "تعذر تثبيت حجز المباراة. حاول مجددًا.", Toast.LENGTH_LONG).show();
                finish(); return;
            }
        }
        getWindow().setFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN,
                WindowManager.LayoutParams.FLAG_FULLSCREEN);
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        getWindow().getDecorView().setSystemUiVisibility(View.SYSTEM_UI_FLAG_HIDE_NAVIGATION);
        setContentView(R.layout.activity_game);
        if (getSupportActionBar() != null) getSupportActionBar().hide();
        setupMatchSplitDoorsEntranceTransition();
        backgroundVideoController = new GameBackgroundVideoController(this, R.id.gameBackgroundVideo, R.raw.bkgame);
        backgroundVideoController.setup();
        soundController = new GameSoundController(this);
        interstitialAdController = new GameInterstitialAdController(this);
        rewardedAdController = new GameRewardedAdController(this);
        rewardedAdController.preload();
        lifelineController = new GameLifelineController(this);
        layoutController = new GameLayoutController(this);
        opponentHudController = new GameOpponentHudController(this);
        offlineContestants = new GameOfflineContestantsController(this);
        campaignHudController = new GameCampaignHudController(this);
        campaignResultStore = new GameCampaignResultStore(this);

        AppPrefs.ensureGuestUser(this);
        myID = AppPrefs.getUserId(this);
        myName = AppPrefs.getUserName(this);
        myPhoto = AppPrefs.getUserPhoto(this);
        myLevel = AppPrefs.getUserLevel(this);
        myScore = AppPrefs.getUserScore(this);
        SOUND_ON = AppPrefs.isSoundEnabled(this);
        MUSIC_ON = AppPrefs.isMusicEnabled(this);

        String modeExtra = getIntent().getStringExtra("mode");
        String matchModeExtra = getIntent().getStringExtra("matchMode");
        GameCampaignLaunchConfig.load(this, modeExtra, matchModeExtra);
        OnlineMatchRecovery.track(this);
        final boolean onlineBoardMatch = modeOnline && "board".equals(matchModeExtra);
        roomId = safeString(getIntent().getStringExtra("roomId"));
        myTeam = safeString(getIntent().getStringExtra("myTeam")).trim().toUpperCase();
        final boolean teamBoardMatch = modeOnline && "team_battle".equals(matchModeExtra)
                && !roomId.isEmpty();
        final boolean battleBoardMatch = modeOnline && "battle".equals(matchModeExtra)
                && !roomId.isEmpty();
        final boolean roomBoardMatch = teamBoardMatch || battleBoardMatch;


        findViewById(android.R.id.content).post(new Runnable() {
            @Override
            public void run() {
                initAdsIfNeeded();
            }
        });

        person = new Person((RelativeLayout) (findViewById(R.id.rlyPerson)));
        categorySelectMusicPlaying = true;
        playSound(R.raw.main_theme_320bit_chosic, false, true);

        if ((modeOnline && !onlineBoardMatch && !roomBoardMatch) || campaignBossBattle) {
            opponentHudController.initCompetitiveHudViews();
        }

        if (modeOnline) {
            parseOpponentsFromIntent();
            if (Data.isNetworkAvailable(GameActivity.this)
                    || (onlineBoardMatch && getPrimaryOpponent() != null && getPrimaryOpponent().bot)) {

                if (onlineBoardMatch) {
                    setupBoardMatch();
                } else if (roomBoardMatch) {
                    setupRoomBoardMatch(teamBoardMatch);
                } else {

                if (eliminationMode) {
                    labScore.setText("الصحيح");
                    labSets.setText("الحالة");
                    labScoreGame.setText("النقاط");
                    txtSetsMe.setText("نشط");
                }
                if (txtMeName != null) txtMeName.setText(myName);

                Data.setImageSource(this, imgMe, myPhoto);
                Data.setImageSource(this, imgAnswer1Player1, myPhoto);
                Data.setImageSource(this, imgAnswer2Player1, myPhoto);
                Data.setImageSource(this, imgAnswer3Player1, myPhoto);
                Data.setImageSource(this, imgAnswer4Player1, myPhoto);
                opponentHudController.configureScoreboardLayout();
                opponentHudController.buildOpponentPanels();
                syncPrimaryOpponentFields();

                if (meOwner) {
                    new Data().createGameID(myID, getOpponentIds(), new OnCreateGameIdListener() {
                        @Override
                        public void onSuccess(String gameID) {
                            GameActivity.this.gameID = gameID;
                            beginOnlineGameSession();
                            for (MatchOpponent opponent : opponents) {
                                if (!opponent.bot) {
                                    FirebaseDatabase.getInstance().getReference()
                                            .child("temp")
                                            .child(opponent.id)
                                            .child("gameID")
                                            .setValue(gameID);
                                }
                            }
                            getQuestions(gameID);
                        }

                        @Override
                        public void onFailed(DatabaseError error) {

                        }
                    });
                } else {
                    getGame();
                }
                }
            } else {
                GameNotice.makeText(GameActivity.this, "لا يوجد اتصال بالإنترنت", Toast.LENGTH_SHORT).show();
            }

        } else {
            if (campaignBossBattle) {
                setupCampaignBossBattle();
                getQuestions("");
            } else if (!campaignMode) {
                // Offline single-player is now the board ("التحدي") mode. The "التحدي
                // الرئيسي" launch sets localTeams=true → two teams (slot 0/1) on one
                // phone, hot-seat, on a 6-category board.
                boardLocalTeams = getIntent().getBooleanExtra("localTeams", false);
                if (boardLocalTeams) {
                    localTeamsSaveId = savedInstanceState != null
                            ? safeString(savedInstanceState.getString("localTeamsSaveId")).trim()
                            : safeString(getIntent().getStringExtra("localTeamsSaveId")).trim();
                    if (localTeamsSaveId.isEmpty()) {
                        localTeamsSaveId = LocalTeamsGameStore.newGameId();
                    }
                    getIntent().putExtra("localTeamsSaveId", localTeamsSaveId);
                    if (getIntent().getBooleanExtra("resumeLocalTeams", false) || savedInstanceState != null) {
                        pendingLocalTeamsRestore = LocalTeamsGameStore.get(this, localTeamsSaveId);
                        if (pendingLocalTeamsRestore != null) {
                            boardTeamAName = pendingLocalTeamsRestore.optString("teamAName", boardTeamAName);
                            boardTeamBName = pendingLocalTeamsRestore.optString("teamBName", boardTeamBName);
                        }
                    }
                } else {
                    offlineBoardSaveId = savedInstanceState != null
                            ? safeString(savedInstanceState.getString("offlineBoardSaveId")).trim()
                            : safeString(getIntent().getStringExtra("offlineBoardSaveId")).trim();
                    if (offlineBoardSaveId.isEmpty()) {
                        offlineBoardSaveId = OfflineBoardGameStore.newGameId();
                    }
                    getIntent().putExtra("offlineBoardSaveId", offlineBoardSaveId);
                    if (getIntent().getBooleanExtra("resumeOfflineBoard", false) || savedInstanceState != null) {
                        pendingOfflineBoardRestore = OfflineBoardGameStore.get(this, offlineBoardSaveId);
                    }
                }
                int playerCount = boardLocalTeams
                        ? 2
                        : Math.max(2, Math.min(8,
                                pendingOfflineBoardRestore != null
                                        ? pendingOfflineBoardRestore.optInt("playerCount", getIntent().getIntExtra("playerCount", 4))
                                        : getIntent().getIntExtra("playerCount", 4)));
                int effectiveChar = AppPrefs.getEffectiveCharacter(this);
                int intentChar = getIntent().getIntExtra("characterIndex", -1);
                int characterIndex;
                if (pendingOfflineBoardRestore != null && pendingOfflineBoardRestore.has("characterIndex")) {
                    int savedChar = pendingOfflineBoardRestore.optInt("characterIndex", -1);
                    characterIndex = CharacterUnlocks.isValid(savedChar) ? savedChar : effectiveChar;
                } else if (CharacterUnlocks.isValid(intentChar)) {
                    characterIndex = intentChar;
                } else {
                    characterIndex = effectiveChar;
                }
                boardCharacterIndex = characterIndex;
                boardMode = true;
                offlineContestants.setupForBoard(playerCount, characterIndex);
                if (boardLocalTeams) {
                    // No animated characters in التحدي الرئيسي — hide the figure podiums,
                    // but keep an avatar-less scoreboard showing each team's name + points.
                    offlineContestants.enableLocalTeamsScoreboard();
                    offlineContestants.setContestantName(0, boardTeamAName);
                    offlineContestants.setContestantName(1, boardTeamBName);
                }
                boardPool = LocalQuestions.loadBoardPool(this);
                buildBoardCategoryList();
                questionsReady = true;
            } else if (campaignBoard) {
                // تحدي المراحل stage played on the التحدي board (solo or boss).
                int effectiveChar = AppPrefs.getEffectiveCharacter(this);
                int intentChar = getIntent().getIntExtra("characterIndex", -1);
                int characterIndex = CharacterUnlocks.isValid(intentChar) ? intentChar : effectiveChar;
                setupCampaignBoardMatch(characterIndex);
                loadCampaignProgressIfNeeded(savedInstanceState);
            } else if (campaignMode) {
                loadCampaignProgressIfNeeded(savedInstanceState);
                if (pendingCampaignResumeQuestion < 0) {
                    getQuestions("");
                }
            } else {
                getQuestions("");
            }
        }

        mpBeep = MediaPlayer.create(this, R.raw.beep);
        mpBeep1 = MediaPlayer.create(this, R.raw.beep1);

        rlyProgress = findViewById(R.id.rlyProgressbar);
        pbTime = findViewById(R.id.pbTime);
        txtProgress = findViewById(R.id.txtProgress);
        txtQuestionCounter = findViewById(R.id.txtQuestionCounter);
        updateQuestionCounter();
        pbTime.setMax(300);
        // The board ("التحدي") screen has no "1/10" counter — hide it before the
        // intro/category-select so it never flashes at the top.
        if (boardMode) {
            setGone(R.id.questionCounterPanel);
        }

        rlyDialog = findViewById(R.id.rlyDialog);
        txtDialog = findViewById(R.id.txtDialog);

        rlyVotes = findViewById(R.id.rlyVotes);
        btnCloseVote = findViewById(R.id.btnCloseVote);
        rlyCall = findViewById(R.id.rlyCall);

        llyQA = findViewById(R.id.llyQA);
        llyA1 = findViewById(R.id.llyA1);
        llyA2 = findViewById(R.id.llyA2);
        llySteps = findViewById(R.id.llySteps);

        imgHelp5050 = findViewById(R.id.imgHelp5050);
        imgHelpCall = findViewById(R.id.imgHelpCall);
        imgHelpAudience = findViewById(R.id.imgHelpAudience);
        txtCallAnswer = findViewById(R.id.txtCallAnswer);
        updateInventoryBadges();
        applyCampaignLifelineRestrictions();
        createCampaignTimerViewIfNeeded();

        imgHome = findViewById(R.id.imgHome);
        imgVolume = findViewById(R.id.imgVolume);

        imgCallerBody = findViewById(R.id.imgCallerBody);
        imgCallerFace = findViewById(R.id.imgCallerFace);
        imgCallerMouth = findViewById(R.id.imgCallerMouth);

        btnDialogYes = findViewById(R.id.btnDialogYes);
        btnDialogNo = findViewById(R.id.btnDialogNo);

        txtQ = findViewById(R.id.txtQ);
        txtA1 = findViewById(R.id.txtA1);
        txtA2 = findViewById(R.id.txtA2);
        txtA3 = findViewById(R.id.txtA3);
        txtA4 = findViewById(R.id.txtA4);
        layoutController.configureAnswerTextSizing();
        layoutController.configureGameSurfaceLayout();
        presenterBubble = new PresenterBubbleController(this, rlyDialog);
        imgA1 = findViewById(R.id.imgA1);
        imgA2 = findViewById(R.id.imgA2);
        imgA3 = findViewById(R.id.imgA3);
        imgA4 = findViewById(R.id.imgA4);
        imgVote1 = findViewById(R.id.imgVote1);
        imgVote2 = findViewById(R.id.imgVote2);
        imgVote3 = findViewById(R.id.imgVote3);
        imgVote4 = findViewById(R.id.imgVote4);
        llySolde = findViewById(R.id.llySolde);
        txtAmount = findViewById(R.id.txtAmount);
        btnGetMoney = findViewById(R.id.btnGetMoney);
        campaignHudController.configureGameplayHud();

        FAST_LIGHTS = false;
        animLights();

        int idStep;
        for (int i = 1; i <= 15; i++) {
            idStep = getResources().getIdentifier("llyStep" + i, "id", this.getPackageName());
            steps.add((LinearLayout) findViewById(idStep));
        }

        listAnswerViews.add(txtA1);
        listAnswerViews.add(txtA2);
        listAnswerViews.add(txtA3);
        listAnswerViews.add(txtA4);

        currentQuestion = -1;
        currentStep = 0;

        goBlinking();

        final Handler handler = new Handler();
        Runnable runnable = new Runnable() {
            int t = 0;

            @Override
            public void run() {
                if (EXITING || isFinishing() || isDestroyed() || presenterDialogue.defer(this)) return;
                t++;
                switch (t) {
                    case 1:
                        person.moveShow2Hands(isCampaignResume() ? 1000 : 2000);
                        if (boardMode) {
                            String boardGreeting = boardOpeningGreeting();
                            showDialog(boardGreeting, "", 800, isCampaignResume() ? 1200 : 2200, R.drawable.mouth_01, false);
                        } else if (modeOnline) {
                            rlyScore.setVisibility(View.VISIBLE);
                            Animations.move(rlyScore, 500, -300, 0, 0, 0);
                            showDialog("مرحبا بكما في مباراة جديدة", "", 800, 2000, R.drawable.mouth_01, false);
                        } else if (campaignMode) {
                            campaignHudController.hideMoneyBox();
                            campaignHudController.showGameplayHud();
                            String msg = getCampaignOpeningMessage();
                            showDialog(msg, "", 800, isCampaignResume() ? 1200 : 2200, R.drawable.mouth_01, false);
                        } else {
                            showDialog("مرحبا بكم في أرض التحدي", "", 800, 2200, R.drawable.mouth_01, false);
                        }
                        handler.postDelayed(this, isCampaignResume() ? 1200 : 3000);
                        break;
                    case 2:
                        person.moveShowHand(1000);
                        if (boardMode) {
                            if (boardOnline) {
                                // The synced board runs its own setup (category pick →
                                // shared board built by the owner); just hide the
                                // millionaire chrome here.
                                applyBoardModeChrome();
                            } else if (boardCampaignMatch && !isCampaignResume()) {
                                showCampaignBoardBriefing();
                            } else {
                                startBoardMode();
                            }
                        } else {
                            startMatchFlow();
                        }
                        break;
                }
            }
        };
        handler.postDelayed(runnable, isCampaignResume() ? 500 : 4000);

        View.OnClickListener buttonListener = new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                gameHaptic(view);
                if (CAN_PLAY) {
                    CAN_PLAY = false;
                    String viewName = getResources().getResourceName(view.getId());
                    myAnswer = Integer.parseInt(String.valueOf(viewName.charAt(viewName.length() - 1)));
                    rlySelected = findViewById(view.getId());
                    imgSelected = (ImageView) rlySelected.getChildAt(0);
                    txtSelected = (TextView) rlySelected.getChildAt(1);
                    if (txtSelected.getVisibility() == View.VISIBLE) {
                        imgSelected.setImageResource(R.drawable.frame_selected);
                        showConfirmationDialog("جواب نهائي ؟", "ConfirmAnswer", 500, 0, R.drawable.mouth_05, false);
                        person.bend(1000, R.drawable.person_02);
                        person.raiseEyeBrowsUp(1000, false, true);
                    }
                }
            }
        };
        (findViewById(R.id.frameA1)).setOnClickListener(buttonListener);
        (findViewById(R.id.frameA2)).setOnClickListener(buttonListener);
        (findViewById(R.id.frameA3)).setOnClickListener(buttonListener);
        (findViewById(R.id.frameA4)).setOnClickListener(buttonListener);

        btnDialogYes.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                gameHaptic(view);

                if (CAN_CLICK) {
                    presenterDialogue.dismissPrompt();
                    CAN_CLICK = false;
                    CAN_HOME = true;
                    rlyDialog.setVisibility(View.INVISIBLE);
                    switch (currentDialog) {
                        case "ConfirmAnswer":
                            rlyVotes.setVisibility(View.INVISIBLE);
                            btnCloseVote.setVisibility(View.INVISIBLE);
                            imgSelected.setImageResource(R.drawable.frame_final);

                            if (modeOnline && !boardMode) {
                                if (Data.isNetworkAvailable(GameActivity.this)) {
                                    stopTimer(false);
                                    CAN_PLAY = false;
                                    submitOnlineAnswer(getAnswerKeyForDisplayedIndex(myAnswer));
                                    rlySelected.getChildAt(2).setVisibility(View.VISIBLE);
                                    resolveOnlineRoundIfReady();
                                } else {
                                    GameNotice.makeText(GameActivity.this, "لا يوجد اتصال بالإنترنت", Toast.LENGTH_SHORT).show();
                                }
                            } else {
                                checkAnswer(false);
                            }
                            break;
                        case "ConfirmHelp5050":
                            usedHelp5050 = true;
                            recordCampaignLifelineUse("5050");
                            lifelineController.hideTwoAnswers();
                            startTimer(false);
                            imgHelp5050.setTag("0");
                            imgHelp5050.setImageResource(R.drawable.help_5050_0);
                            break;
                        case "ConfirmHelpAudience":
                            usedHelpAudience = true;
                            recordCampaignLifelineUse("audience");
                            stopTimer(true);
                            lifelineController.showAudienceVote();
                            imgHelpAudience.setTag("0");
                            imgHelpAudience.setImageResource(R.drawable.help_audience_0);
                            break;
                        case "ConfirmHelpCall":
                            usedHelpCall = true;
                            recordCampaignLifelineUse("call");
                            stopTimer(true);
                            lifelineController.callFriend();
                            imgHelpCall.setTag("0");
                            imgHelpCall.setImageResource(R.drawable.help_call_0);
                            break;
                        case "ConfirmExtraHelp5050":
                            if (PlayerProgress.consumeInventory(GameActivity.this, "5050")) {
                                usedHelp5050 = true;
                                recordCampaignLifelineUse("5050");
                                lifelineController.hideTwoAnswers();
                                startTimer(false);
                                updateInventoryBadges();
                                GameNotice.makeText(GameActivity.this, "تم استخدام 50:50 إضافية", Toast.LENGTH_SHORT).show();
                            }
                            break;
                        case "ConfirmExtraHelpAudience":
                            if (PlayerProgress.consumeInventory(GameActivity.this, "audience")) {
                                usedHelpAudience = true;
                                recordCampaignLifelineUse("audience");
                                stopTimer(true);
                                lifelineController.showAudienceVote();
                                updateInventoryBadges();
                                GameNotice.makeText(GameActivity.this, "تم استخدام مساعدة جمهور إضافية", Toast.LENGTH_SHORT).show();
                            }
                            break;
                        case "ConfirmExtraHelpCall":
                            if (PlayerProgress.consumeInventory(GameActivity.this, "call")) {
                                usedHelpCall = true;
                                recordCampaignLifelineUse("call");
                                stopTimer(true);
                                lifelineController.callFriend();
                                updateInventoryBadges();
                                GameNotice.makeText(GameActivity.this, "تم استخدام اتصال إضافي", Toast.LENGTH_SHORT).show();
                            }
                            break;
                        case "ConfirmHome":
                        case "ConfirmExit":
                            EXITING = true;
                            finishGame();
                            break;
                        case "OpponentLeftContinue":
                            continueMatchWithComputer();
                            break;
                        case "EliminationSpectatorChoice":
                            continueEliminationMatchAsSpectator();
                            break;
                        case "ConfirmRules":
                            person.moveShowHand(1000);
                            if (modeOnline)
                                showDialog("تتكون المباراة من 3 جولات\nكل جولة من 5 أسئلة", "Rules-1", 1000, -1, R.drawable.mouth_05, false);
                            else
                                showDialog("القوانين بسيطة وسهلة", "Rules1", 1000, -1, R.drawable.mouth_05, false);
                            break;
                        case "Rules-1":
                            showDialog("كل إجابة صحيحة تربح قيمتها من النقاط\nوكل إجابة خاطئة تساوي صفر", "Rules0", 1000, -1, R.drawable.mouth_05, false);
                            break;
                        case "Rules0":
                            showDialog("من يفوز بجولتبن يربح المباراة", "Rules1", 1000, -1, R.drawable.mouth_05, false);
                            break;
                        case "Rules1":
                            person.moveHead(600);
                            showDialog("لديك 30 ثانية لللإجابة عن كل سؤال", "Rules2", 1000, -1, R.drawable.mouth_05, false);
                            break;
                        case "Rules2":
                            person.like(600);
                            person.raiseEyeBrowsUp(600, false, true);
                            showDialog("إذا لم تعرف الإجابة يمكنك استخدام إحدى وسائل المساعدة", "Rules3", 2000, -1, R.drawable.mouth_05, false);
                            break;
                        case "Rules3":
                            showDialog("الوسيلة الأولى\nحذف إجابتين خاطئتين", "Rules4", 1000, -1, R.drawable.mouth_05, false);
                            break;
                        case "Rules4":
                            showDialog("الوسيلة الثانية\nالاتصال بصديق", "Rules5", 1000, -1, R.drawable.mouth_05, false);
                            break;
                        case "Rules5":
                            showDialog("الوسيلة الثالثة\nطلب رأي الجمهور", "Rules6", 1000, -1, R.drawable.mouth_05, false);
                            break;
                        case "Rules6":
                            person.moveShowHand(1000);
                            showDialog("يمكنك في أي وقت الانسحاب والاكتفاء بالمبلغ الذي وصلت إليه", "Rules7", 2000, -1, R.drawable.mouth_05, false);
                            break;
                        case "Rules7":
                            playSound(R.raw.commerical_break, true, false);
                            startMatchFlow();
                    }
                }
            }
        });

        btnDialogNo.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                gameHaptic(view);

                if (CAN_CLICK) {
                    presenterDialogue.dismissPrompt();
                    CAN_CLICK = false;
                    CAN_HOME = true;
                    switch (currentDialog) {
                        case "ConfirmAnswer":
                            CAN_PLAY = true;
                            imgSelected.setImageResource(R.drawable.frame);
                            rlyDialog.setVisibility(View.INVISIBLE);
                            person.raiseShoulders();
                            person.moveHead(600);
                            showDialog("حاول مرة أخرى", "", 1000, 1000, R.drawable.mouth_05, true);
                            break;
                        case "ConfirmHelp5050":
                        case "ConfirmHelpAudience":
                        case "ConfirmHelpCall":
                        case "ConfirmExtraHelp5050":
                        case "ConfirmExtraHelpAudience":
                        case "ConfirmExtraHelpCall":
                            rlyDialog.setVisibility(View.INVISIBLE);
                            CAN_PLAY = true;
                            startTimer(false);
                            break;
                        case "ConfirmHome":
                        case "ConfirmExit":
                            CAN_HOME = true;
                            rlyDialog.setVisibility(View.INVISIBLE);
                            CAN_PLAY = true;
                            break;
                        case "OpponentLeftContinue":
                            markMyGameState("finished");
                            EXITING = true;
                            openOnlineResultScreen(true);
                            break;
                        case "EliminationSpectatorChoice":
                            exitEliminationMatchAfterDecliningSpectator();
                            break;
                        case "ConfirmRules":
                        case "Rules1":
                        case "Rules2":
                        case "Rules3":
                        case "Rules4":
                        case "Rules5":
                        case "Rules6":
                        case "Rules7":
                            startMatchFlow();
                            break;
                    }
                }
            }
        });


        imgHelp5050.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                gameHaptic(view);
                if (CAN_PLAY) {
                    if (!isCampaignLifelineAllowed("5050")) {
                        showCampaignLifelineUnavailable();
                        return;
                    }
                    if (imgHelp5050.getTag().toString().equals("1")) {
                        stopTimer(true);
                        showConfirmationDialog("هل تريد حذف إجابتين ؟", "ConfirmHelp5050", 2000, 0, R.drawable.mouth_05, false);
                    } else if (PlayerProgress.getInventory5050(GameActivity.this) > 0) {
                        stopTimer(true);
                        showConfirmationDialog("استخدام 50:50 إضافية من المخزون؟", "ConfirmExtraHelp5050", 1500, 0, R.drawable.mouth_05, false);
                    }
                }
            }
        });


        imgHelpAudience.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                gameHaptic(view);
                if (CAN_PLAY) {
                    if (!isCampaignLifelineAllowed("audience")) {
                        showCampaignLifelineUnavailable();
                        return;
                    }
                    if (imgHelpAudience.getTag().toString().equals("1")) {
                        stopTimer(true);
                        showConfirmationDialog("هل تريد طلب مساعدة الجمهور ؟", "ConfirmHelpAudience", 2000, 0, R.drawable.mouth_05, false);
                    } else if (PlayerProgress.getInventoryAudience(GameActivity.this) > 0) {
                        stopTimer(true);
                        showConfirmationDialog("استخدام مساعدة جمهور إضافية من المخزون؟", "ConfirmExtraHelpAudience", 1500, 0, R.drawable.mouth_05, false);
                    }
                }
            }
        });

        btnCloseVote.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                gameHaptic(view);
                rlyVotes.setVisibility(View.INVISIBLE);
                btnCloseVote.setVisibility(View.INVISIBLE);
            }
        });


        imgHelpCall.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                gameHaptic(view);
                if (CAN_PLAY) {
                    if (!isCampaignLifelineAllowed("call")) {
                        showCampaignLifelineUnavailable();
                        return;
                    }
                    if (imgHelpCall.getTag().toString().equals("1")) {
                        stopTimer(true);
                        showConfirmationDialog("هل تريد الاتصال بصديق ؟", "ConfirmHelpCall", 2000, 0, R.drawable.mouth_05, false);
                    } else if (PlayerProgress.getInventoryCall(GameActivity.this) > 0) {
                        stopTimer(true);
                        showConfirmationDialog("استخدام اتصال إضافي من المخزون؟", "ConfirmExtraHelpCall", 1500, 0, R.drawable.mouth_05, false);
                    }
                }
            }
        });

        imgVolume.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                gameHaptic(view);
                if (SOUND_ON) {
                    if (soundController != null) soundController.setCurrentEffectVolume(0f);
                    SOUND_ON = false;
                    AppPrefs.setSoundEnabled(GameActivity.this, false);
                    imgVolume.setImageResource(R.drawable.game_volume_off);
                } else {
                    if (soundController != null) soundController.setCurrentEffectVolume(1f);
                    SOUND_ON = true;
                    AppPrefs.setSoundEnabled(GameActivity.this, true);
                    imgVolume.setImageResource(R.drawable.game_volume_on);
                }
            }
        });

        View.OnClickListener getMoneyAndHome = new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                gameHaptic(view);
                if (CAN_HOME) {
                    CAN_HOME = false;
                    confirmExit();
                }
            }
        };

        imgHome.setOnClickListener(getMoneyAndHome);
        btnGetMoney.setOnClickListener(getMoneyAndHome);
    }

    @Override
    protected void onSaveInstanceState(@NonNull Bundle outState) {
        super.onSaveInstanceState(outState);
        NativeProgression.save(this, outState);
        if (localTeamsSaveId != null && !localTeamsSaveId.trim().isEmpty()) {
            outState.putString("localTeamsSaveId", localTeamsSaveId);
        }
        if (offlineBoardSaveId != null && !offlineBoardSaveId.trim().isEmpty()) {
            outState.putString("offlineBoardSaveId", offlineBoardSaveId);
        }
        if (campaignMode && !campaignResultPersisted && !EXITING) {
            saveCampaignProgress(campaignBoard ? currentOfflineBoardPhase() : null);
            JSONObject rec = CampaignProgressStore.get(this, campaignStageId);
            if (rec != null) {
                outState.putString("campaignProgressJson", rec.toString());
            }
        }
    }

    private void applyVolumeUi() {
        if (imgVolume == null) return;
        if (SOUND_ON) {
            imgVolume.setImageResource(R.drawable.game_volume_on);
            if (soundController != null) soundController.setCurrentEffectVolume(1f);
        } else {
            imgVolume.setImageResource(R.drawable.game_volume_off);
            if (soundController != null) soundController.setCurrentEffectVolume(0f);
        }
        if (soundController != null) soundController.stopCurrentMusicIfDisabled(MUSIC_ON);
    }

    private void gameHaptic(View view) {
        if (view != null && AppPrefs.isHapticEnabled(this)) {
            AppHaptics.light(this);
        }
    }


    @Override
    protected void onResume() {
        super.onResume();
        ACTIVITY_PAUSED = false;
        if (backgroundGuard.onResume()) return;
        presenterDialogue.resume();
        if (paidDuel != null) {
            paidDuelRenderKey = "";
            paidDuelQuestionTurn = -1;
            wasTimerRunningBeforePause = false;
            wasBoardSelectTimerRunningBeforePause = false;
            paidDuel.resume();
        }
        if (boardOnline && !boardRoomMatch && !boardDuelFinished && myStatusRef != null) {
            duelNeedsBoardResync = true;
            wasTimerRunningBeforePause = false;
            wasBoardSelectTimerRunningBeforePause = false;
            if (duelLocallyConnected) {
                myStatusRef.onDisconnect().setValue("left").addOnSuccessListener(unused -> {
                    if (!ACTIVITY_PAUSED && !EXITING && !boardDuelFinished && !duelActivityDestroyed)
                        markMyGameState("active");
                });
            }
        }
        if (boardCampaignMatch && !campaignResultPersisted && !boardSelectedCategories.isEmpty()
                && !ensureCampaignBoardCategoryAccess()) return;
        if (offlineContestants != null) offlineContestants.setVideosPaused(false);
        for (ChromaVideoView video : resultVideoViews) video.setPaused(false);
        if (backgroundVideoController != null) backgroundVideoController.start();
        SOUND_ON = AppPrefs.isSoundEnabled(this);
        MUSIC_ON = AppPrefs.isMusicEnabled(this);
        applyVolumeUi();

        if (categorySelectMusicPlaying && MUSIC_ON && !EXITING && !backgroundParticipationEnded) {
            playSound(R.raw.main_theme_320bit_chosic, false, true);
        }

        if (mpBeep == null) {
            try { mpBeep = MediaPlayer.create(this, R.raw.beep); } catch (Exception ignored) {}
        }
        if (mpBeep1 == null) {
            try { mpBeep1 = MediaPlayer.create(this, R.raw.beep1); } catch (Exception ignored) {}
        }

        if (boardOnline && !boardRoomMatch && boardDuelFinished) {
            wasTimerRunningBeforePause = false;
            wasBoardSelectTimerRunningBeforePause = false;
            return;
        }
        if (wasTimerRunningBeforePause) {
            wasTimerRunningBeforePause = false;
            long elapsedSincePauseMs = SystemClock.elapsedRealtime() - timerPauseElapsedRealtime;
            int elapsedTicks = (int) (elapsedSincePauseMs / 100L);
            PROGRESS_VALUE -= elapsedTicks;

            if (PROGRESS_VALUE <= 0) {
                PROGRESS_VALUE = 0;
                if (pbTime != null) pbTime.setProgress(0);
                if (txtProgress != null) txtProgress.setText("0");
                handleQuestionTimeout();
            } else {
                int pbText = Math.max(1, (int) Math.ceil(PROGRESS_VALUE / 10.0));
                if (pbTime != null) {
                    pbTime.setProgress(PROGRESS_VALUE);
                    if (pbText > 10) {
                        pbTime.setRingProgressColor(getResources().getColor(R.color.progressGreen));
                    } else if (pbText > 5) {
                        pbTime.setRingProgressColor(getResources().getColor(R.color.progressOrange));
                    } else {
                        pbTime.setRingProgressColor(getResources().getColor(R.color.progressRed));
                    }
                }
                if (txtProgress != null) {
                    txtProgress.setText(String.valueOf(pbText));
                }
                startTimer(false);
                if (CAN_PLAY && isQuestionTimerRunning && !EXITING
                        && !backgroundParticipationEnded) playQuestionMusic();
            }
        }

        if (wasBoardSelectTimerRunningBeforePause) {
            wasBoardSelectTimerRunningBeforePause = false;
            long elapsedMs = SystemClock.elapsedRealtime() - boardSelectPauseElapsedRealtime;
            boardSelectRemainingMs -= elapsedMs;
            if (boardSelectRemainingMs <= 0L) {
                boardSelectRemainingMs = 0L;
                if (boardSelectCountdownView != null) {
                    boardSelectCountdownView.setText("⏱ 0");
                }
                if (!EXITING && boardMode && boardPickerIsHuman) {
                    View overlay = findViewById(R.id.boardOverlay);
                    if (overlay != null && overlay.getVisibility() == View.VISIBLE) {
                        int[] cell = pickRandomRemainingCell();
                        if (cell != null) {
                            GameNotice.makeText(GameActivity.this, "انتهى وقت الاختيار، تم اختيار خانة تلقائياً",
                                    Toast.LENGTH_SHORT).show();
                            onCellPicked(cell[0], cell[1]);
                        }
                    }
                }
            } else {
                startBoardSelectTimerWithDuration(boardSelectRemainingMs);
            }
        }

        if (wasCampaignStageTimerRunningBeforePause && campaignMode && !campaignResultPersisted && campaignTimeLimitSeconds > 0) {
            wasCampaignStageTimerRunningBeforePause = false;
            long elapsedMs = System.currentTimeMillis() - campaignStartedAtMs;
            long remainingMs = campaignBoard
                    ? boardCampaignDeadlineMs - System.currentTimeMillis()
                    : (campaignTimeLimitSeconds * 1000L) - elapsedMs;
            if (remainingMs <= 0L) {
                if (txtCampaignTimer != null) {
                    txtCampaignTimer.setText("⏱ " + formatCampaignRemaining(0));
                }
                handleCampaignTimeExpired();
            } else {
                startCampaignStageTimerWithDuration(remainingMs);
            }
        }
    }
    private void setupCampaignBossBattle() {
        opponents.clear();
        MatchOpponent boss = new MatchOpponent();
        boss.id = "campaign_boss_" + (campaignStageId == null || campaignStageId.trim().isEmpty()
                ? getCampaignStageOrder()
                : campaignStageId.trim());
        boss.bot = true;
        boss.name = campaignBossBotName == null || campaignBossBotName.trim().isEmpty()
                ? "زعيم المرحلة"
                : campaignBossBotName.trim();
        boss.intelligence = resolveCampaignBossIntelligence();
        boss.level = Math.max(1, Math.min(10, boss.intelligence / 10));
        BotProfile profile = BotProfiles.PROFILES[Math.abs(stableHash(boss.id)) % BotProfiles.PROFILES.length];
        boss.photo = profile.photo;
        campaignBossOpponent = boss;
        opponents.add(boss);

        if (labScore != null) labScore.setText("الجولة");
        if (labSets != null) labSets.setText("الصحيح");
        if (labScoreGame != null) labScoreGame.setText("النقاط");
        if (txtMeName != null) txtMeName.setText("أنت");
        if (txtSetsMe != null) txtSetsMe.setText("0");
        if (txtScoreMe != null) txtScoreMe.setText("0");
        if (txtScoreGameMe != null) txtScoreGameMe.setText("0");
        Data.setImageSource(this, imgMe, myPhoto);
        Data.setImageSource(this, imgAnswer1Player1, myPhoto);
        Data.setImageSource(this, imgAnswer2Player1, myPhoto);
        Data.setImageSource(this, imgAnswer3Player1, myPhoto);
        Data.setImageSource(this, imgAnswer4Player1, myPhoto);
        opponentHudController.buildOpponentPanels();
        if (rlyScore != null) {
            rlyScore.setVisibility(View.GONE);
        }
        syncPrimaryOpponentFields();
    }
    private void parseOpponentsFromIntent() {
        opponents.clear();
        String opponentsJson = getIntent().getStringExtra("opponentsJson");
        if (opponentsJson == null || opponentsJson.trim().isEmpty()) {
            opponentsJson = "[]";
        }

        try {
            JSONArray jsonArray = new JSONArray(opponentsJson);
            for (int i = 0; i < jsonArray.length(); i++) {
                JSONObject item = jsonArray.optJSONObject(i);
                if (item == null) {
                    continue;
                }
                MatchOpponent opponent = new MatchOpponent();
                opponent.id = safeString(item.optString("id"));
                opponent.seatId = safeString(item.optString("seatId"));
                if (opponent.seatId.isEmpty()) opponent.seatId = opponent.id;
                opponent.teamId = safeString(item.optString("teamId")).trim().toUpperCase();
                opponent.name = safeDisplayName(item.optString("name"), opponents.size() + 1);
                opponent.photo = safeString(item.optString("photo"));
                opponent.level = Math.max(1, item.optInt("level", 1));
                opponent.intelligence = Math.max(0, item.optInt("intelligence", 0));
                opponent.score = Math.max(0, item.optInt("score", 0));
                opponent.bot = item.optBoolean("bot", false) || "fictitious".equals(opponent.id);
                if (opponent.bot) {
                    applyBotIdentity(opponent, false);
                }
                if (!opponent.id.isEmpty()) {
                    opponents.add(opponent);
                }
            }
        } catch (Exception ignored) {
        }

        if (opponents.isEmpty()) {
            MatchOpponent fallback = new MatchOpponent();
            fallback.id = "fictitious";
            fallback.bot = true;
            applyBotIdentity(fallback, false);
            opponents.add(fallback);
        }

        syncPrimaryOpponentFields();
    }

    private void syncPrimaryOpponentFields() {
        MatchOpponent primaryOpponent = getPrimaryOpponent();
        if (primaryOpponent == null) {
            opponentID = "fictitious";
            opponentName = "الكمبيوتر";
            opponentPhoto = "";
            opponentLevel = 1;
            opponentScore = 0;
            return;
        }
        opponentID = primaryOpponent.id;
        opponentName = primaryOpponent.name;
        opponentPhoto = primaryOpponent.photo;
        opponentLevel = primaryOpponent.level;
        opponentScore = primaryOpponent.score;
    }

    private MatchOpponent getPrimaryOpponent() {
        if (opponents.isEmpty()) {
            return null;
        }
        return opponents.get(0);
    }

    private ArrayList<String> getOpponentIds() {
        ArrayList<String> ids = new ArrayList<>();
        for (MatchOpponent opponent : opponents) {
            if (opponent.id != null && !opponent.id.trim().isEmpty()) {
                ids.add(opponent.id);
            }
        }
        return ids;
    }
    private GradientDrawable createRoundedDrawable(int fillColor, int strokeColor, int strokeDp, int radiusDp) {
        GradientDrawable drawable = new GradientDrawable();
        drawable.setColor(fillColor);
        drawable.setCornerRadius(dp(radiusDp));
        if (strokeDp > 0) {
            drawable.setStroke(dp(strokeDp), strokeColor);
        }
        return drawable;
    }
    private String getCampaignOpeningMessage() {
        return CampaignBoardRules.openingMessage(getCampaignStageOrder(),
                campaignBossBattle || (boardCampaignMatch && "boss".equals(boardCampaignKind)),
                boardCampaignMatch ? boardTargetScore : campaignTargetScore,
                campaignEntry, isCampaignResume());
    }

    private void showCampaignBoardBriefing() {
        boolean boss = "boss".equals(boardCampaignKind);
        int columns = boss ? offlineContestants.contestantCount() : boardSoloCols;
        final ArrayList<String> messages = CampaignBoardRules.briefingMessages(
                boss, boss ? BOARD_ROWS : boardSoloPicks, columns, boardCategoryPolicy,
                campaignTimeLimitSeconds, campaignMaxWrongAnswers, boardRequiredCategoryCount,
                boardWorldCategories, boardBossStyle, boardAllowRevealOptions,
                boardTwoStarScore, boardThreeStarScore);
        final Handler handler = new Handler();
        handler.post(new Runnable() {
            int index = 0;

            @Override
            public void run() {
                if (EXITING || isFinishing() || isDestroyed() || presenterDialogue.defer(this)) return;
                if (EXITING || isFinishing() || isDestroyed() || campaignResultPersisted) return;
                if (ACTIVITY_PAUSED) {
                    handler.postDelayed(this, 250);
                    return;
                }
                if (index >= messages.size()) {
                    startBoardMode();
                    return;
                }
                String message = messages.get(index++);
                person.moveShowHand(800);
                showDialog(message, "", 800, 2200, R.drawable.mouth_01, false);
                // The next iteration waits for the actual typing + reading time.
                // The stage timer starts only after briefing and category selection.
                handler.post(this);
            }
        });
    }

    private String getCampaignAnswerMessage(boolean correct, int starsBefore) {
        if (!correct) {
            if (campaignBossBattle && campaignBossOpponent != null) {
                if (gameScoreMe < campaignBossOpponent.gameScore) {
                    return "الزعيم متقدم، لكن ما زالت لديك فرصة.";
                }
                if (gameScoreMe > campaignBossOpponent.gameScore) {
                    return "أنت متقدم على الزعيم! حافظ على تركيزك.";
                }
            }
            return "لا بأس، الخطأ لا ينهي المرحلة لكنه يؤثر على النجوم.";
        }
        int starsAfter = campaignHudController.getEarnedStars();
        if (starsAfter > starsBefore) {
            if (starsAfter == 1) return "ممتاز! حصلت على النجمة الأولى.";
            if (starsAfter == 2) return "رائع! نجمتان حتى الآن.";
            return "مذهل! ثلاث نجوم!";
        }
        if (campaignBossBattle && campaignBossOpponent != null) {
            if (gameScoreMe < campaignBossOpponent.gameScore) {
                return "الزعيم متقدم، لكن ما زالت لديك فرصة.";
            }
            if (gameScoreMe > campaignBossOpponent.gameScore) {
                return "أنت متقدم على الزعيم! حافظ على تركيزك.";
            }
        }
        return "إجابة رائعة! اقتربت من النجمة التالية.";
    }

    private boolean isShortGameScreen() {
        final DisplayMetrics metrics = GameViewportActivity.canvasMetrics(this);
        return metrics.heightPixels / metrics.density < 390f;
    }

    /** True for the classic single-player offline game (you + 3 AI contestants). */
    boolean isOfflineContestantMode() {
        return !modeOnline && !campaignMode && !campaignBossBattle;
    }

    private boolean isLastOfflineQuestion() {
        int total = Math.min(getQuestionCounterTotal(), questions.size());
        return currentQuestion >= total - 1;
    }

    private void applyQuestionTextSize(String text) {
        if (txtQ == null) {
            return;
        }
        final int qLen = text == null ? 0 : text.length();
        final boolean shortScreen = isShortGameScreen();
        final float sizeSp;
        if (qLen <= 60) {
            sizeSp = shortScreen ? 16f : 18f;
        } else if (qLen <= 90) {
            sizeSp = shortScreen ? 14f : 15f;
        } else if (qLen <= 130) {
            sizeSp = shortScreen ? 12.5f : 13f;
        } else {
            sizeSp = shortScreen ? 10.5f : 11f;
        }
        if (android.os.Build.VERSION.SDK_INT >= 26) {
            txtQ.setAutoSizeTextTypeWithDefaults(TextView.AUTO_SIZE_TEXT_TYPE_NONE);
        }
        txtQ.setTextSize(TypedValue.COMPLEX_UNIT_SP, sizeSp);
        if (txtQ.getMaxLines() == Integer.MAX_VALUE && android.os.Build.VERSION.SDK_INT >= 26) {
            txtQ.setAutoSizeTextTypeUniformWithConfiguration(
                    8, Math.max(9, Math.round(sizeSp)), 1, TypedValue.COMPLEX_UNIT_SP);
        }
    }

    private void applyAnswerTextSizes(ArrayList<String> answerTexts) {
        final float sizeSp = resolveUniformAnswerTextSizeSp(answerTexts);
        for (TextView answerView : listAnswerViews) {
            if (answerView != null) {
                answerView.setTextSize(TypedValue.COMPLEX_UNIT_SP, sizeSp);
            }
        }
    }

    private float resolveAnswerTextSizeSp(String text) {
        final int aLen = text == null ? 0 : text.length();
        final boolean shortScreen = isShortGameScreen();
        if (aLen <= 20) {
            return shortScreen ? 13f : 14f;
        } else if (aLen <= 30) {
            return shortScreen ? 11.5f : 12f;
        } else if (aLen <= 45) {
            return shortScreen ? 9.5f : 10f;
        }
        return 8f;
    }

    private float resolveUniformAnswerTextSizeSp(ArrayList<String> answerTexts) {
        final boolean shortScreen = isShortGameScreen();
        final float maxSizeSp = shortScreen ? 13f : 14f;
        final float minSizeSp = 8f;
        for (float sizeSp = maxSizeSp; sizeSp >= minSizeSp; sizeSp -= 0.5f) {
            if (allAnswerTextsFit(answerTexts, sizeSp)) {
                return sizeSp;
            }
        }

        int longest = 0;
        for (String answerText : answerTexts) {
            longest = Math.max(longest, answerText == null ? 0 : answerText.length());
        }
        return resolveAnswerTextSizeSp(makeLengthProbe(longest));
    }

    private boolean allAnswerTextsFit(ArrayList<String> answerTexts, float sizeSp) {
        if (answerTexts == null || answerTexts.isEmpty()) {
            return true;
        }
        final float textSizePx = TypedValue.applyDimension(
                TypedValue.COMPLEX_UNIT_SP,
                sizeSp,
                getResources().getDisplayMetrics()
        );
        for (int i = 0; i < answerTexts.size() && i < listAnswerViews.size(); i++) {
            TextView answerView = listAnswerViews.get(i);
            if (answerView == null) {
                continue;
            }
            final int availableWidth = getAnswerTextAvailableWidth(answerView);
            if (availableWidth <= 0) {
                return false;
            }
            TextPaint paint = new TextPaint(answerView.getPaint());
            paint.setTextSize(textSizePx);
            if (paint.measureText(answerTexts.get(i) == null ? "" : answerTexts.get(i)) > availableWidth) {
                return false;
            }
        }
        return true;
    }

    private int getAnswerTextAvailableWidth(TextView answerView) {
        int width = answerView.getWidth();
        if (width <= 0 && answerView.getParent() instanceof View) {
            width = ((View) answerView.getParent()).getWidth();
            ViewGroup.LayoutParams layoutParams = answerView.getLayoutParams();
            if (layoutParams instanceof ViewGroup.MarginLayoutParams) {
                ViewGroup.MarginLayoutParams marginParams =
                        (ViewGroup.MarginLayoutParams) layoutParams;
                width -= marginParams.leftMargin + marginParams.rightMargin;
            }
        }
        return width - answerView.getPaddingLeft() - answerView.getPaddingRight();
    }

    private String makeLengthProbe(int length) {
        StringBuilder builder = new StringBuilder(Math.max(0, length));
        for (int i = 0; i < length; i++) {
            builder.append('W');
        }
        return builder.toString();
    }

    private boolean allOpponentsSubmitted() {
        for (MatchOpponent opponent : opponents) {
            if (!opponent.eliminated && !opponent.submitted) {
                return false;
            }
        }
        return true;
    }

    private void autoSubmitSpectatorEliminationRound() {
        if (!modeOnline || !eliminationMode || !spectatorEliminationRound || myAnswerSubmitted) {
            return;
        }
        CAN_PLAY = false;
        final int questionIndex = currentQuestion;
        new Handler().postDelayed(new Runnable() {
            @Override
            public void run() {
                if (EXITING || currentQuestion != questionIndex || myAnswerSubmitted) {
                    return;
                }
                submitOnlineAnswer(0);
                resolveOnlineRoundIfReady();
            }
        }, 150);
    }

    private boolean hasBotOpponents() {
        for (MatchOpponent opponent : opponents) {
            if (opponent.bot && !opponent.eliminated) {
                return true;
            }
        }
        return false;
    }

    private MatchOpponent findOpponentById(String playerId) {
        for (MatchOpponent opponent : opponents) {
            if (opponent.id.equals(playerId)) {
                return opponent;
            }
        }
        return null;
    }

    int dp(int value) {
        return Math.round(getResources().getDisplayMetrics().density * value);
    }

    private String safeDisplayName(String name, int index) {
        String resolved = safeString(name).trim();
        if (resolved.isEmpty()) {
            return index <= 1
                    ? "خصم آلي"
                    : String.format(Locale.getDefault(), "خصم آلي %d", index);
        }
        return resolved;
    }
    private BotProfile resolveBotProfile(String playerId) {
        return GameBotLogic.resolveBotProfile(playerId);
    }

    private void applyBotIdentity(MatchOpponent opponent, boolean replacingHuman) {
        GameBotLogic.applyBotIdentity(opponent);
        if (opponent != null && replacingHuman) {
            GameNotice.makeText(
                    this,
                    opponent.name + " يتابع اللعب الآن كخصم آلي",
                    Toast.LENGTH_SHORT
            ).show();
        }
    }

    private int getFictitiousRandomTime() {
        return GameBotLogic.getFictitiousRandomTime(getCurrentQuestionLevel());
    }

    private int getFictitiousRandomAnswer() {
        return GameBotLogic.getFictitiousRandomAnswer(getCurrentQuestionLevel(), rightAnswer);
    }

    private int getBotDelayMillis(MatchOpponent opponent) {
        return GameBotLogic.getBotDelayMillis(opponent, currentQuestion, getCurrentQuestionLevel(), PROGRESS_VALUE);
    }

    private int getBotDisplayedAnswer(MatchOpponent opponent) {
        return GameBotLogic.getBotDisplayedAnswer(opponent, currentQuestion, getCurrentQuestionLevel(), rightAnswer);
    }

    private int getWrongAnswer(int rightAnswer) {
        return GameBotLogic.getWrongAnswer(rightAnswer);
    }

    private String getCurrentQuestionLevel() {
        if (boardMode && boardCurrentQuestion != null) {
            return boardCurrentQuestion.getLevel();
        }
        if (currentQuestion >= 0 && currentQuestion < questions.size()) {
            return questions.get(currentQuestion).Level;
        }
        return "0";
    }
    private void checkAnswer(final boolean timeout) {
        if (paidDuel != null) {
            submitPaidDuelAnswer(timeout);
            return;
        }
        // The money-ladder amount is irrelevant for online and offline-contestant
        // (board) modes, which both resolve the round without it.
        final int amount = (modeOnline || isOfflineContestantMode() || boardMode)
                ? 0
                : Integer.parseInt(getCurrentStepAmount().replace("$", ""));
        if (!timeout) {
            stopTimer(false);
            playSound(R.raw.drum1, false, true);
            FAST_LIGHTS = true;
        }
        CAN_HOME = true;
        // Board campaign stages run on the التحدي board (handled below), not the
        // classic single-question campaign flow — so exclude boardMode here.
        if (campaignMode && !modeOnline && !boardMode) {
            handleCampaignStageAnswer(timeout);
            return;
        }
        // The board (offline OR online) resolves a single picker's answer, never the
        // classic simultaneous online round — route it before the modeOnline path.
        if (isOfflineContestantMode() || boardMode) {
            handleOfflineContestantAnswer(timeout);
            return;
        }
        final Handler handler = new Handler();
        Runnable runnable = new Runnable() {
            int t = 0;

            @Override
            public void run() {
                if (EXITING || isFinishing() || isDestroyed() || presenterDialogue.defer(this)) return;
                t++;
                switch (t) {
                    case 1:
                        FAST_LIGHTS = false;
                        T_LIGHTS = 3;
                        if (modeOnline) {
                            applyOnlineRoundMetrics();
                            if (handleLocalTimeoutRemovalIfNeeded()) {
                                return;
                            }
                            if (eliminationMode && spectatorEliminationRound) {
                                t = 2;
                                handler.postDelayed(this, 400);
                                break;
                            }
                        }
                        if (!timeout) {
                            if (myAnswer == rightAnswer) {
                                recordCampaignCorrectAnswer();
                                imgSelected.setImageResource(R.drawable.frame_right);
                                PlayerStats.recordCorrectAnswer(GameActivity.this);
                                person.like(1000);
                                playSound(R.raw.correct_answer, false, false);
                                showDialog("الجواب صحيح", "", 1000, 2000, R.drawable.mouth_01, false);
                                if (modeOnline) {
                                    t = 2;
                                }
                                handler.postDelayed(this, 3000);
                            } else {
                                onWrongAnswer(false);
                                if (modeOnline) {
                                    t = 2;
                                    handler.postDelayed(this, 3000);
                                }
                            }
                        } else {
                            onWrongAnswer(true);
                            if (modeOnline) {
                                t = 2;
                                handler.postDelayed(this, 3000);
                            }
                        }
                        break;
                    case 2:
                        Animations.move(llyQA, 1000, 0, -140, 0, 0);
                        Animations.move(llySteps, 1000, 0, -360, 0, 0);
                        String currentStepDialog = getCurrentStepAmount();
                        if (modeOnline) {
                            txtAmount.setText(gameScoreMe + "");
                        } else {
                            txtAmount.setText(currentStepDialog);
                        }
                        if (eliminationMode) {
                            if (spectatorEliminationRound) {
                                handler.postDelayed(this, 500);
                                break;
                            }
                            if (mySubmittedAnswerKey == ANSWER_KEY_RIGHT) {
                                person.moveShowScreen(2000);
                                person.lookAside(1000);
                                showDialog("إجابة صحيحة، ونقاطك الآن " + gameScoreMe, "", 1000, 2000, R.drawable.mouth_01, false);
                            } else {
                                handler.postDelayed(this, 500);
                                CAN_HOME = true;
                                break;
                            }
                            CAN_HOME = true;
                            handler.postDelayed(this, 3000);
                            break;
                        } else if (shouldCompleteCampaignAfterCurrentQuestion()) {
                            person.moveShow2Hands(2000);
                            person.raiseEyeBrowsUp(2000, true, true);
                            showDialog("أحسنت! أنهيت المرحلة بنجاح", "", 2000, 2000, R.drawable.mouth_01, false);
                            CAN_HOME = false;
                        } else if (currentQuestion == 14) {
                            person.moveShow2Hands(2000);
                            person.raiseEyeBrowsUp(2000, true, true);
                            showDialog("ألف مبروك\n لقد فزت بالمليون", "", 2000, 2000, R.drawable.mouth_01, false);
                            CAN_HOME = false;
                        } else {
                            person.moveShowScreen(2000);
                            person.lookAside(1000);
                            showDialog("أصبح رصيدك الآن\n" + currentStepDialog, "", 1000, 2000, R.drawable.mouth_01, false);
                            CAN_HOME = true;
                        }
                        handler.postDelayed(this, 3000);
                        break;
                    case 3:
                        if (modeOnline) {
                            if (eliminationMode) {
                                myResult = handleEliminationRoundProgress();
                                if (myResult == -3) {
                                    return;
                                }
                                if (myResult != -2) t = 6;
                                handler.postDelayed(this, 3000);
                            } else if (checkScoresMulti()) {
                                myResult = checkEndOfGameMulti();
                                if (myResult != -2) t = 6;
                                handler.postDelayed(this, 3000);
                            } else {
                                handler.postDelayed(this, 1000);
                            }
                        } else {
                            if (shouldCompleteCampaignAfterCurrentQuestion()) {
                                goToWinnerScreen(getCurrentStepAmount());
                            } else if (currentQuestion == 14) {
                                goToWinnerScreen("1000000$");
                            } else {
                                if (currentQuestion == 4) {
                                    person.like(1000);
                                    person.raiseEyeBrowsUp(1000, false, true);
                                    showDialog("ممتاز.. لقد ضمنت الآن مبلغ 1000$ حتى لو خسرت", "", 2000, 3000, R.drawable.mouth_01, false);
                                } else if (currentQuestion == 9) {
                                    person.like(1000);
                                    person.raiseEyeBrowsUp(1000, false, true);
                                    showDialog("ممتاز.. لقد ضمنت الآن مبلغ 32000$ حتى لو خسرت", "", 2000, 3000, R.drawable.mouth_01, false);
                                }
                                handler.postDelayed(this, 3000);
                            }
                        }
                        break;
                    case 4:
                        initQuestion();
                        nextStep();
                        playSound(R.raw.lets_play, true, false);
                        String currentStepAmount = getCurrentStepAmount();
                        person.moveHead(1000);
                        person.lookAside(600);
                        showDialog("السؤال التالي قيمته\n" + currentStepAmount, "", 1000, 3000, R.drawable.mouth_02, false);
                        CAN_HOME = true;
                        if (modeOnline) t++;
                        handler.postDelayed(this, 4000);
                        break;
                    case 5:
                        Animations.move(llyQA, 1000, -140, 0, 0, 0);
                        Animations.move(llySteps, 1000, -360, 0, 0, 0);
                        handler.postDelayed(this, 1000);
                        break;
                    case 6:
                        if (modeOnline) {
                            requestSynchronizedQuestion(currentQuestion + 1);
                        } else {
                            nextQuestion();
                        }
                        break;
                    case 7:
                        if (modeOnline) {
                            openOnlineResultScreen(false);
                        }
                        break;
                }
            }
        };
        int delayDrum;
        if (timeout) {
            delayDrum = 100;
        } else {
            delayDrum = (currentQuestion < 5) ? 3000 : ((currentQuestion < 10) ? 6000 : 9000);
         }
        handler.postDelayed(runnable, delayDrum);
    }

    private int duelQuestionCallbackGeneration;

    private boolean isCurrentBoardQuestionCallback(int turn, Question question, int generation) {
        if (EXITING || duelActivityDestroyed) return false;
        if (!boardOnline || boardRoomMatch) return true;
        return !duelActivityDestroyed && !boardDuelFinished && duelLocallyConnected
                && !ACTIVITY_PAUSED && !duelNeedsBoardResync && turn == boardOnlineTurn
                && question == boardCurrentQuestion && generation == duelQuestionCallbackGeneration;
    }

    /** Answer/reveal flow for the offline competition (you + 3 AI contestants). */
    private void handleOfflineContestantAnswer(final boolean timeout) {
        final boolean playerCorrect = !timeout && myAnswer == rightAnswer;
        final int answeredDuelTurn = boardOnlineTurn;
        final Question answeredQuestion = boardCurrentQuestion;
        final int callbackGeneration = duelQuestionCallbackGeneration;
        if (!timeout) {
            offlineContestants.markPlayerAnswered();
        }
        final Handler handler = new Handler();
        Runnable runnable = new Runnable() {
            int t = 0;

            @Override
            public void run() {
                if (EXITING || isFinishing() || isDestroyed() || presenterDialogue.defer(this)) return;
                if (!isCurrentBoardQuestionCallback(answeredDuelTurn,
                        answeredQuestion, callbackGeneration)) return;
                if (boardCampaignMatch && campaignResultPersisted) return;
                t++;
                switch (t) {
                    case 1:
                        FAST_LIGHTS = false;
                        T_LIGHTS = 3;
                        if (boardMode) {
                            // The local human's seat: slot 0 offline/1v1, mySeat on the team board.
                            final int localSeat = boardPickerSlot;
                            // التحدي الرئيسي: a wrong first answer hands the SAME question to
                            // the other team (steal) before the answer is revealed. Abort the
                            // reveal/end-turn sequence here and run the steal attempt instead.
                            if (boardLocalTeams && !playerCorrect && !boardStealActive) {
                                PlayerStats.recordWrongAnswer(GameActivity.this);
                                offlineContestants.showSlotResult(localSeat, false);
                                playSound(R.raw.wrong_answer, false, false);
                                person.sad();
                                beginBoardSteal();
                                return;
                            }
                            if (playerCorrect) {
                                offlineContestants.awardCell(localSeat, currentBoardAwardValue());
                                if (boardRoomMatch || boardCampaignMatch) boardMyCorrectCount++;
                                if (boardCampaignMatch && boardPickedCol >= 0
                                        && boardPickedCol < boardSelectedCategories.size()) {
                                    boardCorrectCategories.add(boardSelectedCategories.get(boardPickedCol));
                                }
                            }
                            offlineContestants.showSlotResult(localSeat, playerCorrect);
                            if (boardCampaignMatch) {
                                campaignAnsweredQuestions++;
                                campaignCorrectAnswers = boardMyCorrectCount;
                                campaignWrongAnswers = campaignAnsweredQuestions - campaignCorrectAnswers;
                            }
                            // Reveal the options so the player sees the correct answer
                            // (they were hidden behind the text box for a typed turn).
                            showBoardTypedPanel(false);
                            setBoardAnswerOptionsVisible(true);
                            if (boardOnline) {
                                writeOnlineTurnResult(boardOnlineTurn, playerCorrect, boardOptionsRevealed);
                            }
                        } else {
                            offlineContestants.revealRound(playerCorrect);
                        }
                        if (playerCorrect) {
                            if (imgSelected != null) imgSelected.setImageResource(R.drawable.frame_right);
                            else if (imgRight != null) imgRight.setImageResource(R.drawable.frame_right);
                            PlayerStats.recordCorrectAnswer(GameActivity.this);
                            person.like(1000);
                            person.raiseEyeBrowsUp(1000, false, true);
                            playSound(R.raw.correct_answer, false, false);
                            showDialog("إجابة صحيحة!", "", 1000, boardCampaignMatch ? 1000 : 2000, R.drawable.mouth_01, false);
                        } else {
                            PlayerStats.recordWrongAnswer(GameActivity.this);
                            playSound(R.raw.wrong_answer, false, false);
                            person.sad();
                            if (!timeout && imgSelected != null) {
                                imgSelected.setImageResource(R.drawable.frame_wrong);
                            }
                            if (imgRight != null) imgRight.setImageResource(R.drawable.frame_right);
                            showDialog(timeout ? "انتهى الوقت للأسف" : "إجابة خاطئة للأسف",
                                    "", 1000, boardCampaignMatch ? 1000 : 2000, R.drawable.mouth_05, false);
                        }
                        if (boardMode && boardLocalTeams && !playerCorrect) {
                            showBoardRefereePanel(true);
                            CAN_HOME = true;
                            // In local teams mode on wrong answer, do not advance automatically.
                            // The game waits until the players press "⏭️ الدور التالي" or "⚖️ تعديل الحكم واحتساب النقاط".
                            break;
                        }
                        CAN_HOME = true;
                        boardRevealHandler = handler;
                        boardRevealRunnable = this;
                        handler.postDelayed(this, boardCampaignMatch ? 2500 : (boardMode ? BOARD_REVEAL_HOLD_MS : 3000));
                        break;
                    case 2:
                        cancelPendingBoardReveal();
                        showBoardRefereePanel(false);
                        if (boardMode) {
                            endBoardTurn();
                            break;
                        }
                        if (isLastOfflineQuestion()) {
                            finishOfflineCompetition();
                        } else {
                            person.moveHead(800);
                            person.lookAside(600);
                            showDialog(offlineContestants.standingsLine(), "", 800, 2000, R.drawable.mouth_02, false);
                            handler.postDelayed(this, 2400);
                        }
                        break;
                    case 3:
                        initQuestion();
                        nextQuestion();
                        break;
                }
            }
        };
        if (boardOnline && !boardRoomMatch) {
            cancelPendingBoardReveal();
            boardRevealHandler = handler;
            boardRevealRunnable = runnable;
        }
        handler.postDelayed(runnable, timeout ? 200 : getAnswerRevealDrumDelayMs());
    }

    private void finishOfflineCompetition() {
        if (presenterDialogue.defer("offlineResult", this::finishOfflineCompetition)) return;
        stopTimer(false);
        CAN_PLAY = false;
        CAN_HOME = false;
        if (boardMode) {
            hideBoardOverlay();
            finishBoardCelebration();
            return;
        }
        final boolean win = offlineContestants.playerIsWinner();
        final int rank = offlineContestants.playerRank();
        final int score = offlineContestants.playerScore();
        final String eventName = boardMode ? "المباراة" : "المسابقة";
        if (win) {
            person.moveShow2Hands(2000);
            person.raiseEyeBrowsUp(1000, false, true);
            playSound(R.raw.new_level, false, false);
            showDialog("مبروك! فزت بـ" + eventName + " بـ " + score + " نقطة", "", 2000, 3000, R.drawable.mouth_01, false);
        } else {
            person.moveShowHand(1000);
            showDialog("انتهت " + eventName + "، ترتيبك " + rank + " من " + offlineContestants.playerCount() + " بـ " + score + " نقطة",
                    "", 2000, 3000, R.drawable.mouth_05, false);
        }
        final Handler handler = new Handler();
        handler.postDelayed(new Runnable() {
            @Override
            public void run() {
                if (EXITING) return;
                try {
                    PlayerStats.recordGameEnd(GameActivity.this, win, score);
                    PlayerProgress.onGameFinished(GameActivity.this, win, score,
                            PlayerStats.getBestStreak(GameActivity.this), usedAllHelps(), usedAnyHelp());
                } catch (Exception ignored) {
                }
                offlineContestants.release();
                stopCurrentSound();
                if (cdtProgress != null) cdtProgress.cancel();
                showInterstitialAd();
            }
        }, 4000);
    }

    /** Solo board (offline التحدي, or 1v1 speed): celebration results screen. */
    private void finishBoardCelebration() {
        final int count = offlineContestants.contestantCount();
        final int myScore = offlineContestants.scoreForSlot(0); // slot 0 = me
        int bestScore = 0;
        for (int g = 0; g < count; g++) {
            bestScore = Math.max(bestScore, offlineContestants.scoreForSlot(g));
        }
        final boolean[] seatWon = new boolean[count];
        int rank = 1;
        for (int g = 0; g < count; g++) {
            int s = offlineContestants.scoreForSlot(g);
            seatWon[g] = (s == bestScore);
            if (s > myScore) rank++;
        }
        final boolean win = seatWon.length > 0 && seatWon[0];
        int topCount = 0;
        for (boolean top : seatWon) if (top) topCount++;
        final boolean tied = win && topCount > 1;
        String headline = tied ? "🤝 تعادل!" : win ? "🏆 فزت بالمباراة!"
                : ("انتهت المباراة — ترتيبك " + rank + " من " + count);
        if (!win && boardOnline && getIntent().getBooleanExtra("resumeOnlineMatch", false))
            headline = "خسرت المباراة التي انتهت أثناء غيابك";
        final int previousCoins = PlayerProgress.getCoins(this);
        if (!settleRandomStake(win, tied, this::finishBoardCelebration)) return;
        try {
            PlayerStats.recordGameEnd(GameActivity.this, tied ? ProgressionRules.DRAW
                    : win ? ProgressionRules.WIN : ProgressionRules.LOSS, myScore);
            PlayerProgress.onGameFinished(GameActivity.this, win && !tied, myScore,
                    PlayerStats.getBestStreak(GameActivity.this), usedAllHelps(), usedAnyHelp());
        } catch (Exception ignored) {
        }
        boardResultCurrencyDelta = PlayerProgress.getCoins(this) - previousCoins;
        if (win) {
            person.moveShow2Hands(1500);
            person.raiseEyeBrowsUp(1000, false, true);
        }
        playSound(win ? R.raw.new_level : R.raw.wrong_answer, false, false);
        showBoardResultScreen(headline, 0, 0, 0, seatWon);
    }

    private boolean settleRandomStake(boolean win, boolean draw, Runnable retry) {
        if (paidDuel != null || getIntent().getIntExtra("stakeCoins", 0) <= 0) return true;
        try {
            if (!NativeProgression.activeAccount(this)) return false;
            RandomStakeLedger.settle(this, safeIntentString("randomStakeId", ""), win, draw);
            return true;
        } catch (RuntimeException failure) {
            GameNoticeDialogs.builder(this).setTitle("تعذر حفظ نتيجة القطع")
                    .setMessage("لم يتم تأكيد تسوية الرهان بعد. أعد المحاولة لحفظ النتيجة.")
                    .setPositiveButton("إعادة المحاولة", (dialog, which) -> retry.run())
                    .setCancelable(false).show();
            return false;
        }
    }

    /** التحدي الرئيسي end: tally both teams (slot 0 = team A, slot 1 = team B) and crown
     *  the higher total — neutral (no "me"), since both teams play on one phone. */
    private void finishLocalTeamsBoard() {
        final int scoreA = offlineContestants.scoreForSlot(0);
        final int scoreB = offlineContestants.scoreForSlot(1);
        final int winSlot = (scoreA == scoreB) ? -1 : (scoreA > scoreB ? 0 : 1);
        final String headline = (winSlot < 0)
                ? "🤝 تعادل!"
                : ("🏆 فاز " + boardTeamName(winSlot) + "!");
        saveLocalTeamsFinished(scoreA, scoreB, winSlot);
        // A hot-seat two-team match has no personal winner; record a game played
        // without claiming a win so the device owner's win stats stay clean.
        try {
            PlayerStats.recordGameEnd(GameActivity.this, ProgressionRules.DRAW, Math.max(scoreA, scoreB));
            PlayerProgress.onGameFinished(GameActivity.this, false, Math.max(scoreA, scoreB),
                    PlayerStats.getBestStreak(GameActivity.this), usedAllHelps(), usedAnyHelp());
        } catch (Exception ignored) {
        }
        playSound(R.raw.new_level, false, false);
        showLocalTeamsResultScreen(headline, scoreA, scoreB, winSlot);
    }

    /** التحدي الرئيسي result: a simple text-only screen (no character reaction videos) —
     *  headline + the two team totals, the winner highlighted, then back to the menu. */
    private void showLocalTeamsResultScreen(String headline, int scoreA, int scoreB, int winSlot) {
        final FrameLayout overlay = (FrameLayout) findViewById(R.id.boardOverlay);
        if (overlay == null) {
            proceedAfterBoardResult();
            return;
        }
        boardResultProceeded = false;
        offlineContestants.release();
        overlay.removeAllViews();
        overlay.setBackgroundColor(0xF6050C1F);
        overlay.setVisibility(View.VISIBLE);
        overlay.bringToFront();

        ScrollView scroll = new ScrollView(this);
        scroll.setLayoutParams(new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT));
        scroll.setFillViewport(true);
        scroll.setVerticalScrollBarEnabled(false);
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setGravity(Gravity.CENTER);
        root.setPadding(dpx(24), dpx(16), dpx(24), dpx(16));
        scroll.addView(root);

        // Championship Crest Badge
        TextView crest = new TextView(this);
        crest.setText("👑🏆");
        crest.setTextSize(TypedValue.COMPLEX_UNIT_SP, 30f);
        crest.setGravity(Gravity.CENTER);
        crest.setBackground(gradientPillBg(0x66020617, 0x991E293B, 0x88FFD700, 1));
        LinearLayout.LayoutParams crestLp = new LinearLayout.LayoutParams(dpx(68), dpx(68));
        crestLp.bottomMargin = dpx(10);
        crest.setLayoutParams(crestLp);
        root.addView(crest);

        TextView tag = makeBoardText("بطولة التحدي الرئيسي • النتيجة النهائية", 12f, 0xFFFFD700, Gravity.CENTER);
        LinearLayout.LayoutParams tagLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        tagLp.bottomMargin = dpx(4);
        tag.setLayoutParams(tagLp);
        root.addView(tag);

        TextView title = makeBoardText(headline, 24f, 0xFFFFFFFF, Gravity.CENTER);
        LinearLayout.LayoutParams tlp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        tlp.bottomMargin = dpx(16);
        title.setLayoutParams(tlp);
        root.addView(title);

        // Dual Result Row
        LinearLayout resultsRow = new LinearLayout(this);
        resultsRow.setOrientation(LinearLayout.HORIZONTAL);
        resultsRow.setGravity(Gravity.CENTER_VERTICAL);
        LinearLayout.LayoutParams resLp = new LinearLayout.LayoutParams(
                dpx(540), LinearLayout.LayoutParams.WRAP_CONTENT);
        resLp.bottomMargin = dpx(16);
        resultsRow.setLayoutParams(resLp);

        resultsRow.addView(makeTeamResultCard(boardTeamAName, scoreA, winSlot == 0, 0xFFFFD700),
                new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f));

        View gap = new View(this);
        resultsRow.addView(gap, new LinearLayout.LayoutParams(dpx(12), 1));

        resultsRow.addView(makeTeamResultCard(boardTeamBName, scoreB, winSlot == 1, 0xFF38BDF8),
                new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f));

        root.addView(resultsRow);

        TextView rewards = makeBoardText(PlayerStats.matchRewardSummary(this), 15f, 0xFF7DD3FC, Gravity.CENTER);
        LinearLayout.LayoutParams rewardsLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        rewardsLp.bottomMargin = dpx(16);
        rewards.setLayoutParams(rewardsLp);
        root.addView(rewards);

        Button back = new Button(this);
        back.setText("العودة لإدارة المباريات 🏆");
        back.setAllCaps(false);
        back.setTextColor(0xFF030D1C);
        back.setTextSize(TypedValue.COMPLEX_UNIT_SP, 14.5f);
        if (getBoardFont() != null) back.setTypeface(getBoardFont(), Typeface.BOLD);
        back.setBackground(gradientPillBg(0xFFFFC727, 0xFFFFA000, 0xFFFFF1A8, 1));
        LinearLayout.LayoutParams blp = new LinearLayout.LayoutParams(dpx(240), dpx(46));
        back.setLayoutParams(blp);
        back.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                proceedAfterBoardResult();
            }
        });
        root.addView(back);

        overlay.addView(scroll);

        // Auto-continue if the players linger.
        new Handler().postDelayed(new Runnable() {
            @Override
            public void run() {
                if (!EXITING) proceedAfterBoardResult();
            }
        }, 16000);
    }

    /** One team's result card: Crest + Name + Score + Winner Badge */
    private View makeTeamResultCard(String name, int score, boolean won, int accent) {
        LinearLayout card = new LinearLayout(this);
        card.setOrientation(LinearLayout.VERTICAL);
        card.setGravity(Gravity.CENTER_HORIZONTAL);
        card.setBackground(cardBg(won ? 0xF20F244C : 0xD5071128, won ? 0xFFFFD700 : 0x4438BDF8, 16, won ? 2 : 1));
        card.setPadding(dpx(16), dpx(12), dpx(16), dpx(12));

        if (won) {
            TextView crownBadge = makeBoardText("👑 الفائز بالبطولة", 10.5f, 0xFFFFD700, Gravity.CENTER);
            crownBadge.setBackground(cardBg(0x33FFD700, 0x88FFD700, 999, 1));
            crownBadge.setPadding(dpx(10), dpx(2), dpx(10), dpx(2));
            LinearLayout.LayoutParams cbLp = new LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT);
            cbLp.bottomMargin = dpx(6);
            crownBadge.setLayoutParams(cbLp);
            card.addView(crownBadge);
        }

        TextView nameView = makeBoardText(name, 15f, accent, Gravity.CENTER);
        nameView.setMaxLines(1);
        nameView.setEllipsize(TextUtils.TruncateAt.END);
        card.addView(nameView);

        TextView scoreView = makeBoardText(score + " نقطة", 20f, 0xFFFFFFFF, Gravity.CENTER);
        LinearLayout.LayoutParams scLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        scLp.topMargin = dpx(4);
        scoreView.setLayoutParams(scLp);
        card.addView(scoreView);

        return card;
    }

    /** تحدي المراحل stage end: solo (reach boardTargetScore) or boss (beat every bot).
     *  Bridges into the campaign pipeline so Flutter awards stars/rewards/progress. */
    private void finishCampaignBoardMatch() {
        if (campaignResultPersisted) return;
        cancelBoardSelectTimer();
        cancelPendingBoardReveal();
        stopTimer(false);
        CAN_PLAY = false;
        CAN_HOME = false;
        hideBoardOverlay();

        final int count = Math.max(1, offlineContestants.contestantCount());
        final int myScore = offlineContestants.scoreForSlot(0);
        boolean completed;

        if ("boss".equals(boardCampaignKind)) {
            boolean beat = count > 1;
            for (int g = 1; g < count; g++) {
                int s = offlineContestants.scoreForSlot(g);
                if (s >= myScore) beat = false;   // must strictly beat every boss
            }
            completed = beat;
        } else {
            completed = myScore >= boardTargetScore;
        }

        // Feed the campaign result pipeline (score/correct counts -> stars in Flutter).
        String constraint = CampaignBoardRules.constraintFailure(campaignWrongAnswers,
                campaignMaxWrongAnswers, CampaignBoardRules.themedCategoryCount(
                        new ArrayList<>(boardCorrectCategories), boardWorldCategories),
                boardRequiredCategoryCount, boardCampaignDeadlineMs, System.currentTimeMillis());
        if (!constraint.isEmpty()) {
            completed = false;
            campaignFailureReason = constraint;
        } else {
            campaignFailureReason = completed ? "" : ("boss".equals(boardCampaignKind)
                    ? "boss_not_defeated" : "target_score_not_reached");
        }
        persistPendingCampaignStageResult(completed, myScore, campaignWrongAnswers);

        try {
            PlayerStats.recordGameEnd(GameActivity.this, completed, myScore);
            if (!campaignMode) {
                PlayerProgress.onGameFinished(GameActivity.this, completed, myScore,
                        PlayerStats.getBestStreak(GameActivity.this), usedAllHelps(), usedAnyHelp());
            }
        } catch (Exception ignored) {
        }
        // Flutter presents the stage result, stars and rewards. Return directly
        // instead of showing the generic board result and its auto-continue delay.
        proceedAfterBoardResult();
    }

    // =====================================================================
    //  Offline board ("التحدي") mode
    //  Flow: category select -> board grid -> question -> board -> ... -> end.
    //  You and the AI bots take turns picking a (category, value) cell; the
    //  picker answers and earns the cell value. The board holds one category per
    //  player with 6 cells each, so every contestant answers exactly 6 questions.
    // =====================================================================

    private void startBoardMode() {
        if (presenterDialogue.defer("boardStart", this::startBoardMode)) return;
        applyBoardModeChrome();
        if (boardCampaignMatch) {
            if (restoreCampaignBoardState(pendingCampaignBoardRestore)) {
                return;
            }
            startCampaignBoardMode();
            return;
        }
        // التحدي الرئيسي (two teams, hot-seat): always a 6-category board, regardless of
        // the two-contestant count. Collect the team names first, then the categories.
        if (boardLocalTeams) {
            boardCols = Math.max(2, Math.min(6, boardAllCategories.size()));
            if (restoreLocalTeamsBoardState(pendingLocalTeamsRestore)) {
                return;
            }
            if (pendingLocalTeamsRestore != null
                    && LocalTeamsGameStore.PHASE_CATEGORY_SELECT.equals(pendingLocalTeamsRestore.optString("phase"))) {
                localTeamsRestoreConsumed = true;
                boardTeamAName = pendingLocalTeamsRestore.optString("teamAName", boardTeamAName);
                boardTeamBName = pendingLocalTeamsRestore.optString("teamBName", boardTeamBName);
                offlineContestants.setContestantName(0, boardTeamAName);
                offlineContestants.setContestantName(1, boardTeamBName);
                saveLocalTeamsProgress(LocalTeamsGameStore.PHASE_CATEGORY_SELECT);
                showCategorySelect();
                return;
            }
            showTeamNamesSetup();
            return;
        }
        // One category card per player so every contestant answers exactly 6 questions
        // (two per value). Capped to the categories actually available.
        if (restoreOfflineBoardState(pendingOfflineBoardRestore)) {
            return;
        }
        if (pendingOfflineBoardRestore != null
                && OfflineBoardGameStore.PHASE_CATEGORY_SELECT.equals(pendingOfflineBoardRestore.optString("phase"))) {
            offlineBoardRestoreConsumed = true;
            saveOfflineBoardProgress(OfflineBoardGameStore.PHASE_CATEGORY_SELECT);
            showCategorySelect();
            return;
        }
        int players = offlineContestants.contestantCount();
        boardCols = Math.max(1, Math.min(players, boardAllCategories.size()));
        saveOfflineBoardProgress(OfflineBoardGameStore.PHASE_CATEGORY_SELECT);
        showCategorySelect();
    }

    /** Returns the full (untruncated) team name for a slot in the local two-team board. */
    private String boardTeamName(int slot) {
        return slot == 1 ? boardTeamBName : boardTeamAName;
    }

    private String boardOpeningGreeting() {
        if (boardCampaignMatch) return getCampaignOpeningMessage();
        if (boardLocalTeams) return localTeamsOpeningGreeting();
        if (pendingOfflineBoardRestore != null) {
            return OfflineBoardGameStore.PHASE_CATEGORY_SELECT.equals(
                    pendingOfflineBoardRestore.optString("phase"))
                    ? "أهلاً بعودتك! نتابع اختيار فئات المباراة."
                    : "أهلاً بعودتك! نكمل المباراة من حيث توقفت.";
        }
        if (recreatedGameSession || getIntent().getBooleanExtra("resumeOnlineMatch", false)) {
            return "أهلاً بعودتك! نكمل المباراة من حيث توقفت.";
        }
        return "مرحبا بكم في تحدي الفئات.. اختاروا فئاتكم";
    }

    private String localTeamsOpeningGreeting() {
        if (pendingLocalTeamsRestore == null) {
            return "تحدي الفرق! أدخلوا أسماء الفريقين";
        }
        String phase = pendingLocalTeamsRestore.optString("phase");
        if (LocalTeamsGameStore.PHASE_SETUP.equals(phase)) {
            return "أهلاً بعودتكم! نتابع إعداد الفريقين.";
        }
        if (LocalTeamsGameStore.PHASE_CATEGORY_SELECT.equals(phase)) {
            return "أهلاً بعودتكم! نتابع اختيار فئات المباراة.";
        }
        JSONObject state = pendingLocalTeamsRestore.optJSONObject("state");
        int slot = 0;
        if (state != null) {
            slot = state.optInt("pickerSlot", state.optInt("turnIndex", 0) % 2);
        } else {
            slot = pendingLocalTeamsRestore.optInt("turnIndex", 0) % 2;
        }
        slot = slot == 1 ? 1 : 0;
        String teamName = slot == 1
                ? pendingLocalTeamsRestore.optString("teamBName", boardTeamBName)
                : pendingLocalTeamsRestore.optString("teamAName", boardTeamAName);
        if (teamName == null || teamName.trim().isEmpty()) {
            teamName = boardTeamName(slot);
        }
        return "أهلا وسهلا بكم من جديد\nللتذكير: الدور الآن لـ " + teamName;
    }

    private void saveLocalTeamsProgress(String phase) {
        if (!boardLocalTeams || localTeamsFinished || localTeamsSaveId == null || localTeamsSaveId.trim().isEmpty()) {
            return;
        }
        try {
            JSONObject record = LocalTeamsGameStore.get(this, localTeamsSaveId);
            if (record == null) {
                record = LocalTeamsGameStore.baseRecord(localTeamsSaveId);
            }
            long now = System.currentTimeMillis();
            if (!record.has("createdAt")) {
                record.put("createdAt", now);
            }
            String safePhase = (phase == null || phase.trim().isEmpty())
                    ? currentLocalTeamsPhase() : phase.trim();
            int scoreA = offlineContestants == null ? 0 : offlineContestants.scoreForSlot(0);
            int scoreB = offlineContestants == null ? 0 : offlineContestants.scoreForSlot(1);
            record.put("updatedAt", now);
            record.put("status", LocalTeamsGameStore.STATUS_IN_PROGRESS);
            record.put("phase", safePhase);
            record.put("teamAName", boardTeamAName);
            record.put("teamBName", boardTeamBName);
            record.put("scoreA", scoreA);
            record.put("scoreB", scoreB);
            record.put("turnIndex", Math.max(0, boardTurnIndex));
            record.put("totalTurns", Math.max(0, boardTotalTurns));
            record.put("winnerSlot", -2);
            record.put("winnerName", "");

            JSONObject state = new JSONObject();
            state.put("phase", safePhase);
            state.put("boardCols", boardCols);
            state.put("cellsRemaining", boardCellsRemaining);
            state.put("turnIndex", boardTurnIndex);
            state.put("totalTurns", boardTotalTurns);
            state.put("pickerSlot", boardPickerSlot);
            state.put("pickedCol", boardPickedCol);
            state.put("pickedRow", boardPickedRow);
            state.put("revealCount", boardRevealCount);
            state.put("stealActive", boardStealActive);
            state.put("optionsRevealed", boardOptionsRevealed);

            JSONArray scores = new JSONArray();
            scores.put(scoreA);
            scores.put(scoreB);
            state.put("scores", scores);

            JSONArray categories = new JSONArray();
            for (String category : boardSelectedCategories) {
                categories.put(category == null ? "" : category);
            }
            state.put("selectedCategories", categories);

            JSONArray cells = new JSONArray();
            if (boardCellQuestion != null) {
                for (int col = 0; col < boardCols; col++) {
                    JSONArray colArray = new JSONArray();
                    for (int row = 0; row < BOARD_ROWS; row++) {
                        JSONObject cell = new JSONObject();
                        cell.put("consumed", boardCellConsumed != null
                                && col < boardCellConsumed.length
                                && boardCellConsumed[col] != null
                                && row < boardCellConsumed[col].length
                                && boardCellConsumed[col][row]);
                        Question q = (col < boardCellQuestion.length && boardCellQuestion[col] != null
                                && row < boardCellQuestion[col].length)
                                ? boardCellQuestion[col][row] : null;
                        cell.put("question", questionToJson(q));
                        colArray.put(cell);
                    }
                    cells.put(colArray);
                }
            }
            state.put("cells", cells);
            record.put("state", state);
            LocalTeamsGameStore.upsert(this, record);
        } catch (Exception ignored) {
        }
    }

    private void saveLocalTeamsFinished(int scoreA, int scoreB, int winSlot) {
        if (!boardLocalTeams || localTeamsSaveId == null || localTeamsSaveId.trim().isEmpty()) {
            return;
        }
        localTeamsFinished = true;
        try {
            JSONObject record = LocalTeamsGameStore.get(this, localTeamsSaveId);
            if (record == null) {
                record = LocalTeamsGameStore.baseRecord(localTeamsSaveId);
            }
            long now = System.currentTimeMillis();
            record.put("updatedAt", now);
            record.put("completedAt", now);
            record.put("status", LocalTeamsGameStore.STATUS_FINISHED);
            record.put("phase", LocalTeamsGameStore.PHASE_FINISHED);
            record.put("teamAName", boardTeamAName);
            record.put("teamBName", boardTeamBName);
            record.put("scoreA", scoreA);
            record.put("scoreB", scoreB);
            record.put("turnIndex", Math.max(0, boardTurnIndex));
            record.put("totalTurns", Math.max(0, boardTotalTurns));
            record.put("winnerSlot", winSlot);
            record.put("winnerName", winSlot < 0 ? "" : boardTeamName(winSlot));
            LocalTeamsGameStore.upsert(this, record);
        } catch (Exception ignored) {
        }
    }

    private String currentLocalTeamsPhase() {
        if (boardCurrentQuestion != null) return LocalTeamsGameStore.PHASE_QUESTION;
        if (boardSelectedCategories.isEmpty()) return LocalTeamsGameStore.PHASE_CATEGORY_SELECT;
        return LocalTeamsGameStore.PHASE_BOARD;
    }

    private Set<Question> savedBoardQuestions(JSONArray cells) {
        Set<Question> saved = new HashSet<>();
        if (cells != null) for (int col = 0; col < cells.length(); col++) {
            JSONArray column = cells.optJSONArray(col);
            if (column == null) continue;
            for (int row = 0; row < column.length(); row++) {
                JSONObject cell = column.optJSONObject(row);
                Question q = cell == null ? null : questionFromJson(cell.optJSONObject("question"));
                if (q != null) saved.add(q);
            }
        }
        // Restored allocations stay playable, while repairs must avoid every
        // saved cell, including cells later in the serialized board.
        QuestionHistory.recordAll(this, saved);
        return saved;
    }

    private Set<String> savedConsumedQuestionKeys(JSONArray cells) {
        Set<String> consumed = new HashSet<>();
        if (cells != null) for (int col = 0; col < cells.length(); col++) {
            JSONArray column = cells.optJSONArray(col);
            if (column == null) continue;
            for (int row = 0; row < column.length(); row++) {
                JSONObject cell = column.optJSONObject(row);
                if (cell == null || !cell.optBoolean("consumed", false)) continue;
                Question q = questionFromJson(cell.optJSONObject("question"));
                if (q != null) consumed.add(QuestionIdentity.key(q));
            }
        }
        return consumed;
    }

    private boolean restoreLocalTeamsBoardState(JSONObject record) {
        if (record == null || localTeamsRestoreConsumed) return false;
        JSONObject state = record.optJSONObject("state");
        if (state == null) return false;
        JSONArray categories = state.optJSONArray("selectedCategories");
        if (categories == null || categories.length() == 0) return false;

        localTeamsRestoreConsumed = true;
        stopCategorySelectMusicIfPlaying();
        boardTeamAName = record.optString("teamAName", boardTeamAName);
        boardTeamBName = record.optString("teamBName", boardTeamBName);
        offlineContestants.setContestantName(0, boardTeamAName);
        offlineContestants.setContestantName(1, boardTeamBName);
        offlineContestants.setScoreForSlot(0, record.optInt("scoreA", 0));
        offlineContestants.setScoreForSlot(1, record.optInt("scoreB", 0));

        boardSelectedCategories.clear();
        for (int i = 0; i < categories.length(); i++) {
            String category = categories.optString(i, "");
            if (!category.trim().isEmpty()) boardSelectedCategories.add(category);
        }
        boardCols = Math.max(1, Math.min(boardSelectedCategories.size(), state.optInt("boardCols", boardSelectedCategories.size())));
        boardCellQuestion = new Question[boardCols][BOARD_ROWS];
        boardCellConsumed = new boolean[boardCols][BOARD_ROWS];

        JSONArray cells = state.optJSONArray("cells");
        Set<Question> used = savedBoardQuestions(cells);
        Set<String> restoredKeys = savedConsumedQuestionKeys(cells);
        for (int col = 0; col < boardCols; col++) {
            for (int row = 0; row < BOARD_ROWS; row++) {
                JSONObject cell = null;
                if (cells != null) {
                    JSONArray colArray = cells.optJSONArray(col);
                    if (colArray != null) cell = colArray.optJSONObject(row);
                }
                if (cell != null) {
                    boardCellConsumed[col][row] = cell.optBoolean("consumed", false);
                    boardCellQuestion[col][row] = questionFromJson(cell.optJSONObject("question"));
                    Question restored = boardCellQuestion[col][row];
                    if (restored != null && !restoredKeys.add(QuestionIdentity.key(restored)) && !boardCellConsumed[col][row])
                        boardCellQuestion[col][row] = null;
                }
                if (boardCellQuestion[col][row] == null) {
                    String category = boardSelectedCategories.get(Math.min(col, boardSelectedCategories.size() - 1));
                    boardCellQuestion[col][row] = drawBoardQuestion(category, boardTierForRow(row), used);
                }
                if (boardCellQuestion[col][row] == null) {
                    questionSelectionFailed(new IllegalStateException(QuestionHistory.EXHAUSTED)); finish(); return true;
                }
            }
        }
        QuestionHistory.recordAll(this, used);

        boardCellsRemaining = state.optInt("cellsRemaining", countRemainingBoardCells());
        boardTurnIndex = state.optInt("turnIndex", 0);
        boardTotalTurns = state.optInt("totalTurns", Math.max(0, boardCols * BOARD_ROWS));
        boardPickerSlot = state.optInt("pickerSlot", 0);
        boardPickedCol = state.optInt("pickedCol", -1);
        boardPickedRow = state.optInt("pickedRow", -1);
        boardRevealCount = Math.max(0, state.optInt("revealCount", 0));
        boardStealActive = state.optBoolean("stealActive", false);
        boardOptionsRevealed = state.optBoolean("optionsRevealed", false);
        boardPickerIsHuman = true;

        String phase = state.optString("phase", record.optString("phase", LocalTeamsGameStore.PHASE_BOARD));
        if (LocalTeamsGameStore.PHASE_QUESTION.equals(phase)
                && boardPickedCol >= 0 && boardPickedCol < boardCols
                && boardPickedRow >= 0 && boardPickedRow < BOARD_ROWS
                && !boardCellConsumed[boardPickedCol][boardPickedRow]) {
            boardCurrentQuestion = boardCellQuestion[boardPickedCol][boardPickedRow];
            hideBoardOverlay();
            initQuestion();
            CAN_PLAY = false;
            showBoardQuestion(boardCurrentQuestion, true);
        } else {
            beginBoardTurn();
        }
        return true;
    }

    private int countRemainingBoardCells() {
        if (boardCellConsumed == null) return Math.max(0, boardCols * BOARD_ROWS);
        int remaining = 0;
        for (int col = 0; col < boardCellConsumed.length; col++) {
            if (boardCellConsumed[col] == null) continue;
            for (int row = 0; row < boardCellConsumed[col].length; row++) {
                if (!boardCellConsumed[col][row]) remaining++;
            }
        }
        return remaining;
    }

    private JSONObject questionToJson(Question q) {
        JSONObject json = new JSONObject();
        if (q == null) return json;
        try {
            json.put("Level", safeString(q.getLevel()));
            json.put("Q", safeString(q.getQ()));
            json.put("R", safeString(q.getR()));
            json.put("W1", safeString(q.getW1()));
            json.put("W2", safeString(q.getW2()));
            json.put("W3", safeString(q.getW3()));
            json.put("Category", safeString(q.getCategory()));
            json.put("Img", safeString(q.getImg()));
            json.put("ClubPath", new JSONArray(q.getClubPath() == null
                    ? new ArrayList<String>() : q.getClubPath()));
        } catch (Exception ignored) {
        }
        return json;
    }

    private Question questionFromJson(JSONObject json) {
        if (json == null || json.length() == 0) return null;
        Question q = new Question();
        q.setLevel(json.optString("Level", "0"));
        q.setQ(json.optString("Q", ""));
        q.setR(json.optString("R", ""));
        q.setW1(json.optString("W1", ""));
        q.setW2(json.optString("W2", ""));
        q.setW3(json.optString("W3", ""));
        q.setCategory(json.optString("Category", ""));
        q.setImg(json.optString("Img", ""));
        JSONArray clubs = json.optJSONArray("ClubPath");
        if (clubs != null) {
            ArrayList<String> clubPath = new ArrayList<>();
            for (int i = 0; i < clubs.length(); i++) {
                String club = clubs.optString(i, "").trim();
                if (!club.isEmpty()) clubPath.add(club);
            }
            q.setClubPath(clubPath);
        }
        return q.getQ() == null || q.getQ().trim().isEmpty() ? null : q;
    }

    private boolean isRecoverableBotBoard() {
        return modeOnline && boardMode && !boardOnline && !boardRoomMatch
                && "board".equals(getIntent().getStringExtra("matchMode"));
    }

    private boolean shouldSaveOfflineBoard() {
        return boardMode
                && !boardLocalTeams
                && !boardOnline
                && !boardRoomMatch
                && !boardCampaignMatch
                && !campaignMode
                && !campaignBossBattle
                && offlineBoardSaveId != null
                && !offlineBoardSaveId.trim().isEmpty();
    }

    private void saveOfflineBoardProgress(String phase) {
        if (!shouldSaveOfflineBoard() || offlineBoardFinished) return;
        try {
            JSONObject record = isRecoverableBotBoard() ? OnlineMatchRecovery.botCheckpoint(this)
                    : OfflineBoardGameStore.get(this, offlineBoardSaveId);
            if (record == null) {
                record = OfflineBoardGameStore.baseRecord(offlineBoardSaveId);
            }
            long now = System.currentTimeMillis();
            if (!record.has("createdAt")) {
                record.put("createdAt", now);
            }
            String safePhase = (phase == null || phase.trim().isEmpty())
                    ? currentOfflineBoardPhase() : phase.trim();
            int playerCount = offlineContestants == null ? 0 : offlineContestants.contestantCount();
            record.put("updatedAt", now);
            record.put("status", OfflineBoardGameStore.STATUS_IN_PROGRESS);
            record.put("phase", safePhase);
            record.put("playerCount", Math.max(2, playerCount));
            record.put("characterIndex", boardCharacterIndex);
            record.put("turnIndex", Math.max(0, boardTurnIndex));
            record.put("totalTurns", Math.max(0, boardTotalTurns));
            record.put("winnerSlot", -2);
            record.put("winnerName", "");
            putOfflineBoardScoreSummary(record);

            JSONObject state = new JSONObject();
            state.put("phase", safePhase);
            state.put("boardCols", boardCols);
            state.put("cellsRemaining", boardCellsRemaining);
            state.put("turnIndex", boardTurnIndex);
            state.put("totalTurns", boardTotalTurns);
            state.put("pickerSlot", boardPickerSlot);
            state.put("pickerIsHuman", boardPickerIsHuman);
            state.put("pickedCol", boardPickedCol);
            state.put("pickedRow", boardPickedRow);
            state.put("revealCount", boardRevealCount);
            state.put("optionsRevealed", boardOptionsRevealed);

            JSONArray names = new JSONArray();
            JSONArray scores = new JSONArray();
            JSONArray intelligence = new JSONArray();
            for (int i = 0; i < playerCount; i++) {
                names.put(offlineContestants.nameForSlot(i));
                scores.put(offlineContestants.scoreForSlot(i));
                intelligence.put(offlineContestants.intelligenceForSlot(i));
            }
            state.put("names", names);
            state.put("scores", scores);
            state.put("intelligence", intelligence);
            record.put("names", names);
            record.put("scores", scores);

            JSONArray categories = new JSONArray();
            for (String category : boardSelectedCategories) {
                categories.put(category == null ? "" : category);
            }
            state.put("selectedCategories", categories);

            JSONArray cells = new JSONArray();
            if (boardCellQuestion != null) {
                for (int col = 0; col < boardCols; col++) {
                    JSONArray colArray = new JSONArray();
                    for (int row = 0; row < BOARD_ROWS; row++) {
                        JSONObject cell = new JSONObject();
                        cell.put("consumed", boardCellConsumed != null
                                && col < boardCellConsumed.length
                                && boardCellConsumed[col] != null
                                && row < boardCellConsumed[col].length
                                && boardCellConsumed[col][row]);
                        Question q = (col < boardCellQuestion.length && boardCellQuestion[col] != null
                                && row < boardCellQuestion[col].length)
                                ? boardCellQuestion[col][row] : null;
                        cell.put("question", questionToJson(q));
                        colArray.put(cell);
                    }
                    cells.put(colArray);
                }
            }
            state.put("cells", cells);
            record.put("state", state);
            if (isRecoverableBotBoard()) {
                if (OfflineBoardGameStore.PHASE_QUESTION.equals(safePhase) && boardPickerIsHuman
                        && (isQuestionTimerRunning || wasTimerRunningBeforePause))
                    state.put("questionDeadlineAt", System.currentTimeMillis() + Math.max(0, PROGRESS_VALUE) * 100L);
                OnlineMatchRecovery.saveBotCheckpoint(this, record);
            } else OfflineBoardGameStore.upsert(this, record);
        } catch (Exception ignored) {
        }
    }

    private void saveOfflineBoardFinished() {
        if (!shouldSaveOfflineBoard()) return;
        offlineBoardFinished = true;
        if (isRecoverableBotBoard()) return;
        try {
            JSONObject record = OfflineBoardGameStore.get(this, offlineBoardSaveId);
            if (record == null) {
                record = OfflineBoardGameStore.baseRecord(offlineBoardSaveId);
            }
            long now = System.currentTimeMillis();
            record.put("updatedAt", now);
            record.put("completedAt", now);
            record.put("status", OfflineBoardGameStore.STATUS_FINISHED);
            record.put("phase", OfflineBoardGameStore.PHASE_FINISHED);
            record.put("playerCount", offlineContestants == null ? 0 : offlineContestants.contestantCount());
            record.put("characterIndex", boardCharacterIndex);
            record.put("turnIndex", Math.max(0, boardTurnIndex));
            record.put("totalTurns", Math.max(0, boardTotalTurns));

            int count = offlineContestants == null ? 0 : offlineContestants.contestantCount();
            int bestScore = -1;
            int bestSlot = -1;
            int bestCount = 0;
            JSONArray names = new JSONArray();
            JSONArray scores = new JSONArray();
            for (int i = 0; i < count; i++) {
                int score = offlineContestants.scoreForSlot(i);
                names.put(offlineContestants.nameForSlot(i));
                scores.put(score);
                if (score > bestScore) {
                    bestScore = score;
                    bestSlot = i;
                    bestCount = 1;
                } else if (score == bestScore) {
                    bestCount++;
                }
            }
            int winnerSlot = bestCount == 1 ? bestSlot : -1;
            record.put("names", names);
            record.put("scores", scores);
            record.put("playerScore", count > 0 ? offlineContestants.scoreForSlot(0) : 0);
            record.put("leaderScore", Math.max(0, bestScore));
            record.put("leaderName", bestSlot >= 0 ? offlineContestants.nameForSlot(bestSlot) : "");
            record.put("winnerSlot", winnerSlot);
            record.put("winnerName", winnerSlot >= 0 ? offlineContestants.nameForSlot(winnerSlot) : "");
            OfflineBoardGameStore.upsert(this, record);
        } catch (Exception ignored) {
        }
    }

    private void putOfflineBoardScoreSummary(JSONObject record) throws Exception {
        int count = offlineContestants == null ? 0 : offlineContestants.contestantCount();
        int bestScore = -1;
        int bestSlot = -1;
        for (int i = 0; i < count; i++) {
            int score = offlineContestants.scoreForSlot(i);
            if (score > bestScore) {
                bestScore = score;
                bestSlot = i;
            }
        }
        record.put("playerScore", count > 0 ? offlineContestants.scoreForSlot(0) : 0);
        record.put("leaderScore", Math.max(0, bestScore));
        record.put("leaderName", bestSlot >= 0 ? offlineContestants.nameForSlot(bestSlot) : "");
    }

    private String currentOfflineBoardPhase() {
        if (boardCurrentQuestion != null) return OfflineBoardGameStore.PHASE_QUESTION;
        if (boardSelectedCategories.isEmpty()) return OfflineBoardGameStore.PHASE_CATEGORY_SELECT;
        return OfflineBoardGameStore.PHASE_BOARD;
    }

    private boolean restoreOfflineBoardState(JSONObject record) {
        if (record == null || offlineBoardRestoreConsumed) return false;
        JSONObject state = record.optJSONObject("state");
        if (state == null) return false;
        if (isRecoverableBotBoard()) restoredBotQuestionDeadline =
                OfflineBoardGameStore.PHASE_QUESTION.equals(state.optString("phase"))
                        && state.optBoolean("pickerIsHuman") ? state.optLong("questionDeadlineAt", 0L) : 0L;
        JSONArray categories = state.optJSONArray("selectedCategories");
        if (categories == null || categories.length() == 0) return false;

        offlineBoardRestoreConsumed = true;
        stopCategorySelectMusicIfPlaying();
        JSONArray names = state.optJSONArray("names");
        JSONArray scores = state.optJSONArray("scores");
        JSONArray intelligence = state.optJSONArray("intelligence");
        int count = offlineContestants.contestantCount();
        for (int i = 0; i < count; i++) {
            if (names != null) offlineContestants.setContestantName(i, names.optString(i, offlineContestants.nameForSlot(i)));
            if (scores != null) offlineContestants.setScoreForSlot(i, scores.optInt(i, 0));
            if (intelligence != null) offlineContestants.setIntelligenceForSlot(i, intelligence.optInt(i, offlineContestants.intelligenceForSlot(i)));
        }

        boardSelectedCategories.clear();
        for (int i = 0; i < categories.length(); i++) {
            String category = categories.optString(i, "");
            if (!category.trim().isEmpty()) boardSelectedCategories.add(category);
        }
        boardCols = Math.max(1, Math.min(boardSelectedCategories.size(),
                state.optInt("boardCols", boardSelectedCategories.size())));
        boardCellQuestion = new Question[boardCols][BOARD_ROWS];
        boardCellConsumed = new boolean[boardCols][BOARD_ROWS];

        JSONArray cells = state.optJSONArray("cells");
        Set<Question> used = savedBoardQuestions(cells);
        Set<String> restoredKeys = savedConsumedQuestionKeys(cells);
        for (int col = 0; col < boardCols; col++) {
            for (int row = 0; row < BOARD_ROWS; row++) {
                JSONObject cell = null;
                if (cells != null) {
                    JSONArray colArray = cells.optJSONArray(col);
                    if (colArray != null) cell = colArray.optJSONObject(row);
                }
                if (cell != null) {
                    boardCellConsumed[col][row] = cell.optBoolean("consumed", false);
                    boardCellQuestion[col][row] = questionFromJson(cell.optJSONObject("question"));
                    Question restored = boardCellQuestion[col][row];
                    if (restored != null && !restoredKeys.add(QuestionIdentity.key(restored)) && !boardCellConsumed[col][row])
                        boardCellQuestion[col][row] = null;
                }
                if (boardCellQuestion[col][row] == null) {
                    String category = boardSelectedCategories.get(Math.min(col, boardSelectedCategories.size() - 1));
                    boardCellQuestion[col][row] = drawBoardQuestion(category, boardTierForRow(row), used);
                }
                if (boardCellQuestion[col][row] == null) {
                    questionSelectionFailed(new IllegalStateException(QuestionHistory.EXHAUSTED)); finish(); return true;
                }
            }
        }
        QuestionHistory.recordAll(this, used);

        boardCellsRemaining = state.optInt("cellsRemaining", countRemainingBoardCells());
        boardTurnIndex = state.optInt("turnIndex", 0);
        boardTotalTurns = state.optInt("totalTurns", Math.max(0, boardCols * BOARD_ROWS));
        boardPickerSlot = state.optInt("pickerSlot", 0);
        boardPickerIsHuman = state.optBoolean("pickerIsHuman", boardPickerSlot == 0);
        boardPickedCol = state.optInt("pickedCol", -1);
        boardPickedRow = state.optInt("pickedRow", -1);
        boardRevealCount = Math.max(0, state.optInt("revealCount", 0));
        boardOptionsRevealed = state.optBoolean("optionsRevealed", false);

        String phase = state.optString("phase", record.optString("phase", OfflineBoardGameStore.PHASE_BOARD));
        if (OfflineBoardGameStore.PHASE_QUESTION.equals(phase)
                && boardPickedCol >= 0 && boardPickedCol < boardCols
                && boardPickedRow >= 0 && boardPickedRow < BOARD_ROWS
                && !boardCellConsumed[boardPickedCol][boardPickedRow]) {
            boardCurrentQuestion = boardCellQuestion[boardPickedCol][boardPickedRow];
            hideBoardOverlay();
            initQuestion();
            CAN_PLAY = false;
            showBoardQuestion(boardCurrentQuestion, boardPickerIsHuman);
        } else {
            beginBoardTurn();
        }
        return true;
    }

    private boolean isCampaignResume() {
        return campaignMode && (pendingCampaignBoardRestore != null || pendingCampaignResumeQuestion >= 0);
    }

    private void clearCampaignProgress() {
        CampaignProgressStore.clear(this);
        pendingCampaignBoardRestore = null;
        pendingCampaignResumeQuestion = -1;
    }

    private void loadCampaignProgressIfNeeded(Bundle savedInstanceState) {
        if (!campaignMode || campaignStageId == null || campaignStageId.trim().isEmpty()) return;
        try {
            JSONObject record = null;
            if (savedInstanceState != null && savedInstanceState.containsKey("campaignProgressJson")) {
                String raw = savedInstanceState.getString("campaignProgressJson");
                if (raw != null && !raw.trim().isEmpty()) {
                    record = new JSONObject(raw);
                }
            }
            if (record == null) {
                record = CampaignProgressStore.get(this, campaignStageId);
            }
            if (record == null) return;

            if (!campaignStageId.equals(record.optString("stageId", ""))) {
                return;
            }
            if (!campaignId.equals(record.optString("campaignId", campaignId))) return;
            if (campaignBoard != record.optBoolean("campaignBoard", false)) return;
            campaignAttemptId = record.optString("attemptId", campaignAttemptId);
            getIntent().putExtra("campaignAttemptId", campaignAttemptId);

            campaignCorrectAnswers = record.optInt("correctAnswers", campaignCorrectAnswers);
            campaignWrongAnswers = record.optInt("wrongAnswers", campaignWrongAnswers);
            campaignAnsweredQuestions = record.optInt("answeredQuestions", campaignAnsweredQuestions);
            campaignLivesRemaining = record.optInt("livesRemaining", campaignLivesRemaining);
            campaignStartedAtMs = record.optLong("startedAtMs", campaignStartedAtMs);
            usedHelp5050 = record.optBoolean("usedHelp5050", usedHelp5050);
            usedHelpAudience = record.optBoolean("usedHelpAudience", usedHelpAudience);
            usedHelpCall = record.optBoolean("usedHelpCall", usedHelpCall);

            if (campaignBoard) {
                // A saved attempt keeps the rules it started with. Legacy saves
                // predate these constraints and must remain playable unchanged.
                campaignTimeLimitSeconds = record.optInt("boardTimeLimitSeconds", 0);
                campaignMaxWrongAnswers = record.optInt("boardMaxWrongAnswers", 0);
                boardRequiredCategoryCount = record.optInt("boardRequiredCategoryCount", 0);
                boardBossStyle = record.optString("boardBossStyle", "balanced");
                boardAllowRevealOptions = record.optBoolean("boardAllowRevealOptions", true);
                boardDesignVersion = record.optInt("boardDesignVersion", 0);
                JSONObject savedBoard = record.optJSONObject("state");
                int legacyOrder = 1;
                try { legacyOrder = Integer.parseInt(campaignStageId.replace("stage_", "")); } catch (Exception ignored) { }
                int legacyPicks = legacyOrder % 10 == 0 ? 6 : legacyOrder % 10 == 3 || legacyOrder % 10 == 7 ? 5 : legacyOrder % 10 == 5 || legacyOrder % 10 == 8 ? 7 : 6;
                boardSoloCols = record.optInt("boardSoloCols", savedBoard == null ? 4 : savedBoard.optInt("boardCols", 4));
                boardSoloPicks = record.optInt("boardSoloPicks", legacyPicks);
                int legacyMaximum = CampaignBoardRules.maximumScore("boss".equals(boardCampaignKind) ? Math.min(8, (legacyOrder - 1) / 10 + 2) : 4, legacyPicks);
                int legacyTarget = Math.min(Math.round((500 + legacyOrder * 22 + (legacyOrder % 10 == 0 ? 180 : 0)) * legacyPicks / 120f) * 20,
                        CampaignBoardRules.maximumScore(4, legacyPicks) - 600);
                boardTargetScore = record.optInt("boardTargetScore", legacyTarget);
                boardTwoStarScore = record.optInt("boardTwoStarScore", Math.min(Math.round(boardTargetScore * 1.25f), legacyMaximum - 400));
                boardThreeStarScore = record.optInt("boardThreeStarScore", Math.min(Math.round(boardTargetScore * 1.55f), legacyMaximum - 200));
                boardCategoryPolicy = record.optString("boardCategoryPolicy", "playerPick");
                boardMyCorrectCount = record.optInt("boardMyCorrectCount", boardMyCorrectCount);
                boardCampaignDeadlineMs = record.optLong("boardDeadlineMs", 0L);
                JSONArray wonCategories = record.optJSONArray("boardCorrectCategories");
                if (wonCategories != null) {
                    for (int i = 0; i < wonCategories.length(); i++) {
                        boardCorrectCategories.add(wonCategories.optString(i));
                    }
                }
                pendingCampaignBoardRestore = record;
            } else {
                int resumeIndex = record.optInt("currentQuestion", -1);
                if (resumeIndex >= 0) {
                    pendingCampaignResumeQuestion = resumeIndex;
                    savedCampaignAmount = record.optString("currentAmount", "$0");
                    currentStep = record.optInt("currentStep", resumeIndex);

                    JSONArray qArr = record.optJSONArray("questions");
                    if (qArr != null && qArr.length() > 0) {
                        ArrayList<Question> loadedQuestions = new ArrayList<>();
                        for (int i = 0; i < qArr.length(); i++) {
                            Question q = questionFromJson(qArr.optJSONObject(i));
                            if (q != null) loadedQuestions.add(q);
                        }
                        if (!loadedQuestions.isEmpty()) {
                            QuestionHistory.recordAll(this, loadedQuestions);
                            questions = loadedQuestions;
                            questionsReady = true;
                        }
                    }
                }
            }
        } catch (Exception ignored) {}
    }

    private void saveCampaignProgress(String phase) {
        if (!campaignMode || campaignResultPersisted || EXITING) return;
        if (campaignBoard) {
            saveCampaignBoardProgress(phase);
        } else {
            saveCampaignClassicProgress();
        }
    }

    private void saveCampaignBoardProgress(String phase) {
        if (!campaignMode || !campaignBoard || campaignResultPersisted || EXITING) return;
        try {
            JSONObject record = new JSONObject();
            long now = System.currentTimeMillis();
            record.put("stageId", campaignStageId);
            record.put("campaignId", campaignId);
            record.put("attemptId", campaignAttemptId);
            record.put("mode", "campaign");
            record.put("campaignBoard", true);
            record.put("boardKind", boardCampaignKind);
            record.put("updatedAt", now);
            record.put("status", OfflineBoardGameStore.STATUS_IN_PROGRESS);
            String safePhase = (phase == null || phase.trim().isEmpty())
                    ? currentOfflineBoardPhase() : phase.trim();
            record.put("phase", safePhase);
            int playerCount = offlineContestants == null ? 0 : offlineContestants.contestantCount();
            record.put("playerCount", Math.max(1, playerCount));
            record.put("characterIndex", boardCharacterIndex);
            record.put("turnIndex", Math.max(0, boardTurnIndex));
            record.put("totalTurns", Math.max(0, boardTotalTurns));
            record.put("boardMyCorrectCount", Math.max(0, boardMyCorrectCount));
            record.put("boardDeadlineMs", boardCampaignDeadlineMs);
            record.put("boardTimeLimitSeconds", campaignTimeLimitSeconds);
            record.put("boardMaxWrongAnswers", campaignMaxWrongAnswers);
            record.put("boardRequiredCategoryCount", boardRequiredCategoryCount);
            record.put("boardBossStyle", boardBossStyle);
            record.put("boardAllowRevealOptions", boardAllowRevealOptions);
            record.put("boardDesignVersion", boardDesignVersion);
            record.put("boardSoloCols", boardSoloCols);
            record.put("boardSoloPicks", boardSoloPicks);
            record.put("boardTargetScore", boardTargetScore);
            record.put("boardTwoStarScore", boardTwoStarScore);
            record.put("boardThreeStarScore", boardThreeStarScore);
            record.put("boardCategoryPolicy", boardCategoryPolicy);
            record.put("boardCorrectCategories", new JSONArray(boardCorrectCategories));
            record.put("correctAnswers", Math.max(0, campaignCorrectAnswers));
            record.put("wrongAnswers", Math.max(0, campaignWrongAnswers));
            record.put("answeredQuestions", Math.max(0, campaignAnsweredQuestions));
            record.put("livesRemaining", Math.max(0, campaignLivesRemaining));
            record.put("startedAtMs", campaignStartedAtMs);
            record.put("usedHelp5050", usedHelp5050);
            record.put("usedHelpAudience", usedHelpAudience);
            record.put("usedHelpCall", usedHelpCall);

            JSONObject state = new JSONObject();
            state.put("phase", safePhase);
            state.put("boardCols", boardCols);
            state.put("cellsRemaining", boardCellsRemaining);
            state.put("turnIndex", boardTurnIndex);
            state.put("totalTurns", boardTotalTurns);
            state.put("pickerSlot", boardPickerSlot);
            state.put("pickerIsHuman", boardPickerIsHuman);
            state.put("pickedCol", boardPickedCol);
            state.put("pickedRow", boardPickedRow);
            state.put("revealCount", boardRevealCount);
            state.put("optionsRevealed", boardOptionsRevealed);

            JSONArray names = new JSONArray();
            JSONArray scores = new JSONArray();
            JSONArray intelligence = new JSONArray();
            for (int i = 0; i < playerCount; i++) {
                names.put(offlineContestants.nameForSlot(i));
                scores.put(offlineContestants.scoreForSlot(i));
                intelligence.put(offlineContestants.intelligenceForSlot(i));
            }
            state.put("names", names);
            state.put("scores", scores);
            state.put("intelligence", intelligence);
            record.put("names", names);
            record.put("scores", scores);

            JSONArray categories = new JSONArray();
            for (String category : boardSelectedCategories) {
                categories.put(category == null ? "" : category);
            }
            state.put("selectedCategories", categories);

            JSONArray cells = new JSONArray();
            if (boardCellQuestion != null) {
                for (int col = 0; col < boardCols; col++) {
                    JSONArray colArray = new JSONArray();
                    for (int row = 0; row < BOARD_ROWS; row++) {
                        JSONObject cell = new JSONObject();
                        cell.put("consumed", boardCellConsumed != null
                                && col < boardCellConsumed.length
                                && boardCellConsumed[col] != null
                                && row < boardCellConsumed[col].length
                                && boardCellConsumed[col][row]);
                        Question q = (col < boardCellQuestion.length && boardCellQuestion[col] != null
                                && row < boardCellQuestion[col].length)
                                ? boardCellQuestion[col][row] : null;
                        cell.put("question", questionToJson(q));
                        colArray.put(cell);
                    }
                    cells.put(colArray);
                }
            }
            state.put("cells", cells);
            record.put("state", state);

            CampaignProgressStore.save(this, campaignStageId, record);
        } catch (Exception ignored) {}
    }

    private void saveCampaignClassicProgress() {
        if (!campaignMode || campaignBoard || campaignResultPersisted || EXITING) return;
        if (currentQuestion < 0) return;
        try {
            JSONObject record = new JSONObject();
            record.put("stageId", campaignStageId);
            record.put("campaignId", campaignId);
            record.put("attemptId", campaignAttemptId);
            record.put("mode", "campaign");
            record.put("campaignBoard", false);
            record.put("currentQuestion", currentQuestion);
            record.put("currentStep", currentStep);
            record.put("currentAmount", txtAmount != null ? txtAmount.getText().toString() : "$0");
            record.put("correctAnswers", campaignCorrectAnswers);
            record.put("wrongAnswers", campaignWrongAnswers);
            record.put("answeredQuestions", campaignAnsweredQuestions);
            record.put("livesRemaining", campaignLivesRemaining);
            record.put("startedAtMs", campaignStartedAtMs);
            record.put("usedHelp5050", usedHelp5050);
            record.put("usedHelpAudience", usedHelpAudience);
            record.put("usedHelpCall", usedHelpCall);

            if (questions != null && !questions.isEmpty()) {
                JSONArray qArr = new JSONArray();
                for (Question q : questions) {
                    qArr.put(questionToJson(q));
                }
                record.put("questions", qArr);
            }

            CampaignProgressStore.save(this, campaignStageId, record);
        } catch (Exception ignored) {}
    }

    private boolean restoreCampaignBoardState(JSONObject record) {
        if (record == null || campaignBoardRestoreConsumed) return false;
        JSONObject state = record.optJSONObject("state");
        if (state == null) return false;
        JSONArray categories = state.optJSONArray("selectedCategories");
        if (categories == null || categories.length() == 0) {
            String phase = state.optString("phase", record.optString("phase", ""));
            if (OfflineBoardGameStore.PHASE_CATEGORY_SELECT.equals(phase) && "playerPick".equals(boardCategoryPolicy)) {
                campaignBoardRestoreConsumed = true;
                startCampaignBoardMode();
                return true;
            }
            return false;
        }

        refreshCampaignCategoryAccess();
        ArrayList<String> savedCategories = new ArrayList<>();
        for (int index = 0; index < categories.length(); index++) {
            String category = categories.optString(index, "").trim();
            String accessibleCategory = CampaignBoardRules.resolveCategory(category, boardPool.keySet());
            if (accessibleCategory != null) savedCategories.add(accessibleCategory);
        }
        int savedColumns = state.optInt("boardCols", categories.length());
        if (!CampaignBoardRules.canUseCategories(savedCategories, savedColumns, boardPool)) {
            pauseCampaignForLockedCategories();
            return true;
        }

        campaignBoardRestoreConsumed = true;
        stopCategorySelectMusicIfPlaying();
        JSONArray names = state.optJSONArray("names");
        JSONArray scores = state.optJSONArray("scores");
        JSONArray intelligence = state.optJSONArray("intelligence");
        int count = offlineContestants.contestantCount();
        for (int i = 0; i < count; i++) {
            if (names != null) offlineContestants.setContestantName(i, names.optString(i, offlineContestants.nameForSlot(i)));
            if (scores != null) offlineContestants.setScoreForSlot(i, scores.optInt(i, 0));
            if (intelligence != null) offlineContestants.setIntelligenceForSlot(i, intelligence.optInt(i, offlineContestants.intelligenceForSlot(i)));
        }

        boardSelectedCategories.clear();
        boardSelectedCategories.addAll(savedCategories);
        boardCols = Math.max(1, Math.min(boardSelectedCategories.size(),
                state.optInt("boardCols", boardSelectedCategories.size())));
        configureCampaignBoardStarThresholds();
        boardCellQuestion = new Question[boardCols][BOARD_ROWS];
        boardCellConsumed = new boolean[boardCols][BOARD_ROWS];

        JSONArray cells = state.optJSONArray("cells");
        Set<Question> used = savedBoardQuestions(cells);
        Set<String> restoredKeys = savedConsumedQuestionKeys(cells);
        for (int col = 0; col < boardCols; col++) {
            for (int row = 0; row < BOARD_ROWS; row++) {
                JSONObject cell = null;
                if (cells != null) {
                    JSONArray colArray = cells.optJSONArray(col);
                    if (colArray != null) cell = colArray.optJSONObject(row);
                }
                if (cell != null) {
                    boardCellConsumed[col][row] = cell.optBoolean("consumed", false);
                    boardCellQuestion[col][row] = questionFromJson(cell.optJSONObject("question"));
                    Question restored = boardCellQuestion[col][row];
                    if (restored != null && !restoredKeys.add(QuestionIdentity.key(restored)) && !boardCellConsumed[col][row])
                        boardCellQuestion[col][row] = null;
                }
                if (boardCellQuestion[col][row] == null) {
                    String category = boardSelectedCategories.get(Math.min(col, boardSelectedCategories.size() - 1));
                    boardCellQuestion[col][row] = drawBoardQuestion(category, boardTierForRow(row), used);
                }
                Question savedQuestion = boardCellQuestion[col][row];
                if (savedQuestion == null) {
                    questionSelectionFailed(new IllegalStateException(QuestionHistory.EXHAUSTED)); finish(); return true;
                }
                if (savedQuestion != null && !AppPrefs.isCategoryUnlocked(this, savedQuestion.getCategory())) {
                    pauseCampaignForLockedCategories();
                    return true;
                }
            }
        }
        QuestionHistory.recordAll(this, used);
        boardCellsRemaining = state.optInt("cellsRemaining", countRemainingBoardCells());
        boardTurnIndex = state.optInt("turnIndex", 0);
        boardTotalTurns = state.optInt("totalTurns", Math.max(0, boardCols * BOARD_ROWS));
        boardPickerSlot = state.optInt("pickerSlot", 0);
        boardPickerIsHuman = state.optBoolean("pickerIsHuman", boardPickerSlot == 0);
        boardPickedCol = state.optInt("pickedCol", -1);
        boardPickedRow = state.optInt("pickedRow", -1);
        boardRevealCount = Math.max(0, state.optInt("revealCount", 0));
        boardOptionsRevealed = state.optBoolean("optionsRevealed", false);

        boardMyCorrectCount = record.optInt("boardMyCorrectCount", boardMyCorrectCount);
        campaignCorrectAnswers = record.optInt("correctAnswers", campaignCorrectAnswers);
        campaignWrongAnswers = record.optInt("wrongAnswers", campaignWrongAnswers);
        campaignAnsweredQuestions = record.optInt("answeredQuestions", campaignAnsweredQuestions);
        campaignLivesRemaining = record.optInt("livesRemaining", campaignLivesRemaining);
        campaignStartedAtMs = record.optLong("startedAtMs", campaignStartedAtMs);

        // Older board saves only tracked the player's correct-answer count.
        campaignAnsweredQuestions = Math.max(campaignAnsweredQuestions,
                CampaignBoardRules.playerTurns(boardTurnIndex, count));
        campaignCorrectAnswers = boardMyCorrectCount;
        campaignWrongAnswers = Math.max(0, campaignAnsweredQuestions - campaignCorrectAnswers);

        nameCampaignBosses();
        if (!startCampaignBoardTimer()) return true;
        String phase = state.optString("phase", record.optString("phase", OfflineBoardGameStore.PHASE_BOARD));
        if (OfflineBoardGameStore.PHASE_QUESTION.equals(phase)
                && boardPickedCol >= 0 && boardPickedCol < boardCols
                && boardPickedRow >= 0 && boardPickedRow < BOARD_ROWS
                && !boardCellConsumed[boardPickedCol][boardPickedRow]) {
            boardCurrentQuestion = boardCellQuestion[boardPickedCol][boardPickedRow];
            hideBoardOverlay();
            initQuestion();
            CAN_PLAY = false;
            showBoardQuestion(boardCurrentQuestion, boardPickerIsHuman);
        } else {
            beginBoardTurn();
        }
        return true;
    }

    // ---- Team-names setup (التحدي الرئيسي) ------------------------------

    /** First screen of التحدي الرئيسي: enter the two team names, then pick the 6
     *  categories. Built as a programmatic overlay over R.id.boardOverlay, matching the
     *  style of {@link #showCategorySelect()}. */
    private void showTeamNamesSetup() {
        final FrameLayout overlay = (FrameLayout) findViewById(R.id.boardOverlay);
        if (overlay == null) {
            showCategorySelect();
            return;
        }
        playCategorySelectMusic();
        saveLocalTeamsProgress(LocalTeamsGameStore.PHASE_SETUP);
        overlay.removeAllViews();
        overlay.setBackgroundColor(0xF6050C1F);
        overlay.setVisibility(View.VISIBLE);
        overlay.bringToFront();

        ScrollView scroll = new ScrollView(this);
        scroll.setLayoutParams(new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT));
        scroll.setFillViewport(true);
        scroll.setVerticalScrollBarEnabled(false);

        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setGravity(Gravity.CENTER_HORIZONTAL);
        root.setPadding(dpx(24), dpx(16), dpx(24), dpx(16));
        scroll.addView(root);

        // Header Tag
        TextView tag = makeBoardText("👑 كلاسيكو التحدي الرئيسي • إعداد المواجهة", 12f, 0xFFFFD700, Gravity.CENTER);
        LinearLayout.LayoutParams tagLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        tagLp.bottomMargin = dpx(4);
        tag.setLayoutParams(tagLp);
        root.addView(tag);

        TextView title = makeBoardText("أدخلوا أسماء الفريقين للمنافسة", 22f, 0xFFFFFFFF, Gravity.CENTER);
        LinearLayout.LayoutParams tlp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        tlp.bottomMargin = dpx(16);
        title.setLayoutParams(tlp);
        root.addView(title);

        // Duel Arena Horizontal Row
        LinearLayout duelRow = new LinearLayout(this);
        duelRow.setOrientation(LinearLayout.HORIZONTAL);
        duelRow.setGravity(Gravity.CENTER_VERTICAL);
        LinearLayout.LayoutParams duelLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        duelLp.bottomMargin = dpx(16);
        duelRow.setLayoutParams(duelLp);

        final EditText inputA = makeTeamNameInput(boardTeamAName, 0xFFFFD700);
        inputA.setImeOptions(android.view.inputmethod.EditorInfo.IME_FLAG_NO_EXTRACT_UI
                | android.view.inputmethod.EditorInfo.IME_FLAG_NO_FULLSCREEN
                | android.view.inputmethod.EditorInfo.IME_ACTION_NEXT);

        View teamACard = makeTeamSetupCard("🛡️ الفريق الأول", "الركن الذهبي", inputA, 0xFFFFD700, 0x88FFD700);
        duelRow.addView(teamACard, new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f));

        // Center VS Badge
        TextView vsView = new TextView(this);
        vsView.setText("VS");
        vsView.setTextColor(0xFFFFE082);
        vsView.setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f);
        vsView.setTypeface(Typeface.DEFAULT_BOLD);
        vsView.setGravity(Gravity.CENTER);
        vsView.setBackground(gradientPillBg(0x66020617, 0x991E293B, 0x88FFD700, 1));
        LinearLayout.LayoutParams vsLp = new LinearLayout.LayoutParams(dpx(42), dpx(42));
        vsLp.setMargins(dpx(12), 0, dpx(12), 0);
        vsView.setLayoutParams(vsLp);
        duelRow.addView(vsView);

        final EditText inputB = makeTeamNameInput(boardTeamBName, 0xFF38BDF8);
        View teamBCard = makeTeamSetupCard("الفريق الثاني ⚔️", "الركن السماوي", inputB, 0xFF38BDF8, 0x8838BDF8);
        duelRow.addView(teamBCard, new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f));

        root.addView(duelRow);

        final Runnable proceed = new Runnable() {
            @Override
            public void run() {
                String a = inputA.getText().toString().trim();
                String b = inputB.getText().toString().trim();
                if (a.isEmpty()) a = "الفريق الأول";
                if (b.isEmpty()) b = "الفريق الثاني";
                boardTeamAName = a;
                boardTeamBName = b;
                offlineContestants.setContestantName(0, a);
                offlineContestants.setContestantName(1, b);
                hideKeyboard();
                saveLocalTeamsProgress(LocalTeamsGameStore.PHASE_CATEGORY_SELECT);
                showCategorySelect();
            }
        };

        inputA.setOnEditorActionListener(new TextView.OnEditorActionListener() {
            @Override
            public boolean onEditorAction(TextView v, int actionId, android.view.KeyEvent event) {
                if (actionId == android.view.inputmethod.EditorInfo.IME_ACTION_NEXT) {
                    inputB.requestFocus();
                    return true;
                }
                return false;
            }
        });
        inputB.setOnEditorActionListener(new TextView.OnEditorActionListener() {
            @Override
            public boolean onEditorAction(TextView v, int actionId, android.view.KeyEvent event) {
                if (actionId == android.view.inputmethod.EditorInfo.IME_ACTION_DONE) {
                    proceed.run();
                    return true;
                }
                return false;
            }
        });

        Button confirm = new Button(this);
        confirm.setText("انطلاق لاختيار الفئات ➔");
        confirm.setAllCaps(false);
        confirm.setTextColor(0xFF030D1C);
        confirm.setTextSize(TypedValue.COMPLEX_UNIT_SP, 15f);
        if (getBoardFont() != null) confirm.setTypeface(getBoardFont(), Typeface.BOLD);
        confirm.setBackground(gradientPillBg(0xFFFFC727, 0xFFFFA000, 0xFFFFF1A8, 1));
        LinearLayout.LayoutParams cflp = new LinearLayout.LayoutParams(dpx(260), dpx(48));
        cflp.topMargin = dpx(6);
        confirm.setLayoutParams(cflp);
        confirm.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                proceed.run();
            }
        });
        root.addView(confirm);

        overlay.addView(scroll);
    }

    private View makeTeamSetupCard(String title, String subtitle, EditText input, int accent, int strokeColor) {
        LinearLayout card = new LinearLayout(this);
        card.setOrientation(LinearLayout.VERTICAL);
        card.setBackground(cardBg(0xDD091530, strokeColor, 14, 1));
        card.setPadding(dpx(14), dpx(10), dpx(14), dpx(10));

        TextView titleView = makeBoardText(title, 13.5f, accent, Gravity.CENTER);
        card.addView(titleView);

        TextView subView = makeBoardText(subtitle, 9.5f, 0xFF94A3B8, Gravity.CENTER);
        LinearLayout.LayoutParams subLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        subLp.topMargin = dpx(2);
        subLp.bottomMargin = dpx(8);
        subView.setLayoutParams(subLp);
        card.addView(subView);

        card.addView(input);
        return card;
    }

    private EditText makeTeamNameInput(String initial, int accent) {
        EditText input = new EditText(this);
        input.setText(initial);
        input.setSingleLine(true);
        input.setInputType(android.text.InputType.TYPE_CLASS_TEXT
                | android.text.InputType.TYPE_TEXT_FLAG_CAP_WORDS);
        input.setImeOptions(android.view.inputmethod.EditorInfo.IME_FLAG_NO_EXTRACT_UI
                | android.view.inputmethod.EditorInfo.IME_FLAG_NO_FULLSCREEN
                | android.view.inputmethod.EditorInfo.IME_ACTION_DONE);
        input.setGravity(Gravity.CENTER);
        input.setTextColor(0xFFFFFFFF);
        input.setHintTextColor(0x66FFFFFF);
        input.setTextSize(15f);
        if (getBoardFont() != null) input.setTypeface(getBoardFont(), Typeface.BOLD);
        input.setFilters(new android.text.InputFilter[]{new android.text.InputFilter.LengthFilter(14)});
        input.setBackground(cardBg(0x44000000, accent, 999, 1));
        input.setPadding(dpx(12), dpx(8), dpx(12), dpx(8));
        input.setLayoutParams(new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT));
        return input;
    }

    /** Sets up the offline board contestants for a تحدي المراحل stage (solo or boss). */
    private void setupCampaignBoardMatch(int characterIndex) {
        boardMode = true;
        boardCampaignMatch = true;
        campaignEligibleQuestionPool = CampaignBoardRules.filterPool(LocalQuestions.loadBoardPool(this), campaignAllowedLevels);
        refreshCampaignCategoryAccess();
        buildBoardCategoryList();
        if ("boss".equals(boardCampaignKind)) {
            int players = Math.max(2, Math.min(8, 1 + Math.max(1, boardBotCount)));
            offlineContestants.setupForBoard(players, characterIndex);
            if (boardBotIntelligence > 0) {
                offlineContestants.setBoardBotIntelligence(boardBotIntelligence);
            }
            for (int i = 1; i < players; i++) {
                offlineContestants.setContestantName(i, "الزعيم " + i);
            }
        } else {
            offlineContestants.setupForSoloBoard(characterIndex);
        }
        questionsReady = true;
    }

    /** Campaign board start: pick the board width + categories per the stage policy. */
    private void startCampaignBoardMode() {
        refreshCampaignCategoryAccess();
        int requiredColumns = "boss".equals(boardCampaignKind)
                ? offlineContestants.contestantCount() : boardSoloCols;
        if (boardAllCategories.size() < requiredColumns) {
            campaignFailureReason = "question_pool_unavailable";
            persistPendingCampaignStageResult(false, 0, 0);
            GameNotice.makeText(this, "أسئلة هذه المرحلة غير متاحة الآن، جرّب مرحلة أخرى", Toast.LENGTH_LONG).show();
            finishCampaignAndReturnToFlutter();
            return;
        }
        boardCols = requiredColumns;
        if (boardRequiredCategoryCount > 0 && CampaignBoardRules.themedCategoryCount(
                new ArrayList<>(campaignEligibleQuestionPool.keySet()), boardWorldCategories)
                < boardRequiredCategoryCount) {
            campaignFailureReason = "question_pool_unavailable";
            persistPendingCampaignStageResult(false, 0, 0);
            GameNotice.makeText(this, "أسئلة فئات هذه المرحلة غير متاحة الآن", Toast.LENGTH_LONG).show();
            finishCampaignAndReturnToFlutter();
            return;
        }
        configureCampaignBoardStarThresholds();
        if (!"playerPick".equals(boardCategoryPolicy) && (boardPool.size() < requiredColumns
                || CampaignBoardRules.themedCategoryCount(new ArrayList<>(boardPool.keySet()), boardWorldCategories) < boardRequiredCategoryCount)) {
            pauseCampaignForLockedCategories();
            return;
        }
        if ("playerPick".equals(boardCategoryPolicy)) {
            if (boardPool.size() < requiredColumns) {
                GameNotice.makeText(this, "تحتاج " + requiredColumns + " فئات مفتوحة لهذه المرحلة. اختر من فئاتك أو افتح فئات إضافية", Toast.LENGTH_LONG).show();
            }
            saveCampaignProgress(OfflineBoardGameStore.PHASE_CATEGORY_SELECT);
            showCategorySelect();
        } else {
            onCategoriesChosen(pickCampaignCategories(boardCols));
        }
    }

    private void configureCampaignBoardStarThresholds() {
        int maximum = getCampaignBoardMaximumScore();
        if (boardTwoStarScore <= 0) {
            boardTwoStarScore = Math.min(Math.round(boardTargetScore * 1.25f), Math.max(1, maximum - 600));
        }
        if (boardThreeStarScore <= 0) {
            boardThreeStarScore = Math.min(Math.round(boardTargetScore * 1.55f), Math.max(1, maximum - 200));
        }
    }

    int getCampaignBoardEarnedStars(int score) {
        return CampaignBoardRules.earnedStars(score, boardTargetScore, boardTwoStarScore, boardThreeStarScore);
    }

    int getCampaignBoardMaximumScore() {
        if (boardDesignVersion < 2) {
            return CampaignBoardRules.maximumScore(boardCols, "boss".equals(boardCampaignKind) ? BOARD_ROWS : boardSoloPicks);
        }
        return "boss".equals(boardCampaignKind)
                ? CampaignBoardRules.bossMaximumScore(boardCols, boardBossStyle)
                : CampaignBoardRules.maximumScore(boardCols, boardSoloPicks);
    }

    /** Auto-picks {@code n} categories for a campaign stage. worldThemed/curated prefer
     *  boardWorldCategories (the world's themed set) and top up with unlocked categories;
     *  random uses the unlocked eligible pool. */
    private ArrayList<String> pickCampaignCategories(int n) {
        refreshCampaignCategoryAccess();
        return CampaignBoardRules.pickCategories(new ArrayList<>(boardPool.keySet()),
                "random".equals(boardCategoryPolicy) ? null : boardWorldCategories, n,
                new Random((campaignId + "|" + campaignStageId).hashCode()));
    }

    private void refreshCampaignCategoryAccess() {
        boardPool = CampaignBoardRules.accessiblePool(campaignEligibleQuestionPool,
                category -> AppPrefs.isCategoryUnlocked(this, category));
        // Keep category challenges reachable after the free catalog was narrowed.
        // Fill missing thematic choices with eligible free subjects, preserving
        // the required number of distinct categories and the stage difficulty.
        if (CampaignBoardRules.themedCategoryCount(new ArrayList<>(boardPool.keySet()), boardWorldCategories) < boardRequiredCategoryCount) {
            for (String category : boardPool.keySet()) {
                if (CategoryConfig.isCoreFree(category) && CampaignBoardRules.resolveCategory(category, boardWorldCategories) == null) {
                    boardWorldCategories.add(category);
                }
            }
        }
    }

    /** Begins after category selection, preserves the deadline across every resume. */
    private boolean startCampaignBoardTimer() {
        if (campaignTimeLimitSeconds <= 0) return true;
        if (boardCampaignDeadlineMs == 0L) {
            boardCampaignDeadlineMs = System.currentTimeMillis() + campaignTimeLimitSeconds * 1000L;
        }
        long remaining = boardCampaignDeadlineMs - System.currentTimeMillis();
        if (remaining <= 0) {
            handleCampaignTimeExpired();
            return false;
        }
        if (campaignStageTimer == null) startCampaignStageTimerWithDuration(remaining);
        return true;
    }

    private String campaignBoardRulesLine() {
        String text = "";
        if (campaignTimeLimitSeconds > 0 && boardCampaignDeadlineMs > 0) {
            text += "⏱ " + formatCampaignRemaining((int) Math.max(0,
                    (boardCampaignDeadlineMs - System.currentTimeMillis() + 999) / 1000));
        }
        if (campaignMaxWrongAnswers > 0) {
            text += "  •  الأخطاء: " + campaignWrongAnswers + "/" + campaignMaxWrongAnswers;
        }
        if (boardRequiredCategoryCount > 0) {
            text += "  •  فئات العالم الصحيحة: " + CampaignBoardRules.themedCategoryCount(
                    new ArrayList<>(boardCorrectCategories), boardWorldCategories)
                    + "/" + boardRequiredCategoryCount;
        }
        return text;
    }

    private void nameCampaignBosses() {
        if (!boardCampaignMatch || !"boss".equals(boardCampaignKind)) return;
        for (int slot = 1; slot < offlineContestants.contestantCount(); slot++) {
            String name = "الزعيم " + slot;
            String style = campaignBossStyleForSlot(slot);
            if ("specialist".equals(style) && !boardSelectedCategories.isEmpty()) {
                name = "خبير " + boardSelectedCategories.get((slot - 1) % boardSelectedCategories.size());
            } else if ("speed".equals(style)) name = "الخاطف " + slot;
            else if ("highValue".equals(style)) name = "صيّاد النقاط " + slot;
            offlineContestants.setContestantName(slot, name);
        }
    }

    boolean isCampaignBossSpecialtyCell(int slot) {
        return boardCols > 0 && boardPickedCol == (slot - 1) % boardCols;
    }

    String campaignBossStyleForSlot(int slot) {
        return CampaignBoardRules.bossStyleForSlot(boardBossStyle, slot);
    }

    int getCampaignBoardCategoryWins() {
        return CampaignBoardRules.themedCategoryCount(
                new ArrayList<>(boardCorrectCategories), boardWorldCategories);
    }

    private void pauseCampaignForLockedCategories() {
        // Keep the saved attempt intact: closing an access-blocked resume is not a
        // failed stage and must not overwrite its state during onPause.
        EXITING = true;
        CAN_PLAY = false;
        stopTimer(false);
        cancelPendingBoardReveal();
        cancelBoardSelectTimer();
        GameNotice.makeText(this, "هذه المرحلة تحتاج فئات مفتوحة كافية من فئات عالمها. افتح الفئات المطلوبة ثم عد؛ محاولتك محفوظة", Toast.LENGTH_LONG).show();
        finish();
    }

    private boolean ensureCampaignBoardCategoryAccess() {
        if (!boardCampaignMatch || campaignResultPersisted) return true;
        refreshCampaignCategoryAccess();
        if (!CampaignBoardRules.canUseCategories(boardSelectedCategories, boardCols, boardPool)) {
            pauseCampaignForLockedCategories();
            return false;
        }
        return true;
    }

    /** Hides the millionaire-style chrome that has no place on the board.
     *  The contestant podium row and host name plate are kept (shown below the
     *  question while answering; the board overlay covers them between turns). */
    private void applyBoardModeChrome() {
        setGone(R.id.questionCounterPanel);
        setGone(R.id.badge5050);
        setGone(R.id.badgeCall);
        setGone(R.id.badgeAudience);
        if (llySteps != null) llySteps.setVisibility(View.GONE);
        if (llySolde != null) llySolde.setVisibility(View.GONE);
        if (imgHelp5050 != null) imgHelp5050.setVisibility(View.GONE);
        if (imgHelpCall != null) imgHelpCall.setVisibility(View.GONE);
        if (imgHelpAudience != null) imgHelpAudience.setVisibility(View.GONE);
    }

    private void setGone(int id) {
        View v = findViewById(id);
        if (v != null) v.setVisibility(View.GONE);
    }

    private void buildBoardCategoryList() {
        boardAllCategories.clear();
        Map<String, ?> categories = boardCampaignMatch ? campaignEligibleQuestionPool : boardPool;
        if (categories != null) {
            for (String cat : categories.keySet()) {
                if (LocalQuestions.isCategoryHidden(cat)) continue;
                boardAllCategories.add(cat);
            }
        }
    }

    // ---- Category selection screen --------------------------------------

    private void playCategorySelectMusic() {
        if (categorySelectMusicPlaying) return;
        categorySelectMusicPlaying = true;
        playSound(R.raw.main_theme_320bit_chosic, true, true);
    }

    private void stopCategorySelectMusicIfPlaying() {
        if (!categorySelectMusicPlaying) return;
        categorySelectMusicPlaying = false;
    }

    private void playQuestionMusic() {
        categorySelectMusicPlaying = false;
        int resource = boardMode
                ? GameAudioProfile.boardQuestionMusic(currentBoardCellValue())
                : GameAudioProfile.questionMusic(currentQuestion);
        playSound(resource, true, true);
    }

    private void showCategorySelect() {
        GameEconomy.clearSelection(this);
        final FrameLayout overlay = (FrameLayout) findViewById(R.id.boardOverlay);
        if (overlay == null) return;
        playCategorySelectMusic();
        overlay.removeAllViews();
        overlay.setBackgroundColor(0xF2071026);
        overlay.setVisibility(View.VISIBLE);
        overlay.bringToFront();

        ScrollView scroll = new ScrollView(this);
        scroll.setLayoutParams(new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT));
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setGravity(Gravity.CENTER_HORIZONTAL);
        root.setPadding(dpx(24), dpx(14), dpx(24), dpx(14));
        scroll.addView(root);

        TextView title = makeBoardText("اختر " + boardCols + " فئات للعب", 22f, 0xFFFFFFFF, Gravity.CENTER);
        LinearLayout.LayoutParams tlp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        tlp.bottomMargin = dpx(4);
        title.setLayoutParams(tlp);
        root.addView(title);

        final TextView counter = makeBoardText("0 / " + boardCols, 16f, 0xFFFFD761, Gravity.CENTER);
        LinearLayout.LayoutParams clp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        clp.bottomMargin = dpx(10);
        counter.setLayoutParams(clp);
        root.addView(counter);

        final ArrayList<String> selected = new ArrayList<>();
        final Button confirm = new Button(this);

        final int cols = 4;
        final int total = boardAllCategories.size();
        final int rows = Math.max(1, (total + cols - 1) / cols);
        int idx = 0;
        for (int r = 0; r < rows; r++) {
            LinearLayout rowLayout = new LinearLayout(this);
            rowLayout.setOrientation(LinearLayout.HORIZONTAL);
            rowLayout.setLayoutParams(new LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT));
            for (int c = 0; c < cols; c++) {
                if (idx < total) {
                    final String category = boardAllCategories.get(idx);
                    final FrameLayout tile = makeCategoryTile(category);
                    tile.setOnClickListener(new View.OnClickListener() {
                        @Override
                        public void onClick(View v) {
                            if (!AppPrefs.isCategoryUnlocked(GameActivity.this, category)) {
                                showCategoryUnlockDialog(category, tile, selected, counter, confirm);
                                return;
                            }
                            if (selected.contains(category)) {
                                selected.remove(category);
                                tile.setBackground(categoryTileBg(false, false));
                            } else {
                                if (selected.size() >= boardCols) {
                                    String categoryLimit = boardCols == 1 ? "فئة واحدة"
                                            : boardCols == 2 ? "فئتين" : boardCols + " فئات";
                                    GameNotice.makeText(GameActivity.this,
                                            "يمكنك اختيار " + categoryLimit + " فقط. ألغِ تحديد فئة لتختار غيرها.",
                                            Toast.LENGTH_LONG).withTone(GameNotice.Tone.WARNING).show();
                                    return;
                                }
                                selected.add(category);
                                tile.setBackground(categoryTileBg(true, false));
                            }
                            counter.setText(selected.size() + " / " + boardCols);
                            boolean ready = selected.size() == boardCols;
                            confirm.setEnabled(ready);
                            confirm.setAlpha(ready ? 1f : 0.5f);
                            scrollToConfirmIfReady(confirm, ready);
                        }
                    });
                    rowLayout.addView(tile);
                } else {
                    View spacer = new View(this);
                    spacer.setLayoutParams(new LinearLayout.LayoutParams(0, dpx(60), 1f));
                    rowLayout.addView(spacer);
                }
                idx++;
            }
            root.addView(rowLayout);
        }

        confirm.setText(boardCampaignMatch ? "ابدأ • القلب يُخصم عند الخسارة" : "ابدأ اللعب");
        confirm.setAllCaps(false);
        confirm.setTextColor(0xFFFFFFFF);
        if (getBoardFont() != null) confirm.setTypeface(getBoardFont(), Typeface.BOLD);
        confirm.setBackground(pillBg(0xFF29B6F6));
        confirm.setEnabled(false);
        confirm.setAlpha(0.5f);
        LinearLayout.LayoutParams cflp = new LinearLayout.LayoutParams(dpx(200), dpx(50));
        cflp.topMargin = dpx(14);
        confirm.setLayoutParams(cflp);
        confirm.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                if (selected.size() == boardCols) {
                    onCategoriesChosen(new ArrayList<>(selected));
                }
            }
        });
        root.addView(confirm);

        overlay.addView(scroll);
    }

    private void scrollToConfirmIfReady(final View confirm, boolean ready) {
        if (!ready || confirm == null) return;
        confirm.postDelayed(new Runnable() {
            @Override
            public void run() {
                if (isFinishing() || isDestroyed()) return;
                android.view.ViewParent p = confirm.getParent();
                while (p != null) {
                    if (p instanceof ScrollView) {
                        ScrollView sv = (ScrollView) p;
                        View child = sv.getChildAt(0);
                        int targetY = child != null ? child.getBottom() : sv.getBottom();
                        sv.smoothScrollTo(0, targetY);
                        return;
                    }
                    p = p.getParent();
                }
            }
        }, 120);
    }

    private FrameLayout makeCategoryTile(final String category) {
        final boolean isUnlocked = AppPrefs.isCategoryUnlocked(this, category);
        FrameLayout tile = new FrameLayout(this);
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(0, dpx(86), 1f);
        lp.setMargins(dpx(5), dpx(5), dpx(5), dpx(5));
        tile.setLayoutParams(lp);
        tile.setTag(category);
        tile.setBackground(categoryTileBg(false, !isUnlocked));
        String art = categoryAssetPath(category);
        if (art != null) {
            ImageView img = new ImageView(this);
            loadCategoryArtwork(img, art);
            img.setScaleType(ImageView.ScaleType.FIT_CENTER);
            img.setPadding(dpx(6), dpx(4), dpx(6), dpx(24));
            if (!isUnlocked) {
                img.setAlpha(0.55f);
            }
            img.setLayoutParams(new FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT));
            tile.addView(img);
        }
        TextView label = makeBoardText(category, 12f, 0xFFFFFFFF, Gravity.CENTER);
        label.setMaxLines(1);
        label.setPadding(dpx(4), dpx(2), dpx(4), dpx(2));
        label.setLayoutParams(new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.WRAP_CONTENT,
                Gravity.BOTTOM));
        tile.addView(label);

        if (!isUnlocked) {
            TextView lockBadge = new TextView(this);
            lockBadge.setText("🔒");
            lockBadge.setTextSize(11f);
            lockBadge.setPadding(dpx(4), dpx(2), dpx(4), dpx(2));
            FrameLayout.LayoutParams blp = new FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.WRAP_CONTENT, FrameLayout.LayoutParams.WRAP_CONTENT,
                    Gravity.TOP | Gravity.START);
            blp.setMargins(dpx(4), dpx(4), 0, 0);
            lockBadge.setLayoutParams(blp);
            tile.addView(lockBadge);
        }
        return tile;
    }

    private void showCategoryUnlockDialog(final String category,
            final FrameLayout tile, final ArrayList<String> selected,
            final TextView counter, final Button confirm) {
        GameEconomy.refresh(this, (wallet, loadError) -> {
            if (isFinishing() || isDestroyed()) return;
            if (loadError != null) { GameNotice.makeText(this, loadError, Toast.LENGTH_LONG).show(); return; }

            final org.json.JSONObject econState = GameEconomy.state(this);
            final int tickets = econState.optInt("tickets", 0);
            final int rentalVouchers = econState.optInt("rentalVouchers", 0);
            final int categoryVouchers = econState.optInt("categoryVouchers", 0);

            int remainingHours = AppPrefs.getRemainingRentalHours(this, category);
            if (remainingHours <= 0) {
                org.json.JSONObject rentals = econState.optJSONObject("rentals");
                if (rentals != null) {
                    long expiry = rentals.optLong(CategoryConfig.normalize(category), 0L);
                    long diff = expiry - GameEconomy.serverTime(this);
                    if (diff > 0) {
                        remainingHours = (int) Math.ceil((double) diff / (3600.0 * 1000.0));
                    }
                }
            }

            final Dialog dialog = new Dialog(this);
            dialog.requestWindowFeature(Window.FEATURE_NO_TITLE);
            final View view = getLayoutInflater().inflate(R.layout.dialog_category_store_rental, null);
            dialog.setContentView(view);

            if (dialog.getWindow() != null) {
                dialog.getWindow().setBackgroundDrawable(new ColorDrawable(Color.TRANSPARENT));
                dialog.getWindow().setDimAmount(0.75f);
                final DisplayMetrics canvas = GameViewportActivity.canvasMetrics(this);
                final int screenWidth = canvas.widthPixels;
                final int screenHeight = canvas.heightPixels;
                final int dialogWidth = Math.min(dpx(520), screenWidth - dpx(24));
                final int maxContentHeight = Math.min(dpx(360), Math.round(screenHeight * 0.88f) - dpx(40));

                WindowManager.LayoutParams lp = new WindowManager.LayoutParams();
                lp.copyFrom(dialog.getWindow().getAttributes());
                lp.width = dialogWidth;
                lp.height = ViewGroup.LayoutParams.WRAP_CONTENT;
                dialog.getWindow().setAttributes(lp);

                final ScrollView scrollView = view.findViewById(R.id.scrollRentalContent);
                if (scrollView != null) {
                    scrollView.getViewTreeObserver().addOnPreDrawListener(new ViewTreeObserver.OnPreDrawListener() {
                        @Override
                        public boolean onPreDraw() {
                            scrollView.getViewTreeObserver().removeOnPreDrawListener(this);
                            if (scrollView.getHeight() > maxContentHeight) {
                                ViewGroup.LayoutParams p = scrollView.getLayoutParams();
                                p.height = maxContentHeight;
                                scrollView.setLayoutParams(p);
                            }
                            return true;
                        }
                    });
                }
            }

            final Typeface font = getBoardFont();

            // Category artwork
            final ImageView imgArt = view.findViewById(R.id.imgCategoryArtwork);
            final String art = categoryAssetPath(category);
            if (art != null && imgArt != null) {
                loadCategoryArtwork(imgArt, art);
            }

            // Close button
            final TextView btnClose = view.findViewById(R.id.btnCloseRentalDialog);
            if (btnClose != null) {
                btnClose.setOnClickListener(v -> dialog.dismiss());
            }

            // Category Name Chip
            final TextView txtChipName = view.findViewById(R.id.txtCategoryChipName);
            if (txtChipName != null) {
                txtChipName.setText(category);
                if (font != null) txtChipName.setTypeface(font, Typeface.BOLD);
            }

            // Title and Subtitle font
            final TextView txtTitle = view.findViewById(R.id.txtRentalTitle);
            if (txtTitle != null && font != null) txtTitle.setTypeface(font, Typeface.BOLD);
            final TextView txtSubtitle = view.findViewById(R.id.txtRentalSubtitle);
            if (txtSubtitle != null && font != null) txtSubtitle.setTypeface(font, Typeface.NORMAL);

            // Active rental pill
            final LinearLayout llActive = view.findViewById(R.id.llActiveRental);
            final TextView txtActive = view.findViewById(R.id.txtActiveRentalText);
            if (remainingHours > 0) {
                if (llActive != null) llActive.setVisibility(View.VISIBLE);
                if (txtActive != null) {
                    txtActive.setText("الاستئجار الحالي: " + remainingHours + " ساعة متبقية • الاستئجار الجديد يمدد رصيدك");
                    if (font != null) txtActive.setTypeface(font, Typeface.BOLD);
                }
            } else if (llActive != null) {
                llActive.setVisibility(View.GONE);
            }

            // Match Ticket option
            final TextView txtTicketBal = view.findViewById(R.id.txtTicketBalance);
            if (txtTicketBal != null) {
                txtTicketBal.setText("رصيدك: " + tickets + (tickets == 1 ? " تذكرة واحدة" : " تذاكر"));
                if (font != null) txtTicketBal.setTypeface(font, Typeface.NORMAL);
            }
            final Button btnTicket = view.findViewById(R.id.btnUseTicket);
            if (btnTicket != null) {
                if (font != null) btnTicket.setTypeface(font, Typeface.BOLD);
                if (tickets < 1) {
                    btnTicket.setAlpha(0.5f);
                }
                btnTicket.setOnClickListener(v -> {
                    if (GameEconomy.state(GameActivity.this).optInt("tickets") < 1) {
                        GameNotice.makeText(GameActivity.this, "تذاكر التصنيفات غير كافية. احصل عليها من المتجر.", Toast.LENGTH_LONG).show();
                        return;
                    }
                    if (!GameEconomy.selectTicket(GameActivity.this, category)) {
                        GameNotice.makeText(GameActivity.this, "اخترت تصنيفات بعدد تذاكرك المتاحة.", Toast.LENGTH_LONG).show();
                        return;
                    }
                    dialog.dismiss();
                    refreshUnlockedTile(category, tile, selected, counter, confirm);
                    GameNotice.makeText(GameActivity.this, "تم اختيار التصنيف لمباراة واحدة.", Toast.LENGTH_SHORT).show();
                });
            }

            // Rewarded Ad option
            final LinearLayout llAd = view.findViewById(R.id.llAdCard);
            final Button btnAd = view.findViewById(R.id.btnWatchAd);
            if (CategoryConfig.allowsAd(category)) {
                if (llAd != null) llAd.setVisibility(View.VISIBLE);
                if (btnAd != null) {
                    if (font != null) btnAd.setTypeface(font, Typeface.BOLD);
                    btnAd.setOnClickListener(v -> {
                        if (rewardedAdController == null) return;
                        if (GameEconomy.remainingAdRewards(GameActivity.this, "tickets") == 0) {
                            GameNotice.makeText(GameActivity.this, "اكتملت إعلانات التذاكر وتجربة التصنيفات لليوم. تتجدد عند منتصف الليل UTC.", Toast.LENGTH_LONG).show();
                            return;
                        }
                        rewardedAdController.show(new GameRewardedAdController.RewardCallback() {
                            public void onRewardEarned(com.google.android.gms.ads.rewarded.RewardItem reward) {
                                dialog.dismiss();
                                categoryEconomyAction("ad", category, "", "", tile, selected, counter, confirm);
                            }
                            public void onAdClosed(boolean earned) {}
                            public void onAdFailedToLoad(String error) {
                                GameNotice.makeText(GameActivity.this, error, Toast.LENGTH_LONG).show();
                            }
                        });
                    });
                }
            } else if (llAd != null) {
                llAd.setVisibility(View.GONE);
            }

            // Rental Voucher option
            final LinearLayout llVoucher = view.findViewById(R.id.llRentalVoucherCard);
            final TextView txtVoucherSub = view.findViewById(R.id.txtRentalVoucherSubtitle);
            final Button btnVoucher = view.findViewById(R.id.btnUseRentalVoucher);
            if (rentalVouchers > 0) {
                if (llVoucher != null) llVoucher.setVisibility(View.VISIBLE);
                if (txtVoucherSub != null) {
                    txtVoucherSub.setText("استئجار أسبوع (7 أيام) مجاناً • رصيدك: " + rentalVouchers + " قسيمة");
                    if (font != null) txtVoucherSub.setTypeface(font, Typeface.NORMAL);
                }
                if (btnVoucher != null) {
                    if (font != null) btnVoucher.setTypeface(font, Typeface.BOLD);
                    btnVoucher.setOnClickListener(v -> {
                        showCategoryActionConfirmDialog(category,
                                "استئجار تصنيف «" + category + "» لمدة أسبوع (7 أيام) مقابل قسيمة استئجار أسبوعية واحدة.\nتُضاف المدة إلى الاستئجار الحالي إن كان سارياً.",
                                () -> {
                                    dialog.dismiss();
                                    categoryEconomyAction("rent", category, "week", "voucher", tile, selected, counter, confirm);
                                });
                    });
                }
            } else if (llVoucher != null) {
                llVoucher.setVisibility(View.GONE);
            }

            // Rental Prices for Day, Week, Month
            final org.json.JSONObject rentalPrices = econState.optJSONObject("rentalPrices");

            // Day
            final org.json.JSONObject dayPrice = rentalPrices != null ? rentalPrices.optJSONObject("day") : null;
            final int dayCoins = dayPrice != null ? dayPrice.optInt("coins", 1500) : 1500;
            final int dayGems = dayPrice != null ? dayPrice.optInt("gems", 15) : 15;

            final Button btnDayCoins = view.findViewById(R.id.btnDayCoins);
            if (btnDayCoins != null) {
                btnDayCoins.setText("🪙 " + dayCoins + " قطعة");
                if (font != null) btnDayCoins.setTypeface(font, Typeface.BOLD);
                btnDayCoins.setOnClickListener(v -> showCategoryActionConfirmDialog(category,
                        "استئجار تصنيف «" + category + "» لمدة يوم واحد (24 ساعة) مقابل " + dayCoins + " قطعة.\nتُضاف المدة إلى الاستئجار الحالي إن كان سارياً.",
                        () -> {
                            dialog.dismiss();
                            categoryEconomyAction("rent", category, "day", "coins", tile, selected, counter, confirm);
                        }));
            }
            final Button btnDayGems = view.findViewById(R.id.btnDayGems);
            if (btnDayGems != null) {
                btnDayGems.setText("💎 " + dayGems + " جوهرة");
                if (font != null) btnDayGems.setTypeface(font, Typeface.BOLD);
                btnDayGems.setOnClickListener(v -> showCategoryActionConfirmDialog(category,
                        "استئجار تصنيف «" + category + "» لمدة يوم واحد (24 ساعة) مقابل " + dayGems + " جوهرة.\nتُضاف المدة إلى الاستئجار الحالي إن كان سارياً.",
                        () -> {
                            dialog.dismiss();
                            categoryEconomyAction("rent", category, "day", "gems", tile, selected, counter, confirm);
                        }));
            }

            // Week
            final org.json.JSONObject weekPrice = rentalPrices != null ? rentalPrices.optJSONObject("week") : null;
            final int weekCoins = weekPrice != null ? weekPrice.optInt("coins", 4500) : 4500;
            final int weekGems = weekPrice != null ? weekPrice.optInt("gems", 45) : 45;

            final Button btnWeekCoins = view.findViewById(R.id.btnWeekCoins);
            if (btnWeekCoins != null) {
                btnWeekCoins.setText("🪙 " + weekCoins + " قطعة");
                if (font != null) btnWeekCoins.setTypeface(font, Typeface.BOLD);
                btnWeekCoins.setOnClickListener(v -> showCategoryActionConfirmDialog(category,
                        "استئجار تصنيف «" + category + "» لمدة أسبوع (7 أيام) مقابل " + weekCoins + " قطعة.\nتُضاف المدة إلى الاستئجار الحالي إن كان سارياً.",
                        () -> {
                            dialog.dismiss();
                            categoryEconomyAction("rent", category, "week", "coins", tile, selected, counter, confirm);
                        }));
            }
            final Button btnWeekGems = view.findViewById(R.id.btnWeekGems);
            if (btnWeekGems != null) {
                btnWeekGems.setText("💎 " + weekGems + " جوهرة");
                if (font != null) btnWeekGems.setTypeface(font, Typeface.BOLD);
                btnWeekGems.setOnClickListener(v -> showCategoryActionConfirmDialog(category,
                        "استئجار تصنيف «" + category + "» لمدة أسبوع (7 أيام) مقابل " + weekGems + " جوهرة.\nتُضاف المدة إلى الاستئجار الحالي إن كان سارياً.",
                        () -> {
                            dialog.dismiss();
                            categoryEconomyAction("rent", category, "week", "gems", tile, selected, counter, confirm);
                        }));
            }

            // Month
            final org.json.JSONObject monthPrice = rentalPrices != null ? rentalPrices.optJSONObject("month") : null;
            final int monthCoins = monthPrice != null ? monthPrice.optInt("coins", 9000) : 9000;
            final int monthGems = monthPrice != null ? monthPrice.optInt("gems", 90) : 90;

            final Button btnMonthCoins = view.findViewById(R.id.btnMonthCoins);
            if (btnMonthCoins != null) {
                btnMonthCoins.setText("🪙 " + monthCoins + " قطعة");
                if (font != null) btnMonthCoins.setTypeface(font, Typeface.BOLD);
                btnMonthCoins.setOnClickListener(v -> showCategoryActionConfirmDialog(category,
                        "استئجار تصنيف «" + category + "» لمدة شهر (30 يوماً) مقابل " + monthCoins + " قطعة.\nتُضاف المدة إلى الاستئجار الحالي إن كان سارياً.",
                        () -> {
                            dialog.dismiss();
                            categoryEconomyAction("rent", category, "month", "coins", tile, selected, counter, confirm);
                        }));
            }
            final Button btnMonthGems = view.findViewById(R.id.btnMonthGems);
            if (btnMonthGems != null) {
                btnMonthGems.setText("💎 " + monthGems + " جوهرة");
                if (font != null) btnMonthGems.setTypeface(font, Typeface.BOLD);
                btnMonthGems.setOnClickListener(v -> showCategoryActionConfirmDialog(category,
                        "استئجار تصنيف «" + category + "» لمدة شهر (30 يوماً) مقابل " + monthGems + " جوهرة.\nتُضاف المدة إلى الاستئجار الحالي إن كان سارياً.",
                        () -> {
                            dialog.dismiss();
                            categoryEconomyAction("rent", category, "month", "gems", tile, selected, counter, confirm);
                        }));
            }

            // Permanent ownership
            final Button btnOwnGems = view.findViewById(R.id.btnOwnGems);
            if (btnOwnGems != null) {
                if (font != null) btnOwnGems.setTypeface(font, Typeface.BOLD);
                btnOwnGems.setOnClickListener(v -> showCategoryActionConfirmDialog(category,
                        "امتلاك تصنيف «" + category + "» بشكل دائم مقابل 150 جوهرة.",
                        () -> {
                            dialog.dismiss();
                            categoryEconomyAction("own", category, "", "gems", tile, selected, counter, confirm);
                        }));
            }
            final Button btnOwnVoucher = view.findViewById(R.id.btnOwnVoucher);
            if (btnOwnVoucher != null) {
                if (font != null) btnOwnVoucher.setTypeface(font, Typeface.BOLD);
                if (categoryVouchers > 0) {
                    btnOwnVoucher.setVisibility(View.VISIBLE);
                    btnOwnVoucher.setText("استخدام قسيمة امتلاك (" + categoryVouchers + ")");
                    btnOwnVoucher.setOnClickListener(v -> showCategoryActionConfirmDialog(category,
                            "امتلاك تصنيف «" + category + "» بشكل دائم باستخدام قسيمة امتلاك.",
                            () -> {
                                dialog.dismiss();
                                categoryEconomyAction("ownVoucher", category, "", "", tile, selected, counter, confirm);
                            }));
                } else {
                    btnOwnVoucher.setVisibility(View.GONE);
                }
            }

            // Footer font
            final TextView txtFooter = view.findViewById(R.id.txtFooterNote);
            if (txtFooter != null && font != null) txtFooter.setTypeface(font, Typeface.NORMAL);

            dialog.show();
        });
    }

    private void showCategoryActionConfirmDialog(final String category, final String message, final Runnable onConfirm) {
        if (isFinishing() || isDestroyed()) return;
        final Dialog confirmDialog = new Dialog(this);
        confirmDialog.requestWindowFeature(Window.FEATURE_NO_TITLE);
        View view = getLayoutInflater().inflate(R.layout.dialog_category_confirm_action, null);
        confirmDialog.setContentView(view);
        if (confirmDialog.getWindow() != null) {
            confirmDialog.getWindow().setBackgroundDrawable(new ColorDrawable(Color.TRANSPARENT));
            confirmDialog.getWindow().setDimAmount(0.65f);
            int width = Math.min(dpx(420), GameViewportActivity.canvasMetrics(this).widthPixels - dpx(32));
            confirmDialog.getWindow().setLayout(width, ViewGroup.LayoutParams.WRAP_CONTENT);
        }

        TextView txtTitle = view.findViewById(R.id.txtConfirmTitle);
        TextView txtMsg = view.findViewById(R.id.txtConfirmMessage);
        Button btnCancel = view.findViewById(R.id.btnConfirmCancel);
        Button btnOk = view.findViewById(R.id.btnConfirmOk);

        Typeface font = getBoardFont();
        if (font != null) {
            if (txtTitle != null) txtTitle.setTypeface(font, Typeface.BOLD);
            if (txtMsg != null) txtMsg.setTypeface(font, Typeface.NORMAL);
            if (btnCancel != null) btnCancel.setTypeface(font, Typeface.BOLD);
            if (btnOk != null) btnOk.setTypeface(font, Typeface.BOLD);
        }

        if (txtTitle != null) txtTitle.setText(category);
        if (txtMsg != null) txtMsg.setText(message);

        if (btnCancel != null) btnCancel.setOnClickListener(v -> confirmDialog.dismiss());
        if (btnOk != null) {
            btnOk.setOnClickListener(v -> {
                confirmDialog.dismiss();
                if (onConfirm != null) onConfirm.run();
            });
        }

        confirmDialog.show();
    }

    private void categoryEconomyAction(String action, String category, String duration, String currency,
            FrameLayout tile, ArrayList<String> selected, TextView counter, Button confirm) {
        java.util.Map<String, Object> data = new java.util.HashMap<>();
        data.put("action", action); data.put("category", category);
        if (!duration.isEmpty()) data.put("duration", duration);
        if (!currency.isEmpty()) data.put("currency", currency);
        GameEconomy.request(this, data, (value, error) -> {
            if (isFinishing() || isDestroyed()) return;
            if (error != null) {
                GameNotice.makeText(this, error, Toast.LENGTH_LONG).show();
            } else {
                String successMsg = "own".equals(action) || "ownVoucher".equals(action)
                        ? "تم امتلاك تصنيف «" + category + "» بنجاح!"
                        : "ad".equals(action)
                        ? "تم فتح تصنيف «" + category + "» لهذه المباراة!"
                        : "تم استئجار تصنيف «" + category + "» بنجاح!";
                GameNotice.makeText(this, successMsg, Toast.LENGTH_SHORT).show();
                refreshUnlockedTile(category, tile, selected, counter, confirm);
            }
        });
    }

    private void refreshUnlockedTile(String category, FrameLayout tile,
                                     ArrayList<String> selected, TextView counter, Button confirm) {
        tile.setBackground(categoryTileBg(true, false));
        tile.removeAllViews();
        String art = categoryAssetPath(category);
        if (art != null) {
            ImageView img = new ImageView(this);
            loadCategoryArtwork(img, art);
            img.setScaleType(ImageView.ScaleType.FIT_CENTER);
            img.setPadding(dpx(6), dpx(4), dpx(6), dpx(24));
            img.setLayoutParams(new FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT));
            tile.addView(img);
        }
        TextView label = makeBoardText(category, 12f, 0xFFFFFFFF, Gravity.CENTER);
        label.setMaxLines(1);
        label.setPadding(dpx(4), dpx(2), dpx(4), dpx(2));
        label.setLayoutParams(new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.WRAP_CONTENT,
                Gravity.BOTTOM));
        tile.addView(label);

        if (!selected.contains(category)) {
            if (counter != null) {
                if (selected.size() < boardCols) {
                    selected.add(category);
                    counter.setText(selected.size() + " / " + boardCols);
                    boolean ready = selected.size() == boardCols;
                    confirm.setEnabled(ready);
                    confirm.setAlpha(ready ? 1f : 0.5f);
                    scrollToConfirmIfReady(confirm, ready);
                }
            } else {
                selected.clear();
                selected.add(category);
                confirm.setEnabled(true);
                confirm.setAlpha(1f);
                scrollToConfirmIfReady(confirm, true);
            }
        }
    }

    private void onCategoriesChosen(ArrayList<String> chosen) {
        prepareQuestionSelection(() -> buildSelectedBoard(chosen));
    }

    private void buildSelectedBoard(ArrayList<String> chosen) {
        if (boardCampaignMatch) {
            refreshCampaignCategoryAccess();
            if (!CampaignBoardRules.canUseCategories(chosen, boardCols, boardPool)) {
                GameNotice.makeText(this, "اختر " + boardCols + " فئات مفتوحة. ربما انتهت مدة فتح إحدى الفئات", Toast.LENGTH_LONG).show();
                showCategorySelect();
                return;
            }
            if (CampaignBoardRules.themedCategoryCount(chosen, boardWorldCategories)
                    < boardRequiredCategoryCount) {
                GameNotice.makeText(this, "اختر على الأقل " + boardRequiredCategoryCount
                        + " فئات من فئات العالم: " + android.text.TextUtils.join("، ", boardWorldCategories),
                        Toast.LENGTH_LONG).show();
                showCategorySelect();
                return;
            }
        }
        stopCategorySelectMusicIfPlaying();
        boardSelectedCategories.clear();
        boardSelectedCategories.addAll(chosen);
        nameCampaignBosses();
        boardCellQuestion = new Question[boardCols][BOARD_ROWS];
        boardCellConsumed = new boolean[boardCols][BOARD_ROWS];
        Set<Question> used = new HashSet<>();
        for (int col = 0; col < boardCols; col++) {
            String cat = boardSelectedCategories.get(col);
            // Reserve the two low and high questions before drawing medium cells
            // from the mixed tier, otherwise a medium pick can consume their pool.
            int[] rowOrder = boardCampaignMatch ? new int[]{0, 3, 2, 5, 1, 4} : new int[]{0, 1, 2, 3, 4, 5};
            for (int row : rowOrder) {
                boardCellQuestion[col][row] = drawBoardQuestion(cat, boardTierForRow(row), used);
            }
        }
        boardCellsRemaining = boardCols * BOARD_ROWS;
        boardTurnIndex = 0;
        // Play only a whole number of full rounds so every contestant picks (and answers)
        // the same count of questions, regardless of how many players there are.
        int playerCount = offlineContestants.contestantCount();
        boardTotalTurns = playerCount > 0
                ? (boardCellsRemaining / playerCount) * playerCount
                : boardCellsRemaining;
        // Solo campaign stage: the lone player takes a fixed budget of picks (not the
        // whole board); reaching boardTargetScore within them passes the stage.
        if (boardCampaignMatch && "solo".equals(boardCampaignKind)) {
            boardTotalTurns = Math.max(1, Math.min(boardSoloPicks, boardCellsRemaining));
        }
        for (int col = 0; col < boardCols; col++) for (int row = 0; row < BOARD_ROWS; row++) {
            if (boardCellQuestion[col][row] == null) {
                GameNotice.makeText(this, QuestionHistory.EXHAUSTED, Toast.LENGTH_LONG).show();
                showCategorySelect(); return;
            }
        }
        int economyOrder = 0;
        try { economyOrder = Integer.parseInt(campaignStageId.replace("stage_", "")); } catch (Exception ignored) {}
        if (!GameEconomy.ensure(this, campaignMode, economyOrder, chosen, this::reserveAndStartSelectedBoard)) return;
        reserveAndStartSelectedBoard();
    }

    private void reserveAndStartSelectedBoard() {
        reserveBoardQuestions(this::startSelectedBoard);
    }

    private void startSelectedBoard() {
        if (boardCampaignMatch && !startCampaignBoardTimer()) return;
        if (boardLocalTeams) {
            saveLocalTeamsProgress(LocalTeamsGameStore.PHASE_BOARD);
        }
        if (shouldSaveOfflineBoard()) {
            saveOfflineBoardProgress(OfflineBoardGameStore.PHASE_BOARD);
        }
        if (boardCampaignMatch) {
            saveCampaignProgress(OfflineBoardGameStore.PHASE_BOARD);
        }
        beginBoardTurn();
    }

    /** Maps a cell row (0..5) onto its difficulty tier; both side columns run 200/400/600. */
    private int boardTierForRow(int row) {
        return row % BOARD_VALUES.length;
    }

    /** Draws one unused question for a (category, tier) cell, with fallbacks. */
    private Question drawBoardQuestion(String category, int tier, Set<Question> used) {
        Question q = pickUnused(boardTierList(category, tier), used);
        if (q != null) return q;
        // Same category, nearest other tiers.
        for (int d = 1; d < BOARD_POOL_TIERS; d++) {
            int[] alts = {tier - d, tier + d};
            for (int t : alts) {
                if (t >= 0 && t < BOARD_POOL_TIERS) {
                    q = pickUnused(boardTierList(category, t), used);
                    if (q != null) return q;
                }
            }
        }
        // Fallback bucket.
        q = pickUnused(boardTierList(LocalQuestions.FALLBACK_CATEGORY, tier), used);
        if (q != null) return q;
        for (int t = 0; t < BOARD_POOL_TIERS; t++) {
            q = pickUnused(boardTierList(LocalQuestions.FALLBACK_CATEGORY, t), used);
            if (q != null) return q;
        }
        // Anything unused anywhere.
        if (boardPool != null) {
            for (ArrayList<ArrayList<Question>> tiers : boardPool.values()) {
                for (ArrayList<Question> list : tiers) {
                    q = pickUnused(list, used);
                    if (q != null) return q;
                }
            }
        }
        return null;
    }

    private ArrayList<Question> boardTierList(String category, int tier) {
        if (boardPool == null || category == null) return null;
        ArrayList<ArrayList<Question>> tiers = boardPool.get(category);
        if (tiers == null) {
            String norm = normalizeArabic(category);
            if (norm.equals(normalizeArabic("أنمي")) || norm.equals(normalizeArabic("انمي"))) {
                tiers = boardPool.get("الأنمي");
                if (tiers == null) tiers = boardPool.get("أنمي");
            } else if (norm.equals(normalizeArabic("الأنمي")) || norm.equals(normalizeArabic("الانمي"))) {
                tiers = boardPool.get("أنمي");
                if (tiers == null) tiers = boardPool.get("الأنمي");
            } else if (norm.equals(normalizeArabic("خمن الأغنية")) || norm.equals(normalizeArabic("خمن الاغنية"))) {
                tiers = boardPool.get("خمن الأغنية");
            } else if (norm.equals(normalizeArabic("قصة مسلسل عربي"))) {
                tiers = boardPool.get("مسلسلات عربية");
            } else if (norm.equals(normalizeArabic("قصة فيلم عربي"))) {
                tiers = boardPool.get("أفلام عربية");
            } else if (norm.equals(normalizeArabic("قصة مسلسل اجنبي")) || norm.equals(normalizeArabic("قصة مسلسل أجنبي"))) {
                tiers = boardPool.get("مسلسلات أجنبية");
            } else if (norm.equals(normalizeArabic("قصة فيلم اجنبي")) || norm.equals(normalizeArabic("قصة فيلم أجنبي"))) {
                tiers = boardPool.get("أفلام أجنبية");
            }
        }
        if (tiers == null || tier < 0 || tier >= tiers.size()) return null;
        return tiers.get(tier);
    }

    private Question pickUnused(ArrayList<Question> list, Set<Question> used) {
        Set<String> excluded = new HashSet<>(questionExclusions);
        excluded.addAll(QuestionHistory.snapshot(this));
        return QuestionSelection.pick(list, excluded, used, boardRandom);
    }

    // ---- Turn loop -------------------------------------------------------

    private void beginBoardTurn() {
        if (presenterDialogue.defer("boardTurnStart", this::beginBoardTurn)) return;
        if (EXITING || duelActivityDestroyed) return;
        int economyOrder = 0;
        try { economyOrder = Integer.parseInt(campaignStageId.replace("stage_", "")); } catch (Exception ignored) {}
        if (!GameEconomy.ensure(this, campaignMode, economyOrder, new ArrayList<>(boardSelectedCategories), this::beginBoardTurn)) return;
        if (boardCampaignMatch && campaignResultPersisted) return;
        if (boardCampaignMatch && !ensureCampaignBoardCategoryAccess()) return;
        boardStealActive = false;
        boardRefereeOverrideApplied = false;
        showBoardRefereePanel(false);
        if (boardCellsRemaining <= 0 || boardTurnIndex >= boardTotalTurns) {
            finishBoardMatch();
            return;
        }
        int count = offlineContestants.contestantCount();
        boardPickerSlot = count > 0 ? boardTurnIndex % count : 0;
        // In التحدي الرئيسي both seats are human teams playing on one phone, so every
        // turn is a human typed turn (no bots).
        boardPickerIsHuman = boardLocalTeams || (boardPickerSlot == 0);
        if (boardLocalTeams) {
            saveLocalTeamsProgress(LocalTeamsGameStore.PHASE_BOARD);
        }
        if (shouldSaveOfflineBoard()) {
            saveOfflineBoardProgress(OfflineBoardGameStore.PHASE_BOARD);
        }
        if (boardCampaignMatch) {
            saveCampaignProgress(OfflineBoardGameStore.PHASE_BOARD);
        }
        showBoardGrid();
        if (!boardPickerIsHuman) {
            new Handler().postDelayed(new Runnable() {
                @Override
                public void run() {
                    if (!EXITING && boardMode) runBotTurn();
                }
            }, boardCampaignMatch ? 650 + boardRandom.nextInt(651) : 1500);
        }
    }

    private void runBotTurn() {
        if (EXITING || duelActivityDestroyed) return;
        if (boardCampaignMatch && campaignResultPersisted) return;
        int[] cell = pickRandomRemainingCell();
        if (cell == null) {
            finishBoardMatch();
            return;
        }
        boardPickedCol = cell[0];
        boardPickedRow = cell[1];
        boardCurrentQuestion = boardCellQuestion[boardPickedCol][boardPickedRow];
        if (shouldSaveOfflineBoard()) {
            saveOfflineBoardProgress(OfflineBoardGameStore.PHASE_QUESTION);
        }
        if (boardCampaignMatch) {
            saveCampaignProgress(OfflineBoardGameStore.PHASE_QUESTION);
        }
        enterBoardQuestion(false);
    }

    private int[] pickRandomRemainingCell() {
        ArrayList<int[]> remaining = new ArrayList<>();
        for (int c = 0; c < boardCols; c++) {
            for (int r = 0; r < BOARD_ROWS; r++) {
                if (!boardCellConsumed[c][r]) remaining.add(new int[]{c, r});
            }
        }
        if (remaining.isEmpty()) return null;
        if (boardCampaignMatch && !boardPickerIsHuman && "boss".equals(boardCampaignKind)) {
            return CampaignBoardRules.pickBossCell(remaining, campaignBossStyleForSlot(boardPickerSlot),
                    (boardPickerSlot - 1) % Math.max(1, boardCols), boardRandom);
        }
        return remaining.get(boardRandom.nextInt(remaining.size()));
    }

    private void onCellPicked(int col, int row) {
        if (boardCampaignMatch && campaignResultPersisted) return;
        if (boardCampaignMatch && !ensureCampaignBoardCategoryAccess()) return;
        if (paidDuel != null) {
            if (!boardPickerIsHuman || paidDuel.isPending() || paidDuelShowingResult
                    || col < 0 || col >= boardCols || row < 0 || row >= BOARD_ROWS
                    || boardCellConsumed[col][row]) return;
            boardPickPending = true;
            cancelBoardSelectTimer();
            Map<String, Object> data = paidDuelTurnArgs();
            data.put("col", col);
            data.put("row", row);
            paidDuel.call("claim", data);
            return;
        }
        if (boardOnline && !boardRoomMatch) {
            if (!duelLocallyConnected || ACTIVITY_PAUSED || duelNeedsBoardResync) return;
            if (!boardPickerIsHuman || boardPickPending || boardPickedCol >= 0
                    || col < 0 || col >= boardCols || row < 0 || row >= BOARD_ROWS
                    || boardCellConsumed[col][row]) return;
            boardPickPending = true;
            cancelBoardSelectTimer();
            claimDuelCell(boardOnlineTurn, col, row);
            return;
        }
        boardPickedCol = col;
        boardPickedRow = row;
        boardCurrentQuestion = boardCellQuestion[col][row];
        if (boardLocalTeams) {
            saveLocalTeamsProgress(LocalTeamsGameStore.PHASE_QUESTION);
        }
        if (shouldSaveOfflineBoard()) {
            saveOfflineBoardProgress(OfflineBoardGameStore.PHASE_QUESTION);
        }
        if (boardCampaignMatch) {
            saveCampaignProgress(OfflineBoardGameStore.PHASE_QUESTION);
        }
        if (boardOnline) {
            cancelBoardSelectTimer();
            writeOnlineTurnPick(boardOnlineTurn, col, row);
        }
        enterBoardQuestion(true);
    }

    private void enterBoardQuestion(boolean humanTurn) {
        if (boardOnline && boardDuelFinished) return;
        hideBoardOverlay();
        initQuestion();
        // Fresh cell: the value starts at full (the steal reuses the same cell without
        // re-entering here, so its carried-over reveal count is preserved).
        boardRevealCount = 0;
        boardPickerIsHuman = humanTurn;
        CAN_PLAY = false;
        showBoardQuestion(boardCurrentQuestion, humanTurn);
        if (boardLocalTeams) {
            saveLocalTeamsProgress(LocalTeamsGameStore.PHASE_QUESTION);
        }
        if (shouldSaveOfflineBoard()) {
            saveOfflineBoardProgress(OfflineBoardGameStore.PHASE_QUESTION);
        }
        if (boardCampaignMatch) {
            saveCampaignProgress(OfflineBoardGameStore.PHASE_QUESTION);
        }
    }

    private void endBoardTurn() {
        if (presenterDialogue.defer("boardTurnEnd", this::endBoardTurn)) return;
        if (boardCampaignMatch && campaignResultPersisted) return;
        if (boardOnline && boardDuelFinished) return;
        showBoardRefereePanel(false);
        if (boardLocalTeams && offlineContestants != null) {
            offlineContestants.setLocalTeamsActiveQuestionSlot(-1);
        }
        if (boardPickedCol >= 0 && boardPickedRow >= 0
                && boardPickedCol < boardCols && boardPickedRow < BOARD_ROWS) {
            boardCellConsumed[boardPickedCol][boardPickedRow] = true;
        }
        boardCurrentQuestion = null;
        if (boardOnline) {
            // Online turns are driven by boardOnlineTurn, not the round-robin index.
            advanceOnlineBoardTurn();
            return;
        }
        boardCellsRemaining--;
        boardTurnIndex++;
        if (boardCampaignMatch && campaignMaxWrongAnswers > 0
                && campaignWrongAnswers > campaignMaxWrongAnswers) {
            finishCampaignBoardMatch();
            return;
        }
        if (boardCellsRemaining <= 0 || boardTurnIndex >= boardTotalTurns) {
            finishBoardMatch();
            return;
        }
        if (boardLocalTeams) {
            saveLocalTeamsProgress(LocalTeamsGameStore.PHASE_BOARD);
        }
        if (shouldSaveOfflineBoard()) {
            saveOfflineBoardProgress(OfflineBoardGameStore.PHASE_BOARD);
        }
        if (boardCampaignMatch) {
            saveCampaignProgress(OfflineBoardGameStore.PHASE_BOARD);
        }
        beginBoardTurn();
    }

    private void finishBoardMatch() {
        if (boardLocalTeams && offlineContestants != null) {
            offlineContestants.setLocalTeamsActiveQuestionSlot(-1);
        }
        hideBoardOverlay();
        if (boardCampaignMatch) {
            finishCampaignBoardMatch();
            return;
        }
        if (boardLocalTeams) {
            finishLocalTeamsBoard();
            return;
        }
        if (boardRoomMatch) {
            finishRoomBoardMatch();
            return;
        }
        if (boardOnline) {
            if (boardDuelFinished) return;
            boardDuelFinished = true;
            markMyGameState("finished");
            detachBoardListeners();
            detachOpponentStatusListener();
        }
        if (shouldSaveOfflineBoard()) {
            saveOfflineBoardFinished();
        }
        finishOfflineCompetition();
        if (boardOnline && !boardRoomMatch) OnlineDuelResultStore.clearCompleted(this, gameID);
    }

    /** Room board end: tally totals (team or solo), report to the room, show results. */
    private void finishRoomBoardMatch() {
        stopTimer(false);
        CAN_PLAY = false;
        CAN_HOME = false;
        hideBoardOverlay();
        detachBoardListeners();

        final int myScore = offlineContestants.scoreForSlot(mySeat);
        final boolean[] seatWon = new boolean[boardSeatCount];
        final boolean win;
        String winnerTeam = "";
        String winnerId = "";
        int teamAScore = 0, teamBScore = 0;
        String headline;

        if (boardTeamMatch) {
            for (int g = 0; g < boardSeatCount; g++) {
                int s = offlineContestants.scoreForSlot(g);
                if ("B".equals(boardSeatTeam[g])) teamBScore += s; else teamAScore += s;
            }
            final int myTeamScore = "B".equals(myTeam) ? teamBScore : teamAScore;
            final int enemyTeamScore = "B".equals(myTeam) ? teamAScore : teamBScore;
            win = myTeamScore > enemyTeamScore;
            boolean tie = myTeamScore == enemyTeamScore;
            winnerTeam = teamAScore > teamBScore ? "A" : (teamBScore > teamAScore ? "B" : "");
            for (int g = 0; g < boardSeatCount; g++) {
                seatWon[g] = tie || winnerTeam.equals(boardSeatTeam[g]);
            }
            headline = win ? "🏆 فاز فريقك!" : (tie ? "🤝 تعادل الفريقان!" : "💔 خسر فريقك");
        } else {
            int rank = 1, bestScore = myScore, bestCount = 0, bestSeat = mySeat;
            for (int g = 0; g < boardSeatCount; g++) {
                int s = offlineContestants.scoreForSlot(g);
                if (s > myScore) rank++;
                if (s > bestScore) { bestScore = s; bestSeat = g; }
            }
            for (int g = 0; g < boardSeatCount; g++) {
                boolean top = offlineContestants.scoreForSlot(g) == bestScore;
                seatWon[g] = top;
                if (top) bestCount++;
            }
            win = (rank == 1);
            winnerId = bestCount == 1 ? boardSeatId[bestSeat] : "";
            headline = win ? "🏆 فزت بالمباراة!"
                    : ("انتهت المباراة — ترتيبك " + rank + " من " + boardSeatCount);
        }

        persistPendingRoomBoardResult(boardTeamMatch, winnerTeam, winnerId);
        markMyGameState("finished");
        detachOpponentStatusListener();
        try {
            boolean tied = boardTeamMatch ? winnerTeam.isEmpty() : win && winnerId.isEmpty();
            PlayerStats.recordGameEnd(GameActivity.this, tied ? ProgressionRules.DRAW
                    : win ? ProgressionRules.WIN : ProgressionRules.LOSS, myScore);
            PlayerProgress.onGameFinished(GameActivity.this, win, myScore,
                    PlayerStats.getBestStreak(GameActivity.this), usedAllHelps(), usedAnyHelp());
        } catch (Exception ignored) {
        }
        if (win) {
            person.moveShow2Hands(1500);
            person.raiseEyeBrowsUp(1000, false, true);
        }
        playSound(win ? R.raw.new_level : R.raw.wrong_answer, false, false);
        showBoardResultScreen(headline, teamAScore, teamBScore, mySeat, seatWon);
    }

    // =====================================================================
    //  Celebration / sad results screen (all board modes: offline, 1v1, room)
    //  A full-screen overlay where every contestant loops their celebration
    //  (winners) or sad (losers) reaction clip, with team/score chrome.
    // =====================================================================

    /**
     * Plays an explosion of golden coins bursting outward in radial arcs across the overlay.
     */
    private void playCoinBurstMotion(final ViewGroup container, final float startX, final float startY, final int count) {
        if (container == null || isFinishing()) return;
        final Random random = new Random();
        final int particleCount = Math.max(10, Math.min(24, count));

        container.post(new Runnable() {
            @Override
            public void run() {
                if (isFinishing() || container.getWidth() <= 0) return;
                final float originX = startX > 0 ? startX : (container.getWidth() / 2f);
                final float originY = startY > 0 ? startY : (container.getHeight() * 0.38f);

                for (int i = 0; i < particleCount; i++) {
                    final TextView coin = new TextView(GameActivity.this);
                    coin.setText("🪙");
                    coin.setTextSize(TypedValue.COMPLEX_UNIT_SP, 20f);
                    coin.setGravity(Gravity.CENTER);
                    coin.setLayoutParams(new FrameLayout.LayoutParams(dpx(36), dpx(36)));
                    coin.setX(originX - dpx(18));
                    coin.setY(originY - dpx(18));
                    coin.setAlpha(0f);
                    coin.setScaleX(0.2f);
                    coin.setScaleY(0.2f);
                    container.addView(coin);

                    double angleRad = Math.toRadians(-180 + random.nextInt(180) + (random.nextBoolean() ? -30 : 30));
                    if (random.nextFloat() < 0.25f) {
                        angleRad = Math.toRadians(random.nextInt(360));
                    }
                    float distance = dpx(90 + random.nextInt(140));
                    final float targetX = originX + (float) (Math.cos(angleRad) * distance) - dpx(18);
                    final float targetY = originY + (float) (Math.sin(angleRad) * distance) + dpx(25 + random.nextInt(50));
                    long duration = 850L + random.nextInt(400);
                    long delay = random.nextInt(180);
                    float rotation = -360f + random.nextInt(720);

                    coin.animate()
                            .x(targetX)
                            .y(targetY)
                            .rotation(rotation)
                            .scaleX(1.15f)
                            .scaleY(1.15f)
                            .alpha(1f)
                            .setDuration(duration / 2)
                            .setStartDelay(delay)
                            .setInterpolator(new DecelerateInterpolator(1.4f))
                            .withEndAction(new Runnable() {
                                @Override
                                public void run() {
                                    coin.animate()
                                            .y(targetY + dpx(40))
                                            .scaleX(0.7f)
                                            .scaleY(0.7f)
                                            .alpha(0f)
                                            .setDuration(duration / 2)
                                            .setInterpolator(new AccelerateInterpolator(1.2f))
                                            .withEndAction(new Runnable() {
                                                @Override
                                                public void run() {
                                                    container.removeView(coin);
                                                }
                                            }).start();
                                }
                            }).start();
                }
            }
        });
    }

    /**
     * Plays falling coins drifting downwards and fading out (representing deducted coins leaving wallet).
     */
    private void playCoinDeductionMotion(final ViewGroup container, final float startX, final float startY, final int count) {
        if (container == null || isFinishing()) return;
        final Random random = new Random();
        final int particleCount = Math.max(8, Math.min(16, count));

        container.post(new Runnable() {
            @Override
            public void run() {
                if (isFinishing() || container.getWidth() <= 0) return;
                final float originX = startX > 0 ? startX : (container.getWidth() / 2f);
                final float originY = startY > 0 ? startY : (container.getHeight() * 0.38f);

                for (int i = 0; i < particleCount; i++) {
                    final TextView coin = new TextView(GameActivity.this);
                    coin.setText("🪙");
                    coin.setTextSize(TypedValue.COMPLEX_UNIT_SP, 18f);
                    coin.setGravity(Gravity.CENTER);
                    coin.setLayoutParams(new FrameLayout.LayoutParams(dpx(32), dpx(32)));
                    float spawnOffsetX = dpx(-60 + random.nextInt(120));
                    coin.setX(originX + spawnOffsetX - dpx(16));
                    coin.setY(originY - dpx(16));
                    coin.setAlpha(0f);
                    coin.setScaleX(0.9f);
                    coin.setScaleY(0.9f);
                    container.addView(coin);

                    final float targetY = originY + dpx(120 + random.nextInt(90));
                    float driftX = coin.getX() + dpx(-30 + random.nextInt(60));
                    long duration = 900L + random.nextInt(400);
                    long delay = i * 80L;
                    float rotation = -180f + random.nextInt(360);

                    coin.animate()
                            .x(driftX)
                            .y(targetY)
                            .rotation(rotation)
                            .alpha(0.85f)
                            .setStartDelay(delay)
                            .setDuration(duration * 2 / 5)
                            .setInterpolator(new AccelerateInterpolator(1.2f))
                            .withEndAction(new Runnable() {
                                @Override
                                public void run() {
                                    coin.animate()
                                            .y(targetY + dpx(50))
                                            .alpha(0f)
                                            .scaleX(0.5f)
                                            .scaleY(0.5f)
                                            .setDuration(duration * 3 / 5)
                                            .withEndAction(new Runnable() {
                                                @Override
                                                public void run() {
                                                    container.removeView(coin);
                                                }
                                            }).start();
                                }
                            }).start();
                }
            }
        });
    }

    /**
     * Smoothly rolls a number counter from start to end with formatting and suffix.
     */
    private void animateNumberCounter(final TextView textView, final int start, final int end,
                                      final String prefix, final String suffix, long duration,
                                      @Nullable final Runnable onComplete) {
        if (textView == null) return;
        ValueAnimator animator = ValueAnimator.ofInt(start, end);
        animator.setDuration(duration);
        animator.setInterpolator(new DecelerateInterpolator(2.0f));
        animator.addUpdateListener(new ValueAnimator.AnimatorUpdateListener() {
            @Override
            public void onAnimationUpdate(ValueAnimator animation) {
                int value = (int) animation.getAnimatedValue();
                textView.setText(String.format(Locale.getDefault(), "%s%,d %s", prefix, value, suffix).trim());
            }
        });
        if (onComplete != null) {
            animator.addListener(new AnimatorListenerAdapter() {
                @Override
                public void onAnimationEnd(Animator animation) {
                    onComplete.run();
                }
            });
        }
        animator.start();
        resultMotionAnimators.add(animator);
    }

    /**
     * Applies a tactile recoil horizontal shake animation.
     */
    private void applyShakeMotion(View view) {
        if (view == null) return;
        ObjectAnimator shake = ObjectAnimator.ofFloat(view, "translationX",
                0f, -dpx(10), dpx(10), -dpx(7), dpx(7), -dpx(3), dpx(3), 0f);
        shake.setDuration(440L);
        shake.setInterpolator(new DecelerateInterpolator());
        shake.start();
        resultMotionAnimators.add(shake);
    }

    /**
     * Applies a gentle floating bobbing motion to an icon.
     */
    private void applyFloatingMotion(View view) {
        if (view == null) return;
        ObjectAnimator floatAnim = ObjectAnimator.ofFloat(view, "translationY", 0f, -dpx(7), 0f);
        floatAnim.setDuration(1500L);
        floatAnim.setRepeatMode(ValueAnimator.REVERSE);
        floatAnim.setRepeatCount(ValueAnimator.INFINITE);
        floatAnim.setInterpolator(new AccelerateDecelerateInterpolator());
        floatAnim.start();
        resultMotionAnimators.add(floatAnim);
    }

    /**
     * Builds and attaches the professional match economy motion banner (coin added/deducted animations).
     */
    private void buildMatchEconomyMotionBanner(final ViewGroup root, final FrameLayout overlay,
                                                final boolean meWon, final boolean matchDraw, final TextView title) {
        final int matchStakeExtra = getIntent().getIntExtra("stakeCoins", 0);
        final boolean isPaid = paidDuel != null || matchStakeExtra > 0;
        Map<String, Object> settlement = paidDuel != null ? PaidDuelController.map(paidDuelState.get("settlement")) : Collections.emptyMap();
        String settlementStatus = PaidDuelController.string(settlement.get("status"));
        boolean isPaidSettled = paidDuel != null ? "paid".equals(settlementStatus) : (matchStakeExtra > 0);
        boolean isDraw = paidDuel != null
                ? ("draw".equals(paidDuelState.get("finishReason")) || "refunded".equals(settlementStatus))
                : matchDraw;
        boolean wonPaid = paidDuel != null ? (isPaidSettled && myID.equals(settlement.get("winnerId"))) : (matchStakeExtra > 0 && meWon && !isDraw);
        boolean lostPaid = isPaid && isPaidSettled && !wonPaid && !isDraw;
        long payoutCoins = paidDuel != null ? PaidDuelController.number(settlement.get("payoutCoins"), 0) : (matchStakeExtra * 2L);
        long stakeCoins = paidDuel != null ? PaidDuelController.number(paidDuelState.get("stakeCoins"), 0) : (long) matchStakeExtra;
        if (stakeCoins <= 0 && payoutCoins > 0) stakeCoins = payoutCoins / 2;
        if (payoutCoins <= 0 && stakeCoins > 0) payoutCoins = stakeCoins * 2;
        final boolean isVictory = isPaid ? wonPaid : meWon;

        root.setClipChildren(false);
        if (overlay != null) overlay.setClipChildren(false);

        final LinearLayout banner = new LinearLayout(this);
        banner.setOrientation(LinearLayout.VERTICAL);
        banner.setGravity(Gravity.CENTER);
        int bgStart, bgEnd, strokeColor;
        if (isVictory) {
            bgStart = 0xF62C1D06;
            bgEnd = 0xF6130B02;
            strokeColor = 0xFFFFD700;
        } else if (isPaid && isDraw) {
            bgStart = 0xF60A1E38;
            bgEnd = 0xF6050E1A;
            strokeColor = 0xFF38BDF8;
        } else if (isPaid && lostPaid) {
            bgStart = 0xF628090D;
            bgEnd = 0xF6120204;
            strokeColor = 0xFFEF4444;
        } else {
            bgStart = 0xF60F172A;
            bgEnd = 0xF6070B14;
            strokeColor = 0xFF475569;
        }
        banner.setBackground(gradientCardBg(bgStart, bgEnd, strokeColor, 20, 2.5f));
        banner.setPadding(dpx(22), dpx(16), dpx(22), dpx(16));
        LinearLayout.LayoutParams blp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        blp.bottomMargin = dpx(12);
        banner.setLayoutParams(blp);

        // Top Icon
        if (isVictory) {
            ImageView trophy = new ImageView(this);
            trophy.setImageResource(R.drawable.ic_main_challenge_mini_trophy);
            LinearLayout.LayoutParams tilp = new LinearLayout.LayoutParams(dpx(44), dpx(44));
            tilp.bottomMargin = dpx(6);
            trophy.setLayoutParams(tilp);
            banner.addView(trophy);
            applyFloatingMotion(trophy);
        } else if (isPaid && isDraw) {
            TextView icon = new TextView(this);
            icon.setText("🤝");
            icon.setTextSize(TypedValue.COMPLEX_UNIT_SP, 30f);
            icon.setGravity(Gravity.CENTER);
            LinearLayout.LayoutParams ilp = new LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT);
            ilp.bottomMargin = dpx(4);
            icon.setLayoutParams(ilp);
            banner.addView(icon);
        } else if (isPaid && lostPaid) {
            TextView icon = new TextView(this);
            icon.setText("🔻");
            icon.setTextSize(TypedValue.COMPLEX_UNIT_SP, 28f);
            icon.setGravity(Gravity.CENTER);
            LinearLayout.LayoutParams ilp = new LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT);
            ilp.bottomMargin = dpx(4);
            icon.setLayoutParams(ilp);
            banner.addView(icon);
        } else {
            TextView icon = new TextView(this);
            icon.setText("🛡️");
            icon.setTextSize(TypedValue.COMPLEX_UNIT_SP, 24f);
            icon.setGravity(Gravity.CENTER);
            LinearLayout.LayoutParams ilp = new LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT);
            ilp.bottomMargin = dpx(4);
            icon.setLayoutParams(ilp);
            banner.addView(icon);
        }

        // Title re-parenting
        if (title != null) {
            if (title.getParent() instanceof ViewGroup) {
                ((ViewGroup) title.getParent()).removeView(title);
            }
            title.setTextSize(TypedValue.COMPLEX_UNIT_SP, isVictory ? 26f : 23f);
            title.setTextColor(isVictory ? 0xFFFFD700 : (isPaid ? (isDraw ? 0xFF7DD3FC : 0xFFFCA5A5) : 0xFFE2E8F0));
            title.setTypeface(getBoardFont() != null ? getBoardFont() : Typeface.DEFAULT_BOLD, Typeface.BOLD);
            title.setShadowLayer(8f, 0, 2f, isVictory ? 0x99FFD700 : (isPaid && !isDraw ? 0x66EF4444 : 0x44000000));
            banner.addView(title);
        }

        // Animated Economy Badge (Pill)
        final LinearLayout badge = new LinearLayout(this);
        badge.setOrientation(LinearLayout.HORIZONTAL);
        badge.setGravity(Gravity.CENTER);
        badge.setPadding(dpx(18), dpx(8), dpx(18), dpx(8));
        LinearLayout.LayoutParams bagLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        bagLp.topMargin = dpx(8);
        bagLp.bottomMargin = dpx(6);
        badge.setLayoutParams(bagLp);

        TextView coinIcon = new TextView(this);
        coinIcon.setText("🪙");
        coinIcon.setTextSize(TypedValue.COMPLEX_UNIT_SP, 24f);
        coinIcon.setPadding(0, 0, dpx(6), 0);
        badge.addView(coinIcon);

        final TextView deltaText = new TextView(this);
        deltaText.setTextSize(TypedValue.COMPLEX_UNIT_SP, 28f);
        deltaText.setTypeface(getBoardFont() != null ? getBoardFont() : Typeface.DEFAULT_BOLD, Typeface.BOLD);
        badge.addView(deltaText);

        if (isVictory) {
            badge.setBackground(gradientCardBg(0x66000000, 0x88382302, 0xFFFFD700, 24, 1.5f));
            deltaText.setTextColor(0xFFFFF59D);
            deltaText.setShadowLayer(10f, 0, 2f, 0xAAFFD700);
        } else if (isPaid && isDraw) {
            badge.setBackground(gradientCardBg(0x66000000, 0x880C2644, 0xFF38BDF8, 24, 1.5f));
            deltaText.setTextColor(0xFFBAE6FD);
        } else if (isPaid && lostPaid) {
            badge.setBackground(gradientCardBg(0x66000000, 0x883B090E, 0xFFEF4444, 24, 1.5f));
            deltaText.setTextColor(0xFFFCA5A5);
            deltaText.setShadowLayer(10f, 0, 2f, 0xAAEF4444);
        } else {
            badge.setBackground(gradientCardBg(0x44000000, 0x661E293B, 0xFF64748B, 24, 1f));
            deltaText.setTextColor(0xFF94A3B8);
        }
        banner.addView(badge);

        // Subtitle text
        TextView subLabel = makeBoardText("", 13.5f, 0xFFFFFFFF, Gravity.CENTER);
        LinearLayout.LayoutParams subLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        subLp.topMargin = dpx(2);
        subLabel.setLayoutParams(subLp);
        banner.addView(subLabel);

        // Wallet Balance Pill
        final TextView walletBalance = makeBoardText("", 14f, 0xFFE2E8F0, Gravity.CENTER);
        walletBalance.setPadding(dpx(14), dpx(5), dpx(14), dpx(5));
        walletBalance.setBackground(gradientCardBg(0x44020617, 0x770F172A, 0x6694A3B8, 16, 1f));
        LinearLayout.LayoutParams wlp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        wlp.topMargin = dpx(8);
        walletBalance.setLayoutParams(wlp);
        banner.addView(walletBalance);

        // Execute Motion & Calculations
        final int currentCoins = paidDuel != null && paidResultCoins != null
                ? paidResultCoins : PlayerProgress.getCoins(this);
        if (isVictory) {
            final int winCoins = (int) (isPaid ? stakeCoins : Math.max(0, boardResultCurrencyDelta));
            final int startingCoins = Math.max(0, currentCoins - winCoins);
            subLabel.setText("✨ أُضيفت أرباح الجائزة (+ " + String.format(Locale.getDefault(), "%,d", winCoins) + " قطعة) إلى محفظتك ✨");
            subLabel.setTextColor(0xFFFFECC0);

            animateNumberCounter(deltaText, 0, winCoins, "+", "قطعة", 1300L, new Runnable() {
                @Override
                public void run() {
                    badge.animate().scaleX(1.15f).scaleY(1.15f).setDuration(160L)
                            .withEndAction(() -> badge.animate().scaleX(1f).scaleY(1f).setDuration(200L).start())
                            .start();
                }
            });
            animateNumberCounter(walletBalance, startingCoins, currentCoins, "💼 رصيدك: ", "قطعة", 1300L, null);

            banner.postDelayed(() -> {
                if (!isFinishing() && overlay != null) {
                    playCoinBurstMotion(overlay, 0, 0, 16);
                }
            }, 300L);
        } else if (isPaid && lostPaid) {
            final int lostAmount = (int) stakeCoins;
            final int startingCoins = currentCoins + lostAmount;
            subLabel.setText("🔻 تم خصم مبلغ الرهان (- " + String.format(Locale.getDefault(), "%,d", lostAmount) + " قطعة) من محفظتك 🔻");
            subLabel.setTextColor(0xFFFECACA);

            animateNumberCounter(deltaText, 0, lostAmount, "-", "قطعة", 1100L, new Runnable() {
                @Override
                public void run() {
                    badge.animate().scaleX(1.12f).scaleY(1.12f).setDuration(140L)
                            .withEndAction(() -> badge.animate().scaleX(1f).scaleY(1f).setDuration(180L).start())
                            .start();
                }
            });
            animateNumberCounter(walletBalance, startingCoins, currentCoins, "💼 الرصيد المتبقي: ", "قطعة", 1100L, null);

            banner.postDelayed(() -> {
                if (!isFinishing() && overlay != null) {
                    playCoinDeductionMotion(overlay, 0, 0, 10);
                }
            }, 200L);
        } else if (isPaid && isDraw) {
            deltaText.setText(String.format(Locale.getDefault(), "↺ استرداد %,d قطعة", (int) stakeCoins));
            subLabel.setText("🤝 لم يتم خصم أي قطعة من رصيدك، أُعيد الرهان كاملًا 🤝");
            subLabel.setTextColor(0xFFBAE6FD);
            walletBalance.setText(String.format(Locale.getDefault(), "💼 رصيدك: %,d قطعة", currentCoins));
        } else {
            deltaText.setText(String.format(Locale.getDefault(), "+%,d قطعة", Math.max(0, boardResultCurrencyDelta)));
            subLabel.setText("مكافأة إكمال المباراة — لم يتم خصم رهان من محفظتك 🛡️");
            subLabel.setTextColor(0xFF94A3B8);
            walletBalance.setText(String.format(Locale.getDefault(), "💼 رصيدك الحالي: %,d قطعة", currentCoins));
        }
        if (paidDuel != null && paidResultCoins == null) {
            walletBalance.setText("💼 يُحدّث الرصيد عند عودة الاتصال");
        }

        root.addView(banner, 0);

        banner.setAlpha(0f);
        banner.setScaleX(0.45f);
        banner.setScaleY(0.45f);
        banner.animate().alpha(1f).scaleX(1f).scaleY(1f).setDuration(isVictory ? 850L : 500L)
                .setInterpolator(new OvershootInterpolator(isVictory ? 2.0f : 1.4f))
                .withEndAction(new Runnable() {
                    @Override
                    public void run() {
                        if (isPaid && lostPaid) {
                            applyShakeMotion(banner);
                        }
                    }
                }).start();
    }

    private void showBoardResultScreen(String headline, int teamAScore, int teamBScore,
                                       int meSeatIndex, boolean[] seatWon) {
        if (!EXITING && presenterDialogue.deferAll("boardResult",
                () -> showBoardResultScreen(headline, teamAScore, teamBScore, meSeatIndex, seatWon))) return;
        if (modeOnline) OnlineMatchRecovery.complete(this, headline, !ACTIVITY_PAUSED);
        final FrameLayout overlay = (FrameLayout) findViewById(R.id.boardOverlay);
        if (overlay == null) {
            proceedAfterBoardResult();
            return;
        }
        final int meSeat = (meSeatIndex >= 0 && meSeatIndex < seatWon.length) ? meSeatIndex : 0;
        boardResultProceeded = false;
        releaseResultVideos();
        // Free the in-game podium video players first so only the result clips run
        // (scores/figures stay readable — release() doesn't clear that data).
        offlineContestants.release();
        overlay.removeAllViews();
        overlay.setBackgroundColor(0xF20A0F2E);
        overlay.setVisibility(View.VISIBLE);
        overlay.bringToFront();

        ScrollView scroll = new ScrollView(this);
        scroll.setLayoutParams(new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT));
        scroll.setFillViewport(true);
        scroll.setVerticalScrollBarEnabled(false);
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setGravity(Gravity.CENTER);
        root.setPadding(dpx(16), dpx(18), dpx(16), dpx(18));
        scroll.addView(root);

        // Headline
        final boolean meWon = (meSeat >= 0 && meSeat < seatWon.length) ? seatWon[meSeat] : false;
        TextView title = makeBoardText(headline, 28f,
                meWon ? 0xFFFFD761 : 0xFFE2E8F0, Gravity.CENTER);
        LinearLayout.LayoutParams tlp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        tlp.bottomMargin = dpx(4);
        title.setLayoutParams(tlp);
        root.addView(title);

        boolean matchDraw = seatWon.length == 2 && seatWon[0] && seatWon[1];
        buildMatchEconomyMotionBanner(root, overlay, meWon, matchDraw, title);

        // Score summary line
        String summary = boardTeamMatch
                ? ("الفريق أ  " + teamAScore + "   —   " + teamBScore + "  الفريق ب")
                : ("نقاطك: " + offlineContestants.scoreForSlot(meSeat));
        TextView sub = makeBoardText(summary + "\n" + PlayerStats.matchRewardSummary(this),
                16f, 0xFFB9C4DE, Gravity.CENTER);
        LinearLayout.LayoutParams slp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        slp.bottomMargin = dpx(14);
        sub.setLayoutParams(slp);
        root.addView(sub);

        // Contestant order: winners first, then by score descending.
        final int count = seatWon.length;
        final Integer[] order = new Integer[count];
        for (int g = 0; g < count; g++) order[g] = g;
        java.util.Arrays.sort(order, new java.util.Comparator<Integer>() {
            @Override
            public int compare(Integer a, Integer b) {
                if (seatWon[a] != seatWon[b]) return seatWon[a] ? -1 : 1;
                return Integer.compare(offlineContestants.scoreForSlot(b),
                        offlineContestants.scoreForSlot(a));
            }
        });

        android.widget.HorizontalScrollView cardsScroll = new android.widget.HorizontalScrollView(this);
        cardsScroll.setHorizontalScrollBarEnabled(false);
        LinearLayout.LayoutParams csLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        csLp.gravity = Gravity.CENTER_HORIZONTAL;
        cardsScroll.setLayoutParams(csLp);
        LinearLayout cardsRow = new LinearLayout(this);
        cardsRow.setOrientation(LinearLayout.HORIZONTAL);
        cardsRow.setGravity(Gravity.BOTTOM);
        cardsRow.setClipChildren(false);
        cardsRow.setClipToPadding(false);
        cardsRow.setPadding(dpx(6), dpx(8), dpx(6), dpx(8));
        for (int i = 0; i < order.length; i++) {
            cardsRow.addView(makeResultCard(order[i], seatWon[order[i]]));
        }
        cardsScroll.addView(cardsRow);
        root.addView(cardsScroll);

        if (boardOnline && !boardRoomMatch) {
            Button details = new Button(this);
            details.setText("تفاصيل الأسئلة والنقاط");
            details.setAllCaps(false);
            final LinearLayout history = new LinearLayout(this);
            history.setOrientation(LinearLayout.VERTICAL);
            history.setVisibility(View.GONE);
            for (int turn = 0; turn < boardTotalTurns; turn++) {
                Map<String, Object> result = OnlineDuelState.map(duelTurnLedger.get("t" + turn));
                if (!Boolean.TRUE.equals(result.get("done"))) continue;
                int col = OnlineDuelState.number(result.get("col"), -1);
                int row = OnlineDuelState.number(result.get("row"), -1);
                String name = myID.equals(result.get("playerId")) ? myName : opponentName;
                int points = OnlineDuelState.number(result.get("points"), 0);
                String outcome = Boolean.TRUE.equals(result.get("correct")) ? "صحيحة" : "خاطئة / انتهى الوقت";
                String question = boardCellQuestion != null && col >= 0 && col < boardCols
                        && row >= 0 && row < BOARD_ROWS ? boardCellQuestion[col][row].getQ() : "";
                TextView entry = makeBoardText((turn + 1) + ". " + name + " • " + outcome
                        + " • " + points + " نقطة\n" + question, 13f, 0xFFE2E8F0, Gravity.RIGHT);
                entry.setPadding(dpx(8), dpx(8), dpx(8), dpx(8));
                history.addView(entry);
            }
            details.setOnClickListener(v -> history.setVisibility(
                    history.getVisibility() == View.GONE ? View.VISIBLE : View.GONE));
            root.addView(details);
            root.addView(history);
        }

        // Return button
        Button back = new Button(this);
        back.setText("العودة للقائمة");
        back.setAllCaps(false);
        back.setTextColor(0xFFFFFFFF);
        back.setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f);
        if (getBoardFont() != null) back.setTypeface(getBoardFont(), Typeface.BOLD);
        back.setBackground(pillBg(0xFF29B6F6));
        LinearLayout.LayoutParams blp = new LinearLayout.LayoutParams(dpx(220), dpx(52));
        blp.topMargin = dpx(18);
        back.setLayoutParams(blp);
        back.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                proceedAfterBoardResult();
            }
        });
        root.addView(back);

        overlay.addView(scroll);

        // Auto-continue if the player lingers.
        if (!(boardOnline && !boardRoomMatch)) new Handler().postDelayed(new Runnable() {
            @Override
            public void run() {
                if (!EXITING) proceedAfterBoardResult();
            }
        }, 16000);
    }

    /** One contestant card: a looping celebration/sad clip + name + score, with chrome. */
    private View makeResultCard(int seat, boolean won) {
        final boolean teamB = boardTeamMatch && "B".equals(boardSeatTeam[seat]);
        final int accent = !boardTeamMatch
                ? (won ? 0xFFFFD761 : 0xFF64748B)
                : (teamB ? 0xFF7DD3FC : 0xFFFFD761);

        LinearLayout card = new LinearLayout(this);
        card.setOrientation(LinearLayout.VERTICAL);
        card.setGravity(Gravity.CENTER_HORIZONTAL);
        card.setClipChildren(false);
        card.setClipToPadding(false);
        LinearLayout.LayoutParams cardLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        cardLp.setMargins(dpx(6), 0, dpx(6), 0);
        card.setLayoutParams(cardLp);
        if (!won) card.setAlpha(0.88f);

        // Crown above winners.
        TextView crown = makeBoardText(won ? "👑" : "", 20f, 0xFFFFD761, Gravity.CENTER);
        LinearLayout.LayoutParams crLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT, dpx(26));
        crLp.gravity = Gravity.CENTER_HORIZONTAL;
        crown.setLayoutParams(crLp);
        card.addView(crown);

        // Video stage: a rounded "spotlight" panel with the chroma-keyed clip on top.
        final float videoAspect = 720f / 1280f;
        int videoH = dpx(won ? 172 : 148);
        int videoW = Math.round(videoH * videoAspect);
        FrameLayout stage = new FrameLayout(this);
        LinearLayout.LayoutParams stLp = new LinearLayout.LayoutParams(videoW, videoH);
        stage.setLayoutParams(stLp);
        stage.setClipChildren(false);

        GradientDrawable stageBg = new GradientDrawable(
                GradientDrawable.Orientation.TOP_BOTTOM,
                new int[]{ (accent & 0x00FFFFFF) | 0x33000000, 0x66061026 });
        stageBg.setCornerRadius(dpx(16));
        stageBg.setStroke(dpx(won ? 3 : 2), accent);
        stage.setBackground(stageBg);

        int charIdx = offlineContestants.characterForSlot(seat);
        int videoRes = GameOfflineContestantsController.reactionVideoForCharacter(charIdx, won);
        if (videoRes != 0 && !GameOfflineContestantsController.isLowEndDevice(this)) {
            ChromaVideoView video = new ChromaVideoView(this, videoRes);
            resultVideoViews.add(video);
            // The stage is already aspect-correct (videoW = videoH * 720/1280), so fill it.
            FrameLayout.LayoutParams vLp = new FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT);
            vLp.gravity = Gravity.CENTER;
            video.setLayoutParams(vLp);
            stage.addView(video);
        } else {
            ImageView img = new ImageView(this);
            img.setImageResource(GameOfflineContestantsController.drawableForCharacter(charIdx));
            img.setScaleType(ImageView.ScaleType.FIT_CENTER);
            FrameLayout.LayoutParams vLp = new FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT);
            vLp.gravity = Gravity.CENTER;
            img.setLayoutParams(vLp);
            stage.addView(img);
        }
        card.addView(stage);

        // Name
        String rawName = resultSeatName(seat);
        if (rawName.length() > 10) rawName = rawName.substring(0, 10);
        TextView name = makeBoardText(rawName, 13f, 0xFFFFFFFF, Gravity.CENTER);
        name.setMaxLines(1);
        LinearLayout.LayoutParams nLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        nLp.topMargin = dpx(6);
        nLp.width = videoW + dpx(12);
        name.setLayoutParams(nLp);
        card.addView(name);

        // Score pill (team-tinted for team mode, gold for solo winner)
        TextView scoreView = makeBoardText(String.valueOf(offlineContestants.scoreForSlot(seat)),
                14f, 0xFF0A0F2E, Gravity.CENTER);
        scoreView.setPadding(dpx(12), dpx(2), dpx(12), dpx(2));
        scoreView.setBackground(pillBg(accent));
        LinearLayout.LayoutParams scLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        scLp.gravity = Gravity.CENTER_HORIZONTAL;
        scLp.topMargin = dpx(4);
        scoreView.setLayoutParams(scLp);
        card.addView(scoreView);

        // Team tag (team mode only)
        if (boardTeamMatch) {
            TextView tag = makeBoardText(teamB ? "الفريق ب" : "الفريق أ", 11f, accent, Gravity.CENTER);
            LinearLayout.LayoutParams tgLp = new LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT);
            tgLp.gravity = Gravity.CENTER_HORIZONTAL;
            tgLp.topMargin = dpx(3);
            tag.setLayoutParams(tgLp);
            card.addView(tag);
        }

        if (won) {
            card.setScaleX(0.9f);
            card.setScaleY(0.9f);
            card.animate().scaleX(1f).scaleY(1f).setDuration(420).start();
        }
        return card;
    }

    /** Card name: raw seat name for the room board, the contestant name otherwise. */
    private String resultSeatName(int seat) {
        if (boardRoomMatch && boardSeatName != null && seat >= 0 && seat < boardSeatName.length
                && boardSeatName[seat] != null && !boardSeatName[seat].trim().isEmpty()) {
            return boardSeatName[seat];
        }
        String n = offlineContestants.nameForSlot(seat);
        return (n == null || n.trim().isEmpty()) ? ("لاعب " + (seat + 1)) : n;
    }

    private void releaseResultVideos() {
        for (Animator animator : resultMotionAnimators) {
            animator.removeAllListeners();
            animator.cancel();
        }
        resultMotionAnimators.clear();
        for (int i = 0; i < resultVideoViews.size(); i++) {
            try {
                resultVideoViews.get(i).release();
            } catch (Exception ignored) {
            }
        }
        resultVideoViews.clear();
    }

    private void proceedAfterBoardResult() {
        if (boardResultProceeded) return;
        boardResultProceeded = true;
        releaseResultVideos();
        hideBoardOverlay();
        offlineContestants.release();
        stopCurrentSound();
        if (cdtProgress != null) cdtProgress.cancel();
        // Campaign stages finish the activity so Flutter's CampaignResultHandler can
        // read the pending result and show the stage result screen (stars/rewards).
        if (boardCampaignMatch) {
            finishCampaignAndReturnToFlutter();
            return;
        }
        showInterstitialAd();
    }

    /** Writes the room board result so the Flutter side can finalize the room. */
    private void persistPendingRoomBoardResult(boolean isTeam, String winnerTeam, String winnerId) {
        if (roomId == null || roomId.trim().isEmpty()) return;
        try {
            JSONObject payload = new JSONObject();
            payload.put("roomId", roomId);
            payload.put("matchMode", isTeam ? "team_battle" : "battle");
            payload.put("boardRoom", true);
            payload.put("isTeam", isTeam);
            payload.put("meOwner", meOwner);
            payload.put("winnerTeam", winnerTeam == null ? "" : winnerTeam);
            payload.put("winnerId", winnerId == null ? "" : winnerId);
            payload.put("score", offlineContestants.scoreForSlot(mySeat));
            payload.put("answeredCount", Math.max(0, boardMyCorrectCount));
            JSONArray array = new JSONArray();
            for (int g = 0; g < boardSeatCount; g++) {
                if (g == mySeat) continue;
                JSONObject o = new JSONObject();
                o.put("id", boardSeatId[g]);
                o.put("userId", boardSeatId[g]);
                o.put("seatId", boardSeatId[g]);
                o.put("name", boardSeatName[g]);
                o.put("score", offlineContestants.scoreForSlot(g));
                o.put("teamId", boardSeatTeam[g] == null ? "" : boardSeatTeam[g]);
                o.put("bot", boardSeatIsBot[g]);
                array.put(o);
            }
            payload.put("opponentsJson", array.toString());
            AppPrefs.setPendingRoomMatchResult(this, payload.toString());
        } catch (Exception ignored) {
        }
    }

    // =====================================================================
    //  Online board ("التحدي") — two real players, one synced board.
    //  Slot 0 is me, slot 1 the matched opponent. Each player picks one
    //  category; the owner assembles the 2x6 board and pushes its questions to
    //  Games/{gameID}/board. Turns alternate (owner on even turns); on your turn
    //  you pick + answer (writing the result), on the opponent's turn you watch
    //  their pick and result. A bot fallback plays the plain offline board.
    // =====================================================================

    /** Entry point for an online speed-challenge board match (after matchmaking). */
    private void setupBoardMatch() {
        int intentChar = getIntent().getIntExtra("characterIndex", -1);
        int characterIndex = CharacterUnlocks.isValid(intentChar)
                ? intentChar
                : AppPrefs.getEffectiveCharacter(this);
        boardMode = true;
        MatchOpponent primary = getPrimaryOpponent();
        String opponentSeatName = (primary != null && primary.name != null
                && !primary.name.trim().isEmpty()) ? primary.name : "الكمبيوتر";
        // Slot 0 = me, slot 1 = opponent — each gets a figure matching its name's gender.
        offlineContestants.setupForRoomBoard(2, characterIndex,
                new String[]{ myName, opponentSeatName }, new String[]{ "", "" }, false);
        if (primary != null && primary.bot && primary.intelligence > 0) {
            offlineContestants.setIntelligenceForSlot(1, primary.intelligence);
        }
        boardPool = LocalQuestions.loadBoardPool(this);
        buildBoardCategoryList();
        questionsReady = true;
        // No human found → fall back to the plain offline board (the intro flow starts
        // it, like offline). With a real opponent, drive the synced online board.
        boardOnline = !(primary == null || primary.bot);
        if (!boardOnline) {
            boardCharacterIndex = characterIndex;
            offlineBoardSaveId = NativeProgression.fallbackId(this);
            // Reuse the board serializer, but keep online bot games in the account's
            // recovery store instead of the device-wide offline match library.
            pendingOfflineBoardRestore = OnlineMatchRecovery.botCheckpoint(this);
        }
        if (boardOnline) {
            if (!safeIntentString("stakeMatchId", "").isEmpty()) {
                gameID = safeIntentString("stakeMatchId", "");
                paidDuel = new PaidDuelController(gameID, myID, new PaidDuelController.Listener() {
                    @Override public void onState(Map<String, Object> match,
                                                   Map<String, Object> question, String action) {
                        applyPaidDuelState(match, question, action);
                    }
                    @Override public void onFailure(Exception error) {
                        if (isFinishing() || duelActivityDestroyed) return;
                        boardPickPending = false;
                        paidDuelExiting = false;
                        paidDuelRenderKey = "";
                        if (!paidDuelState.isEmpty()) applyPaidDuelState(paidDuelState, paidDuelQuestion, "retry");
                        GameNotice.makeText(GameActivity.this, safeString(error.getMessage()).isEmpty()
                                ? "جارٍ إعادة الاتصال بالمباراة…" : error.getMessage(), Toast.LENGTH_LONG).show();
                    }
                });
                findViewById(android.R.id.content).post(() -> {
                    if (!duelActivityDestroyed && !EXITING) paidDuel.resume();
                });
            } else startOnlineBoardSession();
        }
    }

    // =====================================================================
    //  Online TEAM board ("تحدي جماعي") — N players in two teams, one synced
    //  board, launched from a Firestore room (gameID == roomId). Seats are kept
    //  in a deterministic interleaved order (A,B,A,B…) shared by every device, so
    //  turn t belongs to seat (t % N) and consecutive turns alternate teams. The
    //  host (meOwner) builds/pushes the board and drives every bot / abandoned
    //  seat; everyone else watches. Each cell value is added to the picker's team.
    // =====================================================================

    /** Entry point for a room board match (competition or team) after the lobby starts. */
    private void setupRoomBoardMatch(boolean isTeam) {
        int intentChar = getIntent().getIntExtra("characterIndex", -1);
        int characterIndex = CharacterUnlocks.isValid(intentChar)
                ? intentChar
                : AppPrefs.getEffectiveCharacter(this);
        boardMode = true;
        boardRoomMatch = true;
        boardTeamMatch = isTeam;
        boardOnline = true;
        if (isTeam && myTeam.isEmpty()) myTeam = "A";
        gameID = roomId;
        buildBoardSeatOrder();
        // setupForRoomBoard assigns each seat a gender-matched figure for its name and
        // (for team matches) a team tag/colour on the podium.
        offlineContestants.setupForRoomBoard(boardSeatCount, characterIndex,
                boardSeatName, boardSeatTeam, isTeam);
        boardPool = LocalQuestions.loadBoardPool(this);
        buildBoardCategoryList();
        boardCols = boardSeatCount;
        questionsReady = true;
        // gameID is known (== roomId), so begin the session now and open the category
        // pick once onCreate has finished wiring the rest of the views (deferred to a
        // post, so the overlay builds against a fully-initialised activity).
        beginOnlineGameSession();
        findViewById(android.R.id.content).post(new Runnable() {
            @Override
            public void run() {
                if (!EXITING) resumeOrSelectDuelCategory();
            }
        });
    }

    /**
     * Builds the deterministic global seat order from me + all room opponents.
     * Team match → interleave A,B,A,B… (so turns alternate teams); competition →
     * a single list sorted by userId. Every device produces the same order.
     */
    private void buildBoardSeatOrder() {
        if (boardTeamMatch) {
            buildTeamSeatOrder();
        } else {
            buildSoloSeatOrder();
        }
        mySeat = 0;
        String myKey = boardSeatKeyFor(myID, myID);
        for (int g = 0; g < boardSeatCount; g++) {
            if (myKey.equals(boardSeatId[g])) { mySeat = g; break; }
        }
    }

    private void buildTeamSeatOrder() {
        ArrayList<String[]> teamAList = new ArrayList<>();
        ArrayList<String[]> teamBList = new ArrayList<>();
        // [seatId, name, team, bot("1"/"0")]
        addSeatToTeam(teamAList, teamBList, new String[]{
                boardSeatKeyFor(myID, myID), myName, normalizeTeam(myTeam), "0"});
        for (MatchOpponent opp : opponents) {
            if (opp.id == null || opp.id.trim().isEmpty()) continue;
            addSeatToTeam(teamAList, teamBList, new String[]{
                    boardSeatKeyFor(opp.id, opp.seatId), opp.name,
                    normalizeTeam(opp.teamId), opp.bot ? "1" : "0"});
        }
        sortSeatsById(teamAList);
        sortSeatsById(teamBList);

        allocateSeatArrays(teamAList.size() + teamBList.size());
        int idx = 0, i = 0, j = 0;
        while (i < teamAList.size() || j < teamBList.size()) {
            if (i < teamAList.size()) { assignSeat(idx++, teamAList.get(i++)); }
            if (j < teamBList.size()) { assignSeat(idx++, teamBList.get(j++)); }
        }
    }

    private void buildSoloSeatOrder() {
        ArrayList<String[]> all = new ArrayList<>();
        // [seatId, name, team(""), bot("1"/"0")]
        all.add(new String[]{boardSeatKeyFor(myID, myID), myName, "", "0"});
        for (MatchOpponent opp : opponents) {
            if (opp.id == null || opp.id.trim().isEmpty()) continue;
            all.add(new String[]{boardSeatKeyFor(opp.id, opp.seatId), opp.name,
                    "", opp.bot ? "1" : "0"});
        }
        sortSeatsById(all);
        allocateSeatArrays(all.size());
        for (int g = 0; g < all.size(); g++) {
            assignSeat(g, all.get(g));
        }
    }

    private void allocateSeatArrays(int count) {
        boardSeatCount = Math.max(2, count);
        boardSeatId = new String[boardSeatCount];
        boardSeatName = new String[boardSeatCount];
        boardSeatTeam = new String[boardSeatCount];
        boardSeatIsBot = new boolean[boardSeatCount];
        boardSeatLeft = new boolean[boardSeatCount];
    }

    private void assignSeat(int g, String[] seat) {
        if (g < 0 || g >= boardSeatCount) return;
        boardSeatId[g] = seat[0];
        boardSeatName[g] = (seat[1] == null || seat[1].trim().isEmpty()) ? ("لاعب " + (g + 1)) : seat[1];
        boardSeatTeam[g] = seat[2];
        boardSeatIsBot[g] = "1".equals(seat[3]);
        boardSeatLeft[g] = false;
    }

    private void addSeatToTeam(ArrayList<String[]> teamA, ArrayList<String[]> teamB, String[] seat) {
        if ("B".equals(seat[2])) teamB.add(seat); else teamA.add(seat);
    }

    private void sortSeatsById(ArrayList<String[]> list) {
        java.util.Collections.sort(list, new java.util.Comparator<String[]>() {
            @Override
            public int compare(String[] a, String[] b) {
                return a[0].compareTo(b[0]);
            }
        });
    }

    /**
     * The board seat key (used for picks + the global seat order). The player's
     * userId is used so every device derives the same key for every seat: my own
     * device knows me as myID, and other devices know me by my opponent id (both
     * are the same userId). seatId is intentionally ignored to stay deterministic.
     */
    private String boardSeatKeyFor(String id, String seatId) {
        return id == null ? "" : id.trim();
    }

    private String normalizeTeam(String team) {
        String t = team == null ? "" : team.trim().toUpperCase();
        return "B".equals(t) ? "B" : "A";
    }

    private String boardLocalSeatId() {
        return boardRoomMatch ? boardSeatId[mySeat] : myID;
    }

    private int seatIndexForId(String id) {
        if (boardSeatId == null || id == null) return -1;
        for (int g = 0; g < boardSeatCount; g++) {
            if (id.equals(boardSeatId[g])) return g;
        }
        return -1;
    }

    private boolean boardSeatIsLocal(int seat) {
        return boardRoomMatch ? (seat == mySeat) : (seat == 0);
    }

    private DatabaseReference boardRef() {
        return FirebaseDatabase.getInstance().getReference()
                .child("Games").child(gameID).child("board");
    }

    /** Owner creates the game session; the joiner looks it up. Then both pick a category. */
    private void startOnlineBoardSession() {
        if (safeIntentString("duelSessionId", "").isEmpty()) {
            GameNotice.makeText(this, "معرّف المباراة مفقود. أعد البحث عن منافس.", Toast.LENGTH_LONG).show();
            finish();
            return;
        }
        gameID = safeIntentString("duelSessionId", "");
        attachDuelTerminalListener();
        if (meOwner) {
            new Data().createGameIDWithSession(myID, getOpponentIds(), gameID, new OnCreateGameIdListener() {
                @Override
                public void onSuccess(String createdGameID) {
                    if (EXITING || boardDuelFinished) return;
                    gameID = createdGameID;
                    beginOnlineGameSession();
                    attachOpponentStatusListener();
                    resumeOrSelectDuelCategory();
                }

                @Override
                public void onFailed(DatabaseError error) {
                    GameNotice.makeText(GameActivity.this, "تعذر إنشاء المباراة", Toast.LENGTH_SHORT).show();
                    finish();
                }
            });
        } else {
            // Wait for the session reserved by the atomic matchmaking transaction.
            stopDuelSessionListener = new Data().getDuelGameID(myID, opponentID, safeIntentString("duelSessionId", ""), new OnGetGameIdListener() {
                @Override
                public void onSuccess(String foundGameID) {
                    if (EXITING || boardDuelFinished || boardPicksRef != null) return;
                    if (foundGameID == null || foundGameID.trim().isEmpty()) return;
                    gameID = foundGameID;
                    beginOnlineGameSession();
                    attachOpponentStatusListener();
                    resumeOrSelectDuelCategory();
                }

                @Override
                public void onFailed(DatabaseError error) {
                }
            });
        }
    }

    // ---- Online category select (each player picks exactly one) ----------

    private void resumeOrSelectDuelCategory() {
        boardRef().addListenerForSingleValueEvent(new ValueEventListener() {
            @Override public void onDataChange(DataSnapshot board) {
                if (EXITING || boardDuelFinished || duelActivityDestroyed || boardStarted) return;
                if (Boolean.TRUE.equals(board.child("ready").getValue(Boolean.class))) {
                    boardStarted = true;
                    detachBoardSetupListeners();
                    duelNeedsBoardResync = true;
                    loadOnlineBoardFromFirebase(board);
                } else restoreDuelCategorySetup(board);
            }
            @Override public void onCancelled(DatabaseError error) {
                retryDuelAction(boardOnlineTurn, () -> resumeOrSelectDuelCategory());
            }
        });
    }

    private void restoreDuelCategorySetup(DataSnapshot board) {
        String category = board.child("picks").child(myID).child("category").getValue(String.class);
        if (category == null || category.isEmpty()) {
            showOnlineBoardCategorySelect();
        } else {
            stopCategorySelectMusicIfPlaying();
            showBoardWaitingOverlay("اخترت: " + category + "\nبانتظار اختيار الخصم…");
            if (meOwner) {
                if (boardRoomMatch) attachRoomBoardPicksListener();
                else attachBoardPicksListener();
            }
        }
        attachBoardReadyListener();
    }

    private void showOnlineBoardCategorySelect() {
        GameEconomy.clearSelection(this);
        final FrameLayout overlay = (FrameLayout) findViewById(R.id.boardOverlay);
        if (overlay == null) return;
        playCategorySelectMusic();
        overlay.removeAllViews();
        overlay.setBackgroundColor(0xF2071026);
        overlay.setVisibility(View.VISIBLE);
        overlay.bringToFront();

        ScrollView scroll = new ScrollView(this);
        scroll.setLayoutParams(new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT));
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setGravity(Gravity.CENTER_HORIZONTAL);
        root.setPadding(dpx(24), dpx(14), dpx(24), dpx(14));
        scroll.addView(root);

        TextView title = makeBoardText("اختر فئتك للمنافسة", 22f, 0xFFFFFFFF, Gravity.CENTER);
        LinearLayout.LayoutParams tlp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        tlp.bottomMargin = dpx(10);
        title.setLayoutParams(tlp);
        root.addView(title);

        final ArrayList<String> selected = new ArrayList<>();
        final Button confirm = new Button(this);
        final int cols = 4;
        final int total = boardAllCategories.size();
        final int rows = Math.max(1, (total + cols - 1) / cols);
        final ArrayList<FrameLayout> tiles = new ArrayList<>();
        int idx = 0;
        for (int r = 0; r < rows; r++) {
            LinearLayout rowLayout = new LinearLayout(this);
            rowLayout.setOrientation(LinearLayout.HORIZONTAL);
            rowLayout.setLayoutParams(new LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT));
            for (int c = 0; c < cols; c++) {
                if (idx < total) {
                    final String category = boardAllCategories.get(idx);
                    final FrameLayout tile = makeCategoryTile(category);
                    tiles.add(tile);
                    tile.setOnClickListener(new View.OnClickListener() {
                        @Override
                        public void onClick(View v) {
                            if (!AppPrefs.isCategoryUnlocked(GameActivity.this, category)) {
                                showCategoryUnlockDialog(category, tile, selected, null, confirm);
                                return;
                            }
                            selected.clear();
                            selected.add(category);
                            for (FrameLayout t : tiles) {
                                String tCat = t.getTag() instanceof String ? (String) t.getTag() : "";
                                boolean isLocked = !AppPrefs.isCategoryUnlocked(GameActivity.this, tCat);
                                t.setBackground(categoryTileBg(false, isLocked));
                            }
                            tile.setBackground(categoryTileBg(true, false));
                            confirm.setEnabled(true);
                            confirm.setAlpha(1f);
                        }
                    });
                    rowLayout.addView(tile);
                } else {
                    View spacer = new View(this);
                    spacer.setLayoutParams(new LinearLayout.LayoutParams(0, dpx(60), 1f));
                    rowLayout.addView(spacer);
                }
                idx++;
            }
            root.addView(rowLayout);
        }

        confirm.setText("تأكيد");
        confirm.setAllCaps(false);
        confirm.setTextColor(0xFFFFFFFF);
        if (getBoardFont() != null) confirm.setTypeface(getBoardFont(), Typeface.BOLD);
        confirm.setBackground(pillBg(0xFF29B6F6));
        confirm.setEnabled(false);
        confirm.setAlpha(0.5f);
        LinearLayout.LayoutParams cflp = new LinearLayout.LayoutParams(dpx(200), dpx(50));
        cflp.topMargin = dpx(14);
        confirm.setLayoutParams(cflp);
        confirm.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                if (!selected.isEmpty()) {
                    onOnlineCategoryChosen(selected.get(0));
                }
            }
        });
        root.addView(confirm);
        overlay.addView(scroll);
    }

    private void onOnlineCategoryChosen(String category) {
        if (questionSelectionPending || boardDuelFinished) return;
        questionSelectionPending = true;
        QuestionHistory.prepare(this, "", "", excluded -> {
            questionSelectionPending = false;
            if (!EXITING && !isFinishing()) submitOnlineCategory(category);
        }, this::questionSelectionFailed);
    }

    private void submitOnlineCategory(String category) {
        if (boardDuelFinished) return;
        if (gameID == null || gameID.trim().isEmpty()) return;
        getIntent().putExtra("economyChosenCategory", category);
        if (paidDuel != null) {
            Map<String, Object> data = new HashMap<>();
            data.put("category", category);
            paidDuel.call("pickCategory", data);
            return;
        }
        stopCategorySelectMusicIfPlaying();
        showBoardWaitingOverlay("اخترت: " + category
                + (boardRoomMatch ? "\nبانتظار بقية اللاعبين..." : "\nبانتظار اختيار الخصم..."));
        boardRef().child("picks").child(boardLocalSeatId()).child("category").setValue(category);
        attachBoardReadyListener();
        if (meOwner) {
            if (boardRoomMatch) {
                attachRoomBoardPicksListener();
            } else {
                attachBoardPicksListener();
            }
        }
    }

    private void showBoardWaitingOverlay(String message) {
        FrameLayout overlay = (FrameLayout) findViewById(R.id.boardOverlay);
        if (overlay == null) return;
        overlay.removeAllViews();
        overlay.setBackgroundColor(0xF2071026);
        overlay.setVisibility(View.VISIBLE);
        overlay.bringToFront();
        TextView tv = makeBoardText(message, 18f, 0xFFFFD761, Gravity.CENTER);
        FrameLayout.LayoutParams lp = new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.WRAP_CONTENT, FrameLayout.LayoutParams.WRAP_CONTENT, Gravity.CENTER);
        lp.leftMargin = dpx(24);
        lp.rightMargin = dpx(24);
        tv.setLayoutParams(lp);
        overlay.addView(tv);
    }

    // ---- Board build & sync ---------------------------------------------

    /** Owner only: when both categories are in, assemble the board and push it. */
    private void attachBoardPicksListener() {
        if (boardPicksRef != null || gameID == null || gameID.trim().isEmpty()) return;
        final String ownerId = myID;
        final String joinerId = opponentID;
        boardPicksRef = boardRef().child("picks");
        boardPicksListener = new ValueEventListener() {
            @Override
            public void onDataChange(DataSnapshot snapshot) {
                if (EXITING || boardStarted || boardCellQuestion != null) return;
                String ownerCat = snapshot.child(ownerId).child("category").getValue(String.class);
                String joinerCat = snapshot.child(joinerId).child("category").getValue(String.class);
                if (ownerCat == null || ownerCat.isEmpty() || joinerCat == null || joinerCat.isEmpty()) {
                    return;
                }
                buildAndPushOnlineBoard(ownerCat, joinerCat);
            }

            @Override
            public void onCancelled(DatabaseError error) {
            }
        };
        boardPicksRef.addValueEventListener(boardPicksListener);
    }

    /** Host only: once every human seat has picked, assemble the NxBOARD_ROWS board. */
    private void attachRoomBoardPicksListener() {
        if (boardPicksRef != null || gameID == null || gameID.trim().isEmpty()) return;
        boardPicksRef = boardRef().child("picks");
        boardPicksListener = new ValueEventListener() {
            @Override
            public void onDataChange(DataSnapshot snapshot) {
                if (EXITING || boardStarted || boardCellQuestion != null) return;
                HashMap<String, String> picks = new HashMap<>();
                for (int g = 0; g < boardSeatCount; g++) {
                    if (boardSeatIsBot[g]) continue;
                    String cat = snapshot.child(boardSeatId[g]).child("category").getValue(String.class);
                    if (cat == null || cat.isEmpty()) {
                        return; // still waiting for a human to pick
                    }
                    picks.put(boardSeatId[g], cat);
                }
                buildAndPushRoomBoard(picks);
            }

            @Override
            public void onCancelled(DatabaseError error) {
            }
        };
        boardPicksRef.addValueEventListener(boardPicksListener);
    }

    /** Both players: start the board once the owner has published ready cells. */
    private void attachBoardReadyListener() {
        if (boardReadyRef != null || gameID == null || gameID.trim().isEmpty()) return;
        boardReadyRef = boardRef();
        boardReadyListener = new ValueEventListener() {
            @Override
            public void onDataChange(DataSnapshot snapshot) {
                if (EXITING || boardStarted) return;
                if (!boardRoomMatch && (!duelLocallyConnected || ACTIVITY_PAUSED || duelActivityDestroyed)) {
                    duelNeedsBoardResync = true;
                    return;
                }
                Boolean ready = snapshot.child("ready").getValue(Boolean.class);
                if (ready == null || !ready || !snapshot.child("cells").exists()) return;
                boardStarted = true;
                loadOnlineBoardFromFirebase(snapshot);
                detachBoardSetupListeners();
            }

            @Override
            public void onCancelled(DatabaseError error) {
            }
        };
        boardReadyRef.addValueEventListener(boardReadyListener);
    }

    private void buildAndPushOnlineBoard(String ownerCat, String joinerCat) {
        if (boardDuelFinished || boardCellQuestion != null || questionSelectionPending) return;
        retryQuestionSelection = () -> buildAndPushOnlineBoard(ownerCat, joinerCat);
        prepareQuestionSelection(() -> assembleAndPushOnlineBoard(ownerCat, joinerCat));
    }

    private void assembleAndPushOnlineBoard(String ownerCat, String joinerCat) {
        if (boardDuelFinished || boardCellQuestion != null) return;
        boardSelectedCategories.clear();
        boardSelectedCategories.add(ownerCat);
        boardSelectedCategories.add(joinerCat);
        boardCols = 2;
        boardCellQuestion = new Question[2][BOARD_ROWS];
        boardCellConsumed = new boolean[2][BOARD_ROWS];
        Set<Question> used = new HashSet<>();
        for (int col = 0; col < 2; col++) {
            String cat = boardSelectedCategories.get(col);
            for (int row = 0; row < BOARD_ROWS; row++) {
                boardCellQuestion[col][row] = drawBoardQuestion(cat, boardTierForRow(row), used);
            }
        }
        HashMap<String, Object> payload = new HashMap<>();
        payload.put("protocolVersion", 2);
        payload.put("ownerId", myID);
        payload.put("joinerId", opponentID);
        payload.put("rows", BOARD_ROWS);
        payload.put("currentTurn", 0);
        payload.put("phase", "selecting");
        payload.put("categories/0", ownerCat);
        payload.put("categories/1", joinerCat);
        for (int col = 0; col < 2; col++) {
            for (int row = 0; row < BOARD_ROWS; row++) {
                Question q = boardCellQuestion[col][row];
                String key = "cells/" + col + "_" + row;
                payload.put(key + "/Level", q != null && q.getLevel() != null ? q.getLevel() : "0");
                payload.put(key + "/Q", q != null && q.getQ() != null ? q.getQ() : "");
                payload.put(key + "/R", q != null && q.getR() != null ? q.getR() : "");
                payload.put(key + "/W1", q != null && q.getW1() != null ? q.getW1() : "");
                payload.put(key + "/W2", q != null && q.getW2() != null ? q.getW2() : "");
                payload.put(key + "/W3", q != null && q.getW3() != null ? q.getW3() : "");
                payload.put(key + "/Img", q != null && q.getImg() != null ? q.getImg() : "");
                payload.put(key + "/ClubPath", q == null ? new ArrayList<String>() : q.getClubPath());
                payload.put(key + "/Category", q != null && q.getCategory() != null
                        ? q.getCategory() : boardSelectedCategories.get(col));
            }
        }
        payload.put("ready", true);
        reserveBoardQuestions(() -> boardRef().runTransaction(new Transaction.Handler() {
            @Override public Transaction.Result doTransaction(MutableData board) {
                // Withdrawal may settle a duel while its category setup is pending.
                if ("finished".equals(board.child("phase").getValue(String.class))
                        || Boolean.TRUE.equals(board.child("ready").getValue(Boolean.class))) {
                    return Transaction.abort();
                }
                for (Map.Entry<String, Object> entry : payload.entrySet())
                    board.child(entry.getKey()).setValue(entry.getValue());
                return Transaction.success(board);
            }
            @Override public void onComplete(DatabaseError error, boolean committed, DataSnapshot snapshot) {
                // Existing ready/terminal listeners render the committed shared state.
            }
        }, false));
    }

    /** Host only: build the room board (one category per seat) and push it. */
    private void buildAndPushRoomBoard(HashMap<String, String> picks) {
        if (boardCellQuestion != null || questionSelectionPending) return;
        retryQuestionSelection = () -> buildAndPushRoomBoard(picks);
        prepareQuestionSelection(() -> assembleAndPushRoomBoard(picks));
    }

    private void assembleAndPushRoomBoard(HashMap<String, String> picks) {
        if (boardCellQuestion != null) return;
        final int cols = boardSeatCount;
        boardSelectedCategories.clear();
        boardCellQuestion = new Question[cols][BOARD_ROWS];
        boardCellConsumed = new boolean[cols][BOARD_ROWS];
        boardCols = cols;
        Set<Question> used = new HashSet<>();
        Set<String> takenCategories = new HashSet<>();
        HashMap<String, Object> payload = new HashMap<>();
        for (int col = 0; col < cols; col++) {
            String cat = boardSeatIsBot[col] ? null : picks.get(boardSeatId[col]);
            if (cat == null || cat.isEmpty()) {
                cat = randomBoardCategory(takenCategories);
            }
            takenCategories.add(cat);
            boardSelectedCategories.add(cat);
            payload.put("categories/" + col, cat);
            for (int row = 0; row < BOARD_ROWS; row++) {
                Question q = drawBoardQuestion(cat, boardTierForRow(row), used);
                boardCellQuestion[col][row] = q;
                String key = "cells/" + col + "_" + row;
                payload.put(key + "/Level", q != null && q.getLevel() != null ? q.getLevel() : "0");
                payload.put(key + "/Q", q != null && q.getQ() != null ? q.getQ() : "");
                payload.put(key + "/R", q != null && q.getR() != null ? q.getR() : "");
                payload.put(key + "/W1", q != null && q.getW1() != null ? q.getW1() : "");
                payload.put(key + "/W2", q != null && q.getW2() != null ? q.getW2() : "");
                payload.put(key + "/W3", q != null && q.getW3() != null ? q.getW3() : "");
                payload.put(key + "/Img", q != null && q.getImg() != null ? q.getImg() : "");
                payload.put(key + "/ClubPath", q == null ? new ArrayList<String>() : q.getClubPath());
                payload.put(key + "/Category", q != null && q.getCategory() != null
                        ? q.getCategory() : cat);
            }
        }
        payload.put("ready", true);
        reserveBoardQuestions(() -> boardRef().updateChildren(payload));
    }

    /** A board category not already used by another seat, if possible. */
    private String randomBoardCategory(Set<String> taken) {
        if (boardAllCategories.isEmpty()) return LocalQuestions.FALLBACK_CATEGORY;
        ArrayList<String> remaining = new ArrayList<>();
        for (String c : boardAllCategories) {
            if (!taken.contains(c)) remaining.add(c);
        }
        if (remaining.isEmpty()) {
            return boardAllCategories.get(boardRandom.nextInt(boardAllCategories.size()));
        }
        return remaining.get(boardRandom.nextInt(remaining.size()));
    }

    private void loadOnlineBoardFromFirebase(DataSnapshot snapshot) {
        if (boardRoomMatch && !roomQuestionHistoryAdmitted) {
            if (roomQuestionHistoryAdmissionPending) return;
            roomQuestionHistoryAdmissionPending = true;
            QuestionHistory.admitRoom(this, roomId, () -> {
                roomQuestionHistoryAdmissionPending = false;
                roomQuestionHistoryAdmitted = true;
                if (!EXITING && !isFinishing()) loadOnlineBoardFromFirebase(snapshot);
            }, error -> {
                roomQuestionHistoryAdmissionPending = false;
                questionSelectionFailed(error);
                finish();
            });
            return;
        }
        String myCategory = snapshot.child("picks").child(boardLocalSeatId()).child("category").getValue(String.class);
        if (myCategory != null) getIntent().putExtra("economyChosenCategory", myCategory);
        final int cols = boardRoomMatch ? boardSeatCount : 2;
        boardSelectedCategories.clear();
        for (int col = 0; col < cols; col++) {
            String cat = snapshot.child("categories").child(String.valueOf(col)).getValue(String.class);
            boardSelectedCategories.add(cat == null ? "" : cat);
        }
        boardCols = cols;
        boardCellQuestion = new Question[cols][BOARD_ROWS];
        boardCellConsumed = new boolean[cols][BOARD_ROWS];
        for (int col = 0; col < cols; col++) {
            for (int row = 0; row < BOARD_ROWS; row++) {
                DataSnapshot cs = snapshot.child("cells").child(col + "_" + row);
                Question q = new Question();
                q.setLevel(boardCellString(cs.child("Level"), "0"));
                q.setQ(boardCellString(cs.child("Q"), ""));
                q.setR(boardCellString(cs.child("R"), ""));
                q.setW1(boardCellString(cs.child("W1"), ""));
                q.setW2(boardCellString(cs.child("W2"), ""));
                q.setW3(boardCellString(cs.child("W3"), ""));
                q.setCategory(boardCellString(cs.child("Category"), boardSelectedCategories.get(col)));
                q.setImg(boardCellString(cs.child("Img"), ""));
                ArrayList<String> clubs = new ArrayList<>();
                for (DataSnapshot club : cs.child("ClubPath").getChildren()) {
                    String value = boardCellString(club, "");
                    if (!value.isEmpty()) clubs.add(value);
                }
                q.setClubPath(clubs);
                boardCellQuestion[col][row] = q;
            }
        }
        ArrayList<Question> allocated = new ArrayList<>();
        for (Question[] column : boardCellQuestion) java.util.Collections.addAll(allocated, column);
        QuestionHistory.recordAll(this, allocated);
        boardCellsRemaining = cols * BOARD_ROWS;
        boardTotalTurns = cols * BOARD_ROWS;
        hideBoardOverlay();
        int resumeTurn;
        if (boardRoomMatch) {
            RoomBoardRecovery.State recovered = RoomBoardRecovery.restore(
                    OnlineDuelState.map(snapshot.getValue()), boardSeatCount, BOARD_ROWS, BOARD_VALUES);
            boardCellConsumed = recovered.consumed;
            boardCellsRemaining = countRemainingBoardCells();
            for (int seat = 0; seat < boardSeatCount; seat++)
                offlineContestants.setScoreForSlot(seat, recovered.scores[seat]);
            roomResumeTurn = recovered.nextTurn;
            roomResumeCol = recovered.pendingCol;
            roomResumeRow = recovered.pendingRow;
            resumeTurn = recovered.nextTurn;
        } else {
            applyDuelScores(snapshot);
            resumeTurn = OnlineDuelState.number(snapshot.child("currentTurn").getValue(), 0);
        }
        beginOnlineBoardTurn(resumeTurn);
        if (!boardRoomMatch && duelTerminalRef != null && duelTerminalListener != null) {
            duelNeedsBoardResync = true;
            duelTerminalRef.addListenerForSingleValueEvent(duelTerminalListener);
        }
    }

    private String boardCellString(DataSnapshot snap, String fallback) {
        Object value = snap.getValue();
        return value == null ? fallback : String.valueOf(value);
    }

    // ---- Online turn loop ------------------------------------------------

    private Map<String, Object> paidDuelTurnArgs() {
        Map<String, Object> data = new HashMap<>();
        data.put("turn", PaidDuelController.number(paidDuelState.get("currentTurn"), 0));
        return data;
    }

    private void applyPaidDuelState(Map<String, Object> match, Map<String, Object> question, String action) {
        if (EXITING || duelActivityDestroyed || paidDuel == null) return;
        paidDuelState = match;
        paidDuelQuestion = question;
        if (!ACTIVITY_PAUSED && backgroundGuard.enforce()) return;
        if (PaidDuelController.number(match.get("protocolVersion"), 0) != 2) {
            showBoardWaitingOverlay("هذه الدعوة تستخدم إصدارًا سابقًا. ألغِها وأرسل دعوة جديدة للعب بالنظام الأصلي.");
            return;
        }
        meOwner = myID.equals(match.get("ownerId"));
        opponentID = PaidDuelController.string(match.get(meOwner ? "joinerId" : "ownerId"));
        duelLocallyConnected = true;
        duelNeedsBoardResync = false;
        duelServerClockReady = true;
        boardPickPending = false;
        if (paidDuelExiting && "settled".equals(match.get("status"))) {
            matchStateCommitted = true;
            finish();
            return;
        }
        if (ACTIVITY_PAUSED || paidDuelShowingResult) return;

        Map<String, Object> picks = PaidDuelController.map(match.get("picks"));
        String chosen = PaidDuelController.string(PaidDuelController.map(picks.get(myID)).get("category"));
        if (!chosen.isEmpty()) getIntent().putExtra("economyChosenCategory", chosen);
        if ("waiting".equals(match.get("status"))) {
            if (chosen.isEmpty()) {
                if (!paidDuelCategoryShown) {
                    paidDuelCategoryShown = true;
                    showOnlineBoardCategorySelect();
                }
            } else {
                paidDuelCategoryShown = false;
                stopCategorySelectMusicIfPlaying();
                showBoardWaitingOverlay("اخترت: " + chosen + "\nبانتظار اختيار الخصم…");
            }
            return;
        }

        final int turn = (int) PaidDuelController.number(match.get("currentTurn"), 0);
        if (!boardStarted) {
            boardStarted = true;
            boardCols = 2;
            boardTotalTurns = boardCols * BOARD_ROWS;
            boardCellQuestion = new Question[boardCols][BOARD_ROWS];
            boardCellConsumed = new boolean[boardCols][BOARD_ROWS];
            boardSelectedCategories.clear();
            Object categories = match.get("categories");
            for (int col = 0; col < boardCols; col++) {
                String cat = categories instanceof java.util.List && ((java.util.List<?>) categories).size() > col
                        ? PaidDuelController.string(((java.util.List<?>) categories).get(col)) : "";
                boardSelectedCategories.add(cat);
                for (int row = 0; row < BOARD_ROWS; row++) {
                    Question placeholder = new Question();
                    placeholder.setCategory(cat);
                    placeholder.setLevel(String.valueOf(boardTierForRow(row)));
                    placeholder.setQ("");
                    boardCellQuestion[col][row] = placeholder;
                }
            }
            paidDuelLastResultTurn = turn - 1;
            stopCategorySelectMusicIfPlaying();
            applyBoardModeChrome();
        }
        duelTurnLedger = new HashMap<>(PaidDuelController.map(match.get("turns")));
        for (Object value : duelTurnLedger.values()) {
            Map<String, Object> result = PaidDuelController.map(value);
            int col = (int) PaidDuelController.number(result.get("col"), -1);
            int row = (int) PaidDuelController.number(result.get("row"), -1);
            if (Boolean.TRUE.equals(result.get("done")) && col >= 0 && col < boardCols && row >= 0 && row < BOARD_ROWS) {
                boardCellConsumed[col][row] = true;
                Map<String, Object> revealed = PaidDuelController.map(result.get("question"));
                if (!revealed.isEmpty()) boardCellQuestion[col][row] = paidQuestion(revealed);
            }
        }
        if (turn > 0 && paidDuelQuestionTurn == turn - 1 && paidDuelLastResultTurn < turn - 1) {
            Map<String, Object> previous = PaidDuelController.map(duelTurnLedger.get("t" + (turn - 1)));
            if (Boolean.TRUE.equals(previous.get("done"))) {
                showPaidDuelTurnResult(turn - 1, previous);
                return;
            }
        }
        applyPaidDuelScores();
        if ("settled".equals(match.get("status"))) {
            finishPaidDuel();
            return;
        }

        Map<String, Object> activeTurn = PaidDuelController.map(duelTurnLedger.get("t" + turn));
        String phase = PaidDuelController.string(match.get("phase"));
        boolean mine = myID.equals(match.get(turn % 2 == 0 ? "ownerId" : "joinerId"));
        String key = turn + ":" + phase + ":" + activeTurn.get("revealCount") + ":" + paidDuel.isPending();
        if (key.equals(paidDuelRenderKey)) {
            if ("answering".equals(phase) && !isQuestionTimerRunning) startPaidDuelQuestionTimer();
            if ("observing".equals(phase) && paidDuelInputReady && mine) startPaidDuelQuestionTimer();
            return;
        }
        paidDuelRenderKey = key;
        boardOnlineTurn = turn;
        boardPickerIsHuman = mine;
        boardPickerSlot = mine ? 0 : 1;
        boardWatchSeat = 1;
        CAN_HOME = true;
        if ("selecting".equals(phase)) {
            stopTimer(false);
            cancelPendingBoardReveal();
            paidDuelQuestionTurn = -1;
            boardPickedCol = -1;
            boardPickedRow = -1;
            boardCurrentQuestion = null;
            showBoardGrid();
            return;
        }
        if (!"answering".equals(phase) && !"observing".equals(phase)) return;
        Map<String, Object> visibleQuestion = question.isEmpty()
                ? PaidDuelController.map(activeTurn.get("question")) : question;
        if (visibleQuestion.isEmpty()) {
            paidDuelRenderKey = "";
            return;
        }
        boardPickedCol = (int) PaidDuelController.number(activeTurn.get("col"), -1);
        boardPickedRow = (int) PaidDuelController.number(activeTurn.get("row"), -1);
        if (boardPickedCol < 0 || boardPickedCol >= boardCols || boardPickedRow < 0 || boardPickedRow >= BOARD_ROWS) return;
        boardRevealCount = (int) PaidDuelController.number(activeTurn.get("revealCount"), 0);
        boolean newQuestion = paidDuelQuestionTurn != turn;
        if (newQuestion) {
            paidDuelQuestionTurn = turn;
            boardCurrentQuestion = paidQuestion(visibleQuestion);
            boardCellQuestion[boardPickedCol][boardPickedRow] = boardCurrentQuestion;
            paidDuelTypedAnswer = null;
            paidDuelInputReady = false;
            if (mine) enterBoardQuestion(true);
            else {
                enterOnlineWatchQuestion();
                setBoardAnswerOptionsVisible(false);
            }
        }
        if (boardRevealCount > 0) {
            bindPaidDuelOptions(visibleQuestion, false);
            boardAwaitingTypedInput = false;
            boardOptionsRevealed = true;
            showBoardTypedPanel(false);
            setBoardAnswerOptionsVisible(true);
            CAN_PLAY = mine && !paidDuel.isPending();
            if ("reveal".equals(action)) showDialog("اختر الإجابة الصحيحة (القيمة الآن " + currentBoardAwardValue() + ")",
                    "", 600, 1400, R.drawable.mouth_01, true);
        }
        if ("answering".equals(phase)) startPaidDuelQuestionTimer();
    }

    private Question paidQuestion(Map<String, Object> source) {
        Question q = new Question();
        q.setQ(PaidDuelController.string(source.get("text")));
        q.setCategory(PaidDuelController.string(source.get("category")));
        q.setLevel(PaidDuelController.string(source.get("level")));
        q.setImg(PaidDuelController.string(source.get("img")));
        ArrayList<String> clubs = new ArrayList<>();
        Object path = source.get("clubPath");
        if (path instanceof java.util.List) for (Object club : (java.util.List<?>) path) clubs.add(String.valueOf(club));
        q.setClubPath(clubs);
        // Answers remain private until the server resolves the turn.
        q.setR(PaidDuelController.string(source.get("rightAnswer")));
        q.setW1(""); q.setW2(""); q.setW3("");
        if (q.getQ() != null && !q.getQ().trim().isEmpty()) QuestionHistory.record(this, q);
        return q;
    }

    private void bindPaidDuelOptions(Map<String, Object> source, boolean resolved) {
        Object raw = source.get("options");
        if (!(raw instanceof java.util.List)) return;
        java.util.List<?> options = (java.util.List<?>) raw;
        int correctIndex = resolved ? (int) PaidDuelController.number(source.get("correctOptionIndex"), -1) : -1;
        ArrayList<String> display = new ArrayList<>();
        for (int i = 0; i < Math.min(4, options.size()); i++) {
            Map<String, Object> option = PaidDuelController.map(options.get(i));
            String text = option.isEmpty() ? PaidDuelController.string(options.get(i))
                    : PaidDuelController.string(option.get("text"));
            display.add(text);
            TextView view = listAnswerViews.get(i);
            view.setText(text);
            view.setVisibility(View.VISIBLE);
            view.setTag("0");
            if (i == correctIndex) {
                rightAnswer = i + 1;
                txtRight = view;
                rlyRight = (RelativeLayout) view.getParent();
                imgRight = (ImageView) rlyRight.getChildAt(0);
                view.setTag("1");
            }
        }
        applyAnswerTextSizes(display);
    }

    private void submitPaidDuelAnswer(boolean timeout) {
        if (paidDuel.isPending() || paidDuelShowingResult || !boardPickerIsHuman) return;
        if (timeout) { paidDuel.sync(); return; }
        Map<String, Object> data = paidDuelTurnArgs();
        if (boardAwaitingTypedInput && paidDuelTypedAnswer != null) data.put("answerText", paidDuelTypedAnswer);
        else if (boardOptionsRevealed && myAnswer >= 1 && myAnswer <= 4) data.put("optionIndex", myAnswer - 1);
        else return;
        hideKeyboard();
        CAN_PLAY = false;
        stopTimer(false);
        playSound(R.raw.drum1, false, true);
        paidDuel.call("answer", data);
    }

    private void showPaidDuelTurnResult(int turn, Map<String, Object> result) {
        paidDuelLastResultTurn = turn;
        paidDuelShowingResult = true;
        cancelPendingBoardReveal();
        cancelBoardSelectTimer();
        stopTimer(false);
        CAN_PLAY = false;
        boardAwaitingTypedInput = false;
        hideKeyboard();
        showBoardTypedPanel(false);
        Map<String, Object> revealed = PaidDuelController.map(result.get("question"));
        bindPaidDuelOptions(revealed, true);
        setBoardAnswerOptionsVisible(true);
        hideBoardOverlay();
        if (imgRight != null) imgRight.setImageResource(R.drawable.frame_right);
        boolean correct = Boolean.TRUE.equals(result.get("correct"));
        boolean mine = myID.equals(result.get("playerId"));
        int seat = mine ? 0 : 1;
        applyPaidDuelScores();
        offlineContestants.showSlotResult(seat, correct);
        playSound(correct ? R.raw.correct_answer : R.raw.wrong_answer, false, false);
        if (mine) {
            if (correct) { PlayerStats.recordCorrectAnswer(this, false); person.like(1000); }
            else { PlayerStats.recordWrongAnswer(this, false); person.sad(); }
            if (imgSelected != null) imgSelected.setImageResource(correct ? R.drawable.frame_right : R.drawable.frame_wrong);
        }
        String message = mine ? (correct ? "إجابة صحيحة!" : "إجابة خاطئة للأسف")
                : offlineContestants.nameForSlot(1) + (correct ? " أجاب إجابة صحيحة" : " أجاب إجابة خاطئة");
        showDialog(message, "", 700, 2000, correct ? R.drawable.mouth_01 : R.drawable.mouth_05, false);
        duelConnectionHandler.postDelayed(() -> {
            if (duelActivityDestroyed || EXITING) return;
            paidDuelShowingResult = false;
            paidDuelQuestionTurn = -1;
            paidDuelRenderKey = "";
            applyPaidDuelState(paidDuelState, paidDuelQuestion, "afterResult");
        }, BOARD_REVEAL_HOLD_MS);
    }

    private void applyPaidDuelScores() {
        Map<String, Object> scores = PaidDuelController.map(paidDuelState.get("scores"));
        offlineContestants.setScoreForSlot(0, (int) PaidDuelController.number(scores.get(myID), 0));
        offlineContestants.setScoreForSlot(1, (int) PaidDuelController.number(scores.get(opponentID), 0));
    }

    private void startPaidDuelQuestionTimer() {
        if (paidDuel == null || paidDuelShowingResult || ACTIVITY_PAUSED) return;
        if ("observing".equals(paidDuelState.get("phase"))) {
            paidDuelInputReady = true;
            if (boardPickerIsHuman && !paidDuel.isPending()) paidDuel.call("beginAnswer", paidDuelTurnArgs());
            return;
        }
        if (!"answering".equals(paidDuelState.get("phase"))) return;
        if (cdtProgress != null) cdtProgress.cancel();
        isQuestionTimerRunning = true;
        pbTime.setMax(450);
        rlyProgress.setAlpha(1f);
        cdtProgress = new CountDownTimer(Math.max(1L, paidDuel.remainingMillis()), 100L) {
            @Override public void onTick(long ignored) {
                long remaining = paidDuel.remainingMillis();
                PROGRESS_VALUE = (int) Math.min(450, (remaining + 99) / 100);
                pbTime.setProgress(PROGRESS_VALUE);
                int seconds = (int) ((remaining + 999) / 1000);
                txtProgress.setText(String.valueOf(seconds));
                pbTime.setRingProgressColor(getResources().getColor(seconds > 10 ? R.color.progressGreen
                        : seconds > 5 ? R.color.progressOrange : R.color.progressRed));
            }
            @Override public void onFinish() {
                isQuestionTimerRunning = false;
                CAN_PLAY = false;
                if (!paidDuel.isPending()) paidDuel.sync();
            }
        }.start();
    }

    private void finishPaidDuel() {
        if (boardDuelFinished) return;
        boardDuelFinished = true;
        matchStateCommitted = true;
        stopTimer(false);
        cancelBoardSelectTimer();
        cancelPendingBoardReveal();
        CAN_PLAY = false;
        CAN_HOME = false;
        Map<String, Object> settlement = PaidDuelController.map(paidDuelState.get("settlement"));
        boolean paid = "paid".equals(settlement.get("status"));
        boolean won = paid && myID.equals(settlement.get("winnerId"));
        boolean draw = "draw".equals(paidDuelState.get("finishReason")) || "refunded".equals(settlement.get("status"));
        long payoutCoins = PaidDuelController.number(settlement.get("payoutCoins"), 0);
        long stakeCoins = PaidDuelController.number(paidDuelState.get("stakeCoins"), 0);
        if (stakeCoins <= 0 && payoutCoins > 0) stakeCoins = payoutCoins / 2;
        if (payoutCoins <= 0 && stakeCoins > 0) payoutCoins = stakeCoins * 2;
        // Escrow and payout were committed by the server. Never credit/debit them locally.
        String headline = won ? "مبروك فزت بـ" + payoutCoins + " قطعة"
                : !paid ? (draw ? "تعادل! أُعيدت القطع لكما" : "أُلغيت المباراة وأُعيدت القطع")
                : "حظًا أوفر في المباراة القادمة";
        String reason = PaidDuelController.string(paidDuelState.get("finishReason"));
        if (paid && !won && ("forfeit".equals(reason) || "timeout".equals(reason)))
            headline = "خسرت المباراة بسبب مغادرتك أو انتهاء مهلة اللعب";
        final String resultHeadline = headline;
        if (paid || draw) PlayerStats.recordGameEnd(this, draw ? ProgressionRules.DRAW
                : won ? ProgressionRules.WIN : ProgressionRules.LOSS, 0);
        if (won) { person.moveShow2Hands(1500); person.raiseEyeBrowsUp(1000, false, true); }
        playSound(won ? R.raw.new_level : R.raw.wrong_answer, false, false);
        final boolean[] resultShown = {false};
        Runnable renderResult = () -> {
            if (resultShown[0] || isFinishing() || isDestroyed()
                    || !myID.equals(ProgressionAccount.uid(this))) return;
            resultShown[0] = true;
            showBoardResultScreen(resultHeadline, 0, 0, 0, new boolean[]{won || draw, (paid && !won) || draw});
        };
        new Handler().postDelayed(renderResult, 3000L);
        com.google.firebase.firestore.FirebaseFirestore.getInstance().collection("users").document(myID)
                .get(com.google.firebase.firestore.Source.SERVER).addOnCompleteListener(task -> {
                    if (isFinishing() || isDestroyed() || !myID.equals(ProgressionAccount.uid(this))) return;
                    if (task.isSuccessful() && task.getResult() != null) {
                        Long balance = task.getResult().getLong("coins");
                        if (balance != null) paidResultCoins = (int) Math.max(0L, Math.min(Integer.MAX_VALUE, balance));
                    }
                    renderResult.run();
                });
    }

    private void beginOnlineBoardTurn(int turn) {
        ArrayList<String> economyCategories = new ArrayList<>();
        String chosenCategory = getIntent().getStringExtra("economyChosenCategory");
        if (chosenCategory != null && !chosenCategory.isEmpty()) economyCategories.add(chosenCategory);
        if (!GameEconomy.ensure(this, false, 0, economyCategories, () -> beginOnlineBoardTurn(turn))) return;
        duelDisconnectCountdown = null;
        detachBoardTurnListener();
        boardOnlineTurn = turn;
        boardPickPending = false;
        boardAdvancePending = false;
        boardWatchEntered = false;
        boardWatchQuestionShown = false;
        boardWatchResultApplied = false;
        boardOpponentResultReady = false;
        boardPickedCol = -1;
        boardPickedRow = -1;
        boardCurrentQuestion = null;
        if (turn >= boardTotalTurns) {
            finishBoardMatch();
            return;
        }
        if (boardRoomMatch) {
            beginRoomBoardTurn(turn);
            return;
        }
        boolean myTurn = meOwner ? (turn % 2 == 0) : (turn % 2 == 1);
        boardPickerIsHuman = myTurn;
        boardPickerSlot = myTurn ? 0 : 1;
        boardWatchSeat = 1;
        showBoardGrid();
        if (myTurn) {
            // The human picks a cell via the grid (onCellPicked → writes the pick).
            return;
        }
        attachBoardTurnListener(turn);
    }

    /** Room board: turn t belongs to seat (t % N); the host drives bot/abandoned seats. */
    private void beginRoomBoardTurn(final int turn) {
        final int pickerSeat = boardSeatCount > 0 ? (turn % boardSeatCount) : 0;
        boardPickerSlot = pickerSeat;
        boardWatchSeat = pickerSeat;
        boolean iAmPicker = (pickerSeat == mySeat);
        boardPickerIsHuman = iAmPicker;
        showBoardGrid();
        boolean restoringPick = turn == roomResumeTurn && roomResumeCol >= 0 && roomResumeRow >= 0;
        if (restoringPick) {
            boardPickedCol = roomResumeCol;
            boardPickedRow = roomResumeRow;
            roomResumeTurn = -1;
        }
        if (iAmPicker) {
            if (restoringPick) {
                cancelBoardSelectTimer();
                boardCellConsumed[boardPickedCol][boardPickedRow] = true;
                boardCurrentQuestion = boardCellQuestion[boardPickedCol][boardPickedRow];
                enterBoardQuestion(true);
            }
            // I pick a cell via the grid (onCellPicked → writes the pick + answer).
            return;
        }
        boolean seatDriven = boardSeatIsBot[pickerSeat] || boardSeatLeft[pickerSeat];
        if (seatDriven && meOwner) {
            // Host drives the bot/abandoned seat and broadcasts pick + result.
            new Handler().postDelayed(new Runnable() {
                @Override
                public void run() {
                    if (!EXITING && boardMode) runHostBotSeatTurn(turn, pickerSeat);
                }
            }, 1200);
        } else {
            // Watch the picker (a remote human, or the host driving a bot seat).
            attachBoardTurnListener(turn);
        }
    }

    /** Host drives one bot/abandoned seat's turn, writing the pick + result to RTDB. */
    private void runHostBotSeatTurn(int turn, int seat) {
        if (boardOnlineTurn != turn) return;
        if (boardPickedCol < 0 || boardPickedRow < 0) {
            int[] cell = pickRandomRemainingCell();
            if (cell == null) {
                advanceOnlineBoardTurn();
                return;
            }
            boardPickedCol = cell[0];
            boardPickedRow = cell[1];
        }
        boardPickerSlot = seat;
        boardPickerIsHuman = false;
        boardCurrentQuestion = boardCellQuestion[boardPickedCol][boardPickedRow];
        writeOnlineTurnPick(turn, boardPickedCol, boardPickedRow);
        // enterBoardQuestion(false) → bot staggered reveal → resolveBotBoardAnswer(seat),
        // which (for the team host) also writes the turn result before advancing.
        enterBoardQuestion(false);
    }

    private void advanceOnlineBoardTurn() {
        if (paidDuel != null) {
            paidDuel.sync();
            return;
        }
        if (boardRoomMatch) {
            beginOnlineBoardTurn(boardOnlineTurn + 1);
            return;
        }
        if (boardAdvancePending || boardDuelFinished || EXITING) return;
        if (!duelLocallyConnected || ACTIVITY_PAUSED || duelActivityDestroyed) {
            duelNeedsBoardResync = true;
            return;
        }
        boardAdvancePending = true;
        final int turn = boardOnlineTurn;
        boardRef().addListenerForSingleValueEvent(new ValueEventListener() {
            @Override public void onDataChange(DataSnapshot snapshot) {
                boardAdvancePending = false;
                if (EXITING || boardDuelFinished || duelActivityDestroyed || boardOnlineTurn != turn) return;
                if (!duelLocallyConnected || ACTIVITY_PAUSED) {
                    duelNeedsBoardResync = true;
                    return;
                }
                if (!Boolean.TRUE.equals(snapshot.child("turns").child("t" + turn)
                        .child("done").getValue(Boolean.class))) {
                    duelConnectionHandler.postDelayed(() -> {
                        if (!EXITING && !duelActivityDestroyed && boardOnlineTurn == turn) advanceOnlineBoardTurn();
                    }, 750);
                    return;
                }
                applyDuelScores(snapshot);
                beginOnlineBoardTurn(OnlineDuelState.number(snapshot.child("currentTurn").getValue(), turn + 1));
            }
            @Override public void onCancelled(DatabaseError error) {
                boardAdvancePending = false;
                retryDuelAction(turn, () -> advanceOnlineBoardTurn());
            }
        });
    }

    private void attachDuelTerminalListener() {
        if (duelTerminalRef != null) return;
        duelTerminalRef = FirebaseDatabase.getInstance().getReference().child("Games").child(gameID);
        duelTerminalListener = new ValueEventListener() {
            @Override public void onDataChange(DataSnapshot snapshot) {
                applyDuelSessionSnapshot(snapshot);
            }
            @Override public void onCancelled(DatabaseError error) {
                if (!EXITING && !boardDuelFinished && !duelActivityDestroyed)
                    showBoardWaitingOverlay("تعذر مزامنة المباراة. جارٍ إعادة الاتصال…");
            }
        };
        duelTerminalRef.addValueEventListener(duelTerminalListener);
        startDuelDisconnectMonitor();
    }

    private void applyDuelSessionSnapshot(DataSnapshot snapshot) {
        if (EXITING || boardDuelFinished || duelActivityDestroyed || snapshot == null) return;
        duelSessionSnapshot = new HashMap<>(OnlineDuelState.map(snapshot.getValue()));
        DataSnapshot board = snapshot.child("board");
        if ("forfeit".equals(board.child("finishReason").getValue(String.class))) {
            if (ACTIVITY_PAUSED) { duelNeedsBoardResync = true; return; }
            showDuelForfeitResult(board);
            return;
        }
        if (!ACTIVITY_PAUSED && backgroundGuard.enforce()) return;
        boolean ready = Boolean.TRUE.equals(board.child("ready").getValue(Boolean.class));
        boolean active = duelLocallyConnected && !ACTIVITY_PAUSED
                && "active".equals(snapshot.child(myID).child("status").getValue(String.class));
        if (!boardStarted && ready && board.child("cells").exists() && active && questionsReady) {
            boardStarted = true;
            detachBoardSetupListeners();
            duelNeedsBoardResync = true;
            loadOnlineBoardFromFirebase(board);
        }
        if (!boardStarted || !ready) {
            if (duelNeedsBoardResync && active && questionsReady) {
                duelNeedsBoardResync = false;
                restoreDuelCategorySetup(board);
            }
            return;
        }
        if (!active) {
            duelNeedsBoardResync = true;
            return;
        }
        int sharedTurn = OnlineDuelState.number(board.child("currentTurn").getValue(), boardOnlineTurn);
        boolean skipped = Boolean.TRUE.equals(board.child("turns").child("t" + boardOnlineTurn)
                .child("skipped").getValue(Boolean.class));
        if (skipped && sharedTurn > boardOnlineTurn) {
            stopTimer(false);
            cancelPendingBoardReveal();
            applyDuelScores(board);
            beginOnlineBoardTurn(sharedTurn);
        }
        if (duelNeedsBoardResync && duelLocallyConnected && !ACTIVITY_PAUSED
                && "active".equals(snapshot.child(myID).child("status").getValue(String.class))) {
            duelNeedsBoardResync = false;
            stopTimer(false);
            cancelPendingBoardReveal();
            applyDuelScores(board);
            beginOnlineBoardTurn(sharedTurn);
            DataSnapshot pick = board.child("turns").child("t" + sharedTurn);
            if (boardPickerIsHuman && pick.child("col").exists() && pick.child("row").exists()
                    && !Boolean.TRUE.equals(pick.child("done").getValue(Boolean.class))) {
                int col = OnlineDuelState.number(pick.child("col").getValue(), -1);
                int row = OnlineDuelState.number(pick.child("row").getValue(), -1);
                if (col >= 0 && col < boardCols && row >= 0 && row < BOARD_ROWS) {
                    cancelBoardSelectTimer();
                    boardPickedCol = col;
                    boardPickedRow = row;
                    boardCurrentQuestion = boardCellQuestion[col][row];
                    enterBoardQuestion(true);
                }
            }
        }
    }

    private void startDuelDisconnectMonitor() {
        if (duelDisconnectTick != null) return;
        duelDisconnectTick = new Runnable() {
            @Override public void run() {
                if (EXITING || boardDuelFinished || duelActivityDestroyed) return;
                reconcileDuelDisconnect();
                updateDuelDisconnectCountdown();
                duelConnectionHandler.postDelayed(this, 250L);
            }
        };
        duelConnectionHandler.post(duelDisconnectTick);
    }

    private void reconcileDuelDisconnect() {
        if (duelDisconnectTransactionPending || !duelLocallyConnected || ACTIVITY_PAUSED
                || !duelServerClockReady || EXITING || boardDuelFinished || duelActivityDestroyed) return;
        Map<String, Object> board = OnlineDuelState.map(duelSessionSnapshot.get("board"));
        Map<String, Object> mine = OnlineDuelState.map(duelSessionSnapshot.get(myID));
        String status = String.valueOf(OnlineDuelState.map(duelSessionSnapshot.get(opponentID)).get("status"));
        boolean absent = "left".equals(status) || "left_timeout".equals(status) || "away".equals(status);
        if (!"active".equals(mine.get("status")) || !Boolean.TRUE.equals(board.get("ready"))) return;
        long deadline = OnlineDuelState.disconnectDeadline(board);
        Map<String, Object> strikes = OnlineDuelState.map(board.get("disconnectStrikes"));
        String gracePlayer = String.valueOf(OnlineDuelState.map(board.get("disconnectGrace")).get("playerId"));
        boolean needsUpdate = absent && opponentID.equals(OnlineDuelState.picker(board, boardOnlineTurn))
                && (deadline == 0L || getServerNowMs() >= deadline);
        boolean cleanup = strikes.containsKey(myID) || myID.equals(gracePlayer)
                || ("active".equals(status) && (strikes.containsKey(opponentID) || opponentID.equals(gracePlayer)));
        if (!needsUpdate && !cleanup) return;
        duelDisconnectTransactionPending = true;
        final int turn = boardOnlineTurn;
        final DatabaseReference session = FirebaseDatabase.getInstance().getReference().child("Games").child(gameID);
        session.runTransaction(new Transaction.Handler() {
            @Override public Transaction.Result doTransaction(MutableData data) {
                if (!duelLocallyConnected || ACTIVITY_PAUSED || EXITING || duelActivityDestroyed)
                    return Transaction.abort();
                Map<String, Object> state = OnlineDuelState.map(data.getValue());
                int result = OnlineDuelState.reconcileDisconnect(state, myID, turn, getServerNowMs(), true);
                if (result == OnlineDuelState.NO_CHANGE) return Transaction.abort();
                data.child("board").setValue(state.get("board"));
                return Transaction.success(data);
            }
            @Override public void onComplete(DatabaseError error, boolean committed, DataSnapshot snapshot) {
                duelDisconnectTransactionPending = false;
                if (EXITING || boardDuelFinished || duelActivityDestroyed) return;
                if (error == null && snapshot != null) applyDuelSessionSnapshot(snapshot);
                // The monitor retries failed writes while connected; no optimistic turn or winner.
            }
        }, false);
    }

    private void updateDuelDisconnectCountdown() {
        if (!duelLocallyConnected || ACTIVITY_PAUSED || !boardStarted) return;
        Map<String, Object> board = OnlineDuelState.map(duelSessionSnapshot.get("board"));
        Map<String, Object> grace = OnlineDuelState.map(board.get("disconnectGrace"));
        String status = String.valueOf(OnlineDuelState.map(duelSessionSnapshot.get(opponentID)).get("status"));
        boolean absent = "left".equals(status) || "left_timeout".equals(status) || "away".equals(status);
        long deadline = OnlineDuelState.disconnectDeadline(board);
        if (!absent || deadline == 0L || !opponentID.equals(grace.get("playerId"))
                || OnlineDuelState.number(grace.get("turn"), -1) != boardOnlineTurn) {
            if (duelDisconnectCountdown != null) {
                duelDisconnectCountdown = null;
                beginOnlineBoardTurn(boardOnlineTurn);
            }
            return;
        }
        int seconds = (int)Math.max(0L, (deadline - getServerNowMs() + 999L) / 1000L);
        int strikes = OnlineDuelState.number(OnlineDuelState.map(board.get("disconnectStrikes")).get(opponentID), 0);
        String message = "انقطع اتصال المنافس • " + seconds + " ثانية للعودة\n"
                + (strikes == 0 ? "عند انتهاء المهلة يُتخطّى دوره وتكمل اللعب."
                : "هذه المهلة الثانية؛ إن لم يعد تفوز بالمباراة.");
        FrameLayout overlay = (FrameLayout)findViewById(R.id.boardOverlay);
        if (overlay == null) return;
        if (duelDisconnectCountdown == null || duelDisconnectCountdown.getParent() != overlay) {
            showBoardWaitingOverlay(message);
            duelDisconnectCountdown = overlay.getChildAt(0) instanceof TextView
                    ? (TextView)overlay.getChildAt(0) : null;
        } else duelDisconnectCountdown.setText(message);
    }

    private void finishDuelByForfeit() {
        reconcileDuelDisconnect();
    }

    private void showDuelForfeitResult(DataSnapshot snapshot) {
        if (boardDuelFinished) return;
        boolean win = myID.equals(snapshot.child("winnerId").getValue(String.class));
        int previousCoins = PlayerProgress.getCoins(this);
        if (!settleRandomStake(win, false, () -> showDuelForfeitResult(snapshot))) return;
        boardDuelFinished = true;
        stopTimer(false);
        cancelBoardSelectTimer();
        cancelPendingBoardReveal();
        CAN_PLAY = false;
        CAN_HOME = false;
        applyDuelScores(snapshot);
        detachBoardListeners();
        detachOpponentStatusListener();
        markMyGameState("finished");
        int score = offlineContestants.scoreForSlot(0);
        PlayerStats.recordOnlineDuelForfeit(this, win, score);
        OnlineDuelResultStore.clearCompleted(this, gameID);
        PlayerProgress.onGameFinished(this, win, score, PlayerStats.getBestStreak(this), usedAllHelps(), usedAnyHelp());
        boardResultCurrencyDelta = PlayerProgress.getCoins(this) - previousCoins;
        showBoardResultScreen(win ? "🏆 فزت بانسحاب المنافس" : "خسرت المباراة بسبب مغادرتك وعدم العودة خلال المهلة",
                0, 0, 0, new boolean[]{win, !win});
    }

    private void applyDuelScores(DataSnapshot snapshot) {
        Map<String, Object> state = OnlineDuelState.map(snapshot.getValue());
        duelTurnLedger = new HashMap<>(OnlineDuelState.map(state.get("turns")));
        Map<String, Object> scores = OnlineDuelState.scores(state);
        offlineContestants.setScoreForSlot(0, OnlineDuelState.number(scores.get(myID), 0));
        offlineContestants.setScoreForSlot(1, OnlineDuelState.number(scores.get(opponentID), 0));
        if (boardCellConsumed == null) return;
        for (int col = 0; col < boardCols; col++) {
            for (int row = 0; row < BOARD_ROWS; row++) {
                boardCellConsumed[col][row] = snapshot.child("consumed").child(col + "_" + row).exists();
            }
        }
    }

    private void retryDuelAction(int turn, Runnable action) {
        if (EXITING || boardDuelFinished || turn != boardOnlineTurn) return;
        showBoardWaitingOverlay("جارٍ مزامنة المباراة… تحقق من اتصال الإنترنت");
        duelConnectionHandler.postDelayed(() -> {
            if (!EXITING && !boardDuelFinished && !duelActivityDestroyed && turn == boardOnlineTurn) action.run();
        }, 1500);
    }

    private void claimDuelCell(final int turn, final int col, final int row) {
        if (!duelLocallyConnected || ACTIVITY_PAUSED || EXITING || duelActivityDestroyed) {
            duelNeedsBoardResync = true;
            return;
        }
        boardRef().runTransaction(new Transaction.Handler() {
            @Override public Transaction.Result doTransaction(MutableData data) {
                if (!duelLocallyConnected || ACTIVITY_PAUSED || EXITING || duelActivityDestroyed || boardDuelFinished)
                    return Transaction.abort();
                Map<String, Object> state = OnlineDuelState.map(data.getValue());
                if (!OnlineDuelState.claim(state, myID, turn, col, row)) return Transaction.abort();
                data.setValue(state);
                return Transaction.success(data);
            }
            @Override public void onComplete(DatabaseError error, boolean committed, DataSnapshot snapshot) {
                if (EXITING || boardDuelFinished || duelActivityDestroyed || boardOnlineTurn != turn) return;
                if (!duelLocallyConnected || ACTIVITY_PAUSED) {
                    duelNeedsBoardResync = true;
                    return;
                }
                if (error != null) {
                    retryDuelAction(turn, () -> claimDuelCell(turn, col, row));
                    return;
                }
                boardPickPending = false;
                if (!committed) {
                    duelNeedsBoardResync = true;
                    if (duelTerminalRef != null) duelTerminalRef.addListenerForSingleValueEvent(duelTerminalListener);
                    return;
                }
                boardPickedCol = col;
                boardPickedRow = row;
                boardCurrentQuestion = boardCellQuestion[col][row];
                boardCellConsumed[col][row] = true;
                enterBoardQuestion(true);
            }
        }, false);
    }

    private void completeDuelTurn(final int turn, final boolean correct, final int reveals) {
        if (!duelLocallyConnected || ACTIVITY_PAUSED || EXITING || duelActivityDestroyed) {
            duelNeedsBoardResync = true;
            return;
        }
        boardRef().runTransaction(new Transaction.Handler() {
            @Override public Transaction.Result doTransaction(MutableData data) {
                if (!duelLocallyConnected || ACTIVITY_PAUSED || EXITING || duelActivityDestroyed || boardDuelFinished)
                    return Transaction.abort();
                Map<String, Object> state = OnlineDuelState.map(data.getValue());
                if (!OnlineDuelState.complete(state, myID, turn, correct, reveals)) return Transaction.abort();
                data.setValue(state);
                return Transaction.success(data);
            }
            @Override public void onComplete(DatabaseError error, boolean committed, DataSnapshot snapshot) {
                if (EXITING || boardDuelFinished || duelActivityDestroyed || boardOnlineTurn != turn) return;
                if (!duelLocallyConnected || ACTIVITY_PAUSED) {
                    duelNeedsBoardResync = true;
                    return;
                }
                if (error != null) retryDuelAction(turn, () -> completeDuelTurn(turn, correct, reveals));
                else if (!committed && duelTerminalRef != null) {
                    duelNeedsBoardResync = true;
                    duelTerminalRef.addListenerForSingleValueEvent(duelTerminalListener);
                }
            }
        }, false);
    }

    private void writeOnlineTurnPick(int turn, int col, int row) {
        if (gameID == null || gameID.trim().isEmpty()) return;
        HashMap<String, Object> payload = new HashMap<>();
        payload.put("col", col);
        payload.put("row", row);
        boardRef().child("turns").child("t" + turn).updateChildren(payload);
    }

    private void writeOnlineTurnResult(int turn, boolean correct, boolean half) {
        if (paidDuel != null) return; // The server grades the actual submitted answer.
        if (gameID == null || gameID.trim().isEmpty()) return;
        if (!boardRoomMatch) {
            completeDuelTurn(turn, correct, boardRevealCount);
            return;
        }
        HashMap<String, Object> payload = new HashMap<>();
        payload.put("correct", correct);
        payload.put("half", half);
        payload.put("done", true);
        boardRef().child("turns").child("t" + turn).updateChildren(payload);
    }

    private void attachBoardTurnListener(final int turn) {
        if (gameID == null || gameID.trim().isEmpty()) return;
        detachBoardTurnListener();
        boardTurnRef = boardRef().child("turns").child("t" + turn);
        boardTurnListener = new ValueEventListener() {
            @Override
            public void onDataChange(DataSnapshot snapshot) {
                if (EXITING || boardOnlineTurn != turn || boardPickerIsHuman) return;
                if (!boardRoomMatch && (!duelLocallyConnected || ACTIVITY_PAUSED || duelActivityDestroyed)) {
                    duelNeedsBoardResync = true;
                    return;
                }
                if (!boardRoomMatch && Boolean.TRUE.equals(snapshot.child("skipped").getValue(Boolean.class))) {
                    stopTimer(false);
                    cancelPendingBoardReveal();
                    advanceOnlineBoardTurn();
                    return;
                }
                Long col = snapshot.child("col").getValue(Long.class);
                Long row = snapshot.child("row").getValue(Long.class);
                if (col != null && row != null && !boardWatchEntered) {
                    if (col < 0 || col >= boardCols || row < 0 || row >= BOARD_ROWS) return;
                    if (!boardRoomMatch && !opponentID.equals(snapshot.child("playerId").getValue(String.class))) return;
                    boardWatchEntered = true;
                    boardPickedCol = col.intValue();
                    boardPickedRow = row.intValue();
                    if (boardPickedCol >= 0 && boardPickedCol < boardCols
                            && boardPickedRow >= 0 && boardPickedRow < BOARD_ROWS) {
                        boardCurrentQuestion = boardCellQuestion[boardPickedCol][boardPickedRow];
                        boardCellConsumed[boardPickedCol][boardPickedRow] = true;
                    }
                    enterOnlineWatchQuestion();
                }
                Boolean done = snapshot.child("done").getValue(Boolean.class);
                if (done != null && done) {
                    Boolean correct = snapshot.child("correct").getValue(Boolean.class);
                    Boolean half = snapshot.child("half").getValue(Boolean.class);
                    boardOpponentCorrect = correct != null && correct;
                    boardOpponentHalf = half != null && half;
                    boardOpponentPoints = OnlineDuelState.number(snapshot.child("points").getValue(),
                            boardOpponentCorrect ? currentBoardCellValue() / (boardOpponentHalf ? 2 : 1) : 0);
                    boardOpponentResultReady = true;
                    maybeApplyOpponentResult();
                }
            }

            @Override
            public void onCancelled(DatabaseError error) {
            }
        };
        boardTurnRef.addValueEventListener(boardTurnListener);
    }

    /** Watcher view: show the question the opponent picked, then wait for their result. */
    private void enterOnlineWatchQuestion() {
        if (EXITING) return;
        if (boardCurrentQuestion == null) {
            boardWatchQuestionShown = true;
            maybeApplyOpponentResult();
            return;
        }
        hideBoardOverlay();
        initQuestion();
        boardPickerIsHuman = false;
        CAN_PLAY = false;
        Question q = boardCurrentQuestion;
        bindBoardQuestionVisual(q);
        applyQuestionTextSize(q.Q);
        final ArrayList<Integer> answerOrder = getQuestionShuffled(q);
        currentAnswerOrder.clear();
        currentAnswerOrder.addAll(answerOrder);
        final ArrayList<String> answerDisplayTexts = new ArrayList<>();
        for (int i = 0; i < answerOrder.size(); i++) {
            answerDisplayTexts.add(getAnswerText(q, answerOrder.get(i)));
        }
        applyAnswerTextSizes(answerDisplayTexts);
        showBoardTypedPanel(false);
        setBoardAnswerOptionsVisible(true);
        for (int i = 0; i < 4; i++) {
            bindBoardAnswerView(i, answerOrder.get(i), answerDisplayTexts.get(i));
        }
        showDialog("دور " + offlineContestants.nameForSlot(boardWatchSeat) + "..", "", 600, 1500, R.drawable.mouth_01, false);
        boardWatchQuestionShown = true;
        maybeApplyOpponentResult();
    }

    private void maybeApplyOpponentResult() {
        if (boardWatchResultApplied || !boardWatchQuestionShown || !boardOpponentResultReady) return;
        boardWatchResultApplied = true;
        final boolean correct = boardOpponentCorrect;
        final int turnAtResult = boardOnlineTurn;
        int value = currentBoardCellValue();
        if (boardRoomMatch) {
            if (boardOpponentHalf) value = value / 2;
        } else {
            value = boardOpponentPoints;
        }
        if (imgRight != null) imgRight.setImageResource(R.drawable.frame_right);
        if (correct) {
            offlineContestants.awardCell(boardWatchSeat, value);
            playSound(R.raw.correct_answer, false, false);
        } else {
            playSound(R.raw.wrong_answer, false, false);
        }
        offlineContestants.showSlotResult(boardWatchSeat, correct);
        CAN_HOME = true;
        String oppName = offlineContestants.nameForSlot(boardWatchSeat);
        showDialog(oppName + (correct ? " أجاب إجابة صحيحة" : " أجاب إجابة خاطئة"),
                "", 700, 2000, correct ? R.drawable.mouth_01 : R.drawable.mouth_05, false);
        duelConnectionHandler.postDelayed(new Runnable() {
            @Override
            public void run() {
                if (!EXITING && !duelActivityDestroyed && boardOnlineTurn == turnAtResult) advanceOnlineBoardTurn();
            }
        }, BOARD_REVEAL_HOLD_MS);
    }

    // ---- Disconnect handling --------------------------------------------

    private void handleBoardOpponentLeft() {
        if (!boardRoomMatch) {
            finishDuelByForfeit();
            return;
        }
        if (boardOpponentLeft) return;
        boardOpponentLeft = true;
        detachBoardTurnListener();
        if (!boardStarted) {
            // Opponent vanished during setup → finish the board solo against a bot.
            ensureSoloBoardFallback();
            return;
        }
        // If we're mid-watch on their turn and it hasn't resolved, take over as a bot.
        if (boardMode && !boardPickerIsHuman && !boardWatchResultApplied) {
            runOpponentBotTurn();
        }
    }

    /** Room board: a human seat dropped — the host drives its remaining turns as a bot. */
    private void handleRoomBoardSeatLeft(MatchOpponent opponent) {
        int seat = seatIndexForId(boardSeatKeyFor(opponent.id, opponent.seatId));
        if (seat < 0) seat = seatIndexForId(opponent.id);
        if (seat >= 0) {
            boardSeatLeft[seat] = true;
            boardSeatIsBot[seat] = true;
        }
        if (opponent.statusRef != null && opponent.statusListener != null) {
            opponent.statusRef.removeEventListener(opponent.statusListener);
        }
        opponent.statusRef = null;
        opponent.statusListener = null;
        // If it's that seat's turn right now and the host is watching it unresolved,
        // take over immediately so the match doesn't stall.
        if (meOwner && boardStarted && seat >= 0
                && seat == (boardSeatCount > 0 ? (boardOnlineTurn % boardSeatCount) : -1)
                && !boardPickerIsHuman && !boardWatchResultApplied) {
            detachBoardTurnListener();
            runHostBotSeatTurn(boardOnlineTurn, seat);
        }
    }

    private void ensureSoloBoardFallback() {
        if (boardStarted) return;
        boardStarted = true;
        boardOnline = false;
        detachBoardSetupListeners();
        offlineContestants.setContestantName(1, "الكمبيوتر");
        hideBoardOverlay();
        startBoardMode();
    }

    /** Drives the opponent's slot as a bot for one turn (after they disconnect). */
    private void runOpponentBotTurn() {
        if (boardPickedCol < 0 || boardPickedRow < 0) {
            int[] cell = pickRandomRemainingCell();
            if (cell == null) {
                finishBoardMatch();
                return;
            }
            boardPickedCol = cell[0];
            boardPickedRow = cell[1];
        }
        boardPickerSlot = 1;
        boardPickerIsHuman = false;
        boardCurrentQuestion = boardCellQuestion[boardPickedCol][boardPickedRow];
        // showBoardQuestion(.., false) reveals the options and schedules the bot answer,
        // which resolves the cell and calls endBoardTurn → advanceOnlineBoardTurn.
        enterBoardQuestion(false);
    }

    // ---- Listener teardown ----------------------------------------------

    private void detachBoardPicksListener() {
        if (boardPicksRef != null && boardPicksListener != null) {
            boardPicksRef.removeEventListener(boardPicksListener);
        }
        boardPicksRef = null;
        boardPicksListener = null;
    }

    private void detachBoardReadyListener() {
        if (boardReadyRef != null && boardReadyListener != null) {
            boardReadyRef.removeEventListener(boardReadyListener);
        }
        boardReadyRef = null;
        boardReadyListener = null;
    }

    private void detachBoardTurnListener() {
        if (boardTurnRef != null && boardTurnListener != null) {
            boardTurnRef.removeEventListener(boardTurnListener);
        }
        boardTurnRef = null;
        boardTurnListener = null;
    }

    private void detachBoardSetupListeners() {
        detachBoardPicksListener();
        detachBoardReadyListener();
    }

    private void detachBoardListeners() {
        if (stopDuelSessionListener != null) stopDuelSessionListener.run();
        stopDuelSessionListener = null;
        duelConnectionHandler.removeCallbacksAndMessages(null);
        duelDisconnectTick = null;
        duelDisconnectCountdown = null;
        if (duelTerminalRef != null && duelTerminalListener != null)
            duelTerminalRef.removeEventListener(duelTerminalListener);
        duelTerminalRef = null;
        duelTerminalListener = null;
        if (duelConnectionRef != null && duelConnectionListener != null)
            duelConnectionRef.removeEventListener(duelConnectionListener);
        duelConnectionRef = null;
        duelConnectionListener = null;
        detachBoardSetupListeners();
        detachBoardTurnListener();
    }

    // ---- Board grid screen ----------------------------------------------

    private void showBoardGrid() {
        if (boardOnline && boardDuelFinished) return;
        cancelBoardSelectTimer();
        boardAwaitingTypedInput = false;
        showBoardTypedPanel(false);
        if (boardLocalTeams && offlineContestants != null) {
            offlineContestants.setLocalTeamsActiveQuestionSlot(-1);
        }
        final FrameLayout overlay = (FrameLayout) findViewById(R.id.boardOverlay);
        if (overlay == null) return;
        overlay.removeAllViews();
        overlay.setBackgroundColor(0xE6071026);
        overlay.setVisibility(View.VISIBLE);
        overlay.bringToFront();

        ScrollView gridScroll = new ScrollView(this);
        gridScroll.setLayoutParams(new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT));
        gridScroll.setFillViewport(true);
        gridScroll.setVerticalScrollBarEnabled(false);
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setGravity(Gravity.CENTER);
        root.setLayoutParams(new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.WRAP_CONTENT));
        root.setPadding(dpx(16), dpx(8), dpx(16), dpx(8));
        gridScroll.addView(root);

        if (boardLocalTeams) {
            LinearLayout arenaHeader = new LinearLayout(this);
            arenaHeader.setOrientation(LinearLayout.HORIZONTAL);
            arenaHeader.setGravity(Gravity.CENTER_VERTICAL);
            arenaHeader.setBackground(gradientCardBg(0xEE0B1939, 0xEE040A1A, 0x66FFD700, 14, 1));
            arenaHeader.setPadding(dpx(14), dpx(6), dpx(14), dpx(6));
            LinearLayout.LayoutParams ahlp = new LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
            ahlp.bottomMargin = dpx(8);
            arenaHeader.setLayoutParams(ahlp);

            // Team A Card (Gold)
            boolean isTurnA = (boardPickerSlot == 0);
            int scoreA = (offlineContestants != null && offlineContestants.contestantCount() > 0)
                    ? offlineContestants.scoreForSlot(0) : 0;
            LinearLayout teamABox = new LinearLayout(this);
            teamABox.setOrientation(LinearLayout.VERTICAL);
            teamABox.setGravity(Gravity.CENTER);
            teamABox.setBackground(isTurnA ? gradientCardBg(0x44FFD700, 0x22B45309, 0xFFFFD700, 10, 2)
                    : cardBg(0x221E293B, 0x44FFD700, 10, 1));
            teamABox.setPadding(dpx(10), dpx(4), dpx(10), dpx(4));
            LinearLayout.LayoutParams tabLp = new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f);
            teamABox.setLayoutParams(tabLp);

            TextView aTag = makeBoardText((isTurnA ? "⚡ " : "🛡️ ") + boardTeamName(0), 12f, 0xFFFFD700, Gravity.CENTER);
            aTag.setTypeface(Typeface.DEFAULT_BOLD);
            aTag.setMaxLines(1);
            aTag.setEllipsize(TextUtils.TruncateAt.END);
            teamABox.addView(aTag);

            TextView aScore = makeBoardText(scoreA + " نقطة", 11f, 0xFFE2E8F0, Gravity.CENTER);
            teamABox.addView(aScore);
            arenaHeader.addView(teamABox);

            // Center Status / Turn Indicator
            LinearLayout centerBox = new LinearLayout(this);
            centerBox.setOrientation(LinearLayout.VERTICAL);
            centerBox.setGravity(Gravity.CENTER);
            LinearLayout.LayoutParams cbLp = new LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT);
            cbLp.setMargins(dpx(12), 0, dpx(12), 0);
            centerBox.setLayoutParams(cbLp);

            int activeColor = isTurnA ? 0xFFFFD700 : 0xFF38BDF8;
            TextView turnTag = makeBoardText("⚔️ دور " + boardTeamName(boardPickerSlot) + " ⚔️", 13.5f, activeColor, Gravity.CENTER);
            turnTag.setTypeface(Typeface.DEFAULT_BOLD);
            centerBox.addView(turnTag);

            TextView promptTag = makeBoardText("اختر فئة وقيمة السؤال", 10f, 0xFF94A3B8, Gravity.CENTER);
            centerBox.addView(promptTag);

            JSONObject curRec = LocalTeamsGameStore.get(this, localTeamsSaveId);
            final String currentTvCode = curRec != null ? curRec.optString("tvCode", "") : "";
            if (!currentTvCode.isEmpty()) {
                TextView tvBadge = makeBoardText("📺 رمز الشاشة: " + currentTvCode, 9.5f, 0xFFE2B852, Gravity.CENTER);
                tvBadge.setBackground(gradientPillBg(0x33FFD700, 0x1A000000, 0x66FFD700, 1));
                tvBadge.setPadding(dpx(8), dpx(1), dpx(8), dpx(1));
                LinearLayout.LayoutParams tbLp = new LinearLayout.LayoutParams(
                        LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT);
                tbLp.topMargin = dpx(2);
                tvBadge.setLayoutParams(tbLp);
                tvBadge.setOnClickListener(new View.OnClickListener() {
                    @Override
                    public void onClick(View v) {
                        GameNotice.makeText(GameActivity.this, "افتح https://challengeland.web.app/play واكتب الرمز: " + currentTvCode, Toast.LENGTH_LONG).show();
                    }
                });
                centerBox.addView(tvBadge);
            }
            arenaHeader.addView(centerBox);

            // Team B Card (Cyan)
            boolean isTurnB = (boardPickerSlot == 1);
            int scoreB = (offlineContestants != null && offlineContestants.contestantCount() > 1)
                    ? offlineContestants.scoreForSlot(1) : 0;
            LinearLayout teamBBox = new LinearLayout(this);
            teamBBox.setOrientation(LinearLayout.VERTICAL);
            teamBBox.setGravity(Gravity.CENTER);
            teamBBox.setBackground(isTurnB ? gradientCardBg(0x440284C7, 0x220369A1, 0xFF38BDF8, 10, 2)
                    : cardBg(0x221E293B, 0x4438BDF8, 10, 1));
            teamBBox.setPadding(dpx(10), dpx(4), dpx(10), dpx(4));
            LinearLayout.LayoutParams tbbLp = new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f);
            teamBBox.setLayoutParams(tbbLp);

            TextView bTag = makeBoardText((isTurnB ? "⚡ " : "⚔️ ") + boardTeamName(1), 12f, 0xFF38BDF8, Gravity.CENTER);
            bTag.setTypeface(Typeface.DEFAULT_BOLD);
            bTag.setMaxLines(1);
            bTag.setEllipsize(TextUtils.TruncateAt.END);
            teamBBox.addView(bTag);

            TextView bScore = makeBoardText(scoreB + " نقطة", 11f, 0xFFE2E8F0, Gravity.CENTER);
            teamBBox.addView(bScore);
            arenaHeader.addView(teamBBox);

            root.addView(arenaHeader);

            if (shouldUseBoardSelectTimer()) {
                boardSelectCountdownView = makeBoardText("⏱ " + BOARD_SELECT_SECONDS, 15f, 0xFF61FF39, Gravity.CENTER);
                boardSelectCountdownView.setBackground(gradientPillBg(0xCC059669, 0xCC10B981, 0xFF6EE7B7, 1));
                boardSelectCountdownView.setPadding(dpx(14), dpx(3), dpx(14), dpx(3));
                LinearLayout.LayoutParams cdLp = new LinearLayout.LayoutParams(
                        LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT);
                cdLp.gravity = Gravity.CENTER_HORIZONTAL;
                cdLp.bottomMargin = dpx(8);
                boardSelectCountdownView.setLayoutParams(cdLp);
                root.addView(boardSelectCountdownView);
            } else {
                boardSelectCountdownView = null;
            }
        } else {
            String bannerText;
            if (boardCampaignMatch && "solo".equals(boardCampaignKind)) {
                int remaining = Math.max(0, boardTotalTurns - boardTurnIndex);
                bannerText = "الهدف: " + boardTargetScore + "  •  نقاطك: " + offlineContestants.scoreForSlot(0)
                        + "  •  اختيارات متبقية: " + remaining;
            } else {
                bannerText = boardPickerIsHuman ? "دورك.. اختر فئة وقيمة"
                        : ("دور " + offlineContestants.nameForSlot(boardPickerSlot));
            }
            TextView banner = makeBoardText(bannerText, 18f,
                    boardPickerIsHuman ? 0xFF61FF39 : 0xFFFFD761, Gravity.CENTER);
            LinearLayout.LayoutParams blp = new LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
            blp.bottomMargin = dpx(8);
            banner.setLayoutParams(blp);
            root.addView(banner);

            if (boardCampaignMatch && !campaignBoardRulesLine().isEmpty()) {
                boardCampaignRuleView = makeBoardText(campaignBoardRulesLine(), 14f,
                        0xFFFFD761, Gravity.CENTER);
                root.addView(boardCampaignRuleView);
            }

            // 30-second pick timer (human turn only); auto-picks a cell on timeout.
            if (shouldUseBoardSelectTimer()) {
                boardSelectCountdownView = makeBoardText("⏱ " + BOARD_SELECT_SECONDS, 16f, 0xFF61FF39, Gravity.CENTER);
                boardSelectCountdownView.setBackground(headerBg());
                boardSelectCountdownView.setPadding(dpx(14), dpx(3), dpx(14), dpx(3));
                LinearLayout.LayoutParams cdLp = new LinearLayout.LayoutParams(
                        LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT);
                cdLp.gravity = Gravity.CENTER_HORIZONTAL;
                cdLp.bottomMargin = dpx(8);
                boardSelectCountdownView.setLayoutParams(cdLp);
                root.addView(boardSelectCountdownView);
            } else {
                boardSelectCountdownView = null;
            }

            // Compact standings strip (the side score board is hidden behind the overlay).
            android.widget.HorizontalScrollView scoresScroll = new android.widget.HorizontalScrollView(this);
            scoresScroll.setHorizontalScrollBarEnabled(false);
            LinearLayout.LayoutParams ssLp = new LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT);
            ssLp.bottomMargin = dpx(10);
            scoresScroll.setLayoutParams(ssLp);
            LinearLayout scoresRow = new LinearLayout(this);
            scoresRow.setOrientation(LinearLayout.HORIZONTAL);
            scoresRow.setGravity(Gravity.CENTER);
            int contestantCount = offlineContestants.contestantCount();
            for (int s = 0; s < contestantCount; s++) {
                String prefix = boardTeamMatch
                        ? ("[" + ("B".equals(boardSeatTeam[s]) ? "ب" : "أ") + "] ")
                        : "";
                String chipText = prefix + offlineContestants.nameForSlot(s) + ": " + offlineContestants.scoreForSlot(s);
                int chipColor = s == boardPickerSlot
                        ? 0xFFFFD761
                        : (boardTeamMatch && "B".equals(boardSeatTeam[s]) ? 0xFF7DD3FC : 0xFFFFFFFF);
                TextView chip = makeBoardText(chipText, 12f, chipColor, Gravity.CENTER);
                chip.setBackground(headerBg());
                chip.setPadding(dpx(8), dpx(4), dpx(8), dpx(4));
                LinearLayout.LayoutParams chLp = new LinearLayout.LayoutParams(
                        LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT);
                chLp.setMargins(dpx(4), 0, dpx(4), 0);
                chip.setLayoutParams(chLp);
                scoresRow.addView(chip);
            }
            scoresScroll.addView(scoresRow);
            root.addView(scoresScroll);
        }

        // Team board: show the running team totals above the categories.
        if (boardTeamMatch) {
            int teamAScore = 0, teamBScore = 0;
            for (int g = 0; g < boardSeatCount; g++) {
                int s = offlineContestants.scoreForSlot(g);
                if ("B".equals(boardSeatTeam[g])) teamBScore += s; else teamAScore += s;
            }
            String teamLine = "الفريق أ: " + teamAScore + "   |   الفريق ب: " + teamBScore;
            TextView teamTotals = makeBoardText(teamLine, 15f,
                    "B".equals(myTeam) ? 0xFF7DD3FC : 0xFFFFD761, Gravity.CENTER);
            teamTotals.setBackground(headerBg());
            teamTotals.setPadding(dpx(14), dpx(4), dpx(14), dpx(4));
            LinearLayout.LayoutParams ttLp = new LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT);
            ttLp.gravity = Gravity.CENTER_HORIZONTAL;
            ttLp.bottomMargin = dpx(10);
            teamTotals.setLayoutParams(ttLp);
            root.addView(teamTotals);
        }

        // Category blocks, classic التحدي layout: value pills (200/400/600) flank a
        // centre card holding the artwork and name. Up to three blocks per row, but with
        // only two categories (the online 1v1 board) use two so they fill the width
        // instead of being squeezed into two thirds with an empty column.
        final int perRow = Math.min(Math.max(boardCols, 1), 3);
        LinearLayout blockRow = null;
        for (int col = 0; col < boardCols; col++) {
            if (col % perRow == 0) {
                blockRow = new LinearLayout(this);
                blockRow.setOrientation(LinearLayout.HORIZONTAL);
                LinearLayout.LayoutParams rowLp = new LinearLayout.LayoutParams(
                        LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
                rowLp.bottomMargin = dpx(10);
                blockRow.setLayoutParams(rowLp);
                root.addView(blockRow);
            }
            blockRow.addView(makeCategoryBlock(col));
        }
        // Pad a partial last row so its blocks keep the same width as full rows.
        if (blockRow != null) {
            for (int i = ((boardCols - 1) % perRow) + 1; i < perRow; i++) {
                View spacer = new View(this);
                LinearLayout.LayoutParams sLp = new LinearLayout.LayoutParams(0, 1, 1f);
                sLp.setMargins(dpx(6), 0, dpx(6), 0);
                spacer.setLayoutParams(sLp);
                blockRow.addView(spacer);
            }
        }
        overlay.addView(gridScroll);

        if (shouldUseBoardSelectTimer()) {
            startBoardSelectTimer();
        }
    }

    private boolean shouldUseBoardSelectTimer() {
        return boardPickerIsHuman && !boardLocalTeams;
    }

    private void startBoardSelectTimer() {
        cancelBoardSelectTimer();
        if (!shouldUseBoardSelectTimer()) {
            boardSelectCountdownView = null;
            return;
        }
        startBoardSelectTimerWithDuration(paidDuel != null
                ? Math.max(1L, paidDuel.remainingMillis()) : BOARD_SELECT_SECONDS * 1000L);
    }

    private void startBoardSelectTimerWithDuration(long durationMs) {
        cancelBoardSelectTimer();
        boardSelectRemainingMs = durationMs;
        boardSelectTimer = new CountDownTimer(durationMs, 1000L) {
            @Override
            public void onTick(long ms) {
                boardSelectRemainingMs = ms;
                int secs = (int) Math.ceil(ms / 1000.0);
                if (boardSelectCountdownView != null) {
                    boardSelectCountdownView.setText("⏱ " + secs);
                    boardSelectCountdownView.setTextColor(
                            secs > 10 ? 0xFF61FF39 : (secs > 5 ? 0xFFFFA726 : 0xFFFF5252));
                }
            }

            @Override
            public void onFinish() {
                boardSelectTimer = null;
                boardSelectRemainingMs = 0L;
                if (paidDuel != null) {
                    if (!paidDuel.isPending()) paidDuel.sync();
                    return;
                }
                if (EXITING || !boardMode || !boardPickerIsHuman) return;
                View overlay = findViewById(R.id.boardOverlay);
                if (overlay == null || overlay.getVisibility() != View.VISIBLE) return;
                int[] cell = pickRandomRemainingCell();
                if (cell != null) {
                    GameNotice.makeText(GameActivity.this, "انتهى وقت الاختيار، تم اختيار خانة تلقائياً",
                            Toast.LENGTH_SHORT).show();
                    onCellPicked(cell[0], cell[1]);
                }
            }
        }.start();
    }

    private void cancelBoardSelectTimer() {
        if (boardSelectTimer != null) {
            boardSelectTimer.cancel();
            boardSelectTimer = null;
        }
        boardSelectRemainingMs = 0L;
        wasBoardSelectTimerRunningBeforePause = false;
    }

    /** One category block: 200/400/600 pills on each side of the artwork card. */
    private View makeCategoryBlock(final int col) {
        LinearLayout block = new LinearLayout(this);
        block.setOrientation(LinearLayout.HORIZONTAL);
        block.setGravity(Gravity.CENTER_VERTICAL);
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(0,
                LinearLayout.LayoutParams.WRAP_CONTENT, 1f);
        lp.setMargins(dpx(6), 0, dpx(6), 0);
        block.setLayoutParams(lp);
        block.addView(makePillColumn(col, 0));
        block.addView(makeCategoryCard(col));
        block.addView(makePillColumn(col, BOARD_VALUES.length));
        return block;
    }

    private View makePillColumn(final int col, final int firstRow) {
        LinearLayout column = new LinearLayout(this);
        column.setOrientation(LinearLayout.VERTICAL);
        column.setLayoutParams(new LinearLayout.LayoutParams(0,
                LinearLayout.LayoutParams.WRAP_CONTENT, 1f));
        for (int i = 0; i < BOARD_VALUES.length; i++) {
            column.addView(makeValuePill(col, firstRow + i));
        }
        return column;
    }

    private View makeValuePill(final int col, final int row) {
        final boolean consumed = boardCellConsumed[col][row];
        TextView pill = makeBoardText(
                consumed ? "✓" : String.valueOf(BOARD_VALUES[row % BOARD_VALUES.length]),
                16f, consumed ? 0xFFFFFFFF : 0xFF8E1B1B, Gravity.CENTER);
        pill.setBackground(valuePillBg(consumed));
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, dpx(32));
        lp.setMargins(dpx(3), dpx(3), dpx(3), dpx(3));
        pill.setLayoutParams(lp);
        if (consumed) {
            pill.setAlpha(0.5f);
        } else {
            pill.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View v) {
                    if (!boardMode || !boardPickerIsHuman) return;
                    if (boardCellConsumed[col][row]) return;
                    onCellPicked(col, row);
                }
            });
        }
        return pill;
    }

    private View makeCategoryCard(int col) {
        FrameLayout card = new FrameLayout(this);
        // Matches the pill column height: 3 pills x (32 + 6)dp of margins.
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(0, dpx(108), 1.1f);
        lp.setMargins(dpx(3), dpx(3), dpx(3), dpx(3));
        card.setLayoutParams(lp);
        card.setBackground(categoryCardBg());
        String category = boardSelectedCategories.get(col);
        String art = categoryAssetPath(category);
        if (art != null) {
            ImageView img = new ImageView(this);
            loadCategoryArtwork(img, art);
            img.setScaleType(ImageView.ScaleType.FIT_CENTER);
            img.setPadding(dpx(4), dpx(4), dpx(4), dpx(24));
            img.setLayoutParams(new FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT));
            card.addView(img);
        }
        TextView banner = makeBoardText(category, 11f, 0xFFFFFFFF, Gravity.CENTER);
        banner.setMaxLines(1);
        banner.setBackground(bannerBg());
        banner.setPadding(dpx(8), dpx(1), dpx(8), dpx(1));
        FrameLayout.LayoutParams bLp = new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.WRAP_CONTENT, FrameLayout.LayoutParams.WRAP_CONTENT,
                Gravity.BOTTOM | Gravity.CENTER_HORIZONTAL);
        bLp.bottomMargin = dpx(4);
        banner.setLayoutParams(bLp);
        card.addView(banner);
        return card;
    }

    private void hideBoardOverlay() {
        cancelBoardSelectTimer();
        View overlay = findViewById(R.id.boardOverlay);
        if (overlay != null) overlay.setVisibility(View.GONE);
    }

    // ---- Board question display & resolution ----------------------------

    /**
     * Shows a chosen board question. The human gets a text box (type the answer for
     * full value, or reveal the four options for half value); the bots keep the
     * classic staggered reveal and pick one of the four options.
     */
    private void showBoardQuestion(final Question question, final boolean humanTurn) {
        if (EXITING || duelActivityDestroyed || question == null) return;
        ArrayList<String> economyCategories = new ArrayList<>();
        String chosenCategory = getIntent().getStringExtra("economyChosenCategory");
        if (boardOnline && chosenCategory != null) economyCategories.add(chosenCategory);
        else if (!boardOnline) economyCategories.addAll(boardSelectedCategories);
        int economyOrder = 0;
        try { economyOrder = Integer.parseInt(campaignStageId.replace("stage_", "")); } catch (Exception ignored) {}
        if (!GameEconomy.ensure(this, campaignMode, economyOrder, economyCategories, () -> showBoardQuestion(question, humanTurn))) return;
        QuestionHistory.record(this, question);
        if (boardOnline && !boardRoomMatch) duelQuestionCallbackGeneration++;
        final int questionTurn = boardOnlineTurn;
        final int callbackGeneration = duelQuestionCallbackGeneration;
        if (boardCampaignMatch && (!ensureCampaignBoardCategoryAccess()
                || !AppPrefs.isCategoryUnlocked(this, question.getCategory()))) {
            if (!EXITING) pauseCampaignForLockedCategories();
            return;
        }
        if (boardLocalTeams && offlineContestants != null) {
            offlineContestants.setLocalTeamsActiveQuestionSlot(boardPickerSlot);
        }
        boardCurrentQuestion = question;
        playQuestionMusic();
        bindBoardQuestionVisual(question);
        applyQuestionTextSize(question.Q);

        final ArrayList<Integer> answerOrder = getQuestionShuffled(question);
        currentAnswerOrder.clear();
        currentAnswerOrder.addAll(answerOrder);
        final ArrayList<String> answerDisplayTexts = new ArrayList<>();
        for (int i = 0; i < answerOrder.size(); i++) {
            answerDisplayTexts.add(getAnswerText(question, answerOrder.get(i)));
        }
        applyAnswerTextSizes(answerDisplayTexts);

        if (humanTurn) {
            // Bind the options up front (kept hidden) so a later "reveal" works and the
            // correct answer can be highlighted, then open the text box.
            for (int i = 0; i < 4; i++) {
                bindBoardAnswerView(i, answerOrder.get(i), answerDisplayTexts.get(i));
            }
            if (question.getImg() != null && !question.getImg().trim().isEmpty()) {
                txtQ.setText("اضغط لترى الصورة 👁️");
                applyQuestionTextSize("اضغط لترى الصورة 👁️");
                final boolean[] boardDialogOpened = new boolean[]{false};
                final Handler boardAutoPrompt = new Handler();
                final Runnable openBoardObservation = new Runnable() {
                    @Override
                    public void run() {
                        if (boardDialogOpened[0] || isFinishing()
                                || !isCurrentBoardQuestionCallback(questionTurn,
                                        question, callbackGeneration)) return;
                        boardDialogOpened[0] = true;
                        boardAutoPrompt.removeCallbacksAndMessages(null);
                        imageObservationController.showObservationImage(GameActivity.this, question.getImg(), new ImageObservationController.OnObservationFinishedListener() {
                            @Override
                            public void onFinished() {
                                if (isFinishing() || !isCurrentBoardQuestionCallback(questionTurn,
                                        question, callbackGeneration)) return;
                                txtQ.setText(question.Q);
                                applyQuestionTextSize(question.Q);
                                txtQ.setOnClickListener(null);
                                startBoardTypedTurn();
                            }
                        });
                    }
                };
                txtQ.setOnClickListener(new View.OnClickListener() {
                    @Override
                    public void onClick(View v) {
                        openBoardObservation.run();
                    }
                });
                if (boardOnline && !boardRoomMatch) {
                    cancelPendingBoardReveal();
                    boardRevealHandler = boardAutoPrompt;
                    boardRevealRunnable = openBoardObservation;
                }
                boardAutoPrompt.postDelayed(openBoardObservation, 4000);
            } else {
                startBoardTypedTurn();
            }
            return;
        }

        // Bot turn: ensure the text box is gone and the four options are visible.
        showBoardTypedPanel(false);
        setBoardAnswerOptionsVisible(true);
        if (boardCampaignMatch) {
            // A late-world boss can contain 42 AI turns; keep their results readable
            // without repeating the long television-style reveal on every turn.
            for (int option = 0; option < 4; option++) {
                bindBoardAnswerView(option, answerOrder.get(option), answerDisplayTexts.get(option));
            }
            // Normalize to one reveal on fresh and restored bot questions. Campaign
            // bosses use choices, so they pay the same half-value cost as the player.
            boardRevealCount = 1;
            boardOptionsRevealed = true;
            scheduleBotBoardAnswer();
            return;
        }
        final Handler handler = new Handler();
        Runnable runnable = new Runnable() {
            int i = -1;

            @Override
            public void run() {
                if (EXITING) return;
                i++;
                switch (i) {
                    case 0:
                    case 1:
                    case 2:
                    case 3:
                        bindBoardAnswerView(i, answerOrder.get(i), answerDisplayTexts.get(i));
                        handler.postDelayed(this, 700);
                        break;
                    case 4:
                        CAN_PLAY = false;
                        scheduleBotBoardAnswer();
                        break;
                }
            }
        };
        handler.postDelayed(runnable, 700);
    }

    private void bindBoardQuestionVisual(Question question) {
        if (txtQ == null) return;
        txtQ.setVisibility(View.VISIBLE);
        String text = question == null || question.Q == null ? "" : question.Q;
        if (question != null && "مسيرة لاعب".equals(question.getCategory())) {
            txtQ.setMaxLines(Integer.MAX_VALUE);
            if (question.getClubPath() != null && !question.getClubPath().isEmpty()) {
                text = android.text.TextUtils.join(" ⬅️ ", question.getClubPath());
            } else {
                text = text.replaceAll("\\s*(?:،|,|←|⬅\\uFE0F?)\\s*", " ⬅️ ");
            }
            txtQ.setTextDirection(View.TEXT_DIRECTION_RTL);
        } else {
            txtQ.setMaxLines(2);
            txtQ.setTextDirection(View.TEXT_DIRECTION_FIRST_STRONG);
        }
        txtQ.setText(text);
    }
    /** Sets one option's text and tag, tracking which view holds the correct answer. */
    private void bindBoardAnswerView(int i, int answerKey, String text) {
        listAnswerViews.get(i).setText(text);
        if (answerKey == ANSWER_KEY_RIGHT) {
            rightAnswer = i + 1;
            listAnswerViews.get(i).setTag("1");
            txtRight = listAnswerViews.get(i);
            rlyRight = (RelativeLayout) ((ViewGroup) txtRight.getParent());
            imgRight = (ImageView) rlyRight.getChildAt(0);
        } else {
            listAnswerViews.get(i).setTag("0");
        }
    }

    // ---- Typed-answer panel (human board turn) --------------------------

    /** Opens the text box for the human's board turn; the four options stay hidden. */
    private void startBoardTypedTurn() {
        if (presenterDialogue.defer("typedTurn", this::startBoardTypedTurn)) return;
        final int questionTurn = boardOnlineTurn;
        final Question question = boardCurrentQuestion;
        final int callbackGeneration = duelQuestionCallbackGeneration;
        if (!isCurrentBoardQuestionCallback(questionTurn, question, callbackGeneration)) return;
        boardOptionsRevealed = false;
        boardAwaitingTypedInput = true;
        // No option is "selected" yet — clear stale references from earlier turns so
        // a correct typed answer highlights the right frame (via imgRight) instead.
        imgSelected = null;
        rlySelected = null;
        txtSelected = null;
        setBoardAnswerOptionsVisible(false);
        showBoardTypedPanel(true);
        if (boardLocalTeams) {
            saveLocalTeamsProgress(LocalTeamsGameStore.PHASE_QUESTION);
        }
        final Handler handler = new Handler();
        final Runnable startTypedTimer = new Runnable() {
            @Override
            public void run() {
                if (!boardMode || !boardAwaitingTypedInput
                        || !isCurrentBoardQuestionCallback(questionTurn,
                                question, callbackGeneration)) return;
                if (isRecoverableBotBoard() && ACTIVITY_PAUSED) {
                    handler.postDelayed(this, 250L);
                    return;
                }
                CAN_PLAY = false; // frame taps stay disabled until options are revealed
                questionStartTimeMs = System.currentTimeMillis();
                startTimer(true);
                // Don't force the keyboard open: the player reads the question and
                // chooses to type (tap the box) or reveal the options. The keyboard
                // would otherwise cover the "reveal options" button in landscape.
                if (boardAnswerInput != null) boardAnswerInput.requestFocus();
            }
        };
        if (boardOnline && !boardRoomMatch) {
            cancelPendingBoardReveal();
            boardRevealHandler = handler;
            boardRevealRunnable = startTypedTimer;
        }
        handler.postDelayed(startTypedTimer, 700);
    }

    private void restoreImmersiveMode() {
        if (getWindow() != null && getWindow().getDecorView() != null) {
            getWindow().getDecorView().setSystemUiVisibility(
                    View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                            | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                            | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                            | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                            | View.SYSTEM_UI_FLAG_FULLSCREEN
                            | View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY);
        }
    }

    private void setupKeyboardListener() {
        if (boardKeyboardLayoutListener != null) return;
        final View decor = getWindow() != null ? getWindow().getDecorView() : null;
        if (decor == null) return;

        boardKeyboardLayoutListener = new ViewTreeObserver.OnGlobalLayoutListener() {
            private boolean wasOpen = false;
            @Override
            public void onGlobalLayout() {
                if (isFinishing() || isDestroyed()) return;
                Rect r = new Rect();
                decor.getWindowVisibleDisplayFrame(r);
                int screenHeight = decor.getRootView().getHeight();
                int keypadHeight = screenHeight - r.bottom;
                boolean isOpen = keypadHeight > screenHeight * 0.15;
                if (isOpen != wasOpen) {
                    wasOpen = isOpen;
                    isBoardKeyboardShowing = isOpen;
                    onBoardKeyboardVisibilityChanged(isOpen);
                }
            }
        };
        decor.getViewTreeObserver().addOnGlobalLayoutListener(boardKeyboardLayoutListener);
    }

    private void onBoardKeyboardVisibilityChanged(boolean isVisible) {
        if (!boardMode || !boardAwaitingTypedInput) {
            if (!isVisible) restoreImmersiveMode();
            return;
        }

        // Adjust question box height so question, input, and options stay visible above keyboard
        RelativeLayout frameQ = findViewById(R.id.frameQ);
        if (frameQ != null) {
            ViewGroup.LayoutParams lp = frameQ.getLayoutParams();
            if (lp != null) {
                lp.height = isVisible ? dpx(92) : dpx(140);
                frameQ.setLayoutParams(lp);
            }
        }
        TextView txtQ = findViewById(R.id.txtQ);
        if (txtQ != null) {
            txtQ.setTextSize(TypedValue.COMPLEX_UNIT_SP, isVisible ? 18f : 25f);
        }

        if (btnBoardHideKeyboard != null) {
            btnBoardHideKeyboard.setVisibility(isVisible ? View.VISIBLE : View.GONE);
        }

        if (!isVisible) {
            restoreImmersiveMode();
        }
    }

    /** Lazily builds the text box + submit/reveal buttons inside the Q/A column. */
    private void ensureBoardTypedPanel() {
        if (boardTypedAnswerPanel != null || llyQA == null) return;
        setupKeyboardListener();

        LinearLayout panel = new LinearLayout(this);
        panel.setOrientation(LinearLayout.VERTICAL);
        panel.setLayoutDirection(View.LAYOUT_DIRECTION_RTL);
        LinearLayout.LayoutParams panelLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        panelLp.topMargin = dpx(4);
        panel.setLayoutParams(panelLp);

        // --- Main unified action row: [Input field] [Hide keyboard] [Submit] [Reveal options] ---
        LinearLayout mainRow = new LinearLayout(this);
        mainRow.setOrientation(LinearLayout.HORIZONTAL);
        mainRow.setLayoutDirection(View.LAYOUT_DIRECTION_RTL);
        mainRow.setGravity(Gravity.CENTER_VERTICAL);
        LinearLayout.LayoutParams rowLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        mainRow.setLayoutParams(rowLp);

        BoardAnswerEditText input = new BoardAnswerEditText(this);
        input.setSingleLine(true);
        // NO_EXTRACT_UI stops the keyboard taking over the whole screen with its
        // landscape full-screen "extract" editor (the big black box + DONE button).
        input.setImeOptions(EditorInfo.IME_ACTION_DONE | EditorInfo.IME_FLAG_NO_EXTRACT_UI);
        input.setInputType(InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_FLAG_NO_SUGGESTIONS);
        input.setHint("اكتب إجابتك هنا...");
        input.setHintTextColor(0x99FFFFFF);
        input.setTextColor(0xFFFFFFFF);
        input.setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f);
        input.setGravity(Gravity.CENTER);
        input.setTextDirection(View.TEXT_DIRECTION_RTL);
        input.setPadding(dpx(12), dpx(6), dpx(12), dpx(6));
        GradientDrawable inputBg = new GradientDrawable();
        inputBg.setColor(0xEE0E2347);
        inputBg.setCornerRadius(dpx(14));
        inputBg.setStroke(dpx(1.8f), 0xFF38BDF8);
        input.setBackground(inputBg);
        if (getBoardFont() != null) input.setTypeface(getBoardFont(), Typeface.BOLD);
        LinearLayout.LayoutParams inLp = new LinearLayout.LayoutParams(0, dpx(48), 1f);
        inLp.setMargins(dpx(3), 0, dpx(3), 0);
        input.setLayoutParams(inLp);
        input.setOnEditorActionListener(new TextView.OnEditorActionListener() {
            @Override
            public boolean onEditorAction(TextView v, int actionId, android.view.KeyEvent event) {
                if (actionId == EditorInfo.IME_ACTION_DONE) {
                    onBoardSubmitTypedAnswer();
                    return true;
                }
                return false;
            }
        });
        input.setOnKeyBackPressedListener(new BoardAnswerEditText.OnKeyBackPressedListener() {
            @Override
            public void onKeyBackPressed() {
                hideKeyboard();
            }
        });
        mainRow.addView(input);

        // Dedicated quick button to hide keyboard when typing
        Button hideBtn = new Button(this);
        hideBtn.setText("⌨️⌄");
        hideBtn.setAllCaps(false);
        hideBtn.setTextColor(0xFFE2E8F0);
        hideBtn.setTextSize(TypedValue.COMPLEX_UNIT_SP, 15f);
        hideBtn.setGravity(Gravity.CENTER);
        hideBtn.setPadding(0, 0, 0, 0);
        hideBtn.setIncludeFontPadding(false);
        GradientDrawable hideBg = new GradientDrawable();
        hideBg.setColor(0xDD1E293B);
        hideBg.setCornerRadius(dpx(14));
        hideBg.setStroke(dpx(1.5f), 0xFF64748B);
        hideBtn.setBackground(hideBg);
        LinearLayout.LayoutParams hideLp = new LinearLayout.LayoutParams(dpx(46), dpx(48));
        hideLp.setMargins(dpx(2), 0, dpx(2), 0);
        hideBtn.setLayoutParams(hideLp);
        hideBtn.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                hideKeyboard();
            }
        });
        hideBtn.setVisibility(isBoardKeyboardShowing ? View.VISIBLE : View.GONE);
        mainRow.addView(hideBtn);

        // Submit answer button
        Button submit = makeLuxuryBoardButton("تأكيد ✓", new int[]{0xFF10B981, 0xFF059669, 0xFF064E3B}, 0xFF6EE7B7, 0xFFFFFFFF);
        LinearLayout.LayoutParams subLp = new LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, dpx(48));
        subLp.setMargins(dpx(3), 0, dpx(3), 0);
        submit.setPadding(dpx(14), 0, dpx(14), 0);
        submit.setMinWidth(dpx(95));
        submit.setLayoutParams(subLp);
        submit.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                onBoardSubmitTypedAnswer();
            }
        });
        mainRow.addView(submit);

        // Reveal options button - ALWAYS on same row as input, so visible even when keyboard is open!
        Button reveal = makeLuxuryBoardButton("إظهار الخيارات 💡", new int[]{0xFFF59E0B, 0xFFD97706, 0xFF78350F}, 0xFFFDE68A, 0xFFFFFFFF);
        LinearLayout.LayoutParams revLp = new LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, dpx(48));
        revLp.setMargins(dpx(3), 0, dpx(3), 0);
        reveal.setPadding(dpx(14), 0, dpx(14), 0);
        reveal.setMinWidth(dpx(135));
        reveal.setLayoutParams(revLp);
        reveal.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                onBoardRevealOptions();
            }
        });
        mainRow.addView(reveal);

        panel.addView(mainRow);

        // Steal concede button (Row 2, local teams mode)
        Button concede = makeLuxuryBoardButton("🤝 إقرار بصحة إجابة الخصم (منحهم النقاط)", new int[]{0xFF059669, 0xFF047857, 0xFF064E3B}, 0xFFA7F3D0, 0xFFFFFFFF);
        concede.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                onBoardConcedeSteal();
            }
        });
        LinearLayout.LayoutParams concedeLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, dpx(40));
        concedeLp.topMargin = dpx(5);
        concede.setLayoutParams(concedeLp);
        concede.setVisibility(View.GONE);
        panel.addView(concede);

        boardTypedAnswerPanel = panel;
        boardAnswerInput = input;
        btnBoardHideKeyboard = hideBtn;
        btnBoardSubmitAnswer = submit;
        btnBoardRevealOptions = reveal;
        btnBoardConcedeSteal = concede;
        llyQA.addView(panel);
    }

    private Button makeLuxuryBoardButton(String text, int[] gradientColors, int strokeColor, int textColor) {
        Button b = new Button(this);
        b.setText(text);
        b.setAllCaps(false);
        b.setTextColor(textColor);
        b.setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f);
        b.setGravity(Gravity.CENTER);
        b.setIncludeFontPadding(false);
        if (getBoardFont() != null) b.setTypeface(getBoardFont(), Typeface.BOLD);
        else b.setTypeface(Typeface.DEFAULT_BOLD);
        
        GradientDrawable gd = new GradientDrawable(GradientDrawable.Orientation.TOP_BOTTOM, gradientColors);
        gd.setCornerRadius(dpx(22));
        if (strokeColor != 0) {
            gd.setStroke(dpx(1.5f), strokeColor);
        }
        b.setBackground(gd);
        return b;
    }

    private Button makeBoardButton(String text, int color) {
        Button b = new Button(this);
        b.setText(text);
        b.setAllCaps(false);
        b.setTextColor(0xFFFFFFFF);
        b.setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f);
        b.setPadding(dpx(4), 0, dpx(4), 0);
        b.setBackground(pillBg(color));
        if (getBoardFont() != null) b.setTypeface(getBoardFont(), Typeface.BOLD);
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(0, dpx(46), 1f);
        lp.setMargins(dpx(4), 0, dpx(4), 0);
        b.setLayoutParams(lp);
        return b;
    }

    private void showBoardTypedPanel(boolean show) {
        if (show) ensureBoardTypedPanel();
        if (boardTypedAnswerPanel == null) return;
        boardTypedAnswerPanel.setVisibility(show ? View.VISIBLE : View.GONE);
        if (show && boardAnswerInput != null) {
            boardAnswerInput.setText("");
            boardAnswerInput.setEnabled(true);
            if (btnBoardSubmitAnswer != null) btnBoardSubmitAnswer.setEnabled(true);
            if (btnBoardRevealOptions != null) {
                boolean allowed = !boardCampaignMatch || boardAllowRevealOptions;
                btnBoardRevealOptions.setVisibility(allowed ? View.VISIBLE : View.GONE);
                btnBoardRevealOptions.setEnabled(allowed);
            }
            if (btnBoardConcedeSteal != null) {
                boolean showConcede = boardLocalTeams && boardStealActive;
                btnBoardConcedeSteal.setVisibility(showConcede ? View.VISIBLE : View.GONE);
                btnBoardConcedeSteal.setEnabled(showConcede);
            }
        }
        if (!show) hideKeyboard();
    }

    private void onBoardConcedeSteal() {
        if (!boardMode || !boardLocalTeams || !boardStealActive || !boardAwaitingTypedInput) return;
        final int stealSlot = boardPickerSlot;
        final int originalSlot = (stealSlot == 1) ? 0 : 1;
        final String stealTeam = boardTeamName(stealSlot);
        final String originalTeam = boardTeamName(originalSlot);
        final int award = currentBoardAwardValue();

        LinearLayout dialogView = new LinearLayout(this);
        dialogView.setOrientation(LinearLayout.VERTICAL);
        dialogView.setPadding(dpx(22), dpx(20), dpx(22), dpx(20));
        dialogView.setBackground(gameCustomDialogBg(0xF407132D, 0x8838BDF8, 16, 1));
        dialogView.setLayoutDirection(View.LAYOUT_DIRECTION_RTL);

        TextView title = new TextView(this);
        title.setText("🤝 الروح الرياضية والتحكيم");
        title.setTextColor(0xFF38BDF8);
        title.setTextSize(TypedValue.COMPLEX_UNIT_SP, 17.5f);
        if (getBoardFont() != null) title.setTypeface(getBoardFont(), Typeface.BOLD);
        else title.setTypeface(Typeface.DEFAULT_BOLD);
        title.setGravity(Gravity.RIGHT);
        dialogView.addView(title);

        TextView message = new TextView(this);
        message.setText("هل يوافق فريق « " + stealTeam + " » على أن إجابة فريق « " + originalTeam + " » كانت مقبولة وصحيحة، ومنحهم نقاط السؤال (" + award + " نقطة)؟");
        message.setTextColor(0xFFFFFFFF);
        message.setTextSize(TypedValue.COMPLEX_UNIT_SP, 13.5f);
        if (getBoardFont() != null) message.setTypeface(getBoardFont(), Typeface.NORMAL);
        message.setGravity(Gravity.RIGHT);
        LinearLayout.LayoutParams msgLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        msgLp.topMargin = dpx(8);
        msgLp.bottomMargin = dpx(16);
        dialogView.addView(message, msgLp);

        LinearLayout btnRow = new LinearLayout(this);
        btnRow.setOrientation(LinearLayout.HORIZONTAL);
        btnRow.setGravity(Gravity.CENTER_VERTICAL);

        final AlertDialog dialog = GameNoticeDialogs.builder(this)
                .setView(dialogView)
                .create();

        if (dialog.getWindow() != null) {
            dialog.getWindow().setBackgroundDrawableResource(android.R.color.transparent);
        }

        Button confirmBtn = makeLuxuryBoardButton(
                "نعم، احتساب النقاط لـ " + originalTeam,
                new int[]{0xFF10B981, 0xFF059669, 0xFF064E3B},
                0xFFA7F3D0,
                0xFFFFFFFF
        );
        confirmBtn.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                dialog.dismiss();
                executeConcedeSteal(originalSlot, award);
            }
        });
        LinearLayout.LayoutParams confirmLp = new LinearLayout.LayoutParams(0, dpx(44), 1f);
        confirmLp.setMargins(0, 0, dpx(8), 0);
        btnRow.addView(confirmBtn, confirmLp);

        Button cancelBtn = makeLuxuryBoardButton(
                "تراجع",
                new int[]{0x44334155, 0x221E293B},
                0x5594A3B8,
                0xFFCBD5E1
        );
        cancelBtn.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                dialog.dismiss();
            }
        });
        LinearLayout.LayoutParams cancelLp = new LinearLayout.LayoutParams(dpx(86), dpx(44));
        btnRow.addView(cancelBtn, cancelLp);

        dialogView.addView(btnRow, new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT));

        dialog.show();
    }

    private void executeConcedeSteal(int originalSlot, int award) {
        if (EXITING || !boardMode || !boardLocalTeams) return;
        stopTimer(false);
        boardAwaitingTypedInput = false;
        boardStealActive = false;
        showBoardTypedPanel(false);
        hideKeyboard();

        if (offlineContestants != null) {
            offlineContestants.awardCell(originalSlot, award);
            offlineContestants.showSlotResult(originalSlot, true);
            offlineContestants.setLocalTeamsActiveQuestionSlot(-1);
        }

        playSound(R.raw.correct_answer, false, false);
        if (person != null) {
            person.like(1000);
            person.raiseEyeBrowsUp(1000, false, true);
        }

        String teamName = boardTeamName(originalSlot);
        showDialog("بروح رياضية! تم احتساب " + award + " نقطة لفريق " + teamName,
                "", 1000, 2500, R.drawable.mouth_01, false);

        saveLocalTeamsProgress(LocalTeamsGameStore.PHASE_BOARD);

        new Handler().postDelayed(new Runnable() {
            @Override
            public void run() {
                if (!EXITING) endBoardTurn();
            }
        }, 2500);
    }

    private void cancelPendingBoardReveal() {
        if (boardRevealHandler != null && boardRevealRunnable != null) {
            boardRevealHandler.removeCallbacks(boardRevealRunnable);
            boardRevealRunnable = null;
        }
    }

    private void ensureBoardRefereePanel() {
        if (boardRefereePanel != null || llyQA == null) return;
        
        LinearLayout container = new LinearLayout(this);
        container.setOrientation(LinearLayout.HORIZONTAL);
        container.setLayoutDirection(View.LAYOUT_DIRECTION_RTL);
        container.setGravity(Gravity.CENTER_VERTICAL);
        container.setPadding(0, 0, 0, 0);
        
        LinearLayout.LayoutParams panelLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        panelLp.topMargin = dpx(6);
        container.setLayoutParams(panelLp);

        // 1. Referee Override Button (Gold Championship Gradient)
        Button refBtn = makeLuxuryBoardButton(
                "⚖️ تعديل الحكم واحتساب النقاط",
                new int[]{0xFFFFD233, 0xFFF59E0B, 0xFFB45309},
                0xFFFFE885,
                0xFF0F172A
        );
        refBtn.setTextSize(TypedValue.COMPLEX_UNIT_SP, 12.5f);
        refBtn.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                showBoardRefereeDialog();
            }
        });
        LinearLayout.LayoutParams refLp = new LinearLayout.LayoutParams(0, dpx(44), 1f);
        refLp.setMargins(dpx(6), 0, dpx(6), 0);
        container.addView(refBtn, refLp);

        // 2. Next Turn Button (Sapphire & Cyan Glow Gradient)
        Button skipBtn = makeLuxuryBoardButton(
                "⏭️ الدور التالي",
                new int[]{0xFF2563EB, 0xFF1D4ED8, 0xFF0B1B44},
                0xFF60A5FA,
                0xFFFFFFFF
        );
        skipBtn.setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f);
        skipBtn.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                cancelPendingBoardReveal();
                showBoardRefereePanel(false);
                if (!EXITING && boardMode) {
                    endBoardTurn();
                }
            }
        });
        LinearLayout.LayoutParams skipLp = new LinearLayout.LayoutParams(0, dpx(44), 1f);
        skipLp.setMargins(dpx(6), 0, dpx(6), 0);
        container.addView(skipBtn, skipLp);

        boardRefereePanel = container;
        btnBoardRefereeOverride = refBtn;
        llyQA.addView(container);
    }

    private void showBoardRefereePanel(boolean show) {
        if (!boardLocalTeams) {
            if (boardRefereePanel != null) boardRefereePanel.setVisibility(View.GONE);
            return;
        }
        if (show) ensureBoardRefereePanel();
        if (boardRefereePanel != null) {
            boardRefereePanel.setVisibility(show ? View.VISIBLE : View.GONE);
        }
    }

    private void showBoardRefereeDialog() {
        if (!boardMode || !boardLocalTeams) return;
        cancelPendingBoardReveal();
        final int award = currentBoardAwardValue();

        LinearLayout dialogView = new LinearLayout(this);
        dialogView.setOrientation(LinearLayout.VERTICAL);
        dialogView.setPadding(dpx(22), dpx(20), dpx(22), dpx(20));
        dialogView.setBackground(gameCustomDialogBg(0xF407132D, 0x88F59E0B, 16, 1));
        dialogView.setLayoutDirection(View.LAYOUT_DIRECTION_RTL);

        TextView title = new TextView(this);
        title.setText("⚖️ تعديل الحكم والتحكيم اليدوي");
        title.setTextColor(0xFFFFC727);
        title.setTextSize(TypedValue.COMPLEX_UNIT_SP, 17.5f);
        if (getBoardFont() != null) title.setTypeface(getBoardFont(), Typeface.BOLD);
        else title.setTypeface(Typeface.DEFAULT_BOLD);
        title.setGravity(Gravity.RIGHT);
        dialogView.addView(title);

        TextView message = new TextView(this);
        message.setText("إذا اتفقتم بروح رياضية على صحة إحدى الإجابات، اختر الفريق المستحق لمنحه نقاط هذا السؤال (" + award + " نقطة):");
        message.setTextColor(0xFFFFFFFF);
        message.setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f);
        if (getBoardFont() != null) message.setTypeface(getBoardFont(), Typeface.NORMAL);
        message.setGravity(Gravity.RIGHT);
        LinearLayout.LayoutParams msgLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        msgLp.topMargin = dpx(8);
        msgLp.bottomMargin = dpx(16);
        dialogView.addView(message, msgLp);

        final AlertDialog dialog = GameNoticeDialogs.builder(this)
                .setView(dialogView)
                .create();

        if (dialog.getWindow() != null) {
            dialog.getWindow().setBackgroundDrawableResource(android.R.color.transparent);
        }

        // Team A Button (Gold Championship)
        Button btnA = makeLuxuryBoardButton(
                "🏆 احتساب النقاط لـ « " + boardTeamAName + " »",
                new int[]{0xFFFFD233, 0xFFF59E0B, 0xFFB45309},
                0xFFFFE885,
                0xFF0F172A
        );
        btnA.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                dialog.dismiss();
                applyRefereeAward(0, award);
            }
        });
        LinearLayout.LayoutParams aLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, dpx(44));
        aLp.bottomMargin = dpx(8);
        dialogView.addView(btnA, aLp);

        // Team B Button (Sapphire/Cyan)
        Button btnB = makeLuxuryBoardButton(
                "🏆 احتساب النقاط لـ « " + boardTeamBName + " »",
                new int[]{0xFF38BDF8, 0xFF0284C7, 0xFF075985},
                0xFFBAE6FD,
                0xFFFFFFFF
        );
        btnB.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                dialog.dismiss();
                applyRefereeAward(1, award);
            }
        });
        LinearLayout.LayoutParams bLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, dpx(44));
        bLp.bottomMargin = dpx(12);
        dialogView.addView(btnB, bLp);

        // Cancel Button
        Button cancelBtn = makeLuxuryBoardButton(
                "إلغاء والمتابعة للدور التالي",
                new int[]{0x44334155, 0x221E293B},
                0x5594A3B8,
                0xFFCBD5E1
        );
        cancelBtn.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                dialog.dismiss();
                showBoardRefereePanel(false);
                if (!EXITING && boardMode) {
                    endBoardTurn();
                }
            }
        });
        dialogView.addView(cancelBtn, new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, dpx(40)));

        dialog.show();
    }

    private void applyRefereeAward(int slot, int award) {
        if (EXITING || !boardMode || !boardLocalTeams) return;
        boardRefereeOverrideApplied = true;
        cancelPendingBoardReveal();
        showBoardRefereePanel(false);

        if (offlineContestants != null) {
            offlineContestants.awardCell(slot, award);
            offlineContestants.showSlotResult(slot, true);
        }

        playSound(R.raw.correct_answer, false, false);
        if (person != null) {
            person.like(1000);
            person.raiseEyeBrowsUp(1000, false, true);
        }

        String teamName = boardTeamName(slot);
        GameNotice.makeText(this, "تم تعديل الحكم واحتساب " + award + " نقطة لـ " + teamName, Toast.LENGTH_LONG).show();

        saveLocalTeamsProgress(LocalTeamsGameStore.PHASE_BOARD);

        new Handler().postDelayed(new Runnable() {
            @Override
            public void run() {
                if (!EXITING && boardMode) endBoardTurn();
            }
        }, 2200);
    }

    private GradientDrawable gameCustomDialogBg(int fill, int stroke, int radiusDp, int strokeDp) {
        GradientDrawable bg = new GradientDrawable();
        bg.setColor(fill);
        bg.setCornerRadius(dpx(radiusDp));
        if (strokeDp > 0) {
            bg.setStroke(dpx(strokeDp), stroke);
        }
        return bg;
    }

    private void setBoardAnswerOptionsVisible(boolean visible) {
        int v = visible ? View.VISIBLE : View.GONE;
        if (llyA1 != null) llyA1.setVisibility(v);
        if (llyA2 != null) llyA2.setVisibility(v);
    }

    private void hideKeyboard() {
        InputMethodManager imm = (InputMethodManager) getSystemService(Context.INPUT_METHOD_SERVICE);
        if (imm != null) {
            View focus = getCurrentFocus();
            if (focus != null) {
                imm.hideSoftInputFromWindow(focus.getWindowToken(), 0);
            } else if (boardAnswerInput != null) {
                imm.hideSoftInputFromWindow(boardAnswerInput.getWindowToken(), 0);
            }
        }
        if (boardAnswerInput != null && boardAnswerInput.hasFocus()) {
            boardAnswerInput.clearFocus();
        }
        isBoardKeyboardShowing = false;
        if (btnBoardHideKeyboard != null) {
            btnBoardHideKeyboard.setVisibility(View.GONE);
        }
        restoreImmersiveMode();
    }

    /** Player chose to reveal the four options: switch to multiple-choice. Each reveal
     *  halves the cell's award (carried across a التحدي الرئيسي steal). */
    private void onBoardRevealOptions() {
        if (boardCampaignMatch && !boardAllowRevealOptions) return;
        if (!boardMode || !boardAwaitingTypedInput) return;
        if (paidDuel != null) {
            if (paidDuel.isPending()) return;
            hideKeyboard();
            Map<String, Object> data = paidDuelTurnArgs();
            data.put("count", 1);
            paidDuel.call("reveal", data);
            return;
        }
        hideKeyboard();
        boardAwaitingTypedInput = false;
        boardOptionsRevealed = true;
        boardRevealCount++;
        showBoardTypedPanel(false);
        setBoardAnswerOptionsVisible(true);
        CAN_PLAY = true; // the player now taps one of the four options
        if (boardLocalTeams) {
            saveLocalTeamsProgress(LocalTeamsGameStore.PHASE_QUESTION);
        }
        if (shouldSaveOfflineBoard()) {
            saveOfflineBoardProgress(OfflineBoardGameStore.PHASE_QUESTION);
        }
        if (boardCampaignMatch) {
            saveCampaignProgress(OfflineBoardGameStore.PHASE_QUESTION);
        }
        showDialog("اختر الإجابة الصحيحة (القيمة الآن " + currentBoardAwardValue() + ")",
                "", 600, 1400, R.drawable.mouth_01, true);
    }

    /** Player submitted a typed answer: grade it (full value) and resolve the turn. */
    private void onBoardSubmitTypedAnswer() {
        if (!boardMode || !boardAwaitingTypedInput) return;
        String typed = boardAnswerInput != null ? boardAnswerInput.getText().toString() : "";
        if (typed.trim().isEmpty()) {
            GameNotice.makeText(this, "اكتب إجابتك أولاً", Toast.LENGTH_SHORT).show();
            return;
        }
        if (paidDuel != null) {
            if (paidDuel.isPending()) return;
            paidDuelTypedAnswer = typed;
            checkAnswer(false);
            return;
        }
        boardAwaitingTypedInput = false;
        boardOptionsRevealed = false;
        if (btnBoardSubmitAnswer != null) btnBoardSubmitAnswer.setEnabled(false);
        if (btnBoardRevealOptions != null) btnBoardRevealOptions.setEnabled(false);
        showBoardTypedPanel(false);

        boolean correct = BoardAnswerMatcher.isCorrect(typed, boardCurrentQuestion);
        myAnswer = correct ? rightAnswer : 0; // 0 never equals a 1-based right index
        CAN_PLAY = false;
        checkAnswer(false);
    }

    /** Award for the human's board cell: the cell value halved once per options reveal
     *  (full → ½ → ¼). The reveal count carries across a التحدي الرئيسي steal. */
    private int currentBoardAwardValue() {
        return currentBoardCellValue() / (1 << boardRevealCount);
    }

    /** التحدي الرئيسي only: the picking team answered wrong — hand the SAME question to
     *  the other team (steal). Swaps the picker, re-arms the typed-answer panel and
     *  restarts the timer; the steal team's answer resolves the cell normally. */
    private void beginBoardSteal() {
        boardStealActive = true;
        final int stealSlot = (boardPickerSlot == 1) ? 0 : 1;
        boardPickerSlot = stealSlot;
        boardPickerIsHuman = true;
        if (offlineContestants != null) {
            offlineContestants.setLocalTeamsActiveQuestionSlot(stealSlot);
        }
        saveLocalTeamsProgress(LocalTeamsGameStore.PHASE_QUESTION);
        new Handler().postDelayed(new Runnable() {
            @Override
            public void run() {
                if (EXITING || isFinishing() || isDestroyed() || presenterDialogue.defer(this)) return;
                if (EXITING || !boardMode || !boardStealActive) return;
                if (boardAnswerInput != null) boardAnswerInput.setText("");
                if (btnBoardSubmitAnswer != null) btnBoardSubmitAnswer.setEnabled(true);
                if (btnBoardRevealOptions != null) btnBoardRevealOptions.setEnabled(true);
                setBoardAnswerOptionsVisible(false);
                showDialog("الفرصة الآن لفريق " + boardTeamName(stealSlot) + "!",
                        "", 800, 1800, R.drawable.mouth_01, false);
                startBoardTypedTurn();
            }
        }, 1600);
    }

    private void scheduleBotBoardAnswer() {
        final Question q = boardCurrentQuestion;
        final int slot = boardPickerSlot;
        final int turn = boardTurnIndex;
        final int delayMs = boardCampaignMatch
                ? CampaignBoardRules.bossThinkTimeMs(q == null ? "" : q.getLevel(),
                        q == null ? "" : q.Q, campaignBossStyleForSlot(slot),
                        isCampaignBossSpecialtyCell(slot), boardRandom)
                : 1800;
        if (boardCampaignMatch) {
            String name = offlineContestants.nameForSlot(slot);
            showDialog(name + " يفكر في الإجابة..", "", 500,
                    Math.max(600, delayMs - DIALOG_EXTRA_VISIBLE_MS),
                    R.drawable.mouth_01, false);
        }
        new Handler().postDelayed(new Runnable() {
            @Override
            public void run() {
                if (EXITING || isFinishing() || isDestroyed() || turn != boardTurnIndex
                        || slot != boardPickerSlot || q != boardCurrentQuestion
                        || (boardCampaignMatch && campaignResultPersisted)) return;
                if (ACTIVITY_PAUSED) {
                    new Handler().postDelayed(this, 250);
                    return;
                }
                resolveBotBoardAnswer(slot);
            }
        }, delayMs);
    }

    private void resolveBotBoardAnswer(final int slot) {
        if (boardCampaignMatch && campaignResultPersisted) return;
        final Question answeredQuestion = boardCurrentQuestion;
        final int answeredTurn = boardTurnIndex;
        final boolean correct = offlineContestants.rollCorrectForSlot(slot,
                boardCurrentQuestion != null ? boardCurrentQuestion.getLevel() : "0");
        int pickIdx = correct ? rightAnswer : pickRandomWrongIndex(rightAnswer);
        RelativeLayout rlyPick = (RelativeLayout) findViewById(boardFrameIdForIndex(pickIdx));
        final ImageView imgPick = (rlyPick != null && rlyPick.getChildCount() > 0)
                ? (ImageView) rlyPick.getChildAt(0) : null;
        if (imgPick != null) imgPick.setImageResource(R.drawable.frame_final);
        new Handler().postDelayed(new Runnable() {
            @Override
            public void run() {
                if (EXITING || isFinishing() || isDestroyed() || presenterDialogue.defer(this)) return;
                if (EXITING || duelActivityDestroyed || answeredTurn != boardTurnIndex
                        || answeredQuestion != boardCurrentQuestion
                        || (boardCampaignMatch && campaignResultPersisted)) return;
                if (correct) {
                    if (imgPick != null) imgPick.setImageResource(R.drawable.frame_right);
                    offlineContestants.awardCell(slot, CampaignBoardRules.botAwardValue(
                            currentBoardCellValue(), boardCampaignMatch, boardOptionsRevealed));
                    playSound(R.raw.correct_answer, false, false);
                } else {
                    if (imgPick != null) imgPick.setImageResource(R.drawable.frame_wrong);
                    if (imgRight != null) imgRight.setImageResource(R.drawable.frame_right);
                    playSound(R.raw.wrong_answer, false, false);
                }
                offlineContestants.showSlotResult(slot, correct);
                // Room host: broadcast the bot/abandoned seat's result so watchers apply it.
                if (boardOnline && boardRoomMatch && meOwner) {
                    writeOnlineTurnResult(boardOnlineTurn, correct, false);
                }
                String name = offlineContestants.nameForSlot(slot);
                showDialog(name + (correct ? " أجاب إجابة صحيحة" : " أجاب إجابة خاطئة"),
                        "", 700, boardCampaignMatch ? 500 : 2000, correct ? R.drawable.mouth_01 : R.drawable.mouth_05, false);
                new Handler().postDelayed(new Runnable() {
                    @Override
                    public void run() {
                        if (!EXITING) endBoardTurn();
                    }
                }, boardCampaignMatch ? 1700 : BOARD_REVEAL_HOLD_MS);
            }
        }, boardCampaignMatch ? 600 : 1300);
    }

    private int currentBoardCellValue() {
        if (boardPickedRow >= 0 && boardPickedRow < BOARD_ROWS) {
            return BOARD_VALUES[boardPickedRow % BOARD_VALUES.length];
        }
        return 0;
    }

    private int getAnswerRevealDrumDelayMs() {
        if (boardCampaignMatch) return 900;
        if (!boardMode) return 1200;
        switch (currentBoardCellValue()) {
            case 200:
                return 3000;
            case 400:
                return 6000;
            case 600:
                return 9000;
            default:
                return 1200;
        }
    }

    private int boardFrameIdForIndex(int idx) {
        switch (idx) {
            case 1: return R.id.frameA1;
            case 2: return R.id.frameA2;
            case 3: return R.id.frameA3;
            case 4: return R.id.frameA4;
            default: return R.id.frameA1;
        }
    }

    private int pickRandomWrongIndex(int right) {
        int idx;
        do {
            idx = 1 + boardRandom.nextInt(4);
        } while (idx == right);
        return idx;
    }

    // ---- Board UI helpers ------------------------------------------------

    private Typeface getBoardFont() {
        if (boardFont == null) {
            try {
                boardFont = ResourcesCompat.getFont(this, R.font.baloo);
            } catch (Exception ignored) {
            }
        }
        return boardFont;
    }

    /** Finds the artwork in assets/categories whose file name matches the category. */
    private String categoryAssetPath(String category) {
        if (categoryAssetIndex == null) {
            categoryAssetIndex = new HashMap<>();
            try {
                String[] files = getAssets().list("categories");
                if (files != null) {
                    for (String f : files) {
                        int dot = f.lastIndexOf('.');
                        String base = dot > 0 ? f.substring(0, dot) : f;
                        categoryAssetIndex.put(normalizeArabic(base), "categories/" + f);
                    }
                }
            } catch (Exception ignored) {
            }
        }
        String norm = normalizeArabic(category);
        if (norm.equals(normalizeArabic("قصة مسلسل عربي"))) {
            norm = normalizeArabic("مسلسلات عربية");
        } else if (norm.equals(normalizeArabic("قصة فيلم عربي"))) {
            norm = normalizeArabic("أفلام عربية");
        } else if (norm.equals(normalizeArabic("قصة مسلسل اجنبي")) || norm.equals(normalizeArabic("قصة مسلسل أجنبي"))) {
            norm = normalizeArabic("مسلسلات أجنبية");
        } else if (norm.equals(normalizeArabic("قصة فيلم اجنبي")) || norm.equals(normalizeArabic("قصة فيلم أجنبي"))) {
            norm = normalizeArabic("أفلام أجنبية");
        } else if (norm.equals(normalizeArabic("أنمي")) || norm.equals(normalizeArabic("انمي"))) {
            norm = normalizeArabic("الأنمي");
        }
        String exact = categoryAssetIndex.get(norm);
        if (exact == null && (norm.equals(normalizeArabic("الأنمي")) || norm.equals(normalizeArabic("الانمي")))) {
            exact = categoryAssetIndex.get(normalizeArabic("أنمي"));
        }
        if (exact != null) return exact;
        // Fall back to the longest file name contained in the category name (or vice
        // versa) so "جغرافيا ودول" finds جغرافيا.png and "رياضه" finds رياضة.png.
        String best = null;
        int bestLen = 0;
        for (Map.Entry<String, String> e : categoryAssetIndex.entrySet()) {
            String key = e.getKey();
            if (key.length() > bestLen && (norm.contains(key) || key.contains(norm))) {
                best = e.getValue();
                bestLen = key.length();
            }
        }
        return best;
    }

    private void loadCategoryArtwork(ImageView image, String path) {
        // Decode on Picasso workers, bound the texture size, and share its LRU cache.
        Picasso.with(this).load("file:///android_asset/" + path)
                .resize(dpx(160), dpx(160))
                .centerInside().onlyScaleDown().into(image);
    }

    /** Strips tashkeel and unifies alef/teh-marbuta variants for tolerant matching. */
    private static String normalizeArabic(String s) {
        if (s == null) return "";
        StringBuilder b = new StringBuilder(s.length());
        for (char c : s.trim().toCharArray()) {
            if (c >= 'ً' && c <= 'ْ') continue; // harakat incl. shadda
            if (c == 'أ' || c == 'إ' || c == 'آ') c = 'ا'; // hamza alef -> alef
            else if (c == 'ة') c = 'ه'; // teh marbuta -> heh
            else if (c == 'ى') c = 'ي'; // alef maqsura -> yeh
            b.append(c);
        }
        return b.toString();
    }

    private TextView makeBoardText(String text, float sizeSp, int color, int gravity) {
        TextView tv = new TextView(this);
        tv.setText(text);
        tv.setTextColor(color);
        tv.setTextSize(TypedValue.COMPLEX_UNIT_SP, sizeSp);
        tv.setGravity(gravity);
        tv.setIncludeFontPadding(false);
        Typeface f = getBoardFont();
        if (f != null) tv.setTypeface(f, Typeface.BOLD);
        else tv.setTypeface(Typeface.DEFAULT_BOLD);
        return tv;
    }

    private GradientDrawable categoryTileBg(boolean selected) {
        return categoryTileBg(selected, false);
    }

    private GradientDrawable categoryTileBg(boolean selected, boolean locked) {
        GradientDrawable d = new GradientDrawable();
        if (locked) {
            d.setColor(0xD9091328);
            d.setCornerRadius(dpx(12));
            d.setStroke(dpx(1), 0x99FACC15);
        } else {
            d.setColor(selected ? 0xFF1E5AA8 : 0xCC13294B);
            d.setCornerRadius(dpx(12));
            d.setStroke(dpx(selected ? 3 : 1), selected ? 0xFFFFC107 : 0x66FFFFFF);
        }
        return d;
    }

    private GradientDrawable valuePillBg(boolean consumed) {
        GradientDrawable d = new GradientDrawable();
        d.setColor(consumed ? 0xFF39415A : 0xFFEAEAF0);
        d.setCornerRadius(dpx(16));
        return d;
    }

    private GradientDrawable categoryCardBg() {
        GradientDrawable d = new GradientDrawable();
        d.setColor(0xFFF4F6FA);
        d.setCornerRadius(dpx(10));
        return d;
    }

    private GradientDrawable bannerBg() {
        GradientDrawable d = new GradientDrawable();
        d.setColor(0xFFF0822A);
        d.setCornerRadius(dpx(7));
        return d;
    }

    private GradientDrawable headerBg() {
        GradientDrawable d = new GradientDrawable();
        d.setColor(0xFF0E2347);
        d.setCornerRadius(dpx(8));
        d.setStroke(dpx(1), 0x66FFFFFF);
        return d;
    }

    private GradientDrawable pillBg(int color) {
        GradientDrawable d = new GradientDrawable();
        d.setColor(color);
        d.setCornerRadius(dpx(25));
        return d;
    }

    private GradientDrawable pillBg(int fillColor, int strokeColor, int strokeDp) {
        GradientDrawable gd = new GradientDrawable();
        gd.setColor(fillColor);
        gd.setCornerRadius(dpx(999));
        if (strokeDp > 0) gd.setStroke(dpx(strokeDp), strokeColor);
        return gd;
    }

    private GradientDrawable cardBg(int fillColor, int strokeColor, int radiusDp, int strokeDp) {
        GradientDrawable gd = new GradientDrawable();
        gd.setColor(fillColor);
        gd.setCornerRadius(dpx(radiusDp));
        if (strokeDp > 0) gd.setStroke(dpx(strokeDp), strokeColor);
        return gd;
    }

    private GradientDrawable gradientCardBg(int startColor, int endColor, int strokeColor, int radiusDp, float strokeDp) {
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

    private int dpx(float dp) {
        return Math.round(getResources().getDisplayMetrics().density * dp);
    }

    private void applyOnlineRoundMetrics() {
        if (eliminationMode) {
            if (!spectatorEliminationRound && mySubmittedAnswerKey == ANSWER_KEY_RIGHT) {
                setScoreMe += 1;
                mySetCorrectAnswers++;
                myTotalCorrectAnswers++;
            }
            if (!spectatorEliminationRound) {
                if (myRoundPoints > 0) {
                    gameScoreMe += myRoundPoints;
                }
                mySetAnswerTimeMs += myAnswerElapsedMs;
                myTotalAnswerTimeMs += myAnswerElapsedMs;
            }

            for (MatchOpponent opponent : opponents) {
                if (opponent.eliminated) {
                    continue;
                }
                if (opponent.submittedAnswerKey == ANSWER_KEY_RIGHT) {
                    opponent.roundScore += 1;
                    opponent.setCorrectAnswers++;
                    opponent.totalCorrectAnswers++;
                }
                if (opponent.roundPoints > 0) {
                    opponent.gameScore += opponent.roundPoints;
                }
                opponent.setAnswerTimeMs += opponent.answerElapsedMs;
                opponent.totalAnswerTimeMs += opponent.answerElapsedMs;
            }

            txtScoreMe.setText(setScoreMe + "");
            txtScoreGameMe.setText(gameScoreMe + "");
            opponentHudController.refreshOpponentPanels();
            return;
        }

        if (myRoundPoints > 0) {
            setScoreMe += myRoundPoints;
            gameScoreMe += myRoundPoints;
        }
        if (mySubmittedAnswerKey == ANSWER_KEY_RIGHT) {
            mySetCorrectAnswers++;
            myTotalCorrectAnswers++;
        }
        mySetAnswerTimeMs += myAnswerElapsedMs;
        myTotalAnswerTimeMs += myAnswerElapsedMs;
        myTimeoutStreak = mySubmittedAnswerKey == 0 ? myTimeoutStreak + 1 : 0;

        for (MatchOpponent opponent : opponents) {
            if (opponent.roundPoints > 0) {
                opponent.roundScore += opponent.roundPoints;
                opponent.gameScore += opponent.roundPoints;
            }
            if (opponent.submittedAnswerKey == ANSWER_KEY_RIGHT) {
                opponent.setCorrectAnswers++;
                opponent.totalCorrectAnswers++;
            }
            opponent.setAnswerTimeMs += opponent.answerElapsedMs;
            opponent.totalAnswerTimeMs += opponent.answerElapsedMs;
            opponent.timeoutStreak = opponent.submittedAnswerKey == 0 ? opponent.timeoutStreak + 1 : 0;
        }

        txtScoreMe.setText(setScoreMe + "");
        txtScoreGameMe.setText(gameScoreMe + "");
        opponentHudController.refreshOpponentPanels();
    }

    private boolean handleLocalTimeoutRemovalIfNeeded() {
        if (!modeOnline || eliminationMode || localPlayerRemoved || myTimeoutStreak < MAX_TIMEOUT_STREAK) {
            return false;
        }

        localPlayerRemoved = true;
        PlayerStats.recordWrongAnswer(this);
        PlayerStats.recordGameEnd(this, ProgressionRules.ABANDON, 0);
        markMyGameState("left_timeout");
        detachOpponentRoundListener();
        detachQuestionSyncListener();
        stopTimer(false);
        CAN_PLAY = false;
        CAN_HOME = false;

        showDialog("أخطأت في 3 أسئلة متتالية.\nسيكمل خصم آلي اللعب بدلًا منك.", "", 900, 2200, R.drawable.mouth_05, false);
        new Handler().postDelayed(new Runnable() {
            @Override
            public void run() {
                Intent intent = new Intent(GameActivity.this, MainActivity.class);
                intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TASK);
                startActivity(intent);
                finish();
            }
        }, 2500);
        return true;
    }

    private int handleEliminationRoundProgress() {
        final ArrayList<String> eliminatedNames = new ArrayList<>();
        boolean localEliminatedThisRound = false;

        if (!localPlayerEliminated && mySubmittedAnswerKey != ANSWER_KEY_RIGHT) {
            localPlayerEliminated = true;
            markMyGameState("eliminated");
            localEliminatedThisRound = true;
            eliminatedNames.add("أنت");
        }

        for (MatchOpponent opponent : opponents) {
            if (opponent.eliminated) {
                continue;
            }
            if (opponent.submittedAnswerKey != ANSWER_KEY_RIGHT) {
                opponent.eliminated = true;
                eliminatedNames.add(opponent.name);
            }
        }

        opponentHudController.refreshOpponentPanels();

        if (currentQuestion == 14) {
            String leaderId = getMatchLeaderId();
            if (myID.equals(leaderId)) {
                person.moveShow2Hands(2000);
                person.raiseEyeBrowsUp(1000, false, true);
                showDialog("مبروك، فزت في مباراة الإقصاء بأعلى نقاط", "", 2000, 3000, R.drawable.mouth_01, false);
                updateScoreAndLevel();
                return 1;
            }

            showDialog("انتهت مباراة الإقصاء. الفائز هو " + getPlayerDisplayName(leaderId), "", 2000, 3000, R.drawable.mouth_01, false);
            updateScoreAndLevel();
            return -1;
        }

        if (localEliminatedThisRound) {
            if (getAlivePlayersCount() == 0) {
                showDialog("انتهت المباراة، جميع اللاعبين خارج", "", 2000, 3000, R.drawable.mouth_05, false);
                updateScoreAndLevel();
                return -1;
            }
            showDialog("إجابة خاطئة، خرجت من المنافسة.\nهل تريد متابعة المباراة كمشاهد؟", "EliminationSpectatorChoice", 1000, 0, R.drawable.mouth_05, false);
            return -3;
        }

        if (getAlivePlayersCount() == 0) {
            showDialog("انتهت المباراة، جميع اللاعبين خارج", "", 2000, 3000, R.drawable.mouth_05, false);
            updateScoreAndLevel();
            return -1;
        }

        if (eliminatedNames.isEmpty()) {
            showDialog("جميع اللاعبين أجابوا بشكل صحيح", "", 1000, 2000, R.drawable.mouth_01, false);
        } else if (eliminatedNames.size() == 1) {
            showDialog("تم إقصاء " + eliminatedNames.get(0), "", 1000, 2000, R.drawable.mouth_05, false);
        } else {
            showDialog("تم إقصاء " + joinNames(eliminatedNames), "", 1000, 2000, R.drawable.mouth_05, false);
        }
        return -2;
    }

    private void continueEliminationMatchAsSpectator() {
        if (!modeOnline || !eliminationMode || EXITING) {
            return;
        }

        if (getAlivePlayersCount() == 0) {
            updateScoreAndLevel();
            openOnlineResultScreen(false);
            return;
        }

        initQuestion();
        nextStep();
        playSound(R.raw.lets_play, true, false);
        String currentStepAmount = getCurrentStepAmount();
        person.moveHead(1000);
        person.lookAside(600);
        showDialog("السؤال التالي قيمته\n" + currentStepAmount, "", 1000, 3000, R.drawable.mouth_02, false);
        CAN_HOME = true;

        final Handler handler = new Handler();
        handler.postDelayed(new Runnable() {
            @Override
            public void run() {
                if (EXITING) {
                    return;
                }
                Animations.move(llyQA, 1000, -140, 0, 0, 0);
                Animations.move(llySteps, 1000, -360, 0, 0, 0);
                handler.postDelayed(new Runnable() {
                    @Override
                    public void run() {
                        if (EXITING) {
                            return;
                        }
                        requestSynchronizedQuestion(currentQuestion + 1);
                    }
                }, 1000);
            }
        }, 4000);
    }

    private void exitEliminationMatchAfterDecliningSpectator() {
        if (EXITING) {
            return;
        }

        updateScoreAndLevel();
        PlayerProgress.onOnlineMatchFinished(
                GameActivity.this,
                false,
                setMe,
                "elimination",
                false,
                null
        );
        PlayerStats.recordGameEnd(GameActivity.this, false, gameScoreMe * 1000);
        detachOpponentStatusListener();
        detachOpponentRoundListener();
        detachQuestionSyncListener();
        EXITING = true;

        Intent intent = new Intent(GameActivity.this, MainActivity.class);
        intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TASK);
        startActivity(intent);
        finish();
    }

    private int getAlivePlayersCount() {
        int aliveCount = localPlayerEliminated ? 0 : 1;
        for (MatchOpponent opponent : opponents) {
            if (!opponent.eliminated) {
                aliveCount++;
            }
        }
        return aliveCount;
    }

    private String getAliveLeaderId() {
        String leaderId = localPlayerEliminated ? "" : myID;
        for (MatchOpponent opponent : opponents) {
            if (opponent.eliminated) {
                continue;
            }
            if (leaderId.isEmpty() || compareMatchStanding(opponent.id, leaderId) < 0) {
                leaderId = opponent.id;
            }
        }
        return leaderId;
    }

    private String joinNames(ArrayList<String> names) {
        StringBuilder builder = new StringBuilder();
        for (int i = 0; i < names.size(); i++) {
            if (i > 0) {
                builder.append(i == names.size() - 1 ? " و " : "، ");
            }
            builder.append(names.get(i));
        }
        return builder.toString();
    }


    private boolean usedAllHelps() {
        return usedHelp5050 && usedHelpAudience && usedHelpCall;
    }

    private boolean usedAnyHelp() {
        return usedHelp5050 || usedHelpAudience || usedHelpCall;
    }

    private void goToWinnerScreen(String amount) {
        if (!EXITING && presenterDialogue.deferAll("winner", () -> goToWinnerScreen(amount))) return;
        try {
            int prize = Integer.parseInt(amount.replace("$", "").trim());
            PlayerStats.recordGameEnd(GameActivity.this, true, prize);
            if (!campaignMode) {
                PlayerProgress.onGameFinished(GameActivity.this, true, prize, PlayerStats.getBestStreak(GameActivity.this), usedAllHelps(), usedAnyHelp());
            }
            persistPendingCampaignStageResult(true, prize, 0);
        } catch (Exception ignored) {}
        Intent intent = new Intent(GameActivity.this, WinnerActivity.class);
        intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TASK);
        intent.putExtra("amount", amount);
        startActivity(intent);
    }

    private boolean checkScores() {
        if ((currentQuestion == 4) || (currentQuestion == 9) || (currentQuestion == 14)) {
            if (setScoreMe > setScoreOpponent) {
                setMe++;
                setScoreMe = 0;
                setScoreOpponent = 0;
            } else if (setScoreMe < setScoreOpponent) {
                setOpponent++;
                setScoreMe = 0;
                setScoreOpponent = 0;
            } else {
                setMe++;
                setOpponent++;
            }
            txtSetsMe.setText(setMe + "");
            txtSetsOpponent.setText(setOpponent + "");
            txtScoreMe.setText("0");
            txtScoreOpponent.setText("0");
            String setNum = (currentQuestion == 4 ? "الأولى" : (currentQuestion == 9 ? "الثانية" : "الثالثة"));
            if (setMe > setOpponent) {
                person.like(1000);
                person.raiseEyeBrowsUp(1000, false, true);
                showDialog("انتهت الجولة " + setNum + " والنتيجة تقدمك " + setMe + " مقابل " + setOpponent, "", 2000, 3000, R.drawable.mouth_01, false);
            } else if (setMe < setOpponent) {
                showDialog("انتهت الجولة " + setNum + " والنتيجة تأخرك " + setMe + " مقابل " + setOpponent, "", 2000, 3000, R.drawable.mouth_01, false);
            } else {
                showDialog("انتهت الجولة " + setNum + " والنتيجة التعادل " + setMe + " - " + setOpponent, "", 2000, 3000, R.drawable.mouth_01, false);
            }
            return true;
        } else {
            return false;
        }
    }

    private int checkEndOfGame() {
        int res;
        int setNum = (currentQuestion == 4 ? 1 : (currentQuestion == 9 ? 2 : 3));
        if ((currentQuestion == 14) || ((3 - setNum) < Math.abs(setMe - setOpponent))) {
            if (setMe > setOpponent) {
                res = 1;
                person.moveShow2Hands(2000);
                person.raiseEyeBrowsUp(1000, false, true);
                showDialog("مبروك انتهت المباراة بفوزك بنتيجة " + setMe + " مقابل " + setOpponent, "", 2000, 3000, R.drawable.mouth_01, false);
            } else if (setMe < setOpponent) {
                res = -1;
                showDialog("للأسف انتهت المباراة بخسارتك بنتيجة " + setMe + " مقابل " + setOpponent, "", 2000, 3000, R.drawable.mouth_01, false);
            } else {
                res = 0;
                showDialog("انتهت المباراة بالتعادل بنتيجة " + setMe + " - " + setOpponent, "", 2000, 3000, R.drawable.mouth_01, false);
            }
            updateScoreAndLevel();
            return res;
        } else {
            return -2;
        }
    }

    private void updateScoreAndLevel() {
        if (!NativeProgression.activeAccount(this)) return;
        if (gameScoreMe > 0) {
            int newScore = ProgressionRules.safeAdd(myScore, gameScoreMe);
            if (!myID.startsWith("guest_")) Data.setUserScore(myID, newScore);
            int newLevel = PlayerProgress.getLevel(this);

            AppPrefs.setUser(GameActivity.this, myID, myName, myPhoto, newLevel, newScore);
            myScore = newScore;
            if (newLevel > myLevel) {
                if (!myID.startsWith("guest_")) Data.setUserLevel(myID, newLevel);
                final Handler handler = new Handler();
                final int finalNewLevel = newLevel;
                Runnable runnable = new Runnable() {
                    @Override
                    public void run() {
                        if (EXITING || isFinishing() || isDestroyed() || presenterDialogue.defer(this)) return;
                        playSound(R.raw.new_level, false, false);
                        showDialog("ممتاز.. لقد وصلت إلى المستوى " + finalNewLevel, "", 1000, 3000, R.drawable.mouth_01, false);
                    }
                };
                handler.postDelayed(runnable, 3000);
            }
            myLevel = newLevel;
        }
    }

    private void getQuestions(String gameID) {
        questionsReady = false;
        questionsLoadFailed = false;
        if (!modeOnline) {
            prepareQuestionSelection(() -> {
                questions = campaignMode ? LocalQuestions.loadAll(this) : LocalQuestions.load(this, questionExclusions);
                applyCampaignQuestionSelectionIfNeeded();
                if (questions.isEmpty() || campaignMode && questions.size() < getCampaignTargetQuestionCount()) {
                    questionsLoadFailed = true;
                    questionSelectionFailed(new IllegalStateException(QuestionHistory.EXHAUSTED));
                    return;
                }
                questionSelectionPending = true;
                QuestionHistory.reserve(this, "", "", questions, () -> {
                    questionSelectionPending = false;
                    questionsReady = !EXITING && !isFinishing();
                }, error -> { questionsLoadFailed = true; questionSelectionFailed(error); });
            });
            return;
        }
        new Data().getQuestions(gameID, new OnGetQuestionsListener() {
            @Override
            public void onSuccess(ArrayList<Question> questions) {
                QuestionHistory.recordAll(GameActivity.this, questions);
                GameActivity.this.questions = questions;
                questionsReady = questions != null && !questions.isEmpty();
                questionsLoadFailed = false;
            }

            @Override
            public void onFailed(DatabaseError error) {
                questionsReady = false;
                questionsLoadFailed = true;
                startPending = false;
                GameNotice.makeText(GameActivity.this, "تعذر تحميل أسئلة المواجهة", Toast.LENGTH_SHORT).show();
            }
        });
    }

    private void getGame() {
        new Data().getGameID(myID, new OnGetGameIdListener() {
            @Override
            public void onSuccess(String gameID) {
                if (!gameID.equals("")) {
                    GameActivity.this.gameID = gameID;
                    beginOnlineGameSession();
                    Data.removeTempGameID(gameID);
                    new Data().getGameQuestions(GameActivity.this.gameID, new OnGetQuestionsListener() {
                        @Override
                        public void onSuccess(ArrayList<Question> questions) {
                            QuestionHistory.recordAll(GameActivity.this, questions);
                            GameActivity.this.questions = questions;
                            questionsReady = questions != null && !questions.isEmpty();
                            questionsLoadFailed = false;
                        }

                        @Override
                        public void onFailed(DatabaseError error) {
                            questionsReady = false;
                            questionsLoadFailed = true;
                            startPending = false;
                            GameNotice.makeText(GameActivity.this, "تعذر تحميل أسئلة المواجهة", Toast.LENGTH_SHORT).show();
                        }
                    });
                }
            }

            @Override
            public void onFailed(DatabaseError error) {

            }
        });
    }

    private void startMatchFlow() {
        if (!modeOnline || questionsReady) {
            startPending = false;
            letsStart();
            return;
        }
        if (questionsLoadFailed) {
            startPending = false;
            GameNotice.makeText(GameActivity.this, "تعذر تحميل أسئلة المواجهة", Toast.LENGTH_SHORT).show();
            return;
        }
        if (startPending) {
            return;
        }
        startPending = true;
        GameNotice.makeText(GameActivity.this, "جارٍ تجهيز أسئلة المواجهة...", Toast.LENGTH_SHORT).show();
        final Handler handler = new Handler();
        handler.postDelayed(new Runnable() {
            @Override
            public void run() {
                if (EXITING) {
                    startPending = false;
                    return;
                }
                if (questionsLoadFailed) {
                    startPending = false;
                    GameNotice.makeText(GameActivity.this, "تعذر تحميل الأسئلة", Toast.LENGTH_SHORT).show();
                    CAN_CLICK = true;
                    return;
                }
                if (questionsReady) {
                    startPending = false;
                    letsStart();
                } else {
                    handler.postDelayed(this, 300);
                }
            }
        }, 300);
    }

    private void beginOnlineGameSession() {
        if (!modeOnline || gameID == null || gameID.trim().isEmpty()) {
            return;
        }
        attachServerTimeOffsetListener();
        myStatusRef = FirebaseDatabase.getInstance().getReference()
                .child("Games")
                .child(gameID)
                .child(myID)
                .child("status");
        try {
            myStatusRef.onDisconnect().setValue("left");
        } catch (Exception ignored) {
        }
        if (!boardOnline || boardRoomMatch) markMyGameState("active");
        if (boardOnline && !boardRoomMatch && duelConnectionRef == null) {
            OnlineDuelResultStore.track(this, gameID, opponentID);
            duelConnectionRef = FirebaseDatabase.getInstance().getReference(".info/connected");
            duelConnectionListener = new ValueEventListener() {
                @Override public void onDataChange(DataSnapshot snapshot) {
                    if (EXITING || boardDuelFinished || duelActivityDestroyed) return;
                    duelLocallyConnected = Boolean.TRUE.equals(snapshot.getValue(Boolean.class));
                    if (!duelLocallyConnected) {
                        duelNeedsBoardResync = true;
                        stopTimer(false);
                        cancelBoardSelectTimer();
                        cancelPendingBoardReveal();
                        CAN_PLAY = false;
                        showBoardWaitingOverlay("فُقد اتصالك بالمباراة. جارٍ إعادة الاتصال…");
                        return;
                    }
                    myStatusRef.onDisconnect().setValue("left").addOnSuccessListener(unused -> {
                        if (!EXITING && !boardDuelFinished && !duelActivityDestroyed)
                            markMyGameState(ACTIVITY_PAUSED ? "away" : "active");
                    });
                }
                @Override public void onCancelled(DatabaseError error) {}
            };
            duelConnectionRef.addValueEventListener(duelConnectionListener);
        }
        attachOpponentStatusListener();
    }

    private void attachOpponentStatusListener() {
        if (gameID == null || gameID.trim().isEmpty()) {
            return;
        }
        detachOpponentStatusListener();
        for (final MatchOpponent opponent : opponents) {
            if (opponent.bot || opponent.id == null || opponent.id.trim().isEmpty()) {
                continue;
            }
            opponent.statusRef = FirebaseDatabase.getInstance().getReference()
                    .child("Games")
                    .child(gameID)
                    .child(opponent.id)
                    .child("status");
            opponent.statusListener = new ValueEventListener() {
                @Override
                public void onDataChange(DataSnapshot snapshot) {
                    if (EXITING || duelActivityDestroyed || opponent.left || opponent.eliminated) {
                        return;
                    }
                    String status = snapshot.getValue(String.class);
                    if (boardOnline && !boardRoomMatch) {
                        // A disconnected seat stays human. The shared turn-scoped reducer
                        // grants two independent grace periods and verifies a real reconnect.
                        return;
                    }
                    if ("left".equals(status) || "left_timeout".equals(status)) {
                        convertOpponentToComputer(opponent);
                    } else if ("eliminated".equals(status)) {
                        opponent.eliminated = true;
                        opponentHudController.refreshOpponentPanels();
                    }
                }

                @Override
                public void onCancelled(DatabaseError error) {
                }
            };
            opponent.statusRef.addValueEventListener(opponent.statusListener);
        }
    }

    private void detachOpponentStatusListener() {
        for (MatchOpponent opponent : opponents) {
            if (opponent.statusRef != null && opponent.statusListener != null) {
                opponent.statusRef.removeEventListener(opponent.statusListener);
            }
            opponent.statusRef = null;
            opponent.statusListener = null;
        }
    }

    private void markMyGameState(String status) {
        if (paidDuel != null) return;
        if (!modeOnline || gameID == null || gameID.trim().isEmpty()) {
            return;
        }
        if (myStatusRef == null) {
            myStatusRef = FirebaseDatabase.getInstance().getReference()
                    .child("Games")
                    .child(gameID)
                    .child(myID)
                    .child("status");
        }
        myStatusRef.setValue(status);
        if ("active".equals(status) || "away".equals(status)) {
            try {
                myStatusRef.onDisconnect().setValue("left");
            } catch (Exception ignored) {
            }
        } else {
            try {
                myStatusRef.onDisconnect().cancel();
            } catch (Exception ignored) {
            }
        }
        if ("left".equals(status)
                || "left_timeout".equals(status)
                || "finished".equals(status)
                || "eliminated".equals(status)) {
            matchStateCommitted = true;
        }
    }

    private void leaveOnlineMatchIfNeeded() {
        if (isRecoverableBotBoard()) return;
        if (paidDuel != null) return; // Explicit exit goes through the stake callable.
        if (!modeOnline || matchStateCommitted) {
            return;
        }
        // A duel's immutable shared terminal result determines the penalty.
        // Keep its durable identity so exit/final-answer races cannot store a
        // premature loss or suppress the eventual disconnect loss on reconnect.
        if (!boardOnline || boardRoomMatch) PlayerStats.recordGameEnd(this, ProgressionRules.ABANDON, 0);
        markMyGameState("left");
        detachOpponentStatusListener();
        detachOpponentRoundListener();
        detachQuestionSyncListener();
    }

    private void attachServerTimeOffsetListener() {
        if (serverOffsetRef != null) {
            return;
        }
        serverOffsetRef = FirebaseDatabase.getInstance().getReference(".info/serverTimeOffset");
        serverOffsetListener = new ValueEventListener() {
            @Override
            public void onDataChange(DataSnapshot snapshot) {
                Long offset = snapshot.getValue(Long.class);
                serverTimeOffsetMs = offset == null ? 0L : offset;
                duelServerClockReady = offset != null;
            }

            @Override
            public void onCancelled(DatabaseError error) {
            }
        };
        serverOffsetRef.addValueEventListener(serverOffsetListener);
    }

    private void detachServerTimeOffsetListener() {
        if (serverOffsetRef != null && serverOffsetListener != null) {
            serverOffsetRef.removeEventListener(serverOffsetListener);
        }
        serverOffsetRef = null;
        serverOffsetListener = null;
    }

    private void handleOpponentLeftMatch() {
        if (opponentExitHandled || EXITING) {
            return;
        }
        opponentExitHandled = true;
        stopTimer(true);
        stopCurrentSound();
        detachOpponentStatusListener();
        showDialog("انسحب منافسك من المباراة.\nهل تريد أن تكمل مع الكمبيوتر؟", "OpponentLeftContinue", 1000, 0, R.drawable.mouth_05, false);
    }

    private void openOnlineResultScreen(boolean opponentLeft) {
        if (!EXITING && presenterDialogue.deferAll("onlineResult", () -> openOnlineResultScreen(opponentLeft))) return;
        if (!modeOnline) {
            return;
        }
        markMyGameState("finished");
        detachOpponentStatusListener();
        detachOpponentRoundListener();
        detachQuestionSyncListener();
        String leaderId = getMatchLeaderId();
        Intent intent = new Intent(GameActivity.this, ResultActivity.class);
        NativeProgression.copyToResult(this, intent);
        intent.putExtra("matchMode", progressionMode());
        intent.putExtra("roomId", roomId);
        intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TASK);
        intent.putExtra("myScore", gameScoreMe);
        intent.putExtra("myNewScore", myScore);
        intent.putExtra("opponentScore", getHighestOpponentScore());
        intent.putExtra("mySets", setMe);
        intent.putExtra("opponentSets", getLeaderSets());
        intent.putExtra("myName", myName);
        intent.putExtra("myPhoto", myPhoto);
        intent.putExtra("opponentName", opponentName);
        intent.putExtra("opponentPhoto", opponentPhoto);
        intent.putExtra("opponentLeft", opponentLeft);
        intent.putExtra("didWin", myID.equals(leaderId));
        intent.putExtra("winnerName", getPlayerDisplayName(leaderId));
        intent.putExtra("opponentsJson", buildOpponentsSummaryJson());
        boolean tied = !opponentLeft && !localPlayerEliminated && gameScoreMe == getHighestOpponentScore()
                && setMe == getLeaderSets();
        intent.putExtra("progressionDraw", tied);
        PlayerStats.recordGameEnd(this, tied ? ProgressionRules.DRAW
                : (myID.equals(leaderId) || opponentLeft) ? ProgressionRules.WIN : ProgressionRules.LOSS, gameScoreMe * 1000);
        PlayerProgress.onOnlineMatchFinished(this, myID.equals(leaderId) || opponentLeft, setMe,
                progressionMode(), true, progressionMatchId());
        startActivity(intent);
        finish();
    }

    private void continueMatchWithComputer() {
        detachOpponentStatusListener();
        detachOpponentRoundListener();
        cancelPendingFictitiousAnswer();
        opponentID = "fictitious";
        opponentName = "الكمبيوتر";
        opponentPhoto = "";
        opponentExitHandled = false;

        if (txtPlayer2 != null) {
            txtPlayer2.setText(opponentName);
        }

        Data.setImageSource(this, imgOpponent, opponentPhoto);
        Data.setImageSource(this, imgAnswer1Player2, opponentPhoto);
        Data.setImageSource(this, imgAnswer2Player2, opponentPhoto);
        Data.setImageSource(this, imgAnswer3Player2, opponentPhoto);
        Data.setImageSource(this, imgAnswer4Player2, opponentPhoto);

        if (currentQuestion >= 0) {
            Data.initQuestionPlayer(gameID, opponentID, currentQuestion);
            prepareOnlineQuestionSync(currentQuestion);
            scheduleFictitiousAnswerForCurrentQuestion();
        }

        GameNotice.makeText(this, "ستكمل المباراة الآن ضد الكمبيوتر", Toast.LENGTH_SHORT).show();
        CAN_HOME = true;
        if (myAnswer > 0) {
            CAN_PLAY = false;
        } else {
            CAN_PLAY = true;
            startTimer(false);
        }
    }

    private void scheduleFictitiousAnswerForCurrentQuestion() {
        cancelPendingFictitiousAnswer();
        if (!modeOnline || !"fictitious".equals(opponentID) || currentQuestion < 0 || currentQuestion >= questions.size()) {
            return;
        }
        if (opponentAnswer > 0) {
            return;
        }

        final int questionIndex = currentQuestion;
        int remainingMillis = Math.max(1000, ((PROGRESS_VALUE / 10) - 1) * 1000);
        int delayMillis = myAnswer > 0 ? 1200 : Math.min(remainingMillis, 3000);

        pendingFictitiousAnswerRunnable = new Runnable() {
            @Override
            public void run() {
                pendingFictitiousAnswerRunnable = null;
                if (EXITING || opponentExitHandled || !"fictitious".equals(opponentID)) {
                    return;
                }
                if (questionIndex != currentQuestion || opponentAnswerSubmitted || rightAnswer <= 0) {
                    return;
                }

                int randomAnswer = getFictitiousRandomAnswer();
                submitFictitiousRoundAnswer(randomAnswer);
            }
        };
        fictitiousAnswerHandler.postDelayed(pendingFictitiousAnswerRunnable, delayMillis);
    }

    private void submitFictitiousRoundAnswer(final int displayedAnswer) {
        if (!modeOnline || !"fictitious".equals(opponentID) || opponentAnswerSubmitted) {
            return;
        }
        final DatabaseReference fictitiousRef = getRoundSyncRef(currentQuestion);
        if (fictitiousRef == null) {
            return;
        }

        opponentAnswer = displayedAnswer;
        opponentSubmittedAnswerKey = getAnswerKeyForDisplayedIndex(displayedAnswer);
        opponentAnswerSubmitted = true;
        long elapsedMs = displayedAnswer <= 0 ? QUESTION_TIMEOUT_MS : getCurrentAnswerElapsedMs();
        HashMap<String, Object> payload = new HashMap<>();
        payload.put("players/" + opponentID + "/answerKey", opponentSubmittedAnswerKey);
        payload.put("players/" + opponentID + "/submitted", true);
        payload.put("players/" + opponentID + "/correct", opponentSubmittedAnswerKey == ANSWER_KEY_RIGHT);
        payload.put("players/" + opponentID + "/elapsedMs", elapsedMs);
        fictitiousRef.updateChildren(payload);
        if (myAnswerSubmitted) {
            resolveOnlineRoundIfReady();
        }
    }

    private void cancelPendingBotAnswers() {
        for (Runnable runnable : pendingBotAnswerRunnables.values()) {
            fictitiousAnswerHandler.removeCallbacks(runnable);
        }
        pendingBotAnswerRunnables.clear();
    }

    private void scheduleBotAnswersForCurrentQuestion() {
        cancelPendingBotAnswers();
        if (!modeOnline || currentQuestion < 0 || currentQuestion >= questions.size()) {
            return;
        }
        for (MatchOpponent opponent : opponents) {
            if (opponent.bot && !opponent.eliminated) {
                scheduleBotAnswer(opponent);
            }
        }
    }

    private void scheduleBotAnswer(final MatchOpponent opponent) {
        if (opponent == null || !opponent.bot || opponent.submitted || opponent.eliminated) {
            return;
        }
        final int questionIndex = currentQuestion;
        int remainingMillis = Math.max(1000, ((PROGRESS_VALUE / 10) - 1) * 1000);
        int delayMillis = myAnswer > 0 ? 1200 : Math.min(remainingMillis, getBotDelayMillis(opponent));

        Runnable runnable = new Runnable() {
            @Override
            public void run() {
                pendingBotAnswerRunnables.remove(opponent.id);
                if (EXITING || currentQuestion != questionIndex || rightAnswer <= 0 || opponent.submitted) {
                    return;
                }
                int randomAnswer = getBotDisplayedAnswer(opponent);
                submitBotRoundAnswer(opponent, randomAnswer);
            }
        };
        pendingBotAnswerRunnables.put(opponent.id, runnable);
        fictitiousAnswerHandler.postDelayed(runnable, delayMillis);
    }

    private void scheduleCampaignBossAnswer() {
        if (!campaignBossBattle || campaignBossOpponent == null
                || campaignBossOpponent.submitted || currentQuestion < 0
                || currentQuestion >= questions.size()) {
            return;
        }
        final MatchOpponent boss = campaignBossOpponent;
        final int questionIndex = currentQuestion;
        int remainingMillis = Math.max(1000, ((PROGRESS_VALUE / 10) - 1) * 1000);
        final int delayMillis = Math.min(remainingMillis, getBotDelayMillis(boss));

        Runnable runnable = new Runnable() {
            @Override
            public void run() {
                pendingBotAnswerRunnables.remove(boss.id);
                if (EXITING || !campaignBossBattle || currentQuestion != questionIndex
                        || rightAnswer <= 0 || boss.submitted) {
                    return;
                }
                submitCampaignBossAnswer(boss, getCampaignBossDisplayedAnswer(boss), delayMillis);
            }
        };
        pendingBotAnswerRunnables.put(boss.id, runnable);
        fictitiousAnswerHandler.postDelayed(runnable, delayMillis);
    }

    private void ensureCampaignBossAnswered() {
        if (!campaignBossBattle || campaignBossOpponent == null
                || campaignBossOpponent.submitted || rightAnswer <= 0) {
            return;
        }
        int elapsedMs = (int) Math.max(900L, Math.min(QUESTION_TIMEOUT_MS, getCurrentAnswerElapsedMs() + 450L));
        submitCampaignBossAnswer(
                campaignBossOpponent,
                getCampaignBossDisplayedAnswer(campaignBossOpponent),
                elapsedMs
        );
    }

    private void submitCampaignBossAnswer(MatchOpponent boss, int displayedAnswer, long elapsedMs) {
        if (boss == null || boss.submitted || displayedAnswer <= 0) {
            return;
        }
        boss.displayedAnswer = displayedAnswer;
        boss.submittedAnswerKey = getAnswerKeyForDisplayedIndex(displayedAnswer);
        boss.submitted = true;
        boss.answerElapsedMs = Math.max(1L, Math.min(QUESTION_TIMEOUT_MS, elapsedMs));
    }

    private int getCampaignBossDisplayedAnswer(MatchOpponent boss) {
        if (boss == null || rightAnswer <= 0) {
            return 0;
        }
        return new Random().nextDouble() < getCampaignBossAccuracy(boss)
                ? rightAnswer
                : getWrongAnswer(rightAnswer);
    }

    private void submitBotRoundAnswer(final MatchOpponent opponent, final int displayedAnswer) {
        if (!modeOnline || opponent == null || !opponent.bot || opponent.eliminated) {
            return;
        }
        // Always get a fresh ref for the current question — don't rely on the
        // shared roundSyncRef which may have been reassigned for a different
        // question by the time this callback fires.
        final int botQuestion = currentQuestion;
        final DatabaseReference botRef = getRoundSyncRef(botQuestion);
        if (botRef == null) {
            return;
        }

        opponent.displayedAnswer = displayedAnswer;
        opponent.submittedAnswerKey = getAnswerKeyForDisplayedIndex(displayedAnswer);
        opponent.submitted = true;
        opponent.answerElapsedMs = displayedAnswer <= 0 ? QUESTION_TIMEOUT_MS : getCurrentAnswerElapsedMs();

        HashMap<String, Object> payload = new HashMap<>();
        payload.put("players/" + opponent.id + "/answerKey", opponent.submittedAnswerKey);
        payload.put("players/" + opponent.id + "/submitted", true);
        payload.put("players/" + opponent.id + "/correct", opponent.submittedAnswerKey == ANSWER_KEY_RIGHT);
        payload.put("players/" + opponent.id + "/elapsedMs", opponent.answerElapsedMs);
        botRef.updateChildren(payload);
        if (myAnswerSubmitted && botQuestion == currentQuestion) {
            resolveOnlineRoundIfReady();
        }
    }

    private void convertOpponentToComputer(MatchOpponent opponent) {
        if (opponent == null) {
            return;
        }
        if (boardRoomMatch) {
            opponent.left = true;
            handleRoomBoardSeatLeft(opponent);
            return;
        }
        if (boardOnline) {
            handleBoardOpponentLeft();
            return;
        }
        opponent.left = true;
        applyBotIdentity(opponent, true);
        if (opponent.statusRef != null && opponent.statusListener != null) {
            opponent.statusRef.removeEventListener(opponent.statusListener);
        }
        opponent.statusRef = null;
        opponent.statusListener = null;
        opponentHudController.refreshOpponentPanels();
        if (currentQuestion >= 0 && !opponent.submitted) {
            scheduleBotAnswer(opponent);
        }
    }

    private int getHighestOpponentScore() {
        int bestScore = 0;
        for (MatchOpponent opponent : opponents) {
            bestScore = Math.max(bestScore, opponent.gameScore);
        }
        return bestScore;
    }

    private String buildOpponentsSummaryJson() {
        JSONArray array = new JSONArray();
        try {
            for (MatchOpponent opponent : opponents) {
                JSONObject object = new JSONObject();
                object.put("id", opponent.id);
                object.put("name", opponent.name);
                object.put("photo", opponent.photo);
                object.put("score", opponent.gameScore);
                object.put("sets", opponent.sets);
                object.put("bot", opponent.bot);
                object.put("left", opponent.left);
                object.put("intelligence", opponent.intelligence);
                array.put(object);
            }
        } catch (Exception ignored) {
        }
        return array.toString();
    }

    private boolean checkScoresMulti() {
        if ((currentQuestion != 4) && (currentQuestion != 9) && (currentQuestion != 14)) {
            return false;
        }

        String setWinnerId = getSetLeaderId();
        if (myID.equals(setWinnerId)) {
            setMe++;
        } else {
            MatchOpponent winner = findOpponentById(setWinnerId);
            if (winner != null) {
                winner.sets++;
            }
        }
        for (MatchOpponent opponent : opponents) {
            opponent.roundScore = 0;
            opponent.setCorrectAnswers = 0;
            opponent.setAnswerTimeMs = 0L;
        }
        setScoreMe = 0;
        mySetCorrectAnswers = 0;
        mySetAnswerTimeMs = 0L;
        txtSetsMe.setText(String.valueOf(setMe));
        txtScoreMe.setText("0");
        opponentHudController.refreshOpponentPanels();
        String setNumLabelResolved = (currentQuestion == 4 ? "الأولى" : (currentQuestion == 9 ? "الثانية" : "الثالثة"));
        if (myID.equals(setWinnerId)) {
            person.like(1000);
            person.raiseEyeBrowsUp(1000, false, true);
            showDialog("انتهت الجولة " + setNumLabelResolved + " وحسمتها لصالحك", "", 2000, 3000, R.drawable.mouth_01, false);
        } else {
            showDialog("انتهت الجولة " + setNumLabelResolved + " وفاز بها " + getPlayerDisplayName(setWinnerId), "", 2000, 3000, R.drawable.mouth_01, false);
        }
        return true;
        /*

        String setNumLabel = (currentQuestion == 4 ? "الأولى" : (currentQuestion == 9 ? "الثانية" : "الثالثة"));
        if (myID.equals(setWinnerId)) {
            person.like(1000);
            person.raiseEyeBrowsUp(1000, false, true);
            showDialog("انتهت الجولة " + setNumLabel + " وأنت المتصدر بـ " + setMe + " جولات", "", 2000, 3000, R.drawable.mouth_01, false);
        } else {
            showDialog("انتهت الجولة " + setNumLabel + " وأنت في الصدارة مع " + leadersCount + " لاعبين", "", 2000, 3000, R.drawable.mouth_01, false);
        } else {
            showDialog("انتهت الجولة " + setNumLabel + " وأنت خلف المتصدر بـ " + setMe + " جولات", "", 2000, 3000, R.drawable.mouth_01, false);
        }
        return true;
        */
    }

    private int checkEndOfGameMulti() {
        String leaderIdResolved = getMatchLeaderId();
        int setNumResolved = (currentQuestion == 4 ? 1 : (currentQuestion == 9 ? 2 : 3));
        int leaderSetsResolved = getSetsForPlayer(leaderIdResolved);

        // إنهاء مبكر: بعد الجولة الثانية فقط إذا فاز أحد بجولتين (لا يمكن اللحاق به)
        boolean earlyEnd = (setNumResolved == 2 && leaderSetsResolved >= 2);
        if (currentQuestion != 14 && !earlyEnd) {
            return -2;
        }

        // تعادل في الجولات بعد الجولة الثالثة (مثلاً 1-1-1) → الفاصل النقاط الكلية
        boolean tiedOnSets = (currentQuestion == 14 && leaderSetsResolved == 1);

        int resolvedResult;
        if (myID.equals(leaderIdResolved)) {
            resolvedResult = 1;
            person.moveShow2Hands(2000);
            person.raiseEyeBrowsUp(1000, false, true);
            if (earlyEnd) {
                showDialog("مبروك! فزت بجولتين وحسمت المباراة مبكراً", "", 2000, 3000, R.drawable.mouth_01, false);
            } else if (tiedOnSets) {
                showDialog("تعادلنا في الجولات.. لكن نقاطك الأعلى تجعلك الفائز! مبروك", "", 2000, 3000, R.drawable.mouth_01, false);
            } else {
                showDialog("مبروك انتهت المباراة وأنت الفائز", "", 2000, 3000, R.drawable.mouth_01, false);
            }
        } else {
            resolvedResult = -1;
            if (earlyEnd) {
                showDialog("انتهت المباراة مبكراً. " + getPlayerDisplayName(leaderIdResolved) + " فاز بجولتين متتاليتين", "", 2000, 3000, R.drawable.mouth_01, false);
            } else if (tiedOnSets) {
                showDialog("تعادلنا في الجولات! الفائز بأعلى نقاط: " + getPlayerDisplayName(leaderIdResolved), "", 2000, 3000, R.drawable.mouth_01, false);
            } else {
                showDialog("انتهت المباراة. الفائز هو " + getPlayerDisplayName(leaderIdResolved), "", 2000, 3000, R.drawable.mouth_01, false);
            }
        }
        updateScoreAndLevel();
        return resolvedResult;
        /*
        int setNum = (currentQuestion == 4 ? 1 : (currentQuestion == 9 ? 2 : 3));
        int leaderSets = getLeaderSets();
        int leadersCount = getLeadersCount(leaderSets);
        if ((currentQuestion != 14) && ((3 - setNum) >= Math.max(0, leaderSets - setMe))) {
            return -2;
        }

        int res;
        if (setMe == leaderSets && leadersCount == 1) {
            res = 1;
            person.moveShow2Hands(2000);
            person.raiseEyeBrowsUp(1000, false, true);
            showDialog("مبروك انتهت المباراة وأنت الفائز بـ " + setMe + " جولات", "", 2000, 3000, R.drawable.mouth_01, false);
        } else if (setMe == leaderSets) {
            res = 0;
            showDialog("انتهت المباراة بتعادلك في الصدارة مع " + leadersCount + " لاعبين", "", 2000, 3000, R.drawable.mouth_01, false);
        } else {
            res = -1;
            showDialog("للأسف انتهت المباراة وأنت خلف المتصدر بـ " + setMe + " جولات", "", 2000, 3000, R.drawable.mouth_01, false);
        }
        updateScoreAndLevel();
        return res;
        */
    }

    private int getLeaderSets() {
        return getSetsForPlayer(getMatchLeaderId());
    }

    private int getLeadersCount(int leaderSets) {
        return 1;
    }

    private String getSetLeaderId() {
        String leaderId = myID;
        for (MatchOpponent opponent : opponents) {
            if (compareSetStanding(opponent.id, leaderId) < 0) {
                leaderId = opponent.id;
            }
        }
        return leaderId;
    }

    private String getMatchLeaderId() {
        String leaderId = myID;
        for (MatchOpponent opponent : opponents) {
            if (compareMatchStanding(opponent.id, leaderId) < 0) {
                leaderId = opponent.id;
            }
        }
        return leaderId;
    }

    private int compareSetStanding(String leftPlayerId, String rightPlayerId) {
        int scoreCompare = Integer.compare(getSetScoreForPlayer(rightPlayerId), getSetScoreForPlayer(leftPlayerId));
        if (scoreCompare != 0) {
            return scoreCompare;
        }
        int correctCompare = Integer.compare(getSetCorrectAnswersForPlayer(rightPlayerId), getSetCorrectAnswersForPlayer(leftPlayerId));
        if (correctCompare != 0) {
            return correctCompare;
        }
        int timeCompare = Long.compare(getSetAnswerTimeForPlayer(leftPlayerId), getSetAnswerTimeForPlayer(rightPlayerId));
        if (timeCompare != 0) {
            return timeCompare;
        }
        return Integer.compare(stableHash(leftPlayerId), stableHash(rightPlayerId));
    }

    private int compareMatchStanding(String leftPlayerId, String rightPlayerId) {
        int setsCompare = Integer.compare(getSetsForPlayer(rightPlayerId), getSetsForPlayer(leftPlayerId));
        if (setsCompare != 0) {
            return setsCompare;
        }
        int scoreCompare = Integer.compare(getGameScoreForPlayer(rightPlayerId), getGameScoreForPlayer(leftPlayerId));
        if (scoreCompare != 0) {
            return scoreCompare;
        }
        int correctCompare = Integer.compare(getTotalCorrectAnswersForPlayer(rightPlayerId), getTotalCorrectAnswersForPlayer(leftPlayerId));
        if (correctCompare != 0) {
            return correctCompare;
        }
        int timeCompare = Long.compare(getTotalAnswerTimeForPlayer(leftPlayerId), getTotalAnswerTimeForPlayer(rightPlayerId));
        if (timeCompare != 0) {
            return timeCompare;
        }
        return Integer.compare(stableHash(leftPlayerId), stableHash(rightPlayerId));
    }

    private int getSetsForPlayer(String playerId) {
        if (myID.equals(playerId)) {
            return setMe;
        }
        MatchOpponent opponent = findOpponentById(playerId);
        return opponent == null ? 0 : opponent.sets;
    }

    private int getSetScoreForPlayer(String playerId) {
        if (myID.equals(playerId)) {
            return setScoreMe;
        }
        MatchOpponent opponent = findOpponentById(playerId);
        return opponent == null ? 0 : opponent.roundScore;
    }

    private int getGameScoreForPlayer(String playerId) {
        if (myID.equals(playerId)) {
            return gameScoreMe;
        }
        MatchOpponent opponent = findOpponentById(playerId);
        return opponent == null ? 0 : opponent.gameScore;
    }

    private int getSetCorrectAnswersForPlayer(String playerId) {
        if (myID.equals(playerId)) {
            return mySetCorrectAnswers;
        }
        MatchOpponent opponent = findOpponentById(playerId);
        return opponent == null ? 0 : opponent.setCorrectAnswers;
    }

    private int getTotalCorrectAnswersForPlayer(String playerId) {
        if (myID.equals(playerId)) {
            return myTotalCorrectAnswers;
        }
        MatchOpponent opponent = findOpponentById(playerId);
        return opponent == null ? 0 : opponent.totalCorrectAnswers;
    }

    private long getSetAnswerTimeForPlayer(String playerId) {
        if (myID.equals(playerId)) {
            return mySetAnswerTimeMs;
        }
        MatchOpponent opponent = findOpponentById(playerId);
        return opponent == null ? Long.MAX_VALUE : opponent.setAnswerTimeMs;
    }

    private long getTotalAnswerTimeForPlayer(String playerId) {
        if (myID.equals(playerId)) {
            return myTotalAnswerTimeMs;
        }
        MatchOpponent opponent = findOpponentById(playerId);
        return opponent == null ? Long.MAX_VALUE : opponent.totalAnswerTimeMs;
    }

    private String getPlayerDisplayName(String playerId) {
        if (myID.equals(playerId)) {
            return "أنت";
        }
        MatchOpponent opponent = findOpponentById(playerId);
        return opponent == null ? "Player" : opponent.name;
    }

    private void cancelPendingFictitiousAnswer() {
        cancelPendingBotAnswers();
        if (pendingFictitiousAnswerRunnable != null) {
            fictitiousAnswerHandler.removeCallbacks(pendingFictitiousAnswerRunnable);
            pendingFictitiousAnswerRunnable = null;
        }
    }

    private String getRoundKey(int questionIndex) {
        return "q" + questionIndex;
    }

    private DatabaseReference getQuestionSyncRef(int questionIndex) {
        if (gameID == null || gameID.trim().isEmpty()) {
            return null;
        }
        return FirebaseDatabase.getInstance().getReference()
                .child("Games")
                .child(gameID)
                .child("questionSync")
                .child(getRoundKey(questionIndex));
    }

    private DatabaseReference getRoundSyncRef(int questionIndex) {
        if (gameID == null || gameID.trim().isEmpty()) {
            return null;
        }
        return FirebaseDatabase.getInstance().getReference()
                .child("Games")
                .child(gameID)
                .child("rounds")
                .child(getRoundKey(questionIndex));
    }

    private void prepareOnlineQuestionSync(int questionIndex) {
        if (!modeOnline) {
            return;
        }
        roundSyncRef = getRoundSyncRef(questionIndex);
        if (roundSyncRef == null) {
            return;
        }
        // IMPORTANT: only write OWN data — writing opponent's data causes a race
        // condition where a late reset can overwrite an already-submitted opponent
        // answer, causing the game to freeze waiting for a re-submission that
        // will never come.
        HashMap<String, Object> payload = new HashMap<>();
        payload.put("players/" + myID + "/answerKey", 0);
        payload.put("players/" + myID + "/submitted", false);
        payload.put("players/" + myID + "/correct", false);
        payload.put("players/" + myID + "/elapsedMs", QUESTION_TIMEOUT_MS);
        roundSyncRef.updateChildren(payload);
    }

    private void requestSynchronizedQuestion(final int questionIndex) {
        if (!modeOnline) {
            showQuestionNow(questionIndex);
            return;
        }
        if (questionIndex < 0 || questionIndex >= questions.size()) {
            return;
        }
        pendingQuestionIndex = questionIndex;
        scheduledQuestionStartAt = 0L;
        attachQuestionSyncListener(questionIndex);
        ensureQuestionStartScheduled(questionIndex);
    }

    private void attachQuestionSyncListener(final int questionIndex) {
        detachQuestionSyncListener();
        questionSyncRef = getQuestionSyncRef(questionIndex);
        if (questionSyncRef == null) {
            return;
        }

        questionSyncListener = new ValueEventListener() {
            @Override
            public void onDataChange(DataSnapshot snapshot) {
                if (EXITING || pendingQuestionIndex != questionIndex) {
                    return;
                }
                Long startAt = snapshot.child("startAt").getValue(Long.class);
                if (startAt == null || startAt <= 0L) {
                    ensureQuestionStartScheduled(questionIndex);
                    return;
                }
                scheduleQuestionDisplay(questionIndex, startAt);
            }

            @Override
            public void onCancelled(DatabaseError error) {
            }
        };
        questionSyncRef.addValueEventListener(questionSyncListener);
    }

    private void detachQuestionSyncListener() {
        cancelPendingQuestionStart();
        if (questionSyncRef != null && questionSyncListener != null) {
            questionSyncRef.removeEventListener(questionSyncListener);
        }
        questionSyncRef = null;
        questionSyncListener = null;
    }

    private void cancelPendingQuestionStart() {
        if (pendingQuestionStartRunnable != null) {
            questionSyncHandler.removeCallbacks(pendingQuestionStartRunnable);
            pendingQuestionStartRunnable = null;
        }
    }

    private void ensureQuestionStartScheduled(final int questionIndex) {
        if (questionSyncRef == null) {
            questionSyncRef = getQuestionSyncRef(questionIndex);
        }
        if (questionSyncRef == null) {
            return;
        }

        final long candidateStartAt = getServerNowMs() + (questionIndex == 0
                ? FIRST_QUESTION_SYNC_BUFFER_MS
                : NEXT_QUESTION_SYNC_BUFFER_MS);

        questionSyncRef.runTransaction(new Transaction.Handler() {
            @NonNull
            @Override
            public Transaction.Result doTransaction(@NonNull MutableData currentData) {
                Long existingStartAt = currentData.child("startAt").getValue(Long.class);
                Long existingQuestionIndex = currentData.child("questionIndex").getValue(Long.class);
                if (existingStartAt == null
                        || existingStartAt <= 0L
                        || existingQuestionIndex == null
                        || existingQuestionIndex.intValue() != questionIndex) {
                    currentData.child("questionIndex").setValue(questionIndex);
                    currentData.child("startAt").setValue(candidateStartAt);
                }
                return Transaction.success(currentData);
            }

            @Override
            public void onComplete(@Nullable DatabaseError error, boolean committed, @Nullable DataSnapshot currentData) {
                if (error != null || !committed || currentData == null) {
                    return;
                }
                Long startAt = currentData.child("startAt").getValue(Long.class);
                if (startAt != null) {
                    scheduleQuestionDisplay(questionIndex, startAt);
                }
            }
        });
    }

    private void scheduleQuestionDisplay(final int questionIndex, long startAt) {
        if (currentQuestion >= questionIndex || scheduledQuestionStartAt == startAt) {
            return;
        }
        scheduledQuestionStartAt = startAt;
        cancelPendingQuestionStart();
        final long delay = Math.max(0L, startAt - getServerNowMs());
        pendingQuestionStartRunnable = new Runnable() {
            @Override
            public void run() {
                pendingQuestionStartRunnable = null;
                if (EXITING || currentQuestion >= questionIndex || pendingQuestionIndex != questionIndex) {
                    return;
                }
                detachQuestionSyncListener();
                showQuestionNow(questionIndex);
            }
        };
        questionSyncHandler.postDelayed(pendingQuestionStartRunnable, delay);
    }

    private void attachOpponentRoundListener(final int questionIndex) {
        if (!modeOnline) {
            return;
        }
        detachOpponentRoundListener();
        roundSyncRef = getRoundSyncRef(questionIndex);
        if (roundSyncRef == null) {
            return;
        }

        roundSyncListener = new ValueEventListener() {
            @Override
            public void onDataChange(DataSnapshot snapshot) {
                if (EXITING || questionIndex != currentQuestion) {
                    return;
                }
                for (MatchOpponent opponent : opponents) {
                    DataSnapshot opponentSnapshot = snapshot.child("players").child(opponent.id);
                    Long answerValue = opponentSnapshot.child("answerKey").getValue(Long.class);
                    Long elapsedValue = opponentSnapshot.child("elapsedMs").getValue(Long.class);
                    Boolean submittedValue = opponentSnapshot.child("submitted").getValue(Boolean.class);
                    opponent.submittedAnswerKey = answerValue == null ? 0 : answerValue.intValue();
                    opponent.submitted = submittedValue != null && submittedValue;
                    opponent.displayedAnswer = getDisplayedIndexForAnswerKey(opponent.submittedAnswerKey);
                    opponent.answerElapsedMs = elapsedValue == null ? QUESTION_TIMEOUT_MS : elapsedValue;
                }

                if (resolvingRound) {
                    resolveOnlineRoundIfReady();
                }
            }

            @Override
            public void onCancelled(DatabaseError error) {
            }
        };
        roundSyncRef.addValueEventListener(roundSyncListener);
    }

    private void detachOpponentRoundListener() {
        if (roundSyncRef != null && roundSyncListener != null) {
            roundSyncRef.removeEventListener(roundSyncListener);
        }
        roundSyncListener = null;
    }

    private void submitOnlineAnswer(final int answerKey) {
        if (!modeOnline || gameID == null || gameID.trim().isEmpty()) {
            return;
        }
        roundSyncRef = getRoundSyncRef(currentQuestion);
        if (roundSyncRef == null) {
            return;
        }

        mySubmittedAnswerKey = answerKey;
        myAnswerSubmitted = true;
        resolvingRound = true;
        myAnswerElapsedMs = answerKey == 0 ? QUESTION_TIMEOUT_MS : getCurrentAnswerElapsedMs();

        HashMap<String, Object> payload = new HashMap<>();
        payload.put("players/" + myID + "/answerKey", answerKey);
        payload.put("players/" + myID + "/submitted", true);
        payload.put("players/" + myID + "/correct", answerKey == ANSWER_KEY_RIGHT);
        payload.put("players/" + myID + "/elapsedMs", myAnswerElapsedMs);
        roundSyncRef.updateChildren(payload, (error, ref) -> {
            if (error != null || EXITING) {
                return;
            }
            if (resolvingRound) {
                resolveOnlineRoundIfReady();
            }
        });
    }

    private void resolveOnlineRoundIfReady() {
        if (!modeOnline || roundResolved || resolvingFinal || !resolvingRound || !myAnswerSubmitted || !allOpponentsSubmitted()) {
            return;
        }
        if (roundSyncRef == null) {
            roundSyncRef = getRoundSyncRef(currentQuestion);
        }
        if (roundSyncRef == null) {
            return;
        }
        resolvingFinal = true;  // prevent duplicate Firebase reads

        roundSyncRef.addListenerForSingleValueEvent(new ValueEventListener() {
            @Override
            public void onDataChange(DataSnapshot snapshot) {
                if (EXITING || roundResolved) {
                    resolvingFinal = false;
                    return;
                }
                DataSnapshot mySnapshot = snapshot.child("players").child(myID);
                Long myAnswerKeyValue = mySnapshot.child("answerKey").getValue(Long.class);
                Long myElapsedValue = mySnapshot.child("elapsedMs").getValue(Long.class);
                mySubmittedAnswerKey = myAnswerKeyValue == null ? 0 : myAnswerKeyValue.intValue();
                myAnswerElapsedMs = myElapsedValue == null ? QUESTION_TIMEOUT_MS : myElapsedValue;

                ArrayList<RoundRankEntry> rankedCorrectAnswers = new ArrayList<>();
                if (mySubmittedAnswerKey == ANSWER_KEY_RIGHT) {
                    rankedCorrectAnswers.add(new RoundRankEntry(myID, myAnswerElapsedMs));
                }
                for (MatchOpponent opponent : opponents) {
                    DataSnapshot opponentSnapshot = snapshot.child("players").child(opponent.id);
                    Long answerValue = opponentSnapshot.child("answerKey").getValue(Long.class);
                    Long elapsedValue = opponentSnapshot.child("elapsedMs").getValue(Long.class);
                    opponent.submittedAnswerKey = answerValue == null ? 0 : answerValue.intValue();
                    opponent.answerElapsedMs = elapsedValue == null ? QUESTION_TIMEOUT_MS : elapsedValue;
                    opponent.displayedAnswer = getDisplayedIndexForAnswerKey(opponent.submittedAnswerKey);
                    if (opponent.submittedAnswerKey == ANSWER_KEY_RIGHT) {
                        rankedCorrectAnswers.add(new RoundRankEntry(opponent.id, opponent.answerElapsedMs));
                    }
                }

                Collections.sort(rankedCorrectAnswers, new Comparator<RoundRankEntry>() {
                    @Override
                    public int compare(RoundRankEntry left, RoundRankEntry right) {
                        int byElapsed = Long.compare(left.elapsedMs, right.elapsedMs);
                        if (byElapsed != 0) {
                            return byElapsed;
                        }
                        return Integer.compare(
                                getQuestionTieBreaker(left.playerId, currentQuestion),
                                getQuestionTieBreaker(right.playerId, currentQuestion)
                        );
                    }
                });

                myRoundPoints = getSpeedPoints(myID, rankedCorrectAnswers);
                for (MatchOpponent opponent : opponents) {
                    opponent.roundPoints = getSpeedPoints(opponent.id, rankedCorrectAnswers);
                }
                roundResolved = true;
                resolvingRound = false;
                resolvingFinal = false;

                for (MatchOpponent opponent : opponents) {
                    if (opponent.displayedAnswer > 0) {
                        showThumbPlayerAnswer(opponent, opponent.displayedAnswer);
                    }
                }
                checkAnswer(myAnswer <= 0);
            }

            @Override
            public void onCancelled(DatabaseError error) {
                resolvingFinal = false;  // allow retry on network error
            }
        });
    }

    private int getSpeedPoints(String playerId, ArrayList<RoundRankEntry> rankedCorrectAnswers) {
        if (playerId == null || playerId.trim().isEmpty()) return 0;
        for (int i = 0; i < rankedCorrectAnswers.size(); i++) {
            if (playerId.equals(rankedCorrectAnswers.get(i).playerId)) {
                // 1st=10, 2nd=7, 3rd=5, 4th-10th=3
                return i < ONLINE_SPEED_POINTS.length ? ONLINE_SPEED_POINTS[i] : 3;
            }
        }
        return 0;
    }

    private long getCurrentAnswerElapsedMs() {
        if (questionStartTimeMs > 0L) {
            long elapsedMs = System.currentTimeMillis() - questionStartTimeMs;
            if (elapsedMs <= 0L) {
                return 1L;
            }
            return Math.min(QUESTION_TIMEOUT_MS, elapsedMs);
        }
        // Fallback: use progress counter (100ms resolution)
        long elapsedMs = (300L - Math.max(0, PROGRESS_VALUE)) * 100L;
        if (elapsedMs <= 0L) {
            return 1L;
        }
        return Math.min(QUESTION_TIMEOUT_MS, elapsedMs);
    }

    private int getQuestionTieBreaker(String playerId, int questionIndex) {
        return Math.abs(stableHash((gameID == null ? "" : gameID) + "|" + questionIndex + "|" + playerId));
    }

    private int stableHash(String value) {
        if (value == null) {
            return 0;
        }
        int hash = 5381;
        for (int i = 0; i < value.length(); i++) {
            hash = ((hash << 5) + hash) ^ value.charAt(i);
        }
        return hash & 0x7fffffff;
    }

    private long getServerNowMs() {
        return System.currentTimeMillis() + serverTimeOffsetMs;
    }

    String safeString(Object value) {
        return value == null ? "" : String.valueOf(value);
    }

    String safeIntentString(String key, String fallback) {
        String value = getIntent().getStringExtra(key);
        if (value == null || value.trim().isEmpty()) {
            return fallback;
        }
        return value.trim();
    }

    private int getCampaignStageOrder() {
        if (campaignStageId != null) {
            String digits = campaignStageId.replaceAll("[^0-9]", "");
            if (!digits.isEmpty()) {
                try {
                    return Math.max(1, Integer.parseInt(digits));
                } catch (Exception ignored) {
                }
            }
        }
        return 1;
    }

    private int resolveCampaignBossIntelligence() {
        int order = getCampaignStageOrder();
        int defaultValue = order >= 30 ? 85 : (order >= 20 ? 75 : 65);
        int requested = campaignBossBotIntelligence > 0 ? campaignBossBotIntelligence : defaultValue;
        int maxValue = order >= 30 ? 88 : (order >= 20 ? 78 : 68);
        int minValue = order >= 30 ? 82 : (order >= 20 ? 72 : 60);
        return Math.max(minValue, Math.min(maxValue, requested));
    }

    private double getCampaignBossAccuracy(MatchOpponent boss) {
        int order = getCampaignStageOrder();
        double maxAccuracy = order >= 30 ? 0.88d : (order >= 20 ? 0.78d : 0.68d);
        double minAccuracy = order >= 30 ? 0.82d : (order >= 20 ? 0.72d : 0.60d);
        double baseAccuracy = Math.max(0.0d, Math.min(1.0d, boss.intelligence / 100.0d));
        double variation = (new Random().nextInt(7) - 3) / 100.0d;
        return Math.max(minAccuracy, Math.min(maxAccuracy, baseAccuracy + variation));
    }

    String normalizeCampaignMode(String mode) {
        String normalized = mode == null ? "" : mode.trim().replace("_", "").replace("-", "").toLowerCase(Locale.US);
        if ("speed".equals(normalized) || "blitz".equals(normalized)) return "blitz";
        if ("elimination".equals(normalized)) return "elimination";
        if ("survival".equals(normalized)) return "survival";
        if ("nolifeline".equals(normalized)) return "noLifeline";
        if ("battle".equals(normalized)) return "battle";
        if ("rival".equals(normalized)) return "rival";
        if ("series".equals(normalized)) return "series";
        if ("teambattle".equals(normalized)) return "teamBattle";
        if ("boss".equals(normalized) || "bossbattle".equals(normalized)) return "bossBattle";
        return "classic";
    }

    String defaultCampaignWinCondition(String mode) {
        String normalized = normalizeCampaignMode(mode);
        if ("blitz".equals(normalized)) return "finishBeforeTime";
        if ("elimination".equals(normalized)) return "noMistakes";
        if ("survival".equals(normalized)) return "survive";
        if ("battle".equals(normalized)) return "beatOpponent";
        if ("rival".equals(normalized)) return "beatTargetScore";
        if ("series".equals(normalized)) return "winSeries";
        if ("teamBattle".equals(normalized)) return "teamScore";
        if ("bossBattle".equals(normalized)) return "defeatBoss";
        return "completeQuestions";
    }

    private boolean isCampaignBlitzMode() { return "blitz".equals(campaignStageMode); }
    private boolean isCampaignEliminationMode() { return "elimination".equals(campaignStageMode); }
    private boolean isCampaignSurvivalMode() { return "survival".equals(campaignStageMode); }
    private boolean isCampaignNoLifelineMode() { return "noLifeline".equals(campaignStageMode); }
    private boolean isCampaignBattleMode() { return "battle".equals(campaignStageMode); }
    private boolean isCampaignRivalMode() { return "rival".equals(campaignStageMode); }
    private boolean isCampaignSeriesMode() { return "series".equals(campaignStageMode); }
    private boolean isCampaignTeamBattleMode() { return "teamBattle".equals(campaignStageMode); }
    boolean isCampaignBossMode() { return "bossBattle".equals(campaignStageMode) || "boss".equals(campaignStageType); }

    private boolean isCampaignCompetitiveSimulationMode() {
        return isCampaignBattleMode() || isCampaignSeriesMode() || isCampaignTeamBattleMode();
    }

    private int clampInt(int value, int min, int max) {
        return Math.max(min, Math.min(max, value));
    }

    void applyCampaignStageTypeDefaults() {
        if (!campaignMode) {
            return;
        }
        campaignStageType = campaignStageType == null ? "classic" : campaignStageType.trim().toLowerCase(Locale.US);
        campaignStageMode = normalizeCampaignMode(campaignStageMode);
        campaignWinCondition = campaignWinCondition == null || campaignWinCondition.trim().isEmpty()
                ? defaultCampaignWinCondition(campaignStageMode)
                : campaignWinCondition.trim();
        if ("nolifeline".equals(campaignStageType) || "no_lifeline".equals(campaignStageType)) {
            campaignAllow5050 = false;
            campaignAllowAudience = false;
            campaignAllowCall = false;
            campaignStageType = "noLifeline";
        }
        if (isCampaignNoLifelineMode()) {
            campaignAllow5050 = false;
            campaignAllowAudience = false;
            campaignAllowCall = false;
        }
        if (isCampaignSurvivalMode()) {
            campaignLives = campaignLives > 0 ? campaignLives : 3;
            campaignLivesRemaining = campaignLives;
        }
        if (isCampaignEliminationMode()) {
            campaignMaxWrongAnswers = campaignMaxWrongAnswers > 0 ? campaignMaxWrongAnswers : 1;
        }
        if (isCampaignRivalMode()) {
            campaignTargetScore = campaignTargetScore > 0 ? campaignTargetScore : 700;
        }
        if (isCampaignBattleMode() || isCampaignSeriesMode() || isCampaignTeamBattleMode()) {
            campaignOpponentAccuracy = clampInt(campaignOpponentAccuracy > 0 ? campaignOpponentAccuracy : 60, 35, 85);
            campaignOpponentScore = Math.max(0, campaignOpponentStartScore);
            if (campaignOpponentName == null || campaignOpponentName.trim().isEmpty()) {
                campaignOpponentName = isCampaignTeamBattleMode() ? "فريق التحدي" : "خصم آلي";
            }
        }
        if (isCampaignSeriesMode()) {
            campaignSeriesRounds = campaignSeriesRounds > 0 ? campaignSeriesRounds : 3;
            campaignSeriesWinsRequired = campaignSeriesWinsRequired > 0 ? campaignSeriesWinsRequired : 2;
        }
        if (isCampaignTeamBattleMode()) {
            if (campaignTeamAllyName == null || campaignTeamAllyName.trim().isEmpty()) {
                campaignTeamAllyName = "زميلك";
            }
            if (campaignTeamEnemyName == null || campaignTeamEnemyName.trim().isEmpty()) {
                campaignTeamEnemyName = "الفريق المنافس";
            }
        }
        if (isCampaignBossMode()) {
            if (campaignBossBotIntelligence <= 0 && campaignOpponentAccuracy > 0) {
                campaignBossBotIntelligence = campaignOpponentAccuracy;
            }
            campaignBossBotIntelligence = resolveCampaignBossIntelligence();
        }
    }

    private void applyCampaignLifelineRestrictions() {
        if (!campaignMode) {
            return;
        }
        applyCampaignLifelineVisual(imgHelp5050, campaignAllow5050);
        applyCampaignLifelineVisual(imgHelpAudience, campaignAllowAudience);
        applyCampaignLifelineVisual(imgHelpCall, campaignAllowCall);
    }

    private void applyCampaignLifelineVisual(ImageView view, boolean allowed) {
        if (view == null || allowed) {
            return;
        }
        view.setTag("0");
        GameLifelineController.setGreyscale(view);
        view.setImageAlpha(120);
    }

    private boolean isCampaignLifelineAllowed(String type) {
        if (!campaignMode) {
            return true;
        }
        if ("5050".equals(type)) {
            return campaignAllow5050;
        }
        if ("audience".equals(type)) {
            return campaignAllowAudience;
        }
        if ("call".equals(type)) {
            return campaignAllowCall;
        }
        return true;
    }

    private void showCampaignLifelineUnavailable() {
        GameNotice.makeText(this, "هذه المساعدة غير متاحة في هذه المرحلة", Toast.LENGTH_SHORT).show();
    }

    private void recordCampaignLifelineUse(String type) {
        if (!campaignMode) {
            return;
        }
        if ("5050".equals(type)) {
            campaignUsed5050++;
        } else if ("audience".equals(type)) {
            campaignUsedAudience++;
        } else if ("call".equals(type)) {
            campaignUsedCall++;
        }
    }

    private void recordCampaignCorrectAnswer() {
        if (!campaignMode || campaignLastCorrectQuestion == currentQuestion) {
            return;
        }
        campaignLastCorrectQuestion = currentQuestion;
        campaignCorrectAnswers++;
        campaignAnsweredQuestions++;
    }

    private void recordCampaignWrongAnswer() {
        if (!campaignMode || campaignLastWrongQuestion == currentQuestion) {
            return;
        }
        campaignLastWrongQuestion = currentQuestion;
        campaignWrongAnswers++;
        campaignAnsweredQuestions++;
    }

    private void applyCampaignModeAfterAnswer(boolean correct) {
        if (!campaignMode) {
            return;
        }
        if (!correct && isCampaignSurvivalMode()) {
            campaignLivesRemaining = Math.max(0, campaignLivesRemaining - 1);
        }
        if (isCampaignCompetitiveSimulationMode()) {
            simulateCampaignOpponentAnswer();
        }
        if (isCampaignTeamBattleMode()) {
            simulateCampaignTeamRound();
        }
    }

    private void simulateCampaignOpponentAnswer() {
        int accuracy = clampInt(campaignOpponentAccuracy > 0 ? campaignOpponentAccuracy : 60, 35, 85);
        boolean opponentCorrect = new Random().nextInt(100) < accuracy;
        if (opponentCorrect) {
            campaignOpponentCorrectAnswers++;
            campaignOpponentScore += 100;
        } else {
            campaignOpponentWrongAnswers++;
        }
    }

    private void simulateCampaignTeamRound() {
        int allyAccuracy = clampInt(campaignOpponentAccuracy - 6, 45, 78);
        int enemyAccuracy = clampInt(campaignOpponentAccuracy, 45, 85);
        if (new Random().nextInt(100) < allyAccuracy) {
            campaignAllyScore += 100;
        }
        int enemyCorrectThisQuestion = 0;
        if (new Random().nextInt(100) < enemyAccuracy) enemyCorrectThisQuestion++;
        if (new Random().nextInt(100) < Math.max(40, enemyAccuracy - 7)) enemyCorrectThisQuestion++;
        campaignEnemyTeamScore += enemyCorrectThisQuestion * 100;
        campaignTeamScore = getCampaignPlayerScore() + campaignAllyScore;
    }

    int getCampaignPlayerScore() {
        if (boardCampaignMatch) {
            return Math.max(0, offlineContestants.scoreForSlot(0));
        }
        if (campaignBossBattle) {
            return Math.max(0, gameScoreMe);
        }
        return Math.max(0, campaignCorrectAnswers * 100);
    }

    private boolean campaignPlayerBeatsOpponent(int playerScore, int opponentScoreValue, int opponentCorrect) {
        if (playerScore != opponentScoreValue) {
            return playerScore > opponentScoreValue;
        }
        return campaignCorrectAnswers > opponentCorrect;
    }

    private boolean shouldFailCampaignAfterCurrentAnswer() {
        if (!campaignMode) {
            return false;
        }
        if (isCampaignEliminationMode() && campaignWrongAnswers >= Math.max(1, campaignMaxWrongAnswers)) {
            campaignFailureReason = "eliminated";
            return true;
        }
        if (isCampaignSurvivalMode() && campaignLivesRemaining <= 0) {
            campaignFailureReason = "outOfLives";
            return true;
        }
        return false;
    }

    private void failCampaignStage(String reason, int delayMs) {
        if (!campaignMode || campaignResultPersisted) {
            return;
        }
        campaignFailureReason = reason == null ? "" : reason;
        persistPendingCampaignStageResult(false, 0, campaignWrongAnswers);
        new Handler().postDelayed(new Runnable() {
            @Override
            public void run() {
                if (!isFinishing()) {
                    finishCampaignAndReturnToFlutter();
                }
            }
        }, Math.max(0, delayMs));
    }

    private boolean shouldCompleteCampaignAfterCurrentQuestion() {
        return campaignMode
                && campaignQuestionCount > 0
                && campaignAnsweredQuestions >= getCampaignTargetQuestionCount();
    }

    private void applyCampaignBossRoundMetrics(boolean playerCorrect) {
        if (!campaignBossBattle || campaignBossOpponent == null) {
            return;
        }
        MatchOpponent boss = campaignBossOpponent;
        boolean bossCorrect = boss.submittedAnswerKey == ANSWER_KEY_RIGHT;
        if (playerCorrect) {
            mySetCorrectAnswers++;
            myTotalCorrectAnswers++;
            setScoreMe += 100;
            gameScoreMe += 100;
        }
        if (bossCorrect) {
            boss.setCorrectAnswers++;
            boss.totalCorrectAnswers++;
            boss.roundScore += 100;
            boss.gameScore += 100;
        }
        myRoundPoints = playerCorrect ? 100 : 0;
        boss.roundPoints = bossCorrect ? 100 : 0;
        myTotalAnswerTimeMs += myAnswerElapsedMs;
        boss.totalAnswerTimeMs += boss.answerElapsedMs;
        txtScoreMe.setText(setScoreMe + "");
        txtSetsMe.setText(myTotalCorrectAnswers + "");
        txtScoreGameMe.setText(gameScoreMe + "");
        opponentHudController.refreshOpponentPanels();
    }

    int getCampaignTargetQuestionCount() {
        if (boardCampaignMatch) {
            // The number of cells the human personally answers (used only to clamp the
            // reported correct count): boss = one full category (BOARD_ROWS), solo = picks.
            return "boss".equals(boardCampaignKind) ? BOARD_ROWS : Math.max(1, boardSoloPicks);
        }
        int requested = campaignQuestionCount > 0 ? campaignQuestionCount : 10;
        if (campaignMode && questions != null && !questions.isEmpty()) {
            return Math.min(requested, questions.size());
        }
        return requested;
    }

    private void handleCampaignStageAnswer(final boolean timeout) {
        FAST_LIGHTS = false;
        T_LIGHTS = 3;
        CAN_PLAY = false;
        final boolean correct = !timeout && myAnswer == rightAnswer;
        final int starsBefore = campaignHudController.getEarnedStars();
        final String campaignAnswerMessage;
        final int campaignAnswerDialogMs;
        myAnswerElapsedMs = timeout ? QUESTION_TIMEOUT_MS : getCurrentAnswerElapsedMs();
        if (campaignBossBattle) {
            ensureCampaignBossAnswered();
            applyCampaignBossRoundMetrics(correct);
        }
        if (correct) {
            recordCampaignCorrectAnswer();
            if (imgSelected != null) imgSelected.setImageResource(R.drawable.frame_right);
            PlayerStats.recordCorrectAnswer(GameActivity.this, false);
            person.like(700);
            playSound(R.raw.correct_answer, false, false);
            campaignHudController.updateProgressHud(true);
            campaignAnswerMessage = getCampaignAnswerMessage(true, starsBefore);
            campaignAnswerDialogMs = CAMPAIGN_FEEDBACK_MIN_READ_MS;
            showDialog(campaignAnswerMessage, "", CAMPAIGN_FEEDBACK_TALK_MS, campaignAnswerDialogMs, R.drawable.mouth_01, false);
        } else {
            recordCampaignWrongAnswer();
            PlayerStats.recordWrongAnswer(GameActivity.this, false);
            playSound(R.raw.wrong_answer, false, false);
            if (imgSelected != null && !timeout) imgSelected.setImageResource(R.drawable.frame_wrong);
            if (imgRight != null) imgRight.setImageResource(R.drawable.frame_right);
            campaignHudController.updateProgressHud(false);
            campaignAnswerMessage = getCampaignAnswerMessage(false, starsBefore);
            campaignAnswerDialogMs = CAMPAIGN_FEEDBACK_MIN_READ_MS;
            showDialog(campaignAnswerMessage, "", CAMPAIGN_FEEDBACK_TALK_MS, campaignAnswerDialogMs, R.drawable.mouth_05, false);
        }
        final int campaignNextQuestionDelayMs = campaignAnswerDialogMs + CAMPAIGN_FEEDBACK_TRANSITION_GAP_MS;
        applyCampaignModeAfterAnswer(correct);
        campaignHudController.updateProgressHud(false);

        if (campaignBossBattle && campaignBossOpponent != null
                && campaignBossOpponent.displayedAnswer > 0) {
            showThumbPlayerAnswer(campaignBossOpponent, campaignBossOpponent.displayedAnswer);
        }

        new Handler().postDelayed(new Runnable() {
            @Override
            public void run() {
                if (EXITING || campaignResultPersisted) {
                    return;
                }
                if (presenterDialogue.defer(this)) return;
                if (shouldFailCampaignAfterCurrentAnswer()) {
                    failCampaignStage(campaignFailureReason, 0);
                    return;
                }
                if (shouldCompleteCampaignAfterCurrentQuestion()) {
                    completeCampaignStage();
                    return;
                }
                initQuestion();
                if (currentStep < steps.size() - 1) {
                    nextStep();
                }
                // Campaign stages use a fast 10-question flow and skip the
                // classic side/intermediate money screen between questions.
                nextQuestion();
            }
        }, campaignNextQuestionDelayMs);
    }

    private void completeCampaignStage() {
        final int prize = getCampaignCurrentMoney();
        final boolean completed = isCampaignStageCompleteByMode();
        persistPendingCampaignStageResult(completed, completed ? prize : 0, 0);
        finishCampaignAndReturnToFlutter();
    }

    private boolean isCampaignStageCompleteByMode() {
        if (!campaignMode) {
            return true;
        }
        int playerScore = getCampaignPlayerScore();
        if (isCampaignEliminationMode()) {
            boolean completed = campaignWrongAnswers < Math.max(1, campaignMaxWrongAnswers);
            if (!completed) campaignFailureReason = "eliminated";
            return completed;
        }
        if (isCampaignSurvivalMode()) {
            boolean completed = campaignLivesRemaining > 0;
            if (!completed) campaignFailureReason = "outOfLives";
            return completed;
        }
        if (isCampaignBattleMode()) {
            boolean completed = campaignPlayerBeatsOpponent(playerScore, campaignOpponentScore, campaignOpponentCorrectAnswers);
            if (!completed) campaignFailureReason = "lostBattle";
            return completed;
        }
        if (isCampaignRivalMode()) {
            int targetScore = campaignTargetScore > 0 ? campaignTargetScore : 700;
            boolean completed = playerScore >= targetScore;
            if (!completed) campaignFailureReason = "targetNotReached";
            return completed;
        }
        if (isCampaignBossMode()) {
            boolean completed = isCampaignBossDefeated();
            if (!completed) campaignFailureReason = "bossDefeatedPlayer";
            return completed;
        }
        if (isCampaignSeriesMode()) {
            resolveSimpleCampaignSeries();
            boolean completed = campaignPlayerSeriesWins >= Math.max(2, campaignSeriesWinsRequired);
            if (!completed) campaignFailureReason = "lostSeries";
            return completed;
        }
        if (isCampaignTeamBattleMode()) {
            campaignTeamScore = playerScore + campaignAllyScore;
            boolean completed = campaignTeamScore > campaignEnemyTeamScore;
            if (!completed) campaignFailureReason = "lostTeamBattle";
            return completed;
        }
        return true;
    }

    private void resolveSimpleCampaignSeries() {
        // TODO: Replace this summary with visible per-round campaign series UI.
        int requiredWins = Math.max(2, campaignSeriesWinsRequired);
        boolean playerWon = campaignPlayerBeatsOpponent(
                getCampaignPlayerScore(),
                campaignOpponentScore,
                campaignOpponentCorrectAnswers
        );
        campaignPlayerSeriesWins = playerWon ? requiredWins : Math.max(0, requiredWins - 1);
        campaignOpponentSeriesWins = playerWon ? Math.max(0, requiredWins - 1) : requiredWins;
    }

    boolean isCampaignBossDefeated() {
        if (!campaignBossBattle || campaignBossOpponent == null) {
            return true;
        }
        MatchOpponent boss = campaignBossOpponent;
        if (gameScoreMe != boss.gameScore) {
            return gameScoreMe > boss.gameScore;
        }
        if (myTotalCorrectAnswers != boss.totalCorrectAnswers) {
            return myTotalCorrectAnswers > boss.totalCorrectAnswers;
        }
        return myTotalAnswerTimeMs > 0L
                && (boss.totalAnswerTimeMs <= 0L || myTotalAnswerTimeMs < boss.totalAnswerTimeMs);
    }

    private int getCampaignCurrentMoney() {
        try {
            return Integer.parseInt(getCurrentStepAmount().replace("$", "").trim());
        } catch (Exception ignored) {
        }
        try {
            if (txtAmount != null && txtAmount.getText() != null) {
                return Integer.parseInt(txtAmount.getText().toString().replace("$", "").trim());
            }
        } catch (Exception ignored) {
        }
        return 0;
    }

    void createCampaignTimerViewIfNeeded() {
        if (!campaignMode || campaignTimeLimitSeconds <= 0 || txtCampaignTimer != null) {
            return;
        }
        txtCampaignTimer = new TextView(this);
        txtCampaignTimer.setTextColor(Color.WHITE);
        txtCampaignTimer.setTextSize(TypedValue.COMPLEX_UNIT_SP, isCampaignBlitzMode() ? 17 : 12.5f);
        txtCampaignTimer.setTypeface(null, android.graphics.Typeface.BOLD);
        txtCampaignTimer.setPadding(dp(10), dp(4), dp(10), dp(4));
        txtCampaignTimer.setGravity(Gravity.CENTER);
        txtCampaignTimer.setIncludeFontPadding(false);
        txtCampaignTimer.setText("⏱ " + formatCampaignRemaining(campaignTimeLimitSeconds));
        updateCampaignTimerVisual(campaignTimeLimitSeconds);

        if (offlineContestants != null && offlineContestants.isSoloCampaignBoard()) {
            offlineContestants.attachCampaignTimerToSoloCard();
        } else {
            android.widget.FrameLayout.LayoutParams params = new android.widget.FrameLayout.LayoutParams(
                    android.widget.FrameLayout.LayoutParams.WRAP_CONTENT,
                    android.widget.FrameLayout.LayoutParams.WRAP_CONTENT);
            params.gravity = android.view.Gravity.TOP | android.view.Gravity.CENTER_HORIZONTAL;
            params.setMargins(dp(12), dp(10), dp(12), dp(12));
            View root = findViewById(android.R.id.content);
            if (root instanceof android.widget.FrameLayout) {
                ((android.widget.FrameLayout) root).addView(txtCampaignTimer, params);
            }
        }
    }

    private void startCampaignStageTimerIfNeeded() {
        if (!campaignMode || campaignTimeLimitSeconds <= 0 || campaignStageTimer != null || campaignResultPersisted) {
            return;
        }
        campaignStartedAtMs = System.currentTimeMillis();
        startCampaignStageTimerWithDuration(campaignTimeLimitSeconds * 1000L);
    }

    private void startCampaignStageTimerWithDuration(long durationMs) {
        stopCampaignStageTimer();
        campaignStageTimer = new CountDownTimer(durationMs, 1000L) {
            @Override
            public void onTick(long millisUntilFinished) {
                if (boardCampaignMatch && boardCampaignRuleView != null) {
                    boardCampaignRuleView.setText(campaignBoardRulesLine());
                }
                if (txtCampaignTimer != null) {
                    int secondsLeft = (int) Math.ceil(millisUntilFinished / 1000.0);
                    txtCampaignTimer.setText("⏱ " + formatCampaignRemaining(secondsLeft));
                    updateCampaignTimerVisual(secondsLeft);
                }
            }

            @Override
            public void onFinish() {
                handleCampaignTimeExpired();
            }
        }.start();
    }

    private String formatCampaignRemaining(int totalSeconds) {
        int safeSeconds = Math.max(0, totalSeconds);
        return String.format(Locale.US, "%02d:%02d", safeSeconds / 60, safeSeconds % 60);
    }

    void updateCampaignTimerVisual(int secondsLeft) {
        if (txtCampaignTimer == null) {
            return;
        }
        boolean urgent = secondsLeft <= 20 || (isCampaignBlitzMode() && secondsLeft <= 30);
        txtCampaignTimer.setTextColor(urgent ? Color.rgb(255, 230, 230) : Color.WHITE);
        txtCampaignTimer.setBackground(createRoundedDrawable(
                urgent ? Color.argb(225, 150, 20, 34) : Color.argb(205, 10, 28, 48),
                urgent ? Color.argb(240, 255, 112, 112) : Color.argb(220, 255, 216, 74),
                isCampaignBlitzMode() ? 2 : 1,
                14
        ));
    }

    private void handleCampaignTimeExpired() {
        if (!campaignMode || campaignResultPersisted || EXITING) {
            return;
        }
        if (boardCampaignMatch) {
            finishCampaignBoardMatch();
            return;
        }
        CAN_PLAY = false;
        CAN_CLICK = false;
        CAN_HOME = false;
        stopTimer(false);
        GameNotice.makeText(this, "انتهى الوقت!", Toast.LENGTH_SHORT).show();
        campaignFailureReason = "timeExpired";
        persistPendingCampaignStageResult(false, getCampaignCurrentMoney(), campaignWrongAnswers);
        new Handler().postDelayed(new Runnable() {
            @Override
            public void run() {
                if (!isFinishing()) {
                    finishCampaignAndReturnToFlutter();
                }
            }
        }, 1200);
    }

    private void finishCampaignAndReturnToFlutter() {
        if (!EXITING && presenterDialogue.deferAll("campaignResult", this::finishCampaignAndReturnToFlutter)) return;
        if (!campaignMode) {
            return;
        }
        clearCampaignProgress();
        Log.d("CampaignStage", "CAMP_FINISH_TO_FLUTTER");
            stopCurrentSound();
        if (cdtProgress != null) cdtProgress.cancel();
        stopCampaignStageTimer();
        finish();
    }

    void stopCampaignStageTimer() {
        if (campaignStageTimer != null) {
            campaignStageTimer.cancel();
            campaignStageTimer = null;
        }
    }

    private void applyCampaignQuestionSelectionIfNeeded() {
        if (!campaignMode || questions == null || questions.isEmpty()) {
            return;
        }
        ArrayList<Question> selected = new ArrayList<>();
        Set<String> used = new HashSet<>(questionExclusions);
        if (!campaignQuestionIds.isEmpty()) {
            for (Integer id : campaignQuestionIds) {
                if (id == null) {
                    continue;
                }
                int index = id;
                if (index >= 0 && index < questions.size()) {
                    Question question = questions.get(index);
                    if (isCampaignQuestionLevelAllowed(question) && used.add(QuestionIdentity.key(question))) {
                        selected.add(question);
                    } else {
                        Log.w("CampaignStage", "Skipped question id=" + id
                                + " level=" + (question == null ? "" : question.getLevel())
                                + " allowed=" + campaignAllowedLevels);
                    }
                } else {
                    Log.w("CampaignStage", "Question id out of range: " + id);
                }
                if (selected.size() >= getCampaignTargetQuestionCount()) {
                    break;
                }
            }
        }
        if (selected.size() < getCampaignTargetQuestionCount()) {
            for (Question question : QuestionSelection.unseen(questions, used, boardRandom)) {
                if (selected.size() >= getCampaignTargetQuestionCount()) {
                    break;
                }
                if (isCampaignQuestionLevelAllowed(question) && used.add(QuestionIdentity.key(question))) {
                    selected.add(question);
                }
            }
        }
        questions = selected;
        if (isDebuggableBuild()) {
            Log.d("CampaignStage", "loaded campaign questions=" + questions.size()
                    + " levels=" + campaignLevelSummary(questions));
        }
    }

    boolean isDebuggableBuild() {
        return (getApplicationInfo().flags & android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE) != 0;
    }

    private boolean isCampaignQuestionLevelAllowed(Question question) {
        if (question == null || campaignAllowedLevels.isEmpty()) {
            return true;
        }
        String level = question.getLevel() == null ? "" : question.getLevel().trim();
        return campaignAllowedLevels.contains(level);
    }

    private String campaignLevelSummary(ArrayList<Question> list) {
        HashMap<String, Integer> summary = new HashMap<>();
        for (Question question : list) {
            String level = question == null || question.getLevel() == null
                    ? ""
                    : question.getLevel().trim();
            Integer count = summary.get(level);
            summary.put(level, count == null ? 1 : count + 1);
        }
        return summary.toString();
    }

    private void confirmExit() {
        if (paidDuel != null) {
            if (boardDuelFinished) { proceedAfterBoardResult(); return; }
            if (paidDuel.isPending()) return;
            boolean active = "active".equals(paidDuelState.get("status"));
            GameNoticeDialogs.builder(this).setTitle(active ? "الانسحاب من التحدي؟" : "إلغاء التحدي؟")
                    .setMessage(active ? "بعد بدء المباراة يُحسب الانسحاب خسارة ويحصل صديقك على مجموع القطع."
                            : "تُلغى المباراة وتُعاد القطع للطرفين.")
                    .setPositiveButton(active ? "انسحاب" : "إلغاء التحدي", (dialog, which) -> {
                        paidDuelExiting = true;
                        paidDuel.call("forfeit", Collections.emptyMap());
                    }).setNegativeButton("متابعة اللعب", null).show();
            return;
        }
        if (isOfflineContestantMode()) {
            showConfirmationDialog("هل تريد الخروج من المباراة ؟", "ConfirmExit", 2000, 0, R.drawable.mouth_05, false);
            return;
        }
        if (!txtAmount.getText().toString().equals("$0")) {
            showConfirmationDialog("هل تريد الخروج والاكتفاء بالمبلغ الحالي ؟", "ConfirmHome", 2000, 0, R.drawable.mouth_05, false);
        } else {
            showConfirmationDialog("هل تريد الخروج من المباراة ؟", "ConfirmExit", 2000, 0, R.drawable.mouth_05, false);
        }
    }

    private void showInterstitialAd() {
        if (interstitialAdController != null) {
            interstitialAdController.showOrRun(this::navigateToHome);
        } else {
            navigateToHome();
        }
    }

    private void navigateToHome() {
        Intent intent = new Intent(GameActivity.this, MainActivity.class);
        intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TASK);
        startActivity(intent);
    }

    private void showThumbPlayerAnswer(int player, int answer) {
        int resId = getResources().getIdentifier("imgAnswer" + answer + "Player" + player, "id", this.getPackageName());
        findViewById(resId).setVisibility(View.VISIBLE);
    }

    private void showThumbPlayerAnswer(MatchOpponent opponent, int answer) {
        if (opponent == null || answer <= 0 || answer > opponentAnswerContainers.size()) {
            return;
        }
        int index = answer - 1;
        if (index >= opponent.answerThumbViews.size()) {
            return;
        }
        opponent.answerThumbViews.get(index).setVisibility(View.VISIBLE);
    }

    private void letsStart() {
        CAN_HOME = true;
        final Handler handler = new Handler();
        handler.postDelayed(new Runnable() {
            int t = 0;

            @Override
            public void run() {
                if (EXITING || isFinishing() || isDestroyed() || presenterDialogue.defer(this)) return;
                t++;
                switch (t) {
                    case 1:
                        person.raiseEyeBrowsUp(2000, false, true);
                        person.like(2000);
                        if (campaignMode && "boss".equals(campaignStageType) && !campaignBossBotName.trim().isEmpty()) {
                            GameNotice.makeText(GameActivity.this, "تواجه الآن " + campaignBossBotName, Toast.LENGTH_SHORT).show();
                        }
                        if (modeOnline)
                            showDialog("نبدأ الآن.. استعدوا للمباراة", "", 1000, 3000, R.drawable.mouth_01, false);
                        else if (campaignMode) {
                            String msg = (pendingCampaignResumeQuestion >= 0)
                                    ? "استعد.. نتابع أسئلة هذه المرحلة"
                                    : "استعد.. نبدأ أسئلة المرحلة!";
                            showDialog(msg, "", 1000, (pendingCampaignResumeQuestion >= 0) ? 2000 : 3000, R.drawable.mouth_01, false);
                        } else
                            showDialog("نبدأ الآن.. بالتوفيق للجميع", "", 1000, 3000, R.drawable.mouth_01, false);
                        handler.postDelayed(this, (campaignMode && pendingCampaignResumeQuestion >= 0) ? 2500 : 5000);
                        break;
                    case 2:
                        playSound(R.raw.lets_play, true, false);
                        person.moveHead(2000);
                        person.lookAside(2500);
                        if (campaignMode && pendingCampaignResumeQuestion >= 0) {
                            showDialog("نتابع المرحلة.. السؤال رقم " + (pendingCampaignResumeQuestion + 1) + " يقول ..", "", 1000, 2000, R.drawable.mouth_01, false);
                        } else {
                            showDialog("السؤال الأول يقول ..", "", 1000, 2000, R.drawable.mouth_01, false);
                        }
                        handler.postDelayed(this, 2000);
                        break;
                    case 3:
                        if (campaignMode) {
                            if (campaignStartedAtMs <= 0L) {
                                campaignStartedAtMs = System.currentTimeMillis();
                            }
                        }
                        startCampaignStageTimerIfNeeded();
                        if (campaignMode && pendingCampaignResumeQuestion >= 0 && questions != null && pendingCampaignResumeQuestion < questions.size()) {
                            int resumeQ = pendingCampaignResumeQuestion;
                            pendingCampaignResumeQuestion = -1;
                            currentStep = resumeQ;
                            for (int s = 0; s < steps.size(); s++) {
                                if (s < resumeQ) {
                                    steps.get(s).setBackgroundResource(R.color.darkBlueApp);
                                } else if (s == resumeQ) {
                                    steps.get(s).setBackgroundResource(R.color.stepSelected);
                                } else {
                                    steps.get(s).setBackgroundResource(android.R.color.transparent);
                                }
                            }
                            if (savedCampaignAmount != null && !savedCampaignAmount.isEmpty()) {
                                txtAmount.setText(savedCampaignAmount);
                            }
                            campaignHudController.updateProgressHud(false);
                            updateInventoryBadges();
                            applyCampaignLifelineRestrictions();
                            showQuestionNow(resumeQ);
                        } else if (modeOnline || campaignBossBattle) {
                            requestSynchronizedQuestion(0);
                        } else {
                            nextQuestion();
                        }
                        break;
                }

            }
        }, 1000);
    }

    private void finishGame() {
        leaveOnlineMatchIfNeeded();
        stopCurrentSound();
        stopTimer(false);
        if (boardLocalTeams && boardMode && !localTeamsFinished) {
            saveLocalTeamsProgress(currentLocalTeamsPhase());
            GameNotice.makeText(this, "تم حفظ المباراة ويمكنك متابعتها لاحقًا", Toast.LENGTH_SHORT).show();
            if (offlineContestants != null) offlineContestants.release();
            if (cdtProgress != null) cdtProgress.cancel();
            finish();
            return;
        }
        if (shouldSaveOfflineBoard() && !offlineBoardFinished) {
            saveOfflineBoardProgress(currentOfflineBoardPhase());
            GameNotice.makeText(this, "تم حفظ المباراة ويمكنك متابعتها لاحقًا", Toast.LENGTH_SHORT).show();
            if (offlineContestants != null) offlineContestants.release();
            if (cdtProgress != null) cdtProgress.cancel();
            finish();
            return;
        }
        if (isOfflineContestantMode()) {
            final int score = offlineContestants.playerScore();
            person.moveShowHand(1000);
            showDialog("إلى اللقاء، نراكم في تحدٍ جديد", "", 1500, 2000, R.drawable.mouth_01, false);
            (new Handler()).postDelayed(new Runnable() {
                @Override
                public void run() {
                    try {
                        PlayerStats.recordGameEnd(GameActivity.this, ProgressionRules.ABANDON, score);
                        if (!campaignMode) {
                            PlayerProgress.onGameFinished(GameActivity.this, false, score,
                                    PlayerStats.getBestStreak(GameActivity.this), usedAllHelps(), usedAnyHelp());
                        }
                    } catch (Exception ignored) {
                    }
                    offlineContestants.release();
                    stopCurrentSound();
                    if (cdtProgress != null) cdtProgress.cancel();
                    showInterstitialAd();
                }
            }, 1800);
            return;
        }
        if (!txtAmount.getText().toString().equals("$0")) {
            person.like(1000);
            person.raiseEyeBrowsUp(1000, true, true);
            showDialog("تهانينا.. لقد حصلت على مبلغ " + txtAmount.getText().toString(), "", 2000, 3000, R.drawable.mouth_01, false);
        } else {
            person.moveShowHandGrip(1000);
            person.raiseEyeBrowsUp(1000, true, false);
            showDialog("حظا أفضل في المرة القادمة", "", 2000, 2000, R.drawable.mouth_05, false);
        }
        (new Handler()).postDelayed(new Runnable() {
            @Override
            public void run() {
                try {
                    int prize = Integer.parseInt(txtAmount.getText().toString().replace("$", "").trim());
                    PlayerStats.recordGameEnd(GameActivity.this, ProgressionRules.ABANDON, prize);
                    if (!campaignMode) {
                        PlayerProgress.onGameFinished(GameActivity.this, false, prize, PlayerStats.getBestStreak(GameActivity.this), usedAllHelps(), usedAnyHelp());
                    }
                    persistPendingCampaignStageResult(false, prize, 0);
                } catch (Exception ignored) {}
                stopCurrentSound();
                if (cdtProgress != null) cdtProgress.cancel();
                if (campaignMode) {
                    finishCampaignAndReturnToFlutter();
                } else {
                    showInterstitialAd();
                }
            }
        }, 2000);
    }

    private void handleQuestionTimeout() {
        if (paidDuel != null) {
            stopTimer(false);
            CAN_PLAY = false;
            paidDuel.sync();
            return;
        }
        if (cdtProgress != null) {
            cdtProgress.cancel();
            cdtProgress = null;
        }
        isQuestionTimerRunning = false;
        wasTimerRunningBeforePause = false;
        PROGRESS_VALUE = 300;
        //TIMER_VALUE = 10000;
        if (modeOnline && !boardMode) {
            CAN_PLAY = false;
            // Only submit timeout if the player hasn't already
            // submitted (or selected an answer awaiting confirm).
            // This prevents the timer from overwriting a valid
            // answer with a timeout right before resolution.
            if (!myAnswerSubmitted) {
                submitOnlineAnswer(0);
                resolveOnlineRoundIfReady();
            }
        } else {
            checkAnswer(true);
        }
    }

    void startTimer(boolean start) {
        if (backgroundParticipationEnded || backgroundGuard.enforce()) return;
        if (paidDuel != null) {
            startPaidDuelQuestionTimer();
            return;
        }
        int randomTime = 15;
        if (!EXITING) {
            if (start) {
                int startTicks = boardMode ? 450 : 300;
                if (boardCampaignMatch && "boss".equals(boardCampaignKind)
                        && "speed".equals(boardBossStyle)) startTicks = 300;
                PROGRESS_VALUE = startTicks;
                if (isRecoverableBotBoard() && restoredBotQuestionDeadline > 0L) {
                    PROGRESS_VALUE = (int) Math.min(startTicks, Math.max(0L,
                            (restoredBotQuestionDeadline - System.currentTimeMillis() + 99L) / 100L));
                    restoredBotQuestionDeadline = 0L;
                    if (PROGRESS_VALUE <= 0) {
                        handleQuestionTimeout();
                        return;
                    }
                }
                //TIMER_VALUE = 10000;
                pbTime.setMax(startTicks);
                pbTime.setRingProgressColor(getResources().getColor(R.color.progressGreen));
                pbTime.setProgress(0);
                txtProgress.setText(String.valueOf((PROGRESS_VALUE + 9) / 10));
                rlyProgress.setAlpha(1f); // the ring starts transparent in XML; force it opaque
                if (modeOnline && !boardMode && hasBotOpponents()) {
                    randomTime = getFictitiousRandomTime();
                }
                Animations.progressZoomIn(rlyProgress);
                if (modeOnline && !boardMode) {
                    scheduleBotAnswersForCurrentQuestion();
                } else if (campaignBossBattle) {
                    scheduleCampaignBossAnswer();
                }
            }
            isQuestionTimerRunning = true;
            if (start && isRecoverableBotBoard()) saveOfflineBoardProgress(OfflineBoardGameStore.PHASE_QUESTION);
            if (cdtProgress != null) {
                cdtProgress.cancel();
                cdtProgress = null;
            }
            final int finalRandomTime = randomTime;
            long timerDurationMs = Math.max(50000L, (PROGRESS_VALUE + 50) * 100L);
            cdtProgress = new CountDownTimer(timerDurationMs, 100) {
                int pbText;

                @Override
                public void onTick(long l) {
                    //TIMER_VALUE = l;
                    PROGRESS_VALUE--;
                    if (PROGRESS_VALUE > 0 && pbTime != null) {
                        pbTime.setProgress(PROGRESS_VALUE);
                    }
                    if (PROGRESS_VALUE <= 0) {
                        this.cancel();
                        handleQuestionTimeout();
                        return;
                    }
                    if ((PROGRESS_VALUE % 10) == 0) {
                        pbText = PROGRESS_VALUE / 10;
                        if (txtProgress != null) {
                            txtProgress.setText(pbText + "");
                        }
                        if (pbText > 10) {
                            if (pbTime != null) {
                                pbTime.setRingProgressColor(getResources().getColor(R.color.progressGreen));
                            }
                        } else if (pbText > 5) {
                            if (SOUND_ON && mpBeep != null) {
                                try { mpBeep.start(); } catch (Exception ignored) {}
                            }
                            if (pbTime != null) {
                                pbTime.setRingProgressColor(getResources().getColor(R.color.progressOrange));
                            }
                        } else if (pbText > 0) {
                            if (SOUND_ON && mpBeep1 != null) {
                                try { mpBeep1.start(); } catch (Exception ignored) {}
                            }
                            if (pbTime != null) {
                                pbTime.setRingProgressColor(getResources().getColor(R.color.progressRed));
                            }
                        } else {
                            this.cancel();
                            handleQuestionTimeout();
                        }
                    }
                }

                @Override
                public void onFinish() {
                    if (isQuestionTimerRunning) {
                        handleQuestionTimeout();
                    }
                }
            }.start();
        }
    }

    private void stopTimer(boolean pause) {
        if (cdtProgress != null) {
            cdtProgress.cancel();
            cdtProgress = null;
        }
        isQuestionTimerRunning = false;
        if (!pause) {
            wasTimerRunningBeforePause = false;
            Animations.progressZoomOut(rlyProgress);
            //TIMER_VALUE = 10000;
            PROGRESS_VALUE = 300;
        }
    }

    private void animLights() {
        final ImageView imgLight1, imgLight2, imgLight3, imgLight4;

        final ImageView imgShadow;
        imgShadow = findViewById(R.id.imgShadow);
        imgLight1 = findViewById(R.id.imgLight1);
        imgLight2 = findViewById(R.id.imgLight2);
        imgLight3 = findViewById(R.id.imgLight3);
        imgLight4 = findViewById(R.id.imgLight4);


        final Handler handler = new Handler();
        Runnable runnable = new Runnable() {
            boolean toLeft = true;
            int d;

            @Override
            public void run() {
                T_LIGHTS++;
                d = FAST_LIGHTS ? 250 : 1000;
                if ((FAST_LIGHTS) || ((!FAST_LIGHTS) && (T_LIGHTS == 4))) {
                    T_LIGHTS = 0;
                    if (toLeft) {
                        Animations.rotateLight(imgLight1, -20f, 20f, d);
                        Animations.rotateLight(imgLight2, 20f, -20f, d);
                        Animations.rotateLight(imgLight3, -20f, 20f, d);
                        Animations.rotateLight(imgLight4, 20f, -20f, d);
                        toLeft = false;
                    } else {
                        if (FAST_LIGHTS) Animations.fadeShadow(imgShadow);
                        Animations.rotateLight(imgLight1, 20f, -20f, d);
                        Animations.rotateLight(imgLight2, -20f, 20f, d);
                        Animations.rotateLight(imgLight3, 20f, -20f, d);
                        Animations.rotateLight(imgLight4, -20f, 20f, d);
                        toLeft = true;
                    }
                }
                handler.postDelayed(this, 250);
            }
        };
        handler.postDelayed(runnable, 0);
    }

    private void goBlinking() {
        final Handler handler = new Handler();
        Runnable runnable = new Runnable() {
            @Override
            public void run() {
                int times = (new Random()).nextInt(2) + 1;
                int delay = (new Random()).nextInt(5) + 3;
                person.blinkEyes(times);
                handler.postDelayed(this, delay * 1000);
            }
        };
        handler.postDelayed(runnable, 1000);
    }

    private void onWrongAnswer(boolean timeOut) {
        recordCampaignWrongAnswer();
        CAN_HOME = false;
        CAN_CLICK = false;
        CAN_PLAY = false;
        PlayerStats.recordWrongAnswer(GameActivity.this);
        playSound(R.raw.wrong_answer, false, false);
        person.sad();
        imgRight.setImageResource(R.drawable.frame_right);
        if (timeOut) {
            showDialog("انتهى الوقت للأسف", "", 1000, 2000, R.drawable.mouth_05, false);
        } else {
            imgSelected.setImageResource(R.drawable.frame_wrong);
            showDialog("إجابة خاطئة للأسف", "", 1000, 2000, R.drawable.mouth_05, false);
        }

        if (!modeOnline) {
            final Handler handler = new Handler();
            Runnable runnable = new Runnable() {
                int t = 0;

                @Override
                public void run() {
                    if (EXITING || isFinishing() || isDestroyed() || presenterDialogue.defer(this)) return;
                    t++;
                    switch (t) {
                        case 1:
                            if (currentQuestion > 9) {
                                txtAmount.setText("$32000");
                                person.moveShow2Hands(2000);
                                person.raiseEyeBrowsUp(2000, true, true);
                                showDialog("على كل حال لقد فزت بمبلغ $32000\nألف مبروك", "", 2000, 3000, R.drawable.mouth_01, false);
                            } else if (currentQuestion > 4) {
                                txtAmount.setText("$1000");
                                person.moveShow2Hands(2000);
                                person.raiseEyeBrowsUp(2000, true, true);
                                showDialog("على كل حال لقد فزت بمبلغ $1000\nألف مبروك", "", 2000, 3000, R.drawable.mouth_01, false);
                            } else {
                                txtAmount.setText("$0");
                                person.moveShowHand(2000);
                                showDialog("للأسف لم تصل إلى مرحلة تثبيت المبلغ\n حظا أفضل في المرة القادمة", "", 2000, 3000, R.drawable.mouth_01, false);
                            }
                            CAN_HOME = false;
                            handler.postDelayed(this, 4000);
                            break;
                        case 2:
                            // سجّل نتيجة اللعبة مع المبلغ المثبت (إن لم يخرج اللاعب يدوياً)
                            if (!EXITING) {
                                try {
                                    int safeHavenPrize = Integer.parseInt(
                                        txtAmount.getText().toString().replace("$", "").trim());
                                    PlayerStats.recordGameEnd(GameActivity.this, false, safeHavenPrize);
                                    if (!campaignMode) {
                                        PlayerProgress.onGameFinished(GameActivity.this, false, safeHavenPrize,
                                            PlayerStats.getBestStreak(GameActivity.this), usedAllHelps(), usedAnyHelp());
                                    }
                                    persistPendingCampaignStageResult(false, safeHavenPrize, 1);
                                } catch (Exception ignored) {}
                            }
                            showInterstitialAd();
                            break;
                    }

                }
            };
            handler.postDelayed(runnable, 3000);
        }
    }



        /*else {
            if(opponentAnswer>0) {
                showThumbPlayerAnswer(2, opponentAnswer);
                if (opponentAnswer == rightAnswer) {
                    int amount = Integer.parseInt(getCurrentStepAmount().replace("$",""));
                    setScoreOpponent += amount;
                    gameScoreOpponent += amount;
                    txtScoreOpponent.setText(gameScoreOpponent+"");
                }
            }
            final Handler handler = new Handler();
            Runnable runnable = new Runnable() {
                int t = 0;
                @Override
                public void run() {
                    t++;
                    switch(t) {
                        case 1:
                            if (checkScores()) {
                                if(checkEndOfGame()) {
                                    t=3;
                                }
                                handler.postDelayed(this, 3000);
                            } else {
                                handler.postDelayed(this, 1000);
                            }
                            break;
                        case 2:
                            initQuestion();
                            nextStep();
                            playSound(R.raw.lets_play, true, false);
                            String currentStepAmount = getCurrentStepAmount();
                            person.moveHead(1000);
                            person.lookAside(600);
                            showDialog("السؤال التالي قيمته\n" + currentStepAmount, "", 1000, 3000, R.drawable.mouth_02, false);
                            CAN_HOME = true;
                            handler.postDelayed(this, 4000);
                            break;
                        case 3:
                            nextQuestion();
                            break;
                        case 4:
                            goToWinnerScreen(gameScoreMe+"$");
                            break;
                    }
                }
            };
            handler.postDelayed(runnable, 3000);
        }*/
    private void initQuestion() {
        rightAnswer=0;
        if (txtQ != null) txtQ.setVisibility(View.VISIBLE);
        txtQ.setText("");
        txtA1.setVisibility(View.VISIBLE);
        txtA2.setVisibility(View.VISIBLE);
        txtA3.setVisibility(View.VISIBLE);
        txtA4.setVisibility(View.VISIBLE);
        txtA1.setText("");
        txtA2.setText("");
        txtA3.setText("");
        txtA4.setText("");
        imgA1.setImageResource(R.drawable.frame);
        imgA2.setImageResource(R.drawable.frame);
        imgA3.setImageResource(R.drawable.frame);
        imgA4.setImageResource(R.drawable.frame);
        imgVote1.setTag(0);
        imgVote2.setTag(0);
        imgVote3.setTag(0);
        imgVote4.setTag(0);
        GameLifelineController.setVote(this, imgVote1);
        GameLifelineController.setVote(this, imgVote2);
        GameLifelineController.setVote(this, imgVote3);
        GameLifelineController.setVote(this, imgVote4);
        if((modeOnline || campaignBossBattle) && !boardMode) {
            imgAnswer1Player1.setVisibility(View.INVISIBLE);
            imgAnswer2Player1.setVisibility(View.INVISIBLE);
            imgAnswer3Player1.setVisibility(View.INVISIBLE);
            imgAnswer4Player1.setVisibility(View.INVISIBLE);
            myAnswer = 0;
            opponentAnswer = 0;
            myAnswerSubmitted = false;
            resolvingRound = false;
            roundResolved = false;
            resolvingFinal = false;
            mySubmittedAnswerKey = 0;
            myRoundPoints = 0;
            myAnswerElapsedMs = QUESTION_TIMEOUT_MS;
            questionStartTimeMs = 0L;
            currentAnswerOrder.clear();
            cancelPendingFictitiousAnswer();
            detachOpponentRoundListener();
            detachQuestionSyncListener();
            for (MatchOpponent opponent : opponents) {
                opponent.displayedAnswer = 0;
                opponent.submitted = false;
                opponent.submittedAnswerKey = 0;
                opponent.roundPoints = 0;
                opponent.answerElapsedMs = QUESTION_TIMEOUT_MS;
            }
            opponentHudController.refreshOpponentPanels();
        }
        //imgHelp5050.setImageResource(R.drawable.help_5050);
        //imgHelpCall.setImageResource(R.drawable.help_call);
        //imgHelpAudience.setImageResource(R.drawable.help_audience);
    }

    private String getStepAmount(int nStep) {
        TextView txtAmount = (TextView) steps.get(nStep).getChildAt(1);
        return txtAmount.getText().toString();
    }

    private String getCurrentStepAmount() {
        TextView txtAmount = (TextView) steps.get(currentStep).getChildAt(1);
        return txtAmount.getText().toString();
    }

    private void nextStep() {
        steps.get(currentStep).setBackgroundResource(R.color.darkBlueApp);
        currentStep++;
        if(currentStep < steps.size())
            steps.get(currentStep).setBackgroundResource(R.color.stepSelected);
    }

    private void nextQuestion() {
        showQuestionNow(currentQuestion + 1);
    }

    private void showQuestionNow(final int questionIndex) {
        if (presenterDialogue.defer("question:" + questionIndex, () -> showQuestionNow(questionIndex))) return;
        int economyOrder = 0;
        try { economyOrder = Integer.parseInt(campaignStageId.replace("stage_", "")); } catch (Exception ignored) {}
        if (!GameEconomy.ensure(this, campaignMode, economyOrder, new ArrayList<>(boardSelectedCategories), () -> showQuestionNow(questionIndex))) return;
        if(!EXITING) {
            currentQuestion = questionIndex;
            updateQuestionCounter();
            campaignHudController.updateProgressHud(false);
            if (campaignMode && !campaignBoard) {
                saveCampaignProgress(null);
            }
            spectatorEliminationRound = eliminationMode && localPlayerEliminated;
            scheduledQuestionStartAt = 0L;
            pendingQuestionIndex = -1;
            if (currentQuestion < questions.size()) {
                CAN_HOME = true;
                final Question question = questions.get(currentQuestion);
                QuestionHistory.record(this, question);
                playQuestionMusic();

                final ArrayList<Integer> answerOrder = getQuestionShuffled(question);
                currentAnswerOrder.clear();
                currentAnswerOrder.addAll(answerOrder);
                final ArrayList<String> answerDisplayTexts = new ArrayList<>();
                for (int i = 0; i < answerOrder.size(); i++) {
                    int answerKey = answerOrder.get(i);
                    String answerText = getAnswerText(question, answerKey);
                    answerDisplayTexts.add(answerText);
                }
                applyAnswerTextSizes(answerDisplayTexts);

                final Handler handler = new Handler();
                final Runnable runnable = new Runnable() {
                    int i = -1;

                    @Override
                    public void run() {
                        if (EXITING || isFinishing() || isDestroyed() || presenterDialogue.defer(this)) return;
                        if(!EXITING) {
                            i++;
                            switch (i) {
                                case 0:
                                case 1:
                                case 2:
                                case 3:
                                    int answerKey = answerOrder.get(i);
                                    listAnswerViews.get(i).setText(answerDisplayTexts.get(i));
                                    if (answerKey == ANSWER_KEY_RIGHT) {
                                        rightAnswer = i+1;
                                        listAnswerViews.get(i).setTag("1");
                                        txtRight = listAnswerViews.get(i);
                                        rlyRight = (RelativeLayout) ((ViewGroup) txtRight.getParent());
                                        imgRight = (ImageView) rlyRight.getChildAt(0);
                                    } else {
                                        listAnswerViews.get(i).setTag("0");
                                    }
                                    handler.postDelayed(this, 1000);
                                    break;
                                case 4:
                                    CAN_PLAY = !spectatorEliminationRound;
                                    questionStartTimeMs = System.currentTimeMillis();
                                    startTimer(true);
                                    if (!modeOnline && !campaignBossBattle) {
                                        showDialog("اختاروا\nالإجابة الصحيحة", "", 700, 1300, R.drawable.mouth_01, true);
                                    }
                                    if (isOfflineContestantMode()) {
                                        offlineContestants.startRound(getCurrentQuestionLevel(), rightAnswer);
                                    }
                                    if(modeOnline) {
                                        Data.initQuestionPlayer(gameID, myID, currentQuestion);
                                        for (MatchOpponent opponent : opponents) {
                                            Data.initQuestionPlayer(gameID, opponent.id, currentQuestion);
                                        }
                                        opponentAnswer = 0;
                                        prepareOnlineQuestionSync(currentQuestion);
                                        attachOpponentRoundListener(currentQuestion);
                                        autoSubmitSpectatorEliminationRound();
                                    }
                                    break;
                            }
                        }
                    }
                };

                final Runnable startQuestionReveal = new Runnable() {
                    @Override
                    public void run() {
                        if (EXITING || isFinishing()) return;
                        bindBoardQuestionVisual(question);
                        applyQuestionTextSize(question.Q);
                        txtQ.setOnClickListener(null);
                        handler.postDelayed(runnable, 800);
                    }
                };

                if (question.getImg() != null && !question.getImg().trim().isEmpty()) {
                    for (TextView tv : listAnswerViews) {
                        if (tv != null) tv.setText("");
                    }
                    txtQ.setText("اضغط لترى الصورة 👁️");
                    applyQuestionTextSize("اضغط لترى الصورة 👁️");
                    final boolean[] dialogOpened = new boolean[]{false};
                    final Handler autoPromptHandler = new Handler();
                    final Runnable openObservation = new Runnable() {
                        @Override
                        public void run() {
                            if (dialogOpened[0] || EXITING || isFinishing()) return;
                            dialogOpened[0] = true;
                            autoPromptHandler.removeCallbacksAndMessages(null);
                            imageObservationController.showObservationImage(GameActivity.this, question.getImg(), new ImageObservationController.OnObservationFinishedListener() {
                                @Override
                                public void onFinished() {
                                    if (EXITING || isFinishing()) return;
                                    startQuestionReveal.run();
                                }
                            });
                        }
                    };
                    txtQ.setOnClickListener(new View.OnClickListener() {
                        @Override
                        public void onClick(View v) {
                            openObservation.run();
                        }
                    });
                    autoPromptHandler.postDelayed(openObservation, 4000);
                } else {
                    bindBoardQuestionVisual(question);
                    applyQuestionTextSize(question.Q);
                    handler.postDelayed(runnable, 1000);
                }

            } else {
                GameNotice.makeText(this,
                        "خطأ أثناء الانصال .. لا يمكنك الاتصال بالخادم. تحقق من اتصالك بالانترنت ثم حاول مرة أخرى.",
                        Toast.LENGTH_LONG).show();
            }
        }
    }

    String getLetter(int index) {
        String res = "";
        switch (index) {
            case 1: res = "أ"; break;
            case 2: res = "ب"; break;
            case 3: res = "ج"; break;
            case 4: res = "د"; break;
        }
        return  res;
    }

    private void updateQuestionCounter() {
        if (txtQuestionCounter == null) {
            return;
        }
        int total = getQuestionCounterTotal();
        int visibleQuestion = currentQuestion >= 0 ? Math.min(currentQuestion + 1, total) : 1;
        txtQuestionCounter.setText(visibleQuestion + "/" + total + " السؤال");
    }

    private int getQuestionCounterTotal() {
        if (campaignMode) {
            return Math.max(1, getCampaignTargetQuestionCount());
        }
        if (modeOnline) {
            return 5;
        }
        return 10;
    }

    private ArrayList<Integer> getQuestionShuffled(Question question) {
        return GameAnswerOptions.buildShuffledKeys(modeOnline, currentQuestion, gameID, question);
    }

    private String getAnswerText(Question question, int answerKey) {
        return GameAnswerOptions.getAnswerText(question, answerKey);
    }

    private int getAnswerKeyForDisplayedIndex(int displayedIndex) {
        return GameAnswerOptions.getAnswerKeyForDisplayedIndex(currentAnswerOrder, displayedIndex);
    }

    private int getDisplayedIndexForAnswerKey(int answerKey) {
        return GameAnswerOptions.getDisplayedIndexForAnswerKey(currentAnswerOrder, answerKey);
    }

    int getRightAnswer() {
        return GameAnswerOptions.getDisplayedIndexFromTextId(txtRight.getId());
    }

    void playSound(int resID, boolean fading, boolean looping) {
        if (soundController != null) {
            // Block any delayed/async trigger (timers, bot turns, network callbacks,
            // dialog sequences) from starting fresh audio after the activity has been
            // paused/backgrounded — otherwise looping music can keep playing offscreen.
            soundController.play(resID, fading, looping, EXITING || ACTIVITY_PAUSED);
        }
    }

    void stopCurrentSound() {
        if (soundController != null) {
            soundController.stopCurrent();
        }
    }

    private void showConfirmationDialog(final String message, final String tag, final int timeTalk, final int timeDialog, final int nextMouthId, final boolean gameStatusAfter) {
        if (shouldSkipConfirmation(tag)) {
            acceptSkippedConfirmation(tag);
            return;
        }
        showDialog(message, tag, timeTalk, timeDialog, nextMouthId, gameStatusAfter);
    }

    private boolean shouldSkipConfirmation(String tag) {
        return tag != null && tag.startsWith("Confirm") && !AppPrefs.isDialogsEnabled(this);
    }

    private void acceptSkippedConfirmation(String tag) {
        if ("ConfirmRules".equals(tag)) {
            startMatchFlow();
            return;
        }
        currentDialog = tag;
        CAN_CLICK = true;
        btnDialogYes.performClick();
    }

    void showDialog(final String message, final String tag, final int timeTalk, final int timeDialog, final int nextMouthId, final boolean gameStatusAfter) {
        if (EXITING || isFinishing() || isDestroyed()) return;
        // Live board deadlines belong to the shared/server clock. Keep their
        // captions readable without withholding the player's ability to answer.
        final boolean blocking = timeDialog <= 0
                || (!gameStatusAfter && !boardOnline && paidDuel == null);
        presenterDialogue.show(message, timeDialog, blocking, () -> {
            if (EXITING || isFinishing() || isDestroyed()) return;
            if (blocking) {
                CAN_PLAY = false;
                CAN_HOME = false;
                CAN_CLICK = false;
                currentDialog = tag;
            }
            btnDialogYes.setVisibility(View.INVISIBLE);
            btnDialogNo.setVisibility(View.INVISIBLE);
            int msgLen = message.replace("\n", "").length();
            txtDialog.setTextSize(TypedValue.COMPLEX_UNIT_SP,
                    msgLen <= 25 ? 15 : msgLen <= 40 ? 13 : msgLen <= 55 ? 11 : 9);
            txtDialog.setCharacterDelay(PresenterDialogue.CHARACTER_DELAY_MS);
            txtDialog.animateText(message, presenterDialogue::textCompleted);
            rlyDialog.setVisibility(View.VISIBLE);
            rlyDialog.bringToFront();
            presenterBubble.show();
            person.talk(Math.max(timeTalk, (msgLen + 1) * PresenterDialogue.CHARACTER_DELAY_MS), nextMouthId);
            presenterBubble.prepare(message, timeDialog <= 0);
            if (timeDialog <= 0) {
                CAN_CLICK = true;
                btnDialogYes.setVisibility(View.VISIBLE);
                btnDialogNo.setVisibility(View.VISIBLE);
                if ("OpponentLeftContinue".equals(tag)) {
                    btnDialogYes.setText("أكمل");
                    btnDialogNo.setText("إنهاء");
                } else if ("EliminationSpectatorChoice".equals(tag)) {
                    btnDialogYes.setText("متابعة");
                    btnDialogNo.setText("خروج");
                } else {
                    btnDialogYes.setText(timeDialog == 0 ? "نعم" : "التالي");
                    btnDialogNo.setText(timeDialog == 0 ? "لا" : "شكرا");
                }
            }
        }, () -> {
            txtDialog.stopAnimation();
            rlyDialog.setVisibility(View.INVISIBLE);
            if (blocking) {
                CAN_PLAY = gameStatusAfter;
                CAN_HOME = true;
                CAN_CLICK = false;
            }
        });
    }
    @Override
    protected void onStop() {
        backgroundGuard.onStop();
        super.onStop();
    }

    @Override
    protected void onPause() {
        presenterDialogue.pause();
        ACTIVITY_PAUSED = true;
        OnlineMatchRecovery.updateLaunch(this);
        if (paidDuel != null) {
            paidDuel.pause();
            cancelPendingBoardReveal();
        }
        if (boardOnline && !boardRoomMatch && !boardDuelFinished && !EXITING && myStatusRef != null) {
            duelNeedsBoardResync = true;
            cancelPendingBoardReveal();
            markMyGameState("away");
        }
        if (offlineContestants != null) offlineContestants.setVideosPaused(true);
        for (ChromaVideoView video : resultVideoViews) video.setPaused(true);
        if (isQuestionTimerRunning && cdtProgress != null) {
            wasTimerRunningBeforePause = true;
            timerPauseElapsedRealtime = SystemClock.elapsedRealtime();
            cdtProgress.cancel();
            cdtProgress = null;
        } else {
            wasTimerRunningBeforePause = false;
        }
        if (boardSelectTimer != null) {
            wasBoardSelectTimerRunningBeforePause = true;
            boardSelectPauseElapsedRealtime = SystemClock.elapsedRealtime();
            boardSelectTimer.cancel();
            boardSelectTimer = null;
        } else {
            wasBoardSelectTimerRunningBeforePause = false;
        }
        if (campaignStageTimer != null) {
            wasCampaignStageTimerRunningBeforePause = true;
            campaignStageTimer.cancel();
            campaignStageTimer = null;
        } else {
            wasCampaignStageTimerRunningBeforePause = false;
        }
        if (boardLocalTeams && boardMode && !localTeamsFinished) {
            boolean safeToSave = boardCurrentQuestion == null || boardAwaitingTypedInput || CAN_PLAY;
            if (safeToSave) {
                saveLocalTeamsProgress(currentLocalTeamsPhase());
            }
        }
        if (shouldSaveOfflineBoard() && !offlineBoardFinished) {
            boolean safeToSave = boardCurrentQuestion == null || boardAwaitingTypedInput || CAN_PLAY;
            if (safeToSave) {
                saveOfflineBoardProgress(currentOfflineBoardPhase());
            }
        }
        if (campaignMode && !campaignResultPersisted && !EXITING) {
            boolean safeToSave = !campaignBoard || boardCurrentQuestion == null || boardAwaitingTypedInput || CAN_PLAY;
            if (safeToSave) {
                saveCampaignProgress(currentOfflineBoardPhase());
            }
        }
        if (backgroundVideoController != null) backgroundVideoController.pause();
        if (soundController != null) soundController.releaseCurrent();
        GameSoundController.release(mpBeep);
        mpBeep = null;
        GameSoundController.release(mpBeep1);
        mpBeep1 = null;
        super.onPause();
    }

    @Override
    protected void onDestroy() {
        presenterDialogue.dispose();
        presenterHandler.removeCallbacksAndMessages(null);
        backgroundGuard.onDestroy();
        duelActivityDestroyed = true;
        if (paidDuel != null) paidDuel.destroy();
        isQuestionTimerRunning = false;
        wasTimerRunningBeforePause = false;
        wasBoardSelectTimerRunningBeforePause = false;
        wasCampaignStageTimerRunningBeforePause = false;
        if (boardKeyboardLayoutListener != null && getWindow() != null && getWindow().getDecorView() != null) {
            getWindow().getDecorView().getViewTreeObserver().removeOnGlobalLayoutListener(boardKeyboardLayoutListener);
            boardKeyboardLayoutListener = null;
        }
        cancelPendingFictitiousAnswer();
        if (isFinishing()) {
            leaveOnlineMatchIfNeeded();
        }
        detachOpponentStatusListener();
        detachOpponentRoundListener();
        detachQuestionSyncListener();
        detachServerTimeOffsetListener();
        detachBoardListeners();
        if(cdtProgress != null) cdtProgress.cancel();
        cancelBoardSelectTimer();
        stopCampaignStageTimer();
        if (offlineContestants != null) offlineContestants.release();
        releaseResultVideos();
        if (soundController != null) soundController.releaseCurrent();
        GameSoundController.release(mpBeep);
        mpBeep = null;
        GameSoundController.release(mpBeep1);
        mpBeep1 = null;
        if (backgroundVideoController != null) backgroundVideoController.stop();
        backgroundVideoController = null;
        if (imageObservationController != null) {
            imageObservationController.dismiss();
        }
        super.onDestroy();
    }

    private boolean isTouchOnView(View v, MotionEvent ev) {
        if (v == null || v.getVisibility() != View.VISIBLE) return false;
        Rect r = new Rect();
        v.getGlobalVisibleRect(r);
        return r.contains((int) ev.getRawX(), (int) ev.getRawY());
    }

    @Override
    public boolean dispatchTouchEvent(MotionEvent ev) {
        if (ev.getAction() == MotionEvent.ACTION_DOWN) {
            if (boardMode && boardAwaitingTypedInput && boardAnswerInput != null && boardAnswerInput.hasFocus()) {
                Rect inRect = new Rect();
                boardAnswerInput.getGlobalVisibleRect(inRect);
                if (!inRect.contains((int) ev.getRawX(), (int) ev.getRawY())) {
                    boolean touchedAction = isTouchOnView(btnBoardRevealOptions, ev)
                            || isTouchOnView(btnBoardSubmitAnswer, ev)
                            || isTouchOnView(btnBoardHideKeyboard, ev)
                            || isTouchOnView(btnBoardConcedeSteal, ev);
                    if (!touchedAction) {
                        hideKeyboard();
                    }
                }
            }
        }
        return super.dispatchTouchEvent(ev);
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

    @Override
    public void onBackPressed() {
        if (boardMode && boardAwaitingTypedInput) {
            if (isBoardKeyboardShowing || (boardAnswerInput != null && boardAnswerInput.hasFocus())) {
                hideKeyboard();
                return;
            }
            // Keyboard is already hidden; player presses Back to switch from typing to 4 options
            onBoardRevealOptions();
            return;
        }

        confirmExit();
        // The board overlay is brought to the front, so lift the exit dialog above
        // it while it is showing, otherwise the confirmation would be hidden.
        if (boardMode && rlyDialog != null) {
            View overlay = findViewById(R.id.boardOverlay);
            if (overlay != null && overlay.getVisibility() == View.VISIBLE) {
                rlyDialog.bringToFront();
            }
        }
    }

    private void initAdsIfNeeded() {
        if (interstitialAdController != null) {
            interstitialAdController.loadIfNeeded(this::navigateToHome);
        }
    }
    private void persistPendingCampaignStageResult(boolean completed, int money, int wrongAnswers) {
        campaignResultStore.persistPendingStageResult(completed, money, wrongAnswers);
        if (campaignResultPersisted) clearCampaignProgress();
    }

    private void updateInventoryBadges() {
        InventoryBadgeUpdater.update(this);
    }

}
