package com.qi7bali.landchallengeonline;

import java.util.HashMap;
import java.util.Map;

public final class RoomBoardRecoveryTest {
    private static int checks;
    private static void check(boolean condition, String message) {
        checks++;
        if (!condition) throw new AssertionError(message);
    }
    private static Map<String, Object> turn(int col, int row, boolean correct, boolean half, boolean done) {
        return new HashMap<>(Map.of("col", col, "row", row, "correct", correct, "half", half, "done", done));
    }
    public static void main(String[] args) {
        Map<String, Object> turns = new HashMap<>();
        Map<String, Object> board = Map.of("turns", turns);
        int[] values = {200, 400, 600};
        RoomBoardRecovery.State empty = RoomBoardRecovery.restore(board, 2, 6, values);
        check(empty.nextTurn == 0 && empty.scores[0] == 0, "new game starts at zero");
        turns.put("t0", turn(0, 0, true, false, true));
        turns.put("t1", turn(1, 1, true, true, true));
        turns.put("t2", turn(0, 2, false, false, true));
        turns.put("t3", turn(1, 3, false, false, false));
        RoomBoardRecovery.State recovered = RoomBoardRecovery.restore(board, 2, 6, values);
        check(recovered.nextTurn == 3, "rejoin skips committed turns");
        check(recovered.scores[0] == 200 && recovered.scores[1] == 200, "scores include half-value choices");
        check(recovered.consumed[0][0] && recovered.consumed[1][1] && recovered.consumed[0][2], "answered cells stay consumed");
        check(!recovered.consumed[1][3], "pending question can be restored");
        check(recovered.pendingCol == 1 && recovered.pendingRow == 3, "same pending cell");
        check(RoomBoardRecovery.restore(board, 2, 6, values).scores[0] == 200, "repeated restore cannot double score");
        turns.put("t3", turn(0, 0, true, false, true));
        recovered = RoomBoardRecovery.restore(board, 2, 6, values);
        check(recovered.nextTurn == 3 && recovered.scores[1] == 200, "duplicate cell never scores twice");
        turns.put("t3", turn(9, -1, true, false, true));
        check(RoomBoardRecovery.restore(board, 2, 6, values).nextTurn == 3, "invalid cell does not advance");
        turns.clear();
        for (int t = 0; t < 12; t++) turns.put("t" + t, turn(t / 6, t % 6, true, false, true));
        recovered = RoomBoardRecovery.restore(board, 2, 6, values);
        check(recovered.nextTurn == 12, "finished game goes straight to result");
        check(recovered.scores[0] == 2400 && recovered.scores[1] == 2400, "all final scores restored");
        System.out.println("PASS: " + checks + " room board recovery checks");
    }
}
