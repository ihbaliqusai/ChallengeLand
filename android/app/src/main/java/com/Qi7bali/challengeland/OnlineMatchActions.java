package com.qi7bali.landchallengeonline;

import android.app.Activity;
import android.content.Context;
import android.content.ContextWrapper;

import com.google.firebase.auth.FirebaseAuth;
import com.google.firebase.database.DataSnapshot;
import com.google.firebase.database.DatabaseError;
import com.google.firebase.database.FirebaseDatabase;
import com.google.firebase.database.MutableData;
import com.google.firebase.database.Transaction;
import com.google.firebase.functions.FirebaseFunctions;

import org.json.JSONObject;

import java.util.HashMap;
import java.util.Map;

/** Resolves the shared result before a saved match can be replaced. */
public final class OnlineMatchActions {
    private OnlineMatchActions() {}

    public interface Completion {
        void success(String summary);
        void failure(String message);
    }

    public static void inspect(Activity activity, String id, boolean withdraw, Completion completion) {
        String uid = ProgressionAccount.uid(activity);
        JSONObject record = OnlineMatchRecovery.read(activity, id);
        if (record == null) { completion.failure("هذه المباراة لم تعد متاحة."); return; }
        if (record.optBoolean("finished")) {
            try {
                if (withdraw) OnlineMatchRecovery.finishSaved(activity, id, "", true);
                completion.success(OnlineMatchRecovery.summary(record).toString());
            } catch (RuntimeException error) { completion.failure(error.getMessage()); }
            return;
        }
        // Room membership is resolved transactionally by RoomService before this call.
        if (id.startsWith("bot:") || !record.optString("roomId").isEmpty()) {
            try {
                if (withdraw) finish(activity, uid, id, record, "", true, true, 0);
                completion.success(OnlineMatchRecovery.summary(OnlineMatchRecovery.read(activity, id)).toString());
            } catch (RuntimeException error) { completion.failure(error.getMessage()); }
            return;
        }
        if (FirebaseAuth.getInstance().getCurrentUser() == null
                || !uid.equals(FirebaseAuth.getInstance().getCurrentUser().getUid())
                || !Data.isNetworkAvailable(activity)) {
            completion.failure("تحقق من الاتصال ثم أعد المحاولة."); return;
        }
        JSONObject extras = record.optJSONObject("extras");
        if (id.startsWith("paid:")) {
            Map<String, Object> request = new HashMap<>();
            request.put("action", withdraw ? "forfeit" : "sync");
            request.put("matchId", id.substring(5));
            // Stable across retries, including a response lost after server settlement.
            if (withdraw) request.put("operationId", "recovery-forfeit-" + id.substring(5));
            FirebaseFunctions.getInstance("us-central1").getHttpsCallable("friendStakes").call(request)
                    .addOnSuccessListener(response -> {
                        try {
                            requireAccount(activity, uid);
                            Map<String, Object> match = OnlineDuelState.map(
                                    OnlineDuelState.map(response.getData()).get("match"));
                            if (!id.substring(5).equals(match.get("matchId"))
                                    || (!uid.equals(match.get("ownerId")) && !uid.equals(match.get("joinerId"))))
                                throw new IllegalStateException("هذه المباراة لا تخص الحساب الحالي.");
                            if ("settled".equals(match.get("status"))) {
                                String winner = match.get("winnerId") instanceof String ? (String)match.get("winnerId") : "";
                                String reason = String.valueOf(match.get("finishReason"));
                                boolean forfeited = "forfeit".equals(reason);
                                if (winner.isEmpty() && !"draw".equals(reason)) {
                                    OnlineMatchRecovery.finishSaved(activity, id, "أُلغيت المباراة وأُعيدت القطع للطرفين.", withdraw);
                                } else {
                                    finish(activity, uid, id, record, winner, forfeited, withdraw, 0);
                                }
                            }
                            completion.success(OnlineMatchRecovery.summary(OnlineMatchRecovery.read(activity, id)).toString());
                        } catch (RuntimeException error) { completion.failure(error.getMessage()); }
                    }).addOnFailureListener(error -> completion.failure("تعذر التحقق من نتيجة التحدي. حاول مجددًا."));
            return;
        }
        String session = extras == null ? "" : extras.optString("duelSessionId");
        if (session.isEmpty()) { completion.failure("معرّف المباراة مفقود."); return; }
        com.google.firebase.database.DatabaseReference ref = FirebaseDatabase.getInstance().getReference("Games").child(session);
        if (!withdraw) {
            ref.get().addOnSuccessListener(snapshot -> resolveDuel(activity, uid, id, record, snapshot, false, completion))
                    .addOnFailureListener(error -> completion.failure("تعذر التحقق من نتيجة المباراة. حاول مجددًا."));
            return;
        }
        ref.runTransaction(new Transaction.Handler() {
            @Override public Transaction.Result doTransaction(MutableData data) {
                if (!uid.equals(ProgressionAccount.uid(activity))) return Transaction.abort();
                // An empty local cache must still reach the server transaction.
                if (data.getValue() == null) return Transaction.success(data);
                Map<String, Object> state = OnlineDuelState.map(data.getValue());
                if (!OnlineDuelState.withdraw(state, uid)) return Transaction.abort();
                data.setValue(state);
                return Transaction.success(data);
            }
            @Override public void onComplete(DatabaseError error, boolean committed, DataSnapshot snapshot) {
                if (error != null || !committed) {
                    completion.failure("تعذر إنهاء المباراة السابقة. تحقق من الاتصال وحاول مجددًا."); return;
                }
                resolveDuel(activity, uid, id, record, snapshot, true, completion);
            }
        }, false);
    }

    private static void requireAccount(Context context, String uid) {
        if (!uid.equals(ProgressionAccount.uid(context))) throw new IllegalStateException("تغير حساب اللاعب. حاول مجددًا.");
    }

    private static void resolveDuel(Activity activity, String uid, String id, JSONObject record,
                                    DataSnapshot snapshot, boolean withdraw, Completion completion) {
        try {
            requireAccount(activity, uid);
            Map<String, Object> board = OnlineDuelState.map(snapshot.child("board").getValue());
            if ("finished".equals(board.get("phase"))) {
                if (!uid.equals(board.get("ownerId")) && !uid.equals(board.get("joinerId")))
                    throw new IllegalStateException("هذه المباراة لا تخص الحساب الحالي.");
                String winner = board.get("winnerId") instanceof String ? (String)board.get("winnerId") : "";
                int score = OnlineDuelState.number(OnlineDuelState.scores(board).get(uid), 0);
                finish(activity, uid, id, record, winner, "forfeit".equals(board.get("finishReason")), withdraw, score);
            } else if (!snapshot.exists()) {
                // Never replace a missing or offline server snapshot with a new bot game.
                throw new IllegalStateException("تعذر العثور على نتيجة المباراة. حاول مجددًا لاحقًا.");
            }
            completion.success(OnlineMatchRecovery.summary(OnlineMatchRecovery.read(activity, id)).toString());
        } catch (RuntimeException error) { completion.failure(error.getMessage()); }
    }

    private static void finish(Context context, String uid, String id, JSONObject record, String winner,
                               boolean forfeit, boolean observed, int score) {
        requireAccount(context, uid);
        boolean win = uid.equals(winner);
        boolean draw = winner.isEmpty() && !forfeit;
        JSONObject extras = record.optJSONObject("extras");
        String stakeId = extras == null ? "" : extras.optString("randomStakeId");
        if (!stakeId.isEmpty()) RandomStakeLedger.settle(context, stakeId, win, draw);
        SavedMatchContext match = new SavedMatchContext(context, id, record);
        if (forfeit && id.startsWith("duel:")) PlayerStats.recordOnlineDuelForfeit(match, win, score);
        else PlayerStats.recordGameEnd(match, draw ? ProgressionRules.DRAW : win ? ProgressionRules.WIN : ProgressionRules.LOSS, score);
        String message = draw ? "انتهت المباراة بالتعادل." : win ? "فزت بالمباراة."
                : forfeit ? "خسرت المباراة بسبب الانسحاب منها أو عدم العودة خلال المهلة."
                : "خسرت المباراة التي انتهت أثناء غيابك.";
        OnlineMatchRecovery.finishSaved(context, id, message, observed);
    }

    private static final class SavedMatchContext extends ContextWrapper implements ProgressionMatchHost {
        private final String id;
        private final JSONObject record;
        SavedMatchContext(Context context, String id, JSONObject record) { super(context); this.id = id; this.record = record; }
        @Override public String progressionMatchId() {
            String saved = record.optString("matchId");
            if (!saved.isEmpty()) return saved;
            JSONObject extras = record.optJSONObject("extras");
            if (id.startsWith("duel:")) return id;
            if (id.startsWith("paid:")) return "duel:" + id.substring(5);
            if (!record.optString("roomId").isEmpty()) return "room:" + record.optString("roomId") + ":"
                    + progressionMode() + ":" + (extras == null ? 1 : Math.max(1, extras.optInt("roomRoundNumber", 1)));
            return extras == null ? id : extras.optString("progressionMatchId", id);
        }
        @Override public String progressionMode() {
            JSONObject extras = record.optJSONObject("extras");
            return record.optString("matchMode", extras == null ? "board" : extras.optString("matchMode", "board"));
        }
        @Override public String progressionAnswerId() { return ""; }
        @Override public boolean progressionOnline() { return true; }
        @Override public boolean progressionHumanOpponents() { return record.optBoolean("humanOnline", id.startsWith("duel:") || id.startsWith("paid:")); }
    }
}
