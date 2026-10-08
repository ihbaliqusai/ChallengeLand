package com.qi7bali.landchallengeonline;

import java.util.HashMap;
import java.util.Map;
import java.util.Random;

public final class OnlineDuelStateTest {
    private static int checks;
    private static void check(boolean condition, String message) {
        checks++;
        if (!condition) throw new AssertionError(message);
    }

    private static Map<String, Object> board() {
        Map<String, Object> board = new HashMap<>();
        board.put("ready", true);
        board.put("ownerId", "alice");
        board.put("joinerId", "bob");
        board.put("rows", 6L);
        board.put("currentTurn", 0L);
        Map<String, Object> cells = new HashMap<>();
        for (int col = 0; col < 2; col++) for (int row = 0; row < 6; row++)
            cells.put(col + "_" + row, Map.of("Q", "question " + col + "_" + row));
        board.put("cells", cells);
        return board;
    }

    private static Map<String, Object> waiting(String target, long now) {
        Map<String, Object> request = new HashMap<>();
        request.put("status", "waiting");
        request.put("targetId", target);
        request.put("createdAt", now);
        return request;
    }

    public static void main(String[] args) {
        Map<String, Object> board = board();
        check(!OnlineDuelState.claim(board, "bob", 0, 0, 0), "wrong picker");
        check(!OnlineDuelState.claim(board, "alice", 1, 0, 0), "future turn");
        check(!OnlineDuelState.claim(board, "alice", 0, 2, 0), "invalid column");
        check(!OnlineDuelState.claim(board, "alice", 0, 0, -1), "invalid row");
        check(!OnlineDuelState.complete(board, "alice", 0, true, 0), "answer before pick");
        check(OnlineDuelState.claim(board, "alice", 0, 0, 0), "first claim");
        check(OnlineDuelState.claim(board, "alice", 0, 0, 0), "claim retry");
        check(!OnlineDuelState.claim(board, "alice", 0, 1, 0), "double tap different cell");
        check(!OnlineDuelState.complete(board, "bob", 0, true, 0), "opponent cannot submit");
        check(!OnlineDuelState.complete(board, "alice", 0, true, 3), "invalid reveal count");
        check(OnlineDuelState.complete(board, "alice", 0, true, 1), "half value answer");
        check(OnlineDuelState.complete(board, "alice", 0, true, 0), "retry immutable result");
        check(OnlineDuelState.number(OnlineDuelState.scores(board).get("alice"), 0) == 100, "no duplicate/full award");
        check(!OnlineDuelState.claim(board, "bob", 1, 0, 0), "consumed cell reuse");
        check(OnlineDuelState.claim(board, "bob", 1, 1, 0), "second turn");
        OnlineDuelState.forfeit(board, "alice");
        check(!OnlineDuelState.complete(board, "bob", 1, true, 0), "late answer after forfeit");
        OnlineDuelState.forfeit(board, "bob");
        check("alice".equals(board.get("winnerId")), "forfeit winner immutable");

        for (int seed = 0; seed < 150; seed++) {
            board = board();
            Random random = new Random(seed);
            int[] expected = {0, 0};
            for (int turn = 0; turn < 12; turn++) {
                String picker = turn % 2 == 0 ? "alice" : "bob";
                int col = turn / 6, row = turn % 6;
                boolean correct = random.nextBoolean();
                int reveals = random.nextInt(3);
                check(OnlineDuelState.claim(board, picker, turn, col, row), "complete match pick");
                check(OnlineDuelState.complete(board, picker, turn, correct, reveals), "complete match answer");
                check(OnlineDuelState.complete(board, picker, turn, !correct, 0), "delayed duplicate answer");
                expected[turn % 2] += correct ? new int[]{200, 400, 600}[row % 3] / (1 << reveals) : 0;
                Map<String, Object> scores = OnlineDuelState.scores(board);
                check(OnlineDuelState.number(scores.get("alice"), 0) == expected[0], "owner score from ledger");
                check(OnlineDuelState.number(scores.get("bob"), 0) == expected[1], "joiner score from ledger");
                check(OnlineDuelState.number(board.get("currentTurn"), -1) == turn + 1, "exactly one advancement");
            }
            String winner = expected[0] == expected[1] ? "" : expected[0] > expected[1] ? "alice" : "bob";
            check(winner.equals(board.get("winnerId")), "winner by shared score");
            check("finished".equals(board.get("phase")), "complete state");
            check(OnlineDuelState.map(board.get("consumed")).size() == 12, "each question exactly once");
            OnlineDuelState.forfeit(board, "outsider");
            check(winner.equals(board.get("winnerId")), "late disconnect cannot change finished winner");
        }
        board = board();
        for (int turn = 0; turn < 12; turn++) {
            String picker = OnlineDuelState.picker(board, turn);
            OnlineDuelState.claim(board, picker, turn, turn / 6, turn % 6);
            OnlineDuelState.complete(board, picker, turn, false, 0);
        }
        check("".equals(board.get("winnerId")) && "draw".equals(board.get("finishReason")), "zero-zero is draw");

        long now = 1_800_000_000_000L;
        Map<String, Object> queue = new HashMap<>();
        queue.put("alice", waiting("", now));
        queue.put("bob", waiting("", now));
        queue.put("carol", waiting("", now));
        check(OnlineMatchmakingState.claim(queue, "alice", "bob", "session-1", now), "pair atomically");
        check(OnlineMatchmakingState.claim(queue, "bob", "alice", "session-2", now), "mutual search resolves same pair");
        check("session-1".equals(OnlineDuelState.map(queue.get("bob")).get("sessionId")), "one session for both");
        check(!OnlineMatchmakingState.claim(queue, "carol", "alice", "session-3", now), "third player cannot claim matched seat");
        check(!OnlineMatchmakingState.claim(queue, "carol", "carol", "self", now), "self match rejected");
        queue.put("alice", waiting("bob", now));
        queue.put("bob", waiting("alice", now));
        check(!OnlineMatchmakingState.claim(queue, "carol", "alice", "random", now), "friend invite protected");
        check(OnlineMatchmakingState.claim(queue, "bob", "alice", "friend", now), "friend pair works");
        queue.put("alice", waiting("", now - 120_001));
        queue.put("bob", waiting("", now));
        check(!OnlineMatchmakingState.claim(queue, "bob", "alice", "stale", now), "stale request rejected");
        queue.put("alice", waiting("", now));
        OnlineDuelState.map(queue.get("alice")).put("status", "cancelled");
        check(!OnlineMatchmakingState.claim(queue, "bob", "alice", "late", now), "cancel defeats late match");
        check(!OnlineMatchmakingState.claim(queue, "missing", "bob", "late", now), "absent seat cannot be resurrected");
        queue.put("alice", waiting("", now));
        queue.put("bob", waiting("", now));
        check(OnlineMatchmakingState.claim(queue, "alice", "bob", "cancelled-pair", now), "pair before cancel");
        OnlineDuelState.map(queue.get("alice")).put("status", "cancelled");
        check(!OnlineMatchmakingState.claim(queue, "bob", "alice", "resurrected", now), "cancelled matched pair stays cancelled");
        System.out.println("PASS: " + checks + " duel and matchmaking checks (150 complete matches)");
    }
}
