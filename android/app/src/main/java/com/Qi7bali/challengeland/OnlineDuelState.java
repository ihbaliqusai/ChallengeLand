package com.qi7bali.landchallengeonline;

import java.util.HashMap;
import java.util.Map;

/** Deterministic duel reducer. Call only inside a transaction on the entire board. */
final class OnlineDuelState {
    private OnlineDuelState() {}

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
    }
}
