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
        board.put("phase", "selecting");
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

    private static Map<String, Object> session(Map<String, Object> board,
                                               String ownerStatus, String joinerStatus) {
        Map<String, Object> session = new HashMap<>();
        session.put("board", board);
        session.put("alice", new HashMap<>(Map.of("status", ownerStatus)));
        session.put("bob", new HashMap<>(Map.of("status", joinerStatus)));
        return session;
    }

    private static void disconnectChecks() {
        long now = 1_800_000_000_000L;
        Map<String, Object> board = board();
        Map<String, Object> session = session(board, "active", "left");
        check(OnlineDuelState.reconcileDisconnect(session, "alice", 0, now, true)
                == OnlineDuelState.NO_CHANGE, "disconnect during my turn has no grace");
        check(OnlineDuelState.disconnectDeadline(board) == 0, "no off-turn deadline");
        check(OnlineDuelState.claim(board, "alice", 0, 0, 0), "play connected first turn");
        check(OnlineDuelState.complete(board, "alice", 0, false, 0), "connected turn advances");
        check(OnlineDuelState.reconcileDisconnect(session, "alice", 1, now, true)
                == OnlineDuelState.GRACE_STARTED, "grace starts on absent opponent turn");
        check(OnlineDuelState.disconnectDeadline(board) == now + 20_000, "persisted 20-second deadline");
        check(OnlineDuelState.reconcileDisconnect(session, "alice", 1, now + 5_000, true)
                == OnlineDuelState.NO_CHANGE, "repeated disconnect event does not extend grace");
        check(OnlineDuelState.disconnectDeadline(board) == now + 20_000, "deadline unchanged on retry");
        check(OnlineDuelState.reconcileDisconnect(session, "alice", 1, now + 19_999, true)
                == OnlineDuelState.NO_CHANGE, "full grace cannot expire early");
        check(OnlineDuelState.reconcileDisconnect(session, "alice", 1, now + 20_000, true)
                == OnlineDuelState.TURN_SKIPPED, "first disconnect timeout skips turn");
        Map<String, Object> skipped = OnlineDuelState.map(OnlineDuelState.map(board.get("turns")).get("t1"));
        check(Boolean.TRUE.equals(skipped.get("done")) && Boolean.TRUE.equals(skipped.get("skipped"))
                && OnlineDuelState.number(skipped.get("points"), -1) == 0, "skipped turn is done for zero points");
        check(!skipped.containsKey("col") && !skipped.containsKey("row"), "missing pick has no invented coordinates");
        check(OnlineDuelState.map(board.get("consumed")).size() == 1, "skip consumes no arbitrary question");
        check(OnlineDuelState.number(board.get("currentTurn"), -1) == 2, "skip hands play back to connected player");
        check(OnlineDuelState.disconnectDeadline(board) == 0, "skip clears expired turn grace");
        check(OnlineDuelState.number(OnlineDuelState.map(board.get("disconnectStrikes")).get("bob"), 0) == 1,
                "first strike is persisted per player");
        check(OnlineDuelState.reconcileDisconnect(session, "alice", 1, now + 40_000, true)
                == OnlineDuelState.NO_CHANGE, "stale timeout cannot skip a second turn");
        check(!OnlineDuelState.complete(board, "bob", 1, true, 0), "late answer cannot resurrect skipped selection");
        check(OnlineDuelState.claim(board, "alice", 2, 0, 1), "local turn still playable after skip");
        check(OnlineDuelState.complete(board, "alice", 2, false, 0), "local turn after skip completes");
        check(OnlineDuelState.reconcileDisconnect(session, "alice", 3, now + 45_000, true)
                == OnlineDuelState.GRACE_STARTED, "next absent turn gets independent grace");
        check(OnlineDuelState.disconnectDeadline(board) == now + 65_000, "second grace is fresh 20 seconds");
        check(OnlineDuelState.reconcileDisconnect(session, "alice", 3, now + 64_999, true)
                == OnlineDuelState.NO_CHANGE, "second timeout also waits full grace");
        check(OnlineDuelState.reconcileDisconnect(session, "alice", 3, now + 65_000, true)
                == OnlineDuelState.FORFEITED, "second disconnect timeout forfeits match");
        check("finished".equals(board.get("phase")) && "forfeit".equals(board.get("finishReason"))
                && "alice".equals(board.get("winnerId")), "connected player wins second timeout");
        check(OnlineDuelState.reconcileDisconnect(session, "alice", 3, now + 80_000, true)
                == OnlineDuelState.NO_CHANGE, "finished timeout retries are immutable");

        board = board();
        session = session(board, "active", "active");
        check(OnlineDuelState.claim(board, "alice", 0, 0, 0), "answering fixture owner pick");
        check(OnlineDuelState.complete(board, "alice", 0, false, 0), "answering fixture owner completes");
        check(OnlineDuelState.claim(board, "bob", 1, 1, 2), "opponent picked before disconnect");
        OnlineDuelState.map(session.get("bob")).put("status", "left_timeout");
        check(OnlineDuelState.reconcileDisconnect(session, "alice", 1, now, true)
                == OnlineDuelState.GRACE_STARTED, "answering phase gets grace");
        check(OnlineDuelState.reconcileDisconnect(session, "alice", 1, now + 20_000, true)
                == OnlineDuelState.TURN_SKIPPED, "answering phase skip completes for zero");
        skipped = OnlineDuelState.map(OnlineDuelState.map(board.get("turns")).get("t1"));
        check(OnlineDuelState.number(skipped.get("col"), -1) == 1
                && OnlineDuelState.number(skipped.get("row"), -1) == 2, "already selected cell remains in ledger");
        check(OnlineDuelState.map(board.get("consumed")).size() == 2, "answer timeout consumes only original pick");
        check(!OnlineDuelState.complete(board, "bob", 1, true, 0), "late answer cannot score skipped question");
        check(OnlineDuelState.number(OnlineDuelState.scores(board).get("bob"), 0) == 0,
                "disconnected answer awards no points");

        board = board();
        session = session(board, "active", "active");
        board.put("currentTurn", 1);
        OnlineDuelState.map(session.get("bob")).put("status", "away");
        check(OnlineDuelState.reconcileDisconnect(session, "alice", 1, now, true)
                == OnlineDuelState.GRACE_STARTED, "away also receives grace");
        OnlineDuelState.map(session.get("bob")).put("status", "active");
        check(OnlineDuelState.reconcileDisconnect(session, "alice", 0, now + 20_000, true)
                == OnlineDuelState.RECONNECTED, "authoritative reconnection clears even stale callback");
        check(OnlineDuelState.disconnectDeadline(board) == 0, "reconnection defeats expiration race");
        check(OnlineDuelState.number(board.get("currentTurn"), -1) == 1, "reconnection leaves turn playable");
        check(OnlineDuelState.claim(board, "bob", 1, 1, 0), "reconnected opponent can claim");
        check(OnlineDuelState.complete(board, "bob", 1, true, 0), "reconnected opponent can answer");
        board.put("disconnectStrikes", new HashMap<>(Map.of("bob", 1)));
        check(OnlineDuelState.reconcileDisconnect(session, "alice", 2, now + 30_000, true)
                == OnlineDuelState.RECONNECTED, "reconnection clears strike during other player turn");
        check(OnlineDuelState.map(board.get("disconnectStrikes")).isEmpty(), "strike history reset on reconnect");
        check(OnlineDuelState.claim(board, "alice", 2, 0, 0), "reconnected fixture local next turn");
        check(OnlineDuelState.complete(board, "alice", 2, false, 0), "reconnected fixture next turn complete");
        OnlineDuelState.map(session.get("bob")).put("status", "left");
        check(OnlineDuelState.reconcileDisconnect(session, "alice", 3, now + 35_000, true)
                == OnlineDuelState.GRACE_STARTED, "new disconnect after reconnection begins fresh grace");
        check(OnlineDuelState.reconcileDisconnect(session, "alice", 3, now + 55_000, true)
                == OnlineDuelState.TURN_SKIPPED, "new disconnect after reconnection is a first strike");

        board = board();
        session = session(board, "active", "left");
        board.put("currentTurn", 1);
        check(OnlineDuelState.reconcileDisconnect(session, "alice", 1, now, false)
                == OnlineDuelState.NO_CHANGE, "locally offline phone cannot start timeout");
        check(OnlineDuelState.reconcileDisconnect(session, "outsider", 1, now, true)
                == OnlineDuelState.NO_CHANGE, "outsider cannot start timeout");
        check(OnlineDuelState.reconcileDisconnect(session, "bob", 1, now, true)
                == OnlineDuelState.NO_CHANGE, "absent player cannot timeout itself");
        check(OnlineDuelState.reconcileDisconnect(session, "alice", 3, now, true)
                == OnlineDuelState.NO_CHANGE, "future turn cannot start grace");
        OnlineDuelState.map(session.get("alice")).put("status", "left");
        check(OnlineDuelState.reconcileDisconnect(session, "alice", 1, now, true)
                == OnlineDuelState.NO_CHANGE, "both absent cannot choose winner");
        OnlineDuelState.map(session.get("alice")).put("status", "active");
        OnlineDuelState.map(session.get("bob")).put("status", "unknown");
        check(OnlineDuelState.reconcileDisconnect(session, "alice", 1, now, true)
                == OnlineDuelState.NO_CHANGE, "unknown status does not imply disconnect");
        OnlineDuelState.map(session.get("bob")).put("status", "left");
        board.put("ready", false);
        check(OnlineDuelState.reconcileDisconnect(session, "alice", 1, now, true)
                == OnlineDuelState.NO_CHANGE, "unready board cannot lose turns");
        board.put("ready", true);
        check(OnlineDuelState.reconcileDisconnect(session, "alice", 1, now, true)
                == OnlineDuelState.GRACE_STARTED, "race fixture starts grace");
        check(OnlineDuelState.reconcileDisconnect(session, "alice", 1, now + 20_000, false)
                == OnlineDuelState.NO_CHANGE, "locally disconnected phone cannot spend existing grace");
        check(OnlineDuelState.number(board.get("currentTurn"), -1) == 1, "offline callback preserves current turn");
        OnlineDuelState.map(session.get("bob")).put("status", "active");
        check(OnlineDuelState.claim(board, "bob", 1, 0, 0), "answer arrives before timeout transaction");
        check(OnlineDuelState.complete(board, "bob", 1, true, 0), "racing answer completes before timeout");
        check(OnlineDuelState.disconnectDeadline(board) == 0, "real completion clears stale grace");
        check(OnlineDuelState.reconcileDisconnect(session, "alice", 1, now + 20_000, true)
                == OnlineDuelState.NO_CHANGE, "completed answer defeats stale timeout");
        check(OnlineDuelState.number(OnlineDuelState.scores(board).get("bob"), 0) == 200,
                "racing real answer keeps original points");

        board = board();
        session = session(board, "active", "left");
        board.put("currentTurn", 1);
        board.put("disconnectGrace", new HashMap<>(Map.of("playerId", "bob", "turn", 1,
                "startedAt", now, "deadlineAt", now + 1)));
        check(OnlineDuelState.disconnectDeadline(board) == 0, "malformed deadline is not spendable");
        check(OnlineDuelState.reconcileDisconnect(session, "alice", 1, now + 10, true)
                == OnlineDuelState.GRACE_STARTED, "malformed deadline restarts full grace");
        check(OnlineDuelState.disconnectDeadline(board) == now + 20_010, "invalid deadline cannot shortcut wait");
        OnlineDuelState.map(board.get("disconnectGrace")).put("turn", 3);
        check(OnlineDuelState.disconnectDeadline(board) == 0, "another turn deadline is ignored");
        check(OnlineDuelState.reconcileDisconnect(session, "alice", 1, now + 50, true)
                == OnlineDuelState.GRACE_STARTED, "stale turn grace restarts current turn");

        board = board();
        session = session(board, "left", "active");
        check(OnlineDuelState.reconcileDisconnect(session, "bob", 0, now, true)
                == OnlineDuelState.GRACE_STARTED, "joiner can observe absent owner");
        check(OnlineDuelState.reconcileDisconnect(session, "bob", 0, now + 20_000, true)
                == OnlineDuelState.TURN_SKIPPED, "absent owner first timeout also skips");
        check(OnlineDuelState.claim(board, "bob", 1, 1, 0), "joiner can play after absent owner skip");
        check(OnlineDuelState.complete(board, "bob", 1, false, 0), "joiner completes own turn");
        check(OnlineDuelState.reconcileDisconnect(session, "bob", 2, now + 30_000, true)
                == OnlineDuelState.GRACE_STARTED, "owner gets second independent grace");
        check(OnlineDuelState.reconcileDisconnect(session, "bob", 2, now + 50_000, true)
                == OnlineDuelState.FORFEITED && "bob".equals(board.get("winnerId")), "joiner wins absent owner forfeit");

        board = board();
        session = session(board, "active", "active");
        for (int turn = 0; turn < 11; turn++) {
            String picker = OnlineDuelState.picker(board, turn);
            check(OnlineDuelState.claim(board, picker, turn, turn / 6, turn % 6), "last-turn fixture pick");
            check(OnlineDuelState.complete(board, picker, turn, "bob".equals(picker), 0), "last-turn fixture answer");
        }
        check(OnlineDuelState.number(OnlineDuelState.scores(board).get("bob"), 0)
                > OnlineDuelState.number(OnlineDuelState.scores(board).get("alice"), 0), "absent player leads before terminal skip");
        OnlineDuelState.map(session.get("bob")).put("status", "left");
        check(OnlineDuelState.reconcileDisconnect(session, "alice", 11, now, true)
                == OnlineDuelState.GRACE_STARTED, "final turn still allows full grace");
        check(OnlineDuelState.reconcileDisconnect(session, "alice", 11, now + 20_000, true)
                == OnlineDuelState.FORFEITED, "final scheduled timeout cannot leave match hanging");
        check("alice".equals(board.get("winnerId")), "connected player wins terminal timeout regardless score");
        check(OnlineDuelState.number(board.get("currentTurn"), -1) == 12, "terminal skip respects total turns");
        check(OnlineDuelState.map(board.get("consumed")).size() == 11, "terminal missing selection consumes no cell");
        check(OnlineDuelState.disconnectDeadline(board) == 0, "terminal timeout clears deadline");

        board = board();
        session = session(board, "active", "active");
        for (int turn = 0; turn < 3; turn++) {
            String picker = OnlineDuelState.picker(board, turn);
            check(OnlineDuelState.claim(board, picker, turn, 0, turn), "leading-score fixture pick");
            check(OnlineDuelState.complete(board, picker, turn, "bob".equals(picker), 0), "leading-score fixture answer");
        }
        OnlineDuelState.map(session.get("bob")).put("status", "left");
        check(OnlineDuelState.reconcileDisconnect(session, "alice", 3, now, true)
                == OnlineDuelState.GRACE_STARTED, "leading opponent first grace");
        check(OnlineDuelState.reconcileDisconnect(session, "alice", 3, now + 20_000, true)
                == OnlineDuelState.TURN_SKIPPED, "leading opponent first strike skips");
        check(OnlineDuelState.claim(board, "alice", 4, 1, 0), "connected player takes intervening turn");
        check(OnlineDuelState.complete(board, "alice", 4, false, 0), "connected player keeps lower score");
        check(OnlineDuelState.reconcileDisconnect(session, "alice", 5, now + 30_000, true)
                == OnlineDuelState.GRACE_STARTED, "leading opponent second grace");
        check(OnlineDuelState.reconcileDisconnect(session, "alice", 5, now + 50_000, true)
                == OnlineDuelState.FORFEITED, "second strike forfeits before scheduled end");
        check(OnlineDuelState.number(OnlineDuelState.scores(board).get("bob"), 0) > 0
                && OnlineDuelState.number(OnlineDuelState.scores(board).get("alice"), 0) == 0
                && "alice".equals(board.get("winnerId")), "lower-score connected player wins second strike");

        board = board();
        session = session(board, "active", "left");
        board.put("currentTurn", 1);
        board.put("turns", new HashMap<>(Map.of("t1", new HashMap<>(Map.of("playerId", "alice")))));
        check(OnlineDuelState.reconcileDisconnect(session, "alice", 1, now, true)
                == OnlineDuelState.NO_CHANGE, "wrong-picker ledger cannot be skipped or overwritten");
        check(!board.containsKey("disconnectGrace"), "wrong-picker ledger cannot start grace");
    }

    public static void main(String[] args) {
        disconnectChecks();
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
        queue.put("alice", waiting("", now));
        queue.put("bob", waiting("", now));
        OnlineDuelState.map(queue.get("alice")).put("stakeCoins", 50L);
        check(!OnlineMatchmakingState.claim(queue, "alice", "bob", "paid-free", now), "paid search never matches old free client");
        OnlineDuelState.map(queue.get("bob")).put("stakeCoins", 100L);
        check(!OnlineMatchmakingState.claim(queue, "alice", "bob", "different-tier", now), "different stakes cannot match");
        OnlineDuelState.map(queue.get("bob")).put("stakeCoins", 50L);
        check(OnlineMatchmakingState.claim(queue, "alice", "bob", "same-tier", now), "equal stakes match atomically");
        for (Object invalid : new Object[]{15L, 30L, -1L, 4294967346L, 50.5, "50"}) {
            queue.put("alice", waiting("", now));
            queue.put("bob", waiting("", now));
            OnlineDuelState.map(queue.get("alice")).put("stakeCoins", invalid);
            OnlineDuelState.map(queue.get("bob")).put("stakeCoins", invalid);
            check(!OnlineMatchmakingState.claim(queue, "alice", "bob", "invalid-tier", now), "invalid stake cannot join queue");
        }
        System.out.println("PASS: " + checks + " duel and matchmaking checks (150 complete matches)");
    }
}
