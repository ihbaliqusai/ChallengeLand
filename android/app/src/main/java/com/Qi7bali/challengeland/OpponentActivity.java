package com.qi7bali.landchallengeonline;

import android.animation.ValueAnimator;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.media.MediaPlayer;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.VibrationEffect;
import android.os.Vibrator;
import android.view.View;
import android.view.WindowManager;
import android.view.animation.AccelerateInterpolator;
import android.view.animation.DecelerateInterpolator;
import android.view.animation.LinearInterpolator;
import android.view.animation.OvershootInterpolator;
import android.widget.Button;
import android.widget.ImageView;
import android.widget.TextView;
import android.widget.Toast;

import com.google.firebase.auth.FirebaseAuth;
import com.google.firebase.database.DatabaseError;
import com.google.firebase.functions.FirebaseFunctions;
import com.squareup.picasso.Picasso;

import org.json.JSONArray;
import org.json.JSONObject;

import java.util.Random;
import java.util.Map;
import java.util.HashMap;
import java.util.Locale;

public class OpponentActivity extends GameViewportActivity {

    private static final int BOT_FALLBACK_DELAY_MS = 8000;

    boolean browsingOpponents = false;
    boolean requestAccepted = false;
    boolean ownRequestInserted = false;
    boolean launchingGame = false;
    private boolean resolvingOpponent = false;
    private boolean closed = false;
    private boolean audioPaused = false;
    private MediaPlayer matchmakingSound;
    private String duelSessionId = "";
    private String stakeMatchId = "";
    private boolean stakeCancelling = false;
    private String randomStakeId = "";
    private int randomStakeCoins;
    private Runnable stopRequestListener;
    private final Handler queueHeartbeatHandler = new Handler();
    private final Runnable queueHeartbeat = new Runnable() {
        @Override public void run() {
            if (closed || requestAccepted || launchingGame) return;
            Data.refreshDuelSearch(userID);
            queueHeartbeatHandler.postDelayed(this, 30_000L);
        }
    };
    String userID = "";
    String userName = "";
    String userPhoto = "";
    String matchMode = "";
    String friendCode = "";
    int userLevel = 1;
    int userScore = 0;

    ImageView imgPhoto1, imgPhoto2, imgPhoto21, imgPhoto22;
    TextView txtOpponent1, txtOpponent2, txtLevel1, txtLevel2, txtStatus;
    View btnCancel;

    MatchmakingVersusBadgeView vsBadgeView;
    View cardPlayer, cardOpponent;
    ImageView imgPlayerFrameOverlay, imgOpponentFrameOverlay;
    ImageView imgSearchBackground, imgSplitLeft, imgSplitRight;
    View layoutArena;
    ImageView imgSearchGlass, imgPlayerFlag, imgOpponentFlag;
    TextView txtPlayerSubtitle, txtOpponentSubtitle;
    View layoutPlayerTrophy, layoutOpponentTrophy;
    private ValueAnimator searchGlassAnim;
    private ValueAnimator statusPulseAnim;
    private MatchmakingEffectsView matchmakingEffects;
    private final Handler presentationHandler = new Handler();
    private Runnable pendingPresentationLaunch;
    private final Handler shuffleHandler = new Handler();
    private Runnable shuffleRunnable;

    private final Handler matchmakingHandler = new Handler();
    private Runnable matchmakingRunnable;
    private final Handler cancelButtonHandler = new Handler();
    private Runnable cancelButtonRunnable;
    private final Handler botFallbackHandler = new Handler();
    private Runnable botFallbackRunnable;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        // Also protect legacy entry points and rapid overlapping launch calls.
        if (OnlineMatchRecovery.hasActiveMatch(this, null)) {
            GameNotice.makeText(this, "أكمل المباراة السابقة أو انسحب منها من الشاشة الرئيسية أولًا.", Toast.LENGTH_LONG).show();
            finish();
            return;
        }
        GameViewportActivity.configureWindow(getWindow());
        getWindow().setFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN,
                WindowManager.LayoutParams.FLAG_FULLSCREEN);
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        getWindow().getDecorView().setSystemUiVisibility(
                View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                        | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                        | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                        | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                        | View.SYSTEM_UI_FLAG_FULLSCREEN
                        | View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY);
        setContentView(R.layout.activity_opponent);

        imgPhoto1 = findViewById(R.id.imgPhoto1);
        imgPhoto2 = findViewById(R.id.imgPhoto2);
        imgPhoto21 = findViewById(R.id.imgPhoto21);
        imgPhoto22 = findViewById(R.id.imgPhoto22);
        txtOpponent1 = findViewById(R.id.txtOpponent1);
        txtOpponent2 = findViewById(R.id.txtOpponent2);
        txtLevel1 = findViewById(R.id.txtLevel1);
        txtLevel2 = findViewById(R.id.txtLevel2);
        txtStatus = findViewById(R.id.txtStatus);
        btnCancel = findViewById(R.id.btnCancel);

        imgSearchBackground = findViewById(R.id.imgSearchBackground);
        imgSplitLeft = findViewById(R.id.imgSplitLeft);
        imgSplitRight = findViewById(R.id.imgSplitRight);
        if (imgSplitLeft != null) imgSplitLeft.setVisibility(View.INVISIBLE);
        if (imgSplitRight != null) imgSplitRight.setVisibility(View.INVISIBLE);

        vsBadgeView = findViewById(R.id.vsBadgeView);
        cardPlayer = findViewById(R.id.cardPlayer);
        cardOpponent = findViewById(R.id.cardOpponent);
        layoutArena = findViewById(R.id.layoutArena);
        matchmakingEffects = findViewById(R.id.matchmakingEffects);
        imgPlayerFrameOverlay = findViewById(R.id.imgPlayerFrameOverlay);
        imgOpponentFrameOverlay = findViewById(R.id.imgOpponentFrameOverlay);
        imgSearchGlass = findViewById(R.id.imgSearchGlass);
        imgPlayerFlag = findViewById(R.id.imgPlayerFlag);
        imgOpponentFlag = findViewById(R.id.imgOpponentFlag);
        txtPlayerSubtitle = findViewById(R.id.txtPlayerSubtitle);
        txtOpponentSubtitle = findViewById(R.id.txtOpponentSubtitle);
        layoutPlayerTrophy = findViewById(R.id.layoutPlayerTrophy);
        layoutOpponentTrophy = findViewById(R.id.layoutOpponentTrophy);

        btnCancel.setVisibility(View.VISIBLE);
        btnCancel.setOnClickListener(v -> {
            if (launchingGame) return;
            if (!stakeMatchId.isEmpty()) { leaveStakeIntro(); return; }
            if (!randomStakeId.isEmpty()) { cancelRandomSearch(); return; }
            cleanupPendingRequest();
            finish();
        });

        SharedPreferences settings = getSharedPreferences("UserInfo", 0);
        userID = settings.getString("userID", "");
        userName = settings.getString("userName", "");
        userPhoto = settings.getString("userPhoto", "");
        userLevel = settings.getInt("userLevel", 1);
        userScore = settings.getInt("userScore", 0);

        if (userID.isEmpty()) {
            try {
                if (FirebaseAuth.getInstance().getCurrentUser() != null) {
                    userID = FirebaseAuth.getInstance().getCurrentUser().getUid();
                }
            } catch (Exception ignored) {}
        }
        if (userName.isEmpty()) {
            try {
                if (FirebaseAuth.getInstance().getCurrentUser() != null) {
                    userName = FirebaseAuth.getInstance().getCurrentUser().getDisplayName();
                }
            } catch (Exception ignored) {}
            if (userName == null || userName.isEmpty()) {
                userName = "بطل التحدي";
            }
        }

        matchMode = getIntent().getStringExtra("matchMode") == null ? "" : getIntent().getStringExtra("matchMode");
        friendCode = getIntent().getStringExtra("friendCode") == null ? "" : getIntent().getStringExtra("friendCode").trim().toUpperCase();
        stakeMatchId = getIntent().getStringExtra("stakeMatchId") == null ? "" : getIntent().getStringExtra("stakeMatchId");
        randomStakeCoins = getIntent().getIntExtra("stakeCoins", 0);
        if (stakeMatchId.isEmpty() && randomStakeCoins != 0) {
            randomStakeId = savedInstanceState == null ? getIntent().getStringExtra("randomStakeId")
                    : savedInstanceState.getString("randomStakeId");
            if (randomStakeId == null || randomStakeId.isEmpty()) randomStakeId = java.util.UUID.randomUUID().toString();
            getIntent().putExtra("randomStakeId", randomStakeId);
            try {
                if (!RandomStakeLedger.reserve(this, randomStakeId, randomStakeCoins)) {
                    GameNotice.makeText(this, "رصيدك لا يكفي أو أن مبلغ المباراة غير صالح.", Toast.LENGTH_LONG).show();
                    finish(); return;
                }
            } catch (RuntimeException failure) {
                GameNotice.makeText(this, "تعذر حفظ حجز القطع. حاول مجددًا.", Toast.LENGTH_LONG).show();
                finish(); return;
            }
        }

        txtOpponent1.setText(userName);
        Data.setImageSource(this, imgPhoto1, userPhoto);

        int myTrophies = PlayerStats.getTrophies(this);
        if (myTrophies <= 0) myTrophies = userScore;
        if (myTrophies <= 0) myTrophies = 50;
        txtLevel1.setText(String.format(Locale.getDefault(), "%,d", myTrophies));

        if (txtPlayerSubtitle != null) {
            txtPlayerSubtitle.setText("أنت  •  المستوى " + userLevel);
        }

        setupPlayerFlag();
        setupStakeBanner();
        startStatusPulseAnimation();
        startMagnifyingGlassSearchAnimation();

        Data.syncUserProfile(userID, userName, userPhoto, userLevel, userScore);
        Data.setUserActive(userID);

        startBrowsingOpponents();
        if (!stakeMatchId.isEmpty()) {
            requestAccepted = true;
            loadStakedOpponent();
            return;
        }
        ownRequestInserted = true;
        Data.resetDuelSearch(userID, "friend".equals(matchMode) ? "__friend_pending__" : "", randomStakeCoins, () -> {
            if (closed || isFinishing()) return;
            queueHeartbeatHandler.postDelayed(queueHeartbeat, 30_000L);
            if ("friend".equals(matchMode) && !friendCode.isEmpty()) {
                if (btnCancel != null) {
                    btnCancel.setVisibility(View.VISIBLE);
                }
                startFriendInviteFlow();
            } else {
                startRandomMatchFlow();
            }
        }, error -> {
            if (closed || isFinishing()) return;
            setStatus("تعذر بدء البحث. تحقق من الاتصال وأعد المحاولة.");
            if (btnCancel != null) btnCancel.setVisibility(View.VISIBLE);
        });
    }

    private void scheduleCancelButton() {
        cancelButtonRunnable = () -> {
            if (!launchingGame && btnCancel != null) {
                btnCancel.setVisibility(View.VISIBLE);
            }
        };
        cancelButtonHandler.postDelayed(cancelButtonRunnable, 3000);
    }

    /** Accepted paid invitations use this same opponent intro without creating a second RTDB match. */
    private void loadStakedOpponent() {
        if (closed || launchingGame || resolvingOpponent) return;
        resolvingOpponent = true;
        setStatus("جاري تجهيز المواجهة...");
        Map<String, Object> request = new HashMap<>();
        request.put("action", "sync"); request.put("matchId", stakeMatchId);
        FirebaseFunctions.getInstance("us-central1").getHttpsCallable("friendStakes").call(request)
            .addOnSuccessListener(response -> {
                resolvingOpponent = false;
                if (closed || launchingGame || isFinishing()) return;
                try {
                    Map<?, ?> payload = (Map<?, ?>) response.getData();
                    Map<?, ?> match = (Map<?, ?>) payload.get("match");
                    String owner = String.valueOf(match.get("ownerId"));
                    String joiner = String.valueOf(match.get("joinerId"));
                    if (!stakeMatchId.equals(match.get("matchId"))
                        || !(userID.equals(owner) || userID.equals(joiner))
                        || !(match.get("protocolVersion") instanceof Number)
                        || ((Number) match.get("protocolVersion")).intValue() != 2) {
                        stakeIntroError("أرسل دعوة جديدة بالتحديث الحالي للعب التحدي الأصلي."); return;
                    }
                    if ("settled".equals(match.get("status"))) {
                        GameNotice.makeText(this, "انتهت هذه المواجهة وتمت تسوية القطع.", Toast.LENGTH_LONG).show();
                        finish(); return;
                    }
                    duelSessionId = stakeMatchId;
                    final boolean ownerSeat = userID.equals(owner);
                    final String peer = ownerSeat ? joiner : owner;
                    matchmakingHandler.postDelayed(() -> {
                        if (closed || launchingGame || isFinishing()) return;
                        User player = new User(peer); player.name = "صديقك";
                        stopBrowsingOpponents(player, ownerSeat);
                    }, 4000L);
                    new Data().getUserFromFirebase(peer, new OnGetUserInfoListener() {
                        @Override public void onStart() {}
                        @Override public void onSuccess(User player) {
                            if (closed || launchingGame || isFinishing()) return;
                            if (player == null) player = new User(peer);
                            player.id = peer;
                            if (player.name == null || player.name.trim().isEmpty()) player.name = "صديقك";
                            stopBrowsingOpponents(player, ownerSeat);
                        }
                        @Override public void onFailed(DatabaseError error) {
                            if (closed || launchingGame || isFinishing()) return;
                            User player = new User(peer); player.name = "صديقك";
                            stopBrowsingOpponents(player, ownerSeat);
                        }
                    });
                } catch (RuntimeException invalid) {
                    stakeIntroError("تعذر تحميل بيانات المواجهة. أعد المحاولة.");
                }
            }).addOnFailureListener(error -> {
                resolvingOpponent = false;
                if (!closed && !isFinishing()) stakeIntroError("تعذر الاتصال. تحقق من الإنترنت وأعد المحاولة.");
            });
    }

    private void stakeIntroError(String message) {
        GameNoticeDialogs.platformBuilder(this).setMessage(message).setCancelable(false)
            .setPositiveButton("إعادة المحاولة", (dialog, which) -> loadStakedOpponent())
            .setNegativeButton("رجوع", (dialog, which) -> leaveStakeIntro()).show();
    }

    private void leaveStakeIntro() {
        if (stakeCancelling || closed || launchingGame) return;
        GameNoticeDialogs.platformBuilder(this).setTitle("مغادرة التحدي؟")
            .setMessage("قبل بدء اللعب تُعاد القطع. إذا بدأت المباراة فالانسحاب يُحسب خسارة.")
            .setNegativeButton("متابعة", null)
            .setPositiveButton("مغادرة", (dialog, which) -> {
                stakeCancelling = true;
                Map<String, Object> request = new HashMap<>();
                request.put("action", "forfeit"); request.put("matchId", stakeMatchId);
                request.put("operationId", "intro_leave_" + stakeMatchId);
                FirebaseFunctions.getInstance("us-central1").getHttpsCallable("friendStakes").call(request)
                    .addOnCompleteListener(result -> {
                        stakeCancelling = false;
                        if (isFinishing() || isDestroyed()) return;
                        if (result.isSuccessful()) { cleanupPendingRequest(); finish(); }
                        else GameNotice.makeText(this, "تعذر تأكيد المغادرة. تحقق من الاتصال وحاول مجددًا.", Toast.LENGTH_LONG).show();
                    });
            }).show();
    }

    private void startFriendInviteFlow() {
        setStatus("جاري التحقق من كود الصديق...");
        String normalizedFriendCode = Data.normalizeFriendCode(friendCode);
        new Data().getUserIdByFriendCode(normalizedFriendCode, new OnGetGameIdListener() {
            @Override
            public void onSuccess(final String targetUserId) {
                if (closed || launchingGame) {
                    return;
                }
                if (targetUserId == null || targetUserId.trim().isEmpty()) {
                    GameNotice.makeText(OpponentActivity.this, "كود الصديق غير صحيح أو غير مسجل", Toast.LENGTH_LONG).show();
                    finish();
                    return;
                }
                if (targetUserId.equals(userID)) {
                    GameNotice.makeText(OpponentActivity.this, "لا يمكنك تحدي نفسك", Toast.LENGTH_SHORT).show();
                    finish();
                    return;
                }

                // Try claiming existing request from target first
                claimFriendRequest(targetUserId, new OnRandomRequestListener() {
                    @Override
                    public void onStart() {}

                    @Override
                    public void onSuccess(String idOpponent) {
                        if (closed || launchingGame) {
                            return;
                        }
                        if (idOpponent != null && !idOpponent.isEmpty() && !"null".equals(idOpponent)) {
                            requestAccepted = true;
                            setStatus("تم قبول التحدي! جاري تجهيز المواجهة...");
                            resolveOpponentAndLaunch(idOpponent, false);
                            return;
                        }

                        // No active request from target yet -> create our own and wait
                        ownRequestInserted = true;
                        Data.insertRequest(userID, targetUserId);
                        waitForAcceptedRequest();
                        setStatus("تم إرسال الدعوة. بانتظار دخول صديقك...");
                        scheduleFriendPolling(targetUserId);
                    }

                    @Override
                    public void onFailed(DatabaseError error) {
                        if (closed || launchingGame) return;
                        ownRequestInserted = true;
                        Data.insertRequest(userID, targetUserId);
                        waitForAcceptedRequest();
                        setStatus("تم إرسال الدعوة. بانتظار دخول صديقك...");
                        scheduleFriendPolling(targetUserId);
                    }
                });
            }

            @Override
            public void onFailed(DatabaseError error) {
                GameNotice.makeText(OpponentActivity.this, "تعذر العثور على الصديق الآن", Toast.LENGTH_SHORT).show();
                finish();
            }
        });
    }

    private void claimFriendRequest(String targetUserId, OnRandomRequestListener listener) {
        new Data().claimFriendRequest(userID, targetUserId, listener,
            !getIntent().getBooleanExtra("socialAccepted", false));
    }

    private void scheduleFriendPolling(final String targetUserId) {
        if (launchingGame || requestAccepted) {
            return;
        }
        matchmakingHandler.removeCallbacks(matchmakingRunnable);
        matchmakingRunnable = new Runnable() {
            @Override
            public void run() {
                if (!closed && !requestAccepted && !launchingGame) {
                    claimFriendRequest(targetUserId, new OnRandomRequestListener() {
                        @Override
                        public void onStart() {}

                        @Override
                        public void onSuccess(String idOpponent) {
                            if (closed || launchingGame) return;
                            if (idOpponent != null && !idOpponent.isEmpty() && !"null".equals(idOpponent)) {
                                requestAccepted = true;
                                setStatus("تم قبول التحدي! جاري بدء المواجهة...");
                                resolveOpponentAndLaunch(idOpponent, false);
                                return;
                            }
                            scheduleFriendPolling(targetUserId);
                        }

                        @Override
                        public void onFailed(DatabaseError error) {
                            scheduleFriendPolling(targetUserId);
                        }
                    });
                }
            }
        };
        matchmakingHandler.postDelayed(matchmakingRunnable, 2000);
    }

    private void startRandomMatchFlow() {
        setStatus("جاري البحث عن منافس عبر الإنترنت...");
        waitForAcceptedRequest();
        tryClaimAvailableOpponent();
        scheduleBotFallback();
    }

    private void scheduleBotFallback() {
        botFallbackHandler.removeCallbacksAndMessages(null);
        botFallbackRunnable = new Runnable() {
            @Override
            public void run() {
                if (!closed && !requestAccepted && !launchingGame && !"friend".equals(matchMode)) {
                    Data.withdrawDuelSearch(userID, new OnGetGameIdListener() {
                        @Override public void onSuccess(String opponent) {
                            if (closed || launchingGame) return;
                            if (opponent.isEmpty()) launchBotMatch();
                            else resolveOpponentAndLaunch(opponent, false);
                        }
                        @Override public void onFailed(DatabaseError error) { scheduleBotFallback(); }
                    });
                }
            }
        };
        botFallbackHandler.postDelayed(botFallbackRunnable, BOT_FALLBACK_DELAY_MS);
    }

    private void tryClaimAvailableOpponent() {
        if (closed || launchingGame) {
            return;
        }
        new Data().getRandomRequest(userID, randomStakeCoins, new OnRandomRequestListener() {
            @Override
            public void onStart() {
            }

            @Override
            public void onSuccess(String idOpponent) {
                if (closed || launchingGame) {
                    return;
                }
                if (idOpponent != null && !idOpponent.isEmpty() && !"null".equals(idOpponent)) {
                    requestAccepted = true;
                    resolveOpponentAndLaunch(idOpponent, false);
                    return;
                }
                if (!ownRequestInserted) {
                    ownRequestInserted = true;
                    Data.insertRequest(userID);
                    setStatus("لم يتم العثور على خصم فورًا. بانتظار لاعب آخر...");
                }
                scheduleRetry();
            }

            @Override
            public void onFailed(DatabaseError error) {
                scheduleRetry();
            }
        });
    }

    private void waitForAcceptedRequest() {
        if (stopRequestListener != null) stopRequestListener.run();
        stopRequestListener = new Data().getRequestResponse(userID, new OnGetRequestResponseListener() {
            @Override
            public void onStart() {
            }

            @Override
            public void onSuccess(String opponentID) {
                if (closed || launchingGame) {
                    return;
                }
                if (opponentID != null && !opponentID.isEmpty() && !"0".equals(opponentID)) {
                    requestAccepted = true;
                    resolveOpponentAndLaunch(opponentID, true);
                }
            }

            @Override
            public void onFailed(DatabaseError error) {
            }
        });
    }

    private void resolveOpponentAndLaunch(final String opponentId, final boolean ignoredOwner) {
        if (closed || launchingGame || resolvingOpponent) return;
        resolvingOpponent = true;
        requestAccepted = true;
        botFallbackHandler.removeCallbacksAndMessages(null);
        queueHeartbeatHandler.removeCallbacksAndMessages(null);
        new Data().getMatchedSession(userID, opponentId, new OnGetGameIdListener() {
            @Override public void onSuccess(String sessionId) {
                if (closed || launchingGame) return;
                if (sessionId.isEmpty()) {
                    resolvingOpponent = false;
                    setStatus("تعذر التحقق من المباراة. أعد البحث عن منافس.");
                    return;
                }
                duelSessionId = sessionId;
                loadMatchedOpponent(opponentId);
            }
            @Override public void onFailed(DatabaseError error) {
                resolvingOpponent = false;
                setStatus("تعذر الاتصال. جارٍ إعادة التحقق من المباراة…");
                matchmakingHandler.postDelayed(() -> resolveOpponentAndLaunch(opponentId, false), 1500);
            }
        });
    }

    private void loadMatchedOpponent(final String opponentId) {
        final boolean meOwner = userID.compareTo(opponentId) < 0;
        new Data().getUserFromFirebase(opponentId, new OnGetUserInfoListener() {
            @Override
            public void onStart() {
            }

            @Override
            public void onSuccess(User user) {
                if (closed || launchingGame) {
                    return;
                }
                if (user == null) {
                    resolvingOpponent = false;
                    GameNotice.makeText(OpponentActivity.this, "تعذر تحميل بيانات المنافس", Toast.LENGTH_SHORT).show();
                    return;
                }
                user.id = opponentId;
                stopBrowsingOpponents(user, meOwner);
            }

            @Override
            public void onFailed(DatabaseError error) {
                if (closed || launchingGame) return;
                matchmakingHandler.postDelayed(() -> {
                    if (!closed && !launchingGame) loadMatchedOpponent(opponentId);
                }, 1500);
            }
        });
    }

    private void scheduleRetry() {
        if (launchingGame || "friend".equals(matchMode)) {
            return;
        }
        matchmakingHandler.removeCallbacks(matchmakingRunnable);
        matchmakingRunnable = new Runnable() {
            @Override
            public void run() {
                if (!closed && !requestAccepted && !launchingGame) {
                    tryClaimAvailableOpponent();
                }
            }
        };
        matchmakingHandler.postDelayed(matchmakingRunnable, 2000);
    }

    private void setupPlayerFlag() {
        try {
            if (imgPlayerFlag == null) return;
            String country = DeviceCountry.getCountryCode(this);
            int flag = R.drawable.ic_flag_palestine;
            if ("SA".equalsIgnoreCase(country)) flag = R.drawable.ic_flag_saudi;
            else if ("EG".equalsIgnoreCase(country)) flag = R.drawable.ic_flag_egypt;
            imgPlayerFlag.setImageResource(flag);
            imgPlayerFlag.setVisibility(View.VISIBLE);
        } catch (Exception ignored) {}
    }

    private void setupOpponentFlag() {
        try {
            if (imgOpponentFlag == null) return;
            int[] flagDrawables = {
                    R.drawable.ic_flag_palestine,
                    R.drawable.ic_flag_saudi,
                    R.drawable.ic_flag_egypt
            };
            int flag = flagDrawables[(new Random()).nextInt(flagDrawables.length)];
            imgOpponentFlag.setImageResource(flag);
            imgOpponentFlag.setVisibility(View.VISIBLE);
        } catch (Exception ignored) {}
    }

    private void setupStakeBanner() {
        // Bottom stake banner removed per user request
    }

    private void startStatusPulseAnimation() {
        if (txtStatus == null) return;
        if (statusPulseAnim != null) statusPulseAnim.cancel();
        statusPulseAnim = ValueAnimator.ofFloat(0.65f, 1.0f);
        statusPulseAnim.setDuration(900);
        statusPulseAnim.setRepeatCount(ValueAnimator.INFINITE);
        statusPulseAnim.setRepeatMode(ValueAnimator.REVERSE);
        statusPulseAnim.addUpdateListener(anim -> {
            if (!launchingGame && txtStatus != null) {
                txtStatus.setAlpha((float) anim.getAnimatedValue());
            }
        });
        statusPulseAnim.start();
    }

    private void startMagnifyingGlassSearchAnimation() {
        if (imgSearchGlass == null) return;
        if (searchGlassAnim != null) searchGlassAnim.cancel();
        searchGlassAnim = ValueAnimator.ofFloat(0f, (float) (Math.PI * 2));
        searchGlassAnim.setDuration(2200);
        searchGlassAnim.setRepeatCount(ValueAnimator.INFINITE);
        searchGlassAnim.setInterpolator(new LinearInterpolator());
        searchGlassAnim.addUpdateListener(anim -> {
            if (!launchingGame && imgSearchGlass != null) {
                float angle = (float) anim.getAnimatedValue();
                float f = (1f + (float) Math.sin(angle)) * 0.5f;
                float density = getResources().getDisplayMetrics().density;
                imgSearchGlass.setScaleX(0.92f + 0.16f * f);
                imgSearchGlass.setScaleY(0.92f + 0.16f * f);
                imgSearchGlass.setRotation(-8f + 16f * f);
                imgSearchGlass.setTranslationX((float) Math.sin(angle) * 3f * density);
                imgSearchGlass.setTranslationY((float) Math.cos(angle) * 4f * density);
            }
        });
        searchGlassAnim.start();
    }

    private void playSoundEffect(int rawResId) {
        playMatchmakingSound(rawResId, false);
    }

    private void startSearchSound() {
        if (!browsingOpponents || launchingGame || matchmakingSound != null) return;
        playMatchmakingSound(R.raw.lets_play, true);
    }

    private void playMatchmakingSound(int rawResId, boolean looping) {
        stopMatchmakingSound();
        try {
            if (audioPaused || closed || isFinishing() || isDestroyed()
                    || !AppPrefs.isSoundEnabled(this)) return;
            MediaPlayer player = MediaPlayer.create(this, rawResId);
            if (player != null) {
                matchmakingSound = player;
                float gain = GameAudioProfile.effectVolume(rawResId) * (looping ? 0.4f : 1f);
                player.setLooping(looping);
                player.setVolume(gain, gain);
                player.setOnCompletionListener(completed -> {
                    if (matchmakingSound == completed) matchmakingSound = null;
                    GameSoundController.release(completed);
                });
                player.setOnErrorListener((failed, what, extra) -> {
                    if (matchmakingSound == failed) matchmakingSound = null;
                    GameSoundController.release(failed);
                    return true;
                });
                player.start();
            }
        } catch (Exception ignored) { stopMatchmakingSound(); }
    }

    private void stopMatchmakingSound() {
        MediaPlayer player = matchmakingSound;
        matchmakingSound = null;
        GameSoundController.release(player);
    }

    private void playOpponentFoundSound() {
        playSoundEffect(R.raw.match_opponent_found);
    }

    private void playVersusSlamSound() {
        playSoundEffect(R.raw.match_versus_slam);
    }

    private void performHapticImpact() {
        try {
            if (!AppPrefs.isHapticEnabled(this)) return;
            Vibrator v = (Vibrator) getSystemService(Context.VIBRATOR_SERVICE);
            if (v != null && v.hasVibrator()) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    v.vibrate(VibrationEffect.createOneShot(70, VibrationEffect.DEFAULT_AMPLITUDE));
                } else {
                    v.vibrate(70);
                }
            }
        } catch (Exception ignored) {}
    }

    private void startBrowsingOpponents() {
        browsingOpponents = true;
        startSearchSound();
        final int duration = 150;

        shuffleRunnable = new Runnable() {
            private boolean toggle = false;

            @Override
            public void run() {
                if (!browsingOpponents || closed || isFinishing()) return;
                ImageView activeView = toggle ? imgPhoto21 : imgPhoto22;
                ImageView inactiveView = toggle ? imgPhoto22 : imgPhoto21;
                setRandomOpponentImage(activeView, 14);

                activeView.setAlpha(0f);
                activeView.setTranslationY(16f);
                activeView.setVisibility(View.VISIBLE);
                activeView.animate().alpha(1f).translationY(0f).setDuration(duration).start();

                inactiveView.animate().alpha(0f).translationY(-16f).setDuration(duration)
                        .withEndAction(() -> inactiveView.setVisibility(View.INVISIBLE)).start();

                toggle = !toggle;
                shuffleHandler.postDelayed(this, duration);
            }
        };
        shuffleHandler.post(shuffleRunnable);
    }

    /** Reveal, hold the matched player, then carry the showdown into the gameplay wipe. */
    private void playOpponentFoundTransition(String oppName, String oppPhoto, int oppLevel, int oppScore, boolean isBot, Runnable onFinish) {
        browsingOpponents = false;
        if (layoutArena != null) {
            layoutArena.animate().cancel();
            layoutArena.setTranslationY(0f);
        }
        if (vsBadgeView != null) vsBadgeView.stopSearchMotion();
        shuffleHandler.removeCallbacksAndMessages(null);
        presentationHandler.removeCallbacksAndMessages(null);
        for (ImageView image : new ImageView[]{imgPhoto21, imgPhoto22}) {
            if (image != null) image.animate().cancel();
        }

        // Keep the back button visible until the versus panels arrive.
        if (btnCancel != null) {
            btnCancel.setEnabled(false);
        }

        // Stop the searching motion as the card contracts into the reveal glow.
        if (searchGlassAnim != null) {
            searchGlassAnim.cancel();
            searchGlassAnim = null;
        }
        if (imgSearchGlass != null) {
            imgSearchGlass.animate().scaleX(0f).scaleY(0f).alpha(0f).setStartDelay(120).setDuration(160)
                    .withEndAction(() -> imgSearchGlass.setVisibility(View.GONE)).start();
        }

        if (statusPulseAnim != null) {
            statusPulseAnim.cancel();
            statusPulseAnim = null;
        }
        if (txtStatus != null) {
            txtStatus.setText("تم العثور على منافس!");
            txtStatus.setTextColor(0xFFFFFFFF);
            txtStatus.setAlpha(1f);
            txtStatus.setScaleX(1f);
            txtStatus.setScaleY(1f);
        }

        playOpponentFoundSound();
        if (matchmakingEffects != null && cardOpponent != null) {
            matchmakingEffects.playOpponentReveal(cardOpponent);
        }

        // Collapse into a tiny glowing tile before revealing the matched portrait.
        if (cardOpponent != null) {
            cardOpponent.animate().scaleX(0.18f).scaleY(0.18f).setDuration(200)
                    .setInterpolator(new AccelerateInterpolator()).start();
            presentationHandler.postDelayed(() -> {
                        if (closed || isFinishing()) return;
                        if (imgPhoto21 != null) { imgPhoto21.clearAnimation(); imgPhoto21.setVisibility(View.INVISIBLE); }
                        if (imgPhoto22 != null) { imgPhoto22.clearAnimation(); imgPhoto22.setVisibility(View.INVISIBLE); }

                        cardOpponent.setBackgroundResource(R.drawable.bg_card_opponent_found_frame);
                        if (imgOpponentFrameOverlay != null) {
                            imgOpponentFrameOverlay.setImageResource(R.drawable.img_frame_opponent_found);
                        }

                        if (imgPhoto2 != null) {
                            imgPhoto2.setVisibility(View.VISIBLE);
                            if (isBot || oppPhoto == null || oppPhoto.trim().isEmpty()) {
                                setRandomOpponentImage(imgPhoto2, 14);
                            } else if (oppPhoto.startsWith("drawable:")) {
                                Data.setImageSource(OpponentActivity.this, imgPhoto2, oppPhoto);
                            } else {
                                Picasso.with(OpponentActivity.this).load(oppPhoto)
                                        .placeholder(R.drawable.user).error(R.drawable.user)
                                        .noFade().fit().centerCrop().into(imgPhoto2);
                            }
                            imgPhoto2.setAlpha(1f);
                            imgPhoto2.setScaleX(1f);
                            imgPhoto2.setScaleY(1f);
                        }

                        if (txtOpponent2 != null) {
                            txtOpponent2.setText(oppName);
                        }
                        if (txtOpponentSubtitle != null) {
                            txtOpponentSubtitle.setText("المستوى " + oppLevel);
                            txtOpponentSubtitle.setTextColor(0xFFD4F038);
                        }
                        if (txtLevel2 != null) {
                            int oppTrophies = oppScore > 0 ? oppScore : Math.max(50, oppLevel * 25 + (new Random()).nextInt(30));
                            txtLevel2.setText(String.format(Locale.getDefault(), "%,d", oppTrophies));
                        }
                        setupOpponentFlag();

                        // Zoom forward punch (frame_013.png)
                        cardOpponent.animate().scaleX(1.08f).scaleY(1.08f).alpha(1.0f).setStartDelay(0).setDuration(230)
                                .setInterpolator(new OvershootInterpolator(1.3f))
                                .withEndAction(() -> cardOpponent.animate().scaleX(1.0f).scaleY(1.0f).setDuration(120).start())
                                .start();

                        // Opponent trophy pill pops in
                        if (layoutOpponentTrophy != null) {
                            layoutOpponentTrophy.setVisibility(View.VISIBLE);
                            layoutOpponentTrophy.setScaleX(0.2f);
                            layoutOpponentTrophy.setScaleY(0.2f);
                            layoutOpponentTrophy.setAlpha(0f);
                            layoutOpponentTrophy.animate().scaleX(1.0f).scaleY(1.0f).alpha(1.0f).setDuration(240)
                                    .setInterpolator(new OvershootInterpolator(2.0f)).start();
                        }
                    }, 220);
        }

        // Let the revealed opponent read clearly before the fast diagonal slam.
        presentationHandler.postDelayed(() -> {
            if (closed || isFinishing()) return;
            if (btnCancel != null) {
                btnCancel.animate().alpha(0f).setDuration(120)
                        .withEndAction(() -> btnCancel.setVisibility(View.GONE)).start();
            }

            final int screenW = Math.max(1000, getResources().getDisplayMetrics().widthPixels);

            // Close the two split shutters (Purple from left, Orange from right)
            if (imgSplitLeft != null && imgSplitRight != null) {
                imgSplitLeft.setVisibility(View.VISIBLE);
                imgSplitRight.setVisibility(View.VISIBLE);
                imgSplitLeft.setTranslationX(-screenW);
                imgSplitRight.setTranslationX(screenW);

                imgSplitLeft.animate()
                        .translationX(0f)
                        .setDuration(180)
                        .setInterpolator(new DecelerateInterpolator(2.2f))
                        .start();

                imgSplitRight.animate()
                        .translationX(0f)
                        .setDuration(180)
                        .setInterpolator(new DecelerateInterpolator(2.2f))
                        .withEndAction(this::playShowdownImpact)
                        .start();
            } else {
                playShowdownImpact();
            }

            // Top status text fades out (matching frame_014.png)
            if (txtStatus != null) {
                txtStatus.animate().alpha(0f).setDuration(200).start();
            }
        }, 900);

        // Carry the showdown at its original position into the horizontal door wipe.
        presentationHandler.postDelayed(() -> finishOpponentPresentation(onFinish), 2300);
    }

    private void playShowdownImpact() {
        if (closed || isFinishing()) return;
        playVersusSlamSound();
        performHapticImpact();
        if (matchmakingEffects != null) matchmakingEffects.playVersusImpact();
        if (vsBadgeView != null) vsBadgeView.explodeToGoldenVersus();
        for (View card : new View[]{cardPlayer, cardOpponent}) {
            if (card == null) continue;
            card.animate().scaleX(1.08f).scaleY(1.08f).setStartDelay(0).setDuration(100)
                    .withEndAction(() -> card.animate().scaleX(1f).scaleY(1f)
                            .setDuration(100).start()).start();
        }
    }

    private void finishOpponentPresentation(Runnable onFinish) {
        if (closed || isFinishing()) return;
        if (audioPaused) {
            pendingPresentationLaunch = () -> finishOpponentPresentation(onFinish);
            return;
        }
        pendingPresentationLaunch = null;
        if (layoutArena != null) {
            MatchmakingGameTransition.capture(layoutArena.getRootView(), vsBadgeView);
        }
        onFinish.run();
    }

    private void stopBrowsingOpponents(final User opponent, final boolean meOwner) {
        if (launchingGame || closed || !activateRandomStake()) return;
        launchingGame = true;
        requestAccepted = true;
        botFallbackHandler.removeCallbacksAndMessages(null);
        cancelButtonHandler.removeCallbacks(cancelButtonRunnable);
        matchmakingHandler.removeCallbacksAndMessages(null);
        if (ownRequestInserted) {
            ownRequestInserted = false;
        }

        playOpponentFoundTransition(opponent.name, opponent.photo, opponent.level, opponent.score, false, () -> {
            if (closed || isFinishing()) return;
            Intent intent = new Intent(OpponentActivity.this, GameActivity.class);
            intent.putExtra("openSplitDoorsTransition", true);
            intent.putExtra("mode", "online");
            intent.putExtra("meOwner", meOwner);
            intent.putExtra("duelSessionId", duelSessionId);
            if (!stakeMatchId.isEmpty()) {
                intent.putExtra("stakeMatchId", stakeMatchId);
                intent.putExtra("stakeGameplayVersion", 2);
            }
            int stakeCoins = getIntent().getIntExtra("stakeCoins", 0);
            if (stakeCoins > 0) {
                intent.putExtra("stakeCoins", stakeCoins);
                intent.putExtra("randomStakeId", randomStakeId);
            }
            intent.putExtra("matchMode", "board");
            intent.putExtra("characterIndex", AppPrefs.getEffectiveCharacter(OpponentActivity.this));
            try {
                JSONObject opponentJson = new JSONObject();
                opponentJson.put("id", opponent.id);
                opponentJson.put("name", opponent.name);
                opponentJson.put("photo", opponent.photo != null ? opponent.photo : "");
                opponentJson.put("level", opponent.level);
                opponentJson.put("score", opponent.score);
                opponentJson.put("bot", false);
                JSONArray opponentsArray = new JSONArray();
                opponentsArray.put(opponentJson);
                intent.putExtra("opponentsJson", opponentsArray.toString());
            } catch (Exception e) {
                intent.putExtra("opponentsJson", "[]");
            }
            startActivity(intent);
            overridePendingTransition(0, 0);
            finish();
        });
    }

    private void launchBotMatch() {
        if (launchingGame || closed || !activateRandomStake()) return;
        launchingGame = true;
        requestAccepted = true;
        botFallbackHandler.removeCallbacksAndMessages(null);
        cancelButtonHandler.removeCallbacks(cancelButtonRunnable);
        matchmakingHandler.removeCallbacksAndMessages(null);
        if (ownRequestInserted) {
            Data.cancelRequest(userID);
            ownRequestInserted = false;
        }

        final int stakeCoins = getIntent().getIntExtra("stakeCoins", 0);
        final int botIntel;
        final int botLevel;
        if (stakeCoins <= 0) {
            botIntel = 50;
            botLevel = 5;
        } else if (stakeCoins <= 100) {
            botIntel = 68;
            botLevel = 7;
        } else if (stakeCoins <= 500) {
            botIntel = 80;
            botLevel = 8;
        } else if (stakeCoins <= 2000) {
            botIntel = 90;
            botLevel = 9;
        } else {
            botIntel = 96;
            botLevel = 10;
        }

        int botTrophies = Math.max(50, botLevel * 25 + (new Random()).nextInt(30));

        playOpponentFoundTransition("الكمبيوتر", "", botLevel, botTrophies, true, () -> {
            if (closed || isFinishing()) return;
            Intent intent = new Intent(OpponentActivity.this, GameActivity.class);
            intent.putExtra("openSplitDoorsTransition", true);
            intent.putExtra("mode", "online");
            intent.putExtra("meOwner", true);
            intent.putExtra("matchMode", "board");
            if (stakeCoins > 0) {
                intent.putExtra("stakeCoins", stakeCoins);
                intent.putExtra("randomStakeId", randomStakeId);
            }
            intent.putExtra("characterIndex", AppPrefs.getEffectiveCharacter(OpponentActivity.this));
            try {
                JSONObject opponentJson = new JSONObject();
                opponentJson.put("id", "fictitious");
                opponentJson.put("name", "الكمبيوتر");
                opponentJson.put("photo", "");
                opponentJson.put("level", botLevel);
                opponentJson.put("score", 0);
                opponentJson.put("intelligence", botIntel);
                opponentJson.put("bot", true);
                JSONArray opponentsArray = new JSONArray();
                opponentsArray.put(opponentJson);
                intent.putExtra("opponentsJson", opponentsArray.toString());
            } catch (Exception e) {
                intent.putExtra("opponentsJson", "[]");
            }
            startActivity(intent);
            overridePendingTransition(0, 0);
            finish();
        });
    }

    private void setRandomOpponentImage(ImageView img, int maxNumber) {
        int rnd = (new Random()).nextInt(maxNumber) + 1;
        int idImage = this.getResources().getIdentifier("opponent" + String.format("%02d", rnd), "drawable", this.getPackageName());
        img.setImageResource(idImage);
    }

    private void setStatus(String message) {
        if (txtStatus != null) {
            txtStatus.setText(message);
        }
    }

    private boolean activateRandomStake() {
        if (randomStakeId.isEmpty()) return true;
        try {
            if (!userID.equals(ProgressionAccount.uid(this))
                    || !RandomStakeLedger.activate(this, randomStakeId)) return false;
            return true;
        } catch (RuntimeException failure) {
            setStatus("تعذر تثبيت حجز القطع. أعد المحاولة أو ألغِ البحث.");
            if (btnCancel != null) btnCancel.setVisibility(View.VISIBLE);
            return false;
        }
    }

    private void cancelRandomSearch() {
        if (closed || stakeCancelling || launchingGame) return;
        stakeCancelling = true;
        Data.withdrawDuelSearch(userID, new OnGetGameIdListener() {
            @Override public void onSuccess(String opponent) {
                if (closed || launchingGame) { stakeCancelling = false; return; }
                if (!userID.equals(ProgressionAccount.uid(OpponentActivity.this))) { finish(); return; }
                try {
                    if (opponent.isEmpty()) RandomStakeLedger.cancel(OpponentActivity.this, randomStakeId);
                    else {
                        // A simultaneous match claim won the queue transaction: leaving forfeits,
                        // so we must not both refund this contribution and pay the peer a pot.
                        RandomStakeLedger.activate(OpponentActivity.this, randomStakeId);
                        RandomStakeLedger.settle(OpponentActivity.this, randomStakeId, false, false);
                    }
                    cleanupPendingRequest();
                    finish();
                } catch (RuntimeException failure) {
                    stakeCancelling = false;
                    setStatus("تعذر حفظ تسوية القطع. أعد المحاولة.");
                }
            }
            @Override public void onFailed(DatabaseError error) {
                stakeCancelling = false;
                setStatus("تعذر تأكيد إلغاء البحث. تحقق من الاتصال وحاول مجددًا.");
            }
        });
    }

    private void cleanupPendingRequest() {
        closed = true;
        stopMatchmakingSound();
        queueHeartbeatHandler.removeCallbacksAndMessages(null);
        if (stopRequestListener != null) stopRequestListener.run();
        stopRequestListener = null;
        cancelButtonHandler.removeCallbacks(cancelButtonRunnable);
        matchmakingHandler.removeCallbacksAndMessages(null);
        botFallbackHandler.removeCallbacksAndMessages(null);
        shuffleHandler.removeCallbacksAndMessages(null);
        presentationHandler.removeCallbacksAndMessages(null);
        pendingPresentationLaunch = null;
        if (matchmakingEffects != null) matchmakingEffects.stop();
        for (View view : new View[]{cardPlayer, cardOpponent, layoutArena, btnCancel,
                imgSearchGlass, txtStatus, imgPhoto21, imgPhoto22, imgSplitLeft, imgSplitRight,
                layoutOpponentTrophy}) {
            if (view != null) view.animate().cancel();
        }
        if (searchGlassAnim != null) {
            searchGlassAnim.cancel();
            searchGlassAnim = null;
        }
        if (statusPulseAnim != null) {
            statusPulseAnim.cancel();
            statusPulseAnim = null;
        }
        if (ownRequestInserted && !launchingGame) {
            Data.cancelRequest(userID);
            ownRequestInserted = false;
        }
    }

    @Override
    protected void onSaveInstanceState(Bundle outState) {
        super.onSaveInstanceState(outState);
        outState.putString("randomStakeId", randomStakeId);
    }

    @Override
    protected void onDestroy() {
        stopMatchmakingSound();
        cleanupPendingRequest();
        super.onDestroy();
    }

    @Override
    protected void onPause() {
        audioPaused = true;
        stopMatchmakingSound();
        super.onPause();
    }

    @Override
    protected void onResume() {
        super.onResume();
        audioPaused = false;
        startSearchSound();
        if (pendingPresentationLaunch != null) {
            Runnable launch = pendingPresentationLaunch;
            pendingPresentationLaunch = null;
            presentationHandler.post(launch);
        }
    }

    @Override
    public void onBackPressed() {
        if (launchingGame) return;
        if (!stakeMatchId.isEmpty()) { leaveStakeIntro(); return; }
        if (!randomStakeId.isEmpty()) { cancelRandomSearch(); return; }
        cleanupPendingRequest();
        super.onBackPressed();
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
