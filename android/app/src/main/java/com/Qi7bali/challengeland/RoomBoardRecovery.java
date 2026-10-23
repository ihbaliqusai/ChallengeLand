package com.qi7bali.landchallengeonline;

import java.util.Map;

/** Rebuild a room's board from committed turns without replaying rewards or answers. */
final class RoomBoardRecovery {
    static final class State {
        final int[] scores;
        final boolean[][] consumed;
        int nextTurn;
        int pendingCol = -1;
        int pendingRow = -1;
        State(int seats, int rows) {
            scores = new int[seats];
            consumed = new boolean[seats][rows];
        }
    }

    static State restore(Map<String, Object> board, int seats, int rows, int[] values) {
        State state = new State(seats, rows);
        Map<String, Object> turns = OnlineDuelState.map(board.get("turns"));
        for (int turn = 0; turn < seats * rows; turn++) {
            Map<String, Object> result = OnlineDuelState.map(turns.get("t" + turn));
            int col = OnlineDuelState.number(result.get("col"), -1);
            int row = OnlineDuelState.number(result.get("row"), -1);
            if (col < 0 || col >= seats || row < 0 || row >= rows || state.consumed[col][row]) break;
            if (!Boolean.TRUE.equals(result.get("done"))) {
                state.pendingCol = col;
                state.pendingRow = row;
                break;
            }
            state.consumed[col][row] = true;
            if (Boolean.TRUE.equals(result.get("correct"))) {
                int value = values[row % values.length];
                if (Boolean.TRUE.equals(result.get("half"))) value /= 2;
                state.scores[turn % seats] += value;
            }
            state.nextTurn = turn + 1;
        }
        return state;
    }
}
