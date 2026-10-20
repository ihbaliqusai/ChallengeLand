package com.qi7bali.landchallengeonline;

import androidx.appcompat.app.AppCompatActivity;

import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Bundle;
import android.os.Handler;
import android.view.View;
import android.view.WindowManager;
import android.widget.Button;
import android.widget.ImageView;
import android.widget.TextView;
import android.widget.Toast;

import com.google.firebase.auth.FirebaseAuth;
import com.google.firebase.database.DatabaseError;
import com.google.firebase.functions.FirebaseFunctions;

import org.json.JSONArray;
import org.json.JSONObject;

import java.util.Random;
import java.util.Map;
import java.util.HashMap;

public class OpponentActivity extends AppCompatActivity {

    private static final int BOT_FALLBACK_DELAY_MS = 8000;

    boolean browsingOpponents = false;
    boolean requestAccepted = false;
    boolean ownRequestInserted = false;
    boolean launchingGame = false;
    private boolean resolvingOpponent = false;
    private boolean closed = false;
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
    Button btnCancel;

    private final Handler matchmakingHandler = new Handler();
    private Runnable matchmakingRunnable;
    private final Handler cancelButtonHandler = new Handler();
    private Runnable cancelButtonRunnable;
    private final Handler botFallbackHandler = new Handler();
    private Runnable botFallbackRunnable;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        getWindow().setFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN,
                WindowManager.LayoutParams.FLAG_FULLSCREEN);
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        getWindow().getDecorView().setSystemUiVisibility(View.SYSTEM_UI_FLAG_HIDE_NAVIGATION);
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
        btnCancel.setOnClickListener(v -> {
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
                    Toast.makeText(this, "رصيدك لا يكفي أو أن مبلغ المباراة غير صالح.", Toast.LENGTH_LONG).show();
                    finish(); return;
                }
            } catch (RuntimeException failure) {
                Toast.makeText(this, "تعذر حفظ حجز القطع. حاول مجددًا.", Toast.LENGTH_LONG).show();
                finish(); return;
            }
        }

        txtOpponent1.setText(userName);
        Data.setImageSource(this, imgPhoto1, userPhoto);
        txtLevel1.setText(String.valueOf(userLevel));

        Data.syncUserProfile(userID, userName, userPhoto, userLevel, userScore);
        Data.setUserActive(userID);

        scheduleCancelButton();
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
                        Toast.makeText(this, "انتهت هذه المواجهة وتمت تسوية القطع.", Toast.LENGTH_LONG).show();
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
        new android.app.AlertDialog.Builder(this).setMessage(message).setCancelable(false)
            .setPositiveButton("إعادة المحاولة", (dialog, which) -> loadStakedOpponent())
            .setNegativeButton("رجوع", (dialog, which) -> leaveStakeIntro()).show();
    }

    private void leaveStakeIntro() {
        if (stakeCancelling || closed || launchingGame) return;
        new android.app.AlertDialog.Builder(this).setTitle("مغادرة التحدي؟")
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
                        else Toast.makeText(this, "تعذر تأكيد المغادرة. تحقق من الاتصال وحاول مجددًا.", Toast.LENGTH_LONG).show();
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
                    Toast.makeText(OpponentActivity.this, "كود الصديق غير صحيح أو غير مسجل", Toast.LENGTH_LONG).show();
                    finish();
                    return;
                }
                if (targetUserId.equals(userID)) {
                    Toast.makeText(OpponentActivity.this, "لا يمكنك تحدي نفسك", Toast.LENGTH_SHORT).show();
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
                Toast.makeText(OpponentActivity.this, "تعذر العثور على الصديق الآن", Toast.LENGTH_SHORT).show();
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
                    Toast.makeText(OpponentActivity.this, "تعذر تحميل بيانات المنافس", Toast.LENGTH_SHORT).show();
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

    private void startBrowsingOpponents() {
        final int margin = 180;
        final int duration = 500;

        browsingOpponents = true;

        setRandomOpponentImage(imgPhoto21, 14);
        Animations.animOpponent(imgPhoto21, duration, margin);

        final Handler handler = new Handler();
        Runnable runnable = new Runnable() {
            boolean photo1 = true;

            @Override
            public void run() {
                if (browsingOpponents) {
                    if (photo1) {
                        setRandomOpponentImage(imgPhoto22, 14);
                        Animations.animOpponent(imgPhoto22, duration, margin);
                        photo1 = false;
                    } else {
                        setRandomOpponentImage(imgPhoto21, 14);
                        Animations.animOpponent(imgPhoto21, duration, margin);
                        photo1 = true;
                    }
                    handler.postDelayed(this, duration / 2);
                }
            }
        };
        handler.postDelayed(runnable, duration / 2);
    }

    private void stopBrowsingOpponents(final User opponent, final boolean meOwner) {
        if (launchingGame || closed || !activateRandomStake()) return;
        launchingGame = true;
        requestAccepted = true;
        browsingOpponents = false;
        botFallbackHandler.removeCallbacksAndMessages(null);
        cancelButtonHandler.removeCallbacks(cancelButtonRunnable);
        if (btnCancel != null) btnCancel.setVisibility(View.GONE);
        matchmakingHandler.removeCallbacksAndMessages(null);
        if (ownRequestInserted) {
            ownRequestInserted = false;
        }
        imgPhoto22.clearAnimation();
        imgPhoto21.clearAnimation();
        imgPhoto21.setVisibility(View.INVISIBLE);
        imgPhoto22.setVisibility(View.INVISIBLE);
        imgPhoto2.setVisibility(View.VISIBLE);
        Data.setImageSource(this, imgPhoto2, opponent.photo);
        txtOpponent2.setText(opponent.name);
        txtLevel2.setText(String.valueOf(opponent.level));
        setStatus("تم العثور على منافس. جاري بدء المباراة...");

        Handler handler = new Handler();
        Runnable runnable = new Runnable() {
            @Override
            public void run() {
                if (closed || isFinishing()) return;
                Intent intent = new Intent(OpponentActivity.this, GameActivity.class);
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
                finish();
            }
        };
        handler.postDelayed(runnable, 1000);
    }

    private void launchBotMatch() {
        if (launchingGame || closed || !activateRandomStake()) return;
        launchingGame = true;
        requestAccepted = true;
        browsingOpponents = false;
        botFallbackHandler.removeCallbacksAndMessages(null);
        cancelButtonHandler.removeCallbacks(cancelButtonRunnable);
        matchmakingHandler.removeCallbacksAndMessages(null);
        if (btnCancel != null) btnCancel.setVisibility(View.GONE);
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

        imgPhoto22.clearAnimation();
        imgPhoto21.clearAnimation();
        imgPhoto21.setVisibility(View.INVISIBLE);
        imgPhoto22.setVisibility(View.INVISIBLE);
        imgPhoto2.setVisibility(View.VISIBLE);
        setRandomOpponentImage(imgPhoto2, 14);
        txtOpponent2.setText("الكمبيوتر");
        txtLevel2.setText(String.valueOf(botLevel));
        setStatus("لم نجد لاعباً متاحاً الآن. سنبدأ ضد خصم آلي...");

        Handler handler = new Handler();
        Runnable runnable = new Runnable() {
            @Override
            public void run() {
                if (closed || isFinishing()) return;
                Intent intent = new Intent(OpponentActivity.this, GameActivity.class);
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
                finish();
            }
        };
        handler.postDelayed(runnable, 800);
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
        queueHeartbeatHandler.removeCallbacksAndMessages(null);
        if (stopRequestListener != null) stopRequestListener.run();
        stopRequestListener = null;
        cancelButtonHandler.removeCallbacks(cancelButtonRunnable);
        matchmakingHandler.removeCallbacksAndMessages(null);
        botFallbackHandler.removeCallbacksAndMessages(null);
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
        cleanupPendingRequest();
        super.onDestroy();
    }

    @Override
    public void onBackPressed() {
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
