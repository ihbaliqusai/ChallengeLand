package com.qi7bali.landchallengeonline;

import android.os.Handler;
import android.os.SystemClock;

import com.google.firebase.auth.FirebaseAuth;
import com.google.firebase.firestore.FirebaseFirestore;
import com.google.firebase.firestore.ListenerRegistration;
import com.google.firebase.functions.FirebaseFunctions;

import java.util.Collections;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

/** Server transport for a paid duel. Rendering remains in the original GameActivity. */
final class PaidDuelController {
    interface Listener {
        void onState(Map<String, Object> match, Map<String, Object> question, String action);
        void onFailure(Exception error);
    }

    private final String matchId;
    private final String uid;
    private final Listener callback;
    private final Handler handler = new Handler();
    private ListenerRegistration registration;
    private boolean resumed;
    private boolean destroyed;
    private boolean pending;
    private long lastSync;
    private long serverAnchor;
    private long elapsedAnchor;
    private Map<String, Object> match = Collections.emptyMap();
    private Map<String, Object> question = Collections.emptyMap();
    private int questionTurn = -1;

    PaidDuelController(String matchId, String uid, Listener callback) {
        this.matchId = matchId;
        this.uid = uid;
        this.callback = callback;
    }

    private final Runnable tick = new Runnable() {
        @Override public void run() {
            if (!resumed || destroyed) return;
            long deadline = number(match.get("deadlineAtMillis"), 0);
            long interval = deadline > 0 && serverNow() >= deadline ? 1500L : 10000L;
            if (!pending && SystemClock.elapsedRealtime() - lastSync >= interval) sync();
            handler.postDelayed(this, 500L);
        }
    };

    void resume() {
        if (destroyed || resumed) return;
        resumed = true;
        registration = FirebaseFirestore.getInstance().collection("friend_stake_views")
                .document(matchId).addSnapshotListener((snapshot, error) -> {
                    if (!resumed || destroyed) return;
                    if (error != null) { callback.onFailure(error); return; }
                    if (snapshot != null && snapshot.exists()) {
                        accept(snapshot.getData(), Collections.emptyMap(), "snapshot");
                        if (!pending && needsQuestion()) sync();
                    }
                });
        sync();
        handler.post(tick);
    }

    void pause() {
        resumed = false;
        handler.removeCallbacks(tick);
        if (registration != null) registration.remove();
        registration = null;
    }

    void destroy() {
        pause();
        destroyed = true;
        handler.removeCallbacksAndMessages(null);
    }

    boolean isPending() { return pending; }
    long remainingMillis() {
        return Math.max(0L, number(match.get("deadlineAtMillis"), 0) - serverNow());
    }
    Map<String, Object> state() { return match; }
    void sync() { call("sync", Collections.emptyMap()); }

    void call(String action, Map<String, Object> values) {
        if (pending || destroyed) return;
        if (FirebaseAuth.getInstance().getCurrentUser() == null
                || !uid.equals(FirebaseAuth.getInstance().getCurrentUser().getUid())) {
            callback.onFailure(new IllegalStateException("تغيّر الحساب. أعد فتح المباراة."));
            return;
        }
        pending = true;
        lastSync = SystemClock.elapsedRealtime();
        Map<String, Object> data = new HashMap<>(values);
        data.put("action", action);
        data.put("matchId", matchId);
        if (!"sync".equals(action)) data.put("operationId", UUID.randomUUID().toString());
        FirebaseFunctions.getInstance("us-central1").getHttpsCallable("friendStakes").call(data)
                .addOnSuccessListener(response -> {
                    pending = false;
                    if (destroyed) return;
                    Map<String, Object> payload = map(response.getData());
                    accept(map(payload.get("match")), map(payload.get("question")), action);
                }).addOnFailureListener(error -> {
                    pending = false;
                    if (destroyed) return;
                    callback.onFailure(error);
                    // A lost response may follow a committed answer; reconcile before retrying.
                    handler.postDelayed(() -> { if (resumed && !pending) sync(); }, 1800L);
                });
    }

    private boolean needsQuestion() {
        String phase = string(match.get("phase"));
        return "active".equals(match.get("status"))
                && ("answering".equals(phase) || "observing".equals(phase))
                && (question.isEmpty() || questionTurn != number(match.get("currentTurn"), -1));
    }

    private void accept(Map<String, Object> latest, Map<String, Object> incomingQuestion, String action) {
        if (!matchId.equals(string(latest.get("matchId")))
                || (!uid.equals(latest.get("ownerId")) && !uid.equals(latest.get("joinerId")))) return;
        long incomingTurn = number(latest.get("currentTurn"), -1);
        long currentTurn = number(match.get("currentTurn"), -1);
        if (incomingTurn < currentTurn || ("settled".equals(match.get("status"))
                && !"settled".equals(latest.get("status")))) return;
        if (incomingTurn == currentTurn && "active".equals(match.get("status"))
                && "waiting".equals(latest.get("status"))) return;
        if (incomingTurn == currentTurn && "answering".equals(match.get("phase"))
                && ("selecting".equals(latest.get("phase")) || "observing".equals(latest.get("phase")))) return;
        Map<String, Object> latestTurn = map(map(latest.get("turns")).get("t" + incomingTurn));
        Map<String, Object> previousTurn = map(map(match.get("turns")).get("t" + incomingTurn));
        if (incomingTurn == currentTurn
                && number(latestTurn.get("revealCount"), 0) < number(previousTurn.get("revealCount"), 0)) return;
        if (questionTurn != incomingTurn) {
            question = Collections.emptyMap();
            questionTurn = -1;
        }
        Map<String, Object> projected = map(latestTurn.get("question"));
        if (!incomingQuestion.isEmpty() || !projected.isEmpty()) {
            question = incomingQuestion.isEmpty() ? projected : incomingQuestion;
            questionTurn = (int) incomingTurn;
        }
        match = latest;
        long serverTime = number(latest.get("serverTimeMillis"), 0);
        if (serverTime > serverAnchor) {
            serverAnchor = serverTime;
            elapsedAnchor = SystemClock.elapsedRealtime();
        }
        callback.onState(match, question, action);
    }

    private long serverNow() {
        return serverAnchor > 0 ? serverAnchor + SystemClock.elapsedRealtime() - elapsedAnchor
                : System.currentTimeMillis();
    }

    @SuppressWarnings("unchecked") static Map<String, Object> map(Object value) {
        return value instanceof Map ? (Map<String, Object>) value : Collections.emptyMap();
    }
    static long number(Object value, long fallback) {
        return value instanceof Number ? ((Number) value).longValue() : fallback;
    }
    static String string(Object value) { return value == null ? "" : String.valueOf(value); }
}
