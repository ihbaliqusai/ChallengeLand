package com.qi7bali.landchallengeonline;

import java.util.HashMap;
import java.util.Map;

/** Deterministic duel reducer. Call only inside a transaction on the entire board. */
final class OnlineDuelState {
    private OnlineDuelState() {}

    static final long DISCONNECT_GRACE_MS = 20_000L;
    static final int NO_CHANGE = 0;
    static final int GRACE_STARTED = 1;
    static final int RECONNECTED = 2;
    static final int TURN_SKIPPED = 3;
    static final int FORFEITED = 4;

    static int number(Object value, int fallback) {
        return value instanceof Number ? ((Number) value).intValue() : fallback;
    }

    @SuppressWarnings("unchecked")
    static Map<String, Object> map(Object value) {
        return value instanceof Map ? (Map<String, Object>) value : new HashMap<>();
    }

    static String picker(Map<String, Object> board, int turn) {
        return String.valueOf(board.get(turn % 2 == 0 ? "ownerId" : "joinerId"));
    }

    /**
     * Resolve an absent opponent from a transaction on the ENTIRE game session.
     * The caller's live connection and both authoritative statuses are required:
     * a cached "left" event on an offline phone must never award that phone a win.
     */
    static int reconcileDisconnect(Map<String, Object> session, String observer,
                                   int expectedTurn, long nowMs, boolean locallyConnected) {
        Map<String, Object> board = map(session.get("board"));
        if (!locallyConnected || nowMs < 0 || !participant(board, observer)
                || !Boolean.TRUE.equals(board.get("ready"))
                || "finished".equals(board.get("phase"))
                || !"active".equals(status(session, observer))) return NO_CHANGE;

        String owner = String.valueOf(board.get("ownerId"));
        String joiner = String.valueOf(board.get("joinerId"));
        boolean reconnected = false;
        if ("active".equals(status(session, owner))) reconnected |= resetDisconnect(board, owner);
        if ("active".equals(status(session, joiner))) reconnected |= resetDisconnect(board, joiner);
        int changed = reconnected ? RECONNECTED : NO_CHANGE;
        // Connection cleanup remains valid even if this callback captured an old
        // turn. Only a callback for the current turn can start or spend its grace.
        int turn = number(board.get("currentTurn"), -1);
        if (turn != expectedTurn || turn < 0 || turn >= number(board.get("rows"), 0) * 2
                || (!"selecting".equals(board.get("phase"))
                    && !"answering".equals(board.get("phase")))) return changed;

        String missing = owner.equals(observer) ? joiner : owner;
        if (!missing.equals(picker(board, turn)) || !absent(status(session, missing))) return changed;
        Map<String, Object> result = map(map(board.get("turns")).get("t" + turn));
        if (Boolean.TRUE.equals(result.get("done"))
                || (!result.isEmpty() && !missing.equals(result.get("playerId")))) return changed;

        Map<String, Object> grace = map(board.get("disconnectGrace"));
        long deadline = disconnectDeadline(board);
        if (!missing.equals(grace.get("playerId")) || deadline == 0) {
            if (nowMs > Long.MAX_VALUE - DISCONNECT_GRACE_MS) return changed;
            grace = new HashMap<>();
            grace.put("playerId", missing);
            grace.put("turn", turn);
            grace.put("startedAt", nowMs);
            grace.put("deadlineAt", nowMs + DISCONNECT_GRACE_MS);
            board.put("disconnectGrace", grace);
            session.put("board", board);
            return GRACE_STARTED;
        }
        if (nowMs < deadline) return changed;

        Map<String, Object> strikes = map(board.get("disconnectStrikes"));
        int previous = Math.max(0, number(strikes.get(missing), 0));
        strikes.put(missing, previous >= 1 ? 2 : 1);
        board.put("disconnectStrikes", strikes);
        // A missing selection has no cell coordinates. Preserve a real pick,
        // if one exists, and never select or consume a random cell on its behalf.
        result.put("playerId", missing);
        result.put("correct", false);
        result.put("revealCount", 0);
        result.put("points", 0);
        result.put("done", true);
        result.put("skipped", true);
        result.put("skipReason", "disconnected");
        Map<String, Object> turns = map(board.get("turns"));
        turns.put("t" + turn, result);
        board.put("turns", turns);
        board.put("currentTurn", turn + 1);
        board.remove("disconnectGrace");
        board.put("scores", scores(board));
        if (previous >= 1 || turn + 1 >= number(board.get("rows"), 0) * 2) {
            forfeit(board, observer);
            session.put("board", board);
            return FORFEITED;
        }
        board.put("phase", "selecting");
        session.put("board", board);
        return TURN_SKIPPED;
    }

    /** Current turn's valid persisted deadline, or zero when no grace is live. */
    static long disconnectDeadline(Map<String, Object> board) {
        if ("finished".equals(board.get("phase"))) return 0;
        Map<String, Object> grace = map(board.get("disconnectGrace"));
        int turn = number(grace.get("turn"), -1);
        Object started = grace.get("startedAt"), deadline = grace.get("deadlineAt");
        if (turn < 0 || turn != number(board.get("currentTurn"), -1)
                || !participant(board, String.valueOf(grace.get("playerId")))
                || !picker(board, turn).equals(grace.get("playerId"))
                || !(started instanceof Number) || !(deadline instanceof Number)) return 0;
        long startMs = ((Number) started).longValue();
        long deadlineMs = ((Number) deadline).longValue();
        return startMs >= 0 && startMs <= Long.MAX_VALUE - DISCONNECT_GRACE_MS
                && deadlineMs == startMs + DISCONNECT_GRACE_MS ? deadlineMs : 0;
    }

    private static boolean participant(Map<String, Object> board, String player) {
        Object owner = board.get("ownerId"), joiner = board.get("joinerId");
        return owner instanceof String && joiner instanceof String
                && !((String) owner).isEmpty() && !((String) joiner).isEmpty()
                && !owner.equals(joiner) && (owner.equals(player) || joiner.equals(player));
    }

    private static String status(Map<String, Object> session, String player) {
        return String.valueOf(map(session.get(player)).get("status"));
    }

    private static boolean absent(String status) {
        return "left".equals(status) || "left_timeout".equals(status) || "away".equals(status);
    }

    private static boolean resetDisconnect(Map<String, Object> board, String player) {
        boolean changed = false;
        Map<String, Object> strikes = map(board.get("disconnectStrikes"));
        if (strikes.containsKey(player)) {
            strikes.remove(player);
            if (strikes.isEmpty()) board.remove("disconnectStrikes");
            else board.put("disconnectStrikes", strikes);
            changed = true;
        }
        if (player.equals(map(board.get("disconnectGrace")).get("playerId"))) {
            board.remove("disconnectGrace");
            changed = true;
        }
        return changed;
    }

    static boolean claim(Map<String, Object> board, String player, int turn, int col, int row) {
        if (!Boolean.TRUE.equals(board.get("ready")) || "finished".equals(board.get("phase"))
                || turn != number(board.get("currentTurn"), 0) || !player.equals(picker(board, turn))
                || col < 0 || col >= 2 || row < 0 || row >= number(board.get("rows"), 0)) return false;
        Map<String, Object> turns = map(board.get("turns"));
        String key = "t" + turn;
        Map<String, Object> existing = map(turns.get(key));
        if (!existing.isEmpty()) {
            return player.equals(existing.get("playerId"))
                    && col == number(existing.get("col"), -1) && row == number(existing.get("row"), -1);
        }
        String cell = col + "_" + row;
        Map<String, Object> consumed = map(board.get("consumed"));
        if (consumed.containsKey(cell) || !map(board.get("cells")).containsKey(cell)) return false;
        Map<String, Object> pick = new HashMap<>();
        pick.put("playerId", player);
        pick.put("col", col);
        pick.put("row", row);
        turns.put(key, pick);
        consumed.put(cell, turn);
        board.put("turns", turns);
        board.put("consumed", consumed);
        board.put("phase", "answering");
        return true;
    }

    static boolean complete(Map<String, Object> board, String player, int turn,
                            boolean correct, int reveals) {
        Map<String, Object> result = map(map(board.get("turns")).get("t" + turn));
        if (!player.equals(result.get("playerId"))) return false;
        // A delayed answer cannot revive a turn already skipped for disconnect.
        if (Boolean.TRUE.equals(result.get("skipped"))) return false;
        // Retries return the original result without awarding again.
        if (Boolean.TRUE.equals(result.get("done"))) return true;
        if ("finished".equals(board.get("phase")) || turn != number(board.get("currentTurn"), 0)
                || reveals < 0 || reveals > 2) return false;
        int row = number(result.get("row"), -1);
        if (row < 0) return false;
        int points = correct ? new int[]{200, 400, 600}[row % 3] / (1 << reveals) : 0;
        result.put("correct", correct);
        result.put("revealCount", reveals);
        result.put("points", points);
        result.put("done", true);
        Map<String, Object> scores = scores(board);
        board.put("scores", scores);
        int next = turn + 1;
        board.put("currentTurn", next);
        board.remove("disconnectGrace");
        boolean finished = next >= number(board.get("rows"), 0) * 2;
        board.put("phase", finished ? "finished" : "selecting");
        if (finished) {
            String owner = String.valueOf(board.get("ownerId"));
            String joiner = String.valueOf(board.get("joinerId"));
            int a = number(scores.get(owner), 0), b = number(scores.get(joiner), 0);
            board.put("winnerId", a == b ? "" : a > b ? owner : joiner);
            board.put("finishReason", a == b ? "draw" : "completed");
        }
        return true;
    }

    static Map<String, Object> scores(Map<String, Object> board) {
        Map<String, Object> scores = new HashMap<>();
        for (Object value : map(board.get("turns")).values()) {
            Map<String, Object> result = map(value);
            if (!Boolean.TRUE.equals(result.get("done"))) continue;
            String id = String.valueOf(result.get("playerId"));
            scores.put(id, number(scores.get(id), 0) + number(result.get("points"), 0));
        }
        return scores;
    }

    static void forfeit(Map<String, Object> board, String winner) {
        if ("finished".equals(board.get("phase"))) return;
        board.put("phase", "finished");
        board.put("winnerId", winner);
        board.put("finishReason", "forfeit");
        board.put("scores", scores(board));
        board.remove("disconnectGrace");
    }
}
