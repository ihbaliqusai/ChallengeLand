package com.qi7bali.landchallengeonline;

/** Pure rules shared by every native game mode. Keep in sync with trophy_league.dart. */
public final class ProgressionRules {
    private ProgressionRules() {}
    public static final String WIN = "win", LOSS = "loss", DRAW = "draw", ABANDON = "abandon";

    public static int trophyDelta(String outcome, boolean humanOnline, int gamesBefore,
                                  int winStreak, int correct, int answered) {
        if (DRAW.equals(outcome)) return 0;
        if (!WIN.equals(outcome)) return gamesBefore < 8 ? -10 : -18;
        int delta = 22 + (humanOnline ? 8 : 0);
        if (winStreak >= 3) delta += (int) Math.min(10L, ((long) winStreak - 2) * 2);
        if (answered >= 5) {
            if ((long) correct * 100 >= (long) answered * 90) delta += 5;
            else if ((long) correct * 100 >= (long) answered * 75) delta += 3;
        }
        return delta;
    }

    /** Shared hot-seat sessions have no account-specific winner. */
    public static int trophyDelta(String mode, String outcome, boolean humanOnline, int gamesBefore,
                                  int winStreak, int correct, int answered) {
        if (answered <= 0) return 0;
        if ("local_teams".equals(mode) && DRAW.equals(outcome)) return 6;
        return trophyDelta(outcome, humanOnline, gamesBefore, winStreak, correct, answered);
    }

    /** Only a confirmed human duel forfeit can resolve without an answered question. */
    public static int onlineDuelForfeitTrophyDelta(boolean won, int gamesBefore,
                                                 int winStreak, int correct, int answered) {
        return trophyDelta(won ? WIN : LOSS, true, gamesBefore, winStreak, correct, answered);
    }

    public static int completionXp(String outcome, boolean online) {
        if (ABANDON.equals(outcome)) return 0;
        if (WIN.equals(outcome)) return online ? 100 : 80;
        if (DRAW.equals(outcome)) return online ? 50 : 40;
        return online ? 30 : 20;
    }

    public static int safeAdd(int value, int delta) {
        return (int) Math.max(0L, Math.min(Integer.MAX_VALUE, (long) value + delta));
    }
}
