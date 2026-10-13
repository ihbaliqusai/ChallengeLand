package com.qi7bali.landchallengeonline;

import android.content.Context;
import android.content.ContextWrapper;
import android.content.SharedPreferences;
import android.os.Handler;
import android.os.Looper;

import com.google.firebase.auth.FirebaseAuth;
import com.google.firebase.auth.FirebaseUser;
import com.google.firebase.database.DataSnapshot;
import com.google.firebase.database.FirebaseDatabase;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

/** Retains active duel identities until their immutable terminal results are recorded. */
public final class OnlineDuelResultStore {
    private OnlineDuelResultStore() {}

    private static final String PENDING = "pendingDuel:";
    private static final long REPLAY_TIMEOUT_MS = 3_000L;

    private static boolean accountIsActive(Context context, String uid) {
        FirebaseUser user = FirebaseAuth.getInstance().getCurrentUser();
        return user != null && uid.equals(user.getUid()) && uid.equals(ProgressionAccount.uid(context));
    }

    private static boolean validKey(String key) {
        return key != null && !key.trim().isEmpty() && key.length() <= 256
                && key.equals(key.trim()) && !key.matches(".*[.#$\\[\\]/\\x00-\\x1F\\x7F].*");
    }

    public static synchronized void track(Context context, String sessionId, String opponentUid) {
        String uid = ProgressionAccount.uid(context);
        if (!validKey(sessionId) || !validKey(opponentUid) || uid.equals(opponentUid)
                || !accountIsActive(context, uid)) return;
        SharedPreferences storage = ProgressionAccount.preferences(context);
        if (storage.contains("match:duel:" + sessionId)) return;
        ProgressionAccount.commitOrRollback(storage,
                storage.edit().putString(PENDING + sessionId, opponentUid));
    }

    public static synchronized void clearCompleted(Context context, String sessionId) {
        if (!validKey(sessionId)) return;
        SharedPreferences storage = ProgressionAccount.preferences(context);
        if (!storage.contains("match:duel:" + sessionId)) return;
        ProgressionAccount.commitOrRollback(storage, storage.edit().remove(PENDING + sessionId));
    }

    /** Completes promptly offline; unresolved identities remain durable for the next attempt. */
    public static void replayPending(Context context, Runnable completion) {
        Context app = context.getApplicationContext();
        String uid = ProgressionAccount.uid(app);
        if (!accountIsActive(app, uid)) {
            completion.run();
            return;
        }
        SharedPreferences storage = ProgressionAccount.preferences(app);
        List<String> sessions = new ArrayList<>();
        for (Map.Entry<String, ?> entry : storage.getAll().entrySet()) {
            if (entry.getKey().startsWith(PENDING) && entry.getValue() instanceof String) {
                String id = entry.getKey().substring(PENDING.length());
                if (validKey(id)) sessions.add(id);
            }
        }
        if (sessions.isEmpty()) {
            completion.run();
            return;
        }
        Handler main = new Handler(Looper.getMainLooper());
        boolean[] finished = {false};
        int[] remaining = {sessions.size()};
        Runnable finish = () -> {
            if (finished[0]) return;
            finished[0] = true;
            completion.run();
        };
        main.postDelayed(finish, REPLAY_TIMEOUT_MS);
        for (String sessionId : sessions) {
            String opponentUid = storage.getString(PENDING + sessionId, "");
            FirebaseDatabase.getInstance().getReference("Games").child(sessionId).child("board")
                    .get().addOnCompleteListener(task -> {
                        if (finished[0]) return;
                        if (task.isSuccessful() && accountIsActive(app, uid)) {
                            try {
                                replayTerminal(app, uid, sessionId, opponentUid, task.getResult());
                            } catch (RuntimeException ignored) {
                                // A failed durable commit keeps the identity available for retry.
                            }
                        }
                        if (--remaining[0] == 0) {
                            main.removeCallbacks(finish);
                            finish.run();
                        }
                    });
        }
    }

    private static void replayTerminal(Context context, String uid, String sessionId,
                                       String opponentUid, DataSnapshot board) {
        if (board == null || !"finished".equals(board.child("phase").getValue(String.class))) return;
        String owner = board.child("ownerId").getValue(String.class);
        String joiner = board.child("joinerId").getValue(String.class);
        if (!((uid.equals(owner) && opponentUid.equals(joiner))
                || (uid.equals(joiner) && opponentUid.equals(owner)))) return;
        String reason = board.child("finishReason").getValue(String.class);
        String winner = board.child("winnerId").getValue(String.class);
        boolean forfeit = "forfeit".equals(reason);
        if (forfeit && !uid.equals(winner) && !opponentUid.equals(winner)) return;
        if (!forfeit && !"completed".equals(reason) && !"draw".equals(reason)) return;
        if (!forfeit && winner != null && !winner.isEmpty()
                && !uid.equals(winner) && !opponentUid.equals(winner)) return;
        DuelContext match = new DuelContext(context, sessionId);
        Map<String, Object> scores = OnlineDuelState.scores(OnlineDuelState.map(board.getValue()));
        int score = Math.max(0, OnlineDuelState.number(scores.get(uid), 0));
        if (forfeit) {
            PlayerStats.recordOnlineDuelForfeit(match, uid.equals(winner), score);
        } else {
            PlayerStats.recordGameEnd(match, winner == null || winner.isEmpty() ? ProgressionRules.DRAW
                    : uid.equals(winner) ? ProgressionRules.WIN : ProgressionRules.LOSS, score);
        }
        clearCompleted(context, sessionId);
    }

    /** Replays only the retained session, independently of whichever screen is visible. */
    private static final class DuelContext extends ContextWrapper implements ProgressionMatchHost {
        private final String sessionId;

        DuelContext(Context context, String sessionId) {
            super(context);
            this.sessionId = sessionId;
        }

        @Override public String progressionMatchId() { return "duel:" + sessionId; }
        @Override public String progressionMode() { return "board"; }
        @Override public String progressionAnswerId() { return ""; }
        @Override public boolean progressionOnline() { return true; }
        @Override public boolean progressionHumanOpponents() { return true; }
    }
}
