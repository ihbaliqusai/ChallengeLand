package com.qi7bali.landchallengeonline;

import android.content.Context;
import android.content.SharedPreferences;
import java.util.LinkedHashMap;
import java.util.Map;

/** Account statistics and durable answer/match receipts, committed atomically with XP. */
public class PlayerStats {
    private static final String[] COUNTERS = {
            "gamesPlayed", "wins", "losses", "draws", "abandoned", "highestMoney", "lastPrize",
            "correctAnswers", "wrongAnswers", "bestStreak", "currentStreak", "currentWinStreak",
            "bestWinStreak", "trophies", "bestTrophies", "trophiesEarned", "trophiesLost", "xp",
            "onlineWins", "blitzFinishes", "eliminationWins", "survivalWins", "seriesWins", "teamBattleWins",
            "localTeamsPlayed", "offlineBoardPlayed", "offlineBoardWins", "friendMatchesPlayed", "randomMatchesPlayed"
    };
    private static final String[] MODES = {"campaign", "offline", "local_teams", "board", "battle",
            "team_battle", "blitz", "elimination", "survival", "series"};
    private static SharedPreferences prefs(Context c) { return ProgressionAccount.preferences(c); }
    private static int value(Context c, String key) { return prefs(c).getInt(key, 0); }
    public static int getGamesPlayed(Context c) { return value(c, "gamesPlayed"); }
    public static int getWins(Context c) { return value(c, "wins"); }
    public static int getLosses(Context c) { return value(c, "losses"); }
    public static int getDraws(Context c) { return value(c, "draws"); }
    public static int getAbandoned(Context c) { return value(c, "abandoned"); }
    public static int getTrophies(Context c) { return value(c, "trophies"); }
    public static int getBestTrophies(Context c) { return value(c, "bestTrophies"); }
    public static int getTrophiesEarned(Context c) { return value(c, "trophiesEarned"); }
    public static int getTrophiesLost(Context c) { return value(c, "trophiesLost"); }
    public static int getHighestMoney(Context c) { return value(c, "highestMoney"); }
    public static int getLastPrize(Context c) { return value(c, "lastPrize"); }
    public static long getTotalEarnings(Context c) { return prefs(c).getLong("totalEarnings", 0); }
    public static int getCorrectAnswers(Context c) { return value(c, "correctAnswers"); }
    public static int getWrongAnswers(Context c) { return value(c, "wrongAnswers"); }
    public static int getTotalAnswered(Context c) { return ProgressionRules.safeAdd(getCorrectAnswers(c), getWrongAnswers(c)); }
    public static int getBestStreak(Context c) { return value(c, "bestStreak"); }
    public static int getCurrentStreak(Context c) { return value(c, "currentStreak"); }
    public static int getCurrentWinStreak(Context c) { return value(c, "currentWinStreak"); }
    public static int getBestWinStreak(Context c) { return value(c, "bestWinStreak"); }

    public static Map<String, Integer> snapshot(Context c) {
        Map<String, Integer> result = new LinkedHashMap<>();
        for (String key : COUNTERS) result.put(key, value(c, key));
        for (String mode : MODES) {
            for (String field : new String[]{"games", "wins", "losses", "draws", "abandoned"}) {
                String key = "mode_" + mode + "_" + field;
                result.put(key, value(c, key));
            }
        }
        int games = getGamesPlayed(c), answered = getTotalAnswered(c);
        result.put("totalAnswered", answered);
        result.put("winStreak", getCurrentWinStreak(c));
        result.put("totalEarnings", (int)Math.min(Integer.MAX_VALUE, getTotalEarnings(c)));
        result.put("winPercent", games == 0 ? 0 : (int)((long)getWins(c) * 100 / games));
        result.put("accuracy", answered == 0 ? 0 : (int)((long)getCorrectAnswers(c) * 100 / answered));
        result.put("level", PlayerProgress.getLevel(c));
        result.put("progressionVersion", 2);
        return result;
    }

    public static void writeHydration(SharedPreferences.Editor e, Map<String, Integer> values) {
        for (String key : COUNTERS) if (values.containsKey(key)) e.putInt(key, Math.max(0, values.get(key)));
        for (Map.Entry<String, Integer> item : values.entrySet()) {
            if (item.getKey().startsWith("mode_")) e.putInt(item.getKey(), Math.max(0, item.getValue()));
        }
        if (values.containsKey("winStreak")) e.putInt("currentWinStreak", Math.max(0, values.get("winStreak")));
        if (values.containsKey("totalEarnings")) e.putLong("totalEarnings", Math.max(0, values.get("totalEarnings")));
    }

    public static synchronized void hydrateProgression(Context c, Map<String, Integer> values) {
        SharedPreferences.Editor e = prefs(c).edit();
        writeHydration(e, values);
        ProgressionAccount.commitOrRollback(prefs(c), e);
    }

    public static void recordCorrectAnswer(Context c) { recordAnswer(c, true, true); }
    public static void recordCorrectAnswer(Context c, boolean grantCoins) { recordAnswer(c, true, grantCoins); }
    public static void recordWrongAnswer(Context c) { recordAnswer(c, false, true); }
    public static void recordWrongAnswer(Context c, boolean grantCoins) { recordAnswer(c, false, grantCoins); }

    private static synchronized void recordAnswer(Context c, boolean correct, boolean grantCoins) {
        if (!NativeProgression.activeAccount(c)) return;
        SharedPreferences p = prefs(c);
        String match = NativeProgression.matchId(c), question = NativeProgression.answerId(c);
        String receipt = "answer:" + match + ":" + question;
        if (question.isEmpty() || p.contains("match:" + match) || p.getBoolean(receipt, false)) return;
        int streak = correct ? ProgressionRules.safeAdd(p.getInt("currentStreak", 0), 1) : 0;
        String counter = correct ? "correctAnswers" : "wrongAnswers";
        String sessionCounter = "session:" + match + (correct ? ":correct" : ":wrong");
        SharedPreferences.Editor e = p.edit()
                .putBoolean(receipt, true)
                .putInt(counter, ProgressionRules.safeAdd(p.getInt(counter, 0), 1))
                .putInt(sessionCounter, ProgressionRules.safeAdd(p.getInt(sessionCounter, 0), 1))
                .putBoolean("session:" + match + ":humanOnline", p.getBoolean("session:" + match + ":humanOnline", false) || NativeProgression.humanOnline(c))
                .putInt("currentStreak", streak)
                .putInt("bestStreak", Math.max(streak, p.getInt("bestStreak", 0)))
                .putInt("xp", ProgressionRules.safeAdd(p.getInt("xp", 0), correct ? 10 : 3));
        // Campaign currency comes from the stage payout on Flutter. Legacy
        // board paths use this overload too, so enforce the mode policy here.
        if (correct && grantCoins && !"campaign".equals(NativeProgression.mode(c))
                && !PlayerProgress.isCoinStake(c)) {
            e.putInt("coins", ProgressionRules.safeAdd(p.getInt("coins", 0), 20));
        }
        ProgressionAccount.commitOrRollback(p, e);
        PlayerProgress.checkProgressionAchievements(c);
    }

    public static void recordGameEnd(Context c, boolean won, int prizeMoney) {
        recordGameEnd(c, won ? ProgressionRules.WIN : ProgressionRules.LOSS, prizeMoney);
    }

    public static synchronized void recordGameEnd(Context c, String outcome, int prizeMoney) {
        recordGameEnd(c, outcome, prizeMoney, false);
    }

    /** An accepted human duel has a real winner/loser even before the first answer. */
    public static synchronized void recordOnlineDuelForfeit(Context c, boolean won, int prizeMoney) {
        if (!NativeProgression.activeAccount(c) || !NativeProgression.online(c)
                || !NativeProgression.humanOnline(c) || !"board".equals(NativeProgression.mode(c))) return;
        String id = NativeProgression.matchId(c);
        if (id == null || !id.startsWith("duel:") || id.length() <= "duel:".length()) return;
        recordGameEnd(c, won ? ProgressionRules.WIN : ProgressionRules.LOSS, prizeMoney, true);
    }

    private static void recordGameEnd(Context c, String outcome, int prizeMoney, boolean duelForfeit) {
        if (!NativeProgression.activeAccount(c)) return;
        SharedPreferences p = prefs(c);
        String id = NativeProgression.matchId(c), receipt = "match:" + id;
        if (p.contains(receipt)) return;
        if (!ProgressionRules.WIN.equals(outcome) && !ProgressionRules.DRAW.equals(outcome)
                && !ProgressionRules.ABANDON.equals(outcome)) outcome = ProgressionRules.LOSS;
        int correct = p.getInt("session:" + id + ":correct", 0);
        int answered = ProgressionRules.safeAdd(correct, p.getInt("session:" + id + ":wrong", 0));
        // An empty lobby or a result reached before gameplay is not a played
        // match and must not unlock wins, milestones, XP or trophies.
        if (answered == 0 && !duelForfeit) return;
        if (answered == 0 && duelForfeit
                && !p.contains("pendingDuel:" + id.substring("duel:".length()))) return;
        int games = p.getInt("gamesPlayed", 0);
        boolean won = ProgressionRules.WIN.equals(outcome);
        int streak = won ? ProgressionRules.safeAdd(p.getInt("currentWinStreak", 0), 1) : 0;
        String mode = NativeProgression.mode(c);
        if (mode == null || mode.isEmpty()) mode = "offline";
        int oldTrophies = p.getInt("trophies", 0);
        int requestedDelta = duelForfeit
                ? ProgressionRules.onlineDuelForfeitTrophyDelta(won, games, streak, correct, answered)
                : ProgressionRules.trophyDelta(mode, outcome,
                        p.getBoolean("session:" + id + ":humanOnline", false) || NativeProgression.humanOnline(c), games, streak, correct, answered);
        int nextTrophies = ProgressionRules.safeAdd(oldTrophies, requestedDelta);
        int delta = nextTrophies - oldTrophies;
        int xp = answered == 0 ? 0 : ProgressionRules.completionXp(outcome, NativeProgression.online(c));
        int prize = Math.max(0, prizeMoney);
        String field = won ? "wins" : ProgressionRules.DRAW.equals(outcome) ? "draws"
                : ProgressionRules.ABANDON.equals(outcome) ? "abandoned" : "losses";
        String modeGames = "mode_" + mode + "_games", modeOutcome = "mode_" + mode + "_" + field;
        SharedPreferences.Editor e = p.edit()
                .putString(receipt, outcome)
                .putInt("reward:" + id + ":xp", (int)Math.min(Integer.MAX_VALUE, (long)xp + (long)correct * 10 + (long)(answered - correct) * 3))
                .putInt("reward:" + id + ":trophies", delta)
                .putInt("gamesPlayed", ProgressionRules.safeAdd(games, 1))
                .putInt(field, ProgressionRules.safeAdd(p.getInt(field, 0), 1))
                .putInt(modeGames, ProgressionRules.safeAdd(p.getInt(modeGames, 0), 1))
                .putInt(modeOutcome, ProgressionRules.safeAdd(p.getInt(modeOutcome, 0), 1))
                .putInt("lastPrize", prize)
                .putInt("highestMoney", Math.max(prize, p.getInt("highestMoney", 0)))
                .putLong("totalEarnings", saturatedEarnings(p.getLong("totalEarnings", 0), prize))
                .putInt("currentStreak", 0)
                .putInt("currentWinStreak", streak)
                .putInt("bestWinStreak", Math.max(streak, p.getInt("bestWinStreak", 0)))
                .putInt("xp", ProgressionRules.safeAdd(p.getInt("xp", 0), xp))
                .putInt("trophies", nextTrophies)
                .putInt("bestTrophies", Math.max(nextTrophies, p.getInt("bestTrophies", 0)))
                .putInt("trophiesEarned", ProgressionRules.safeAdd(p.getInt("trophiesEarned", 0), Math.max(0, delta)))
                .putInt("trophiesLost", ProgressionRules.safeAdd(p.getInt("trophiesLost", 0), Math.max(0, -delta)));
        if (NativeProgression.online(c) && won) {
            e.putInt("onlineWins", ProgressionRules.safeAdd(p.getInt("onlineWins", 0), 1));
            String winCounter = "team_battle".equals(mode) ? "teamBattleWins" : mode + "Wins";
            if ("team_battle".equals(mode) || "series".equals(mode) || "survival".equals(mode) || "elimination".equals(mode)) {
                e.putInt(winCounter, ProgressionRules.safeAdd(p.getInt(winCounter, 0), 1));
            }
        }
        if ("blitz".equals(mode) && !ProgressionRules.ABANDON.equals(outcome)) {
            e.putInt("blitzFinishes", ProgressionRules.safeAdd(p.getInt("blitzFinishes", 0), 1));
        }
        ProgressionAccount.commitOrRollback(p, e);
        PlayerProgress.checkProgressionAchievements(c);
    }

    private static long saturatedEarnings(long earnings, int prize) {
        long base = Math.max(0L, earnings);
        return base > Long.MAX_VALUE - prize ? Long.MAX_VALUE : base + prize;
    }

    public static String matchOutcome(Context c) { return prefs(c).getString("match:" + NativeProgression.matchId(c), ""); }
    public static int matchXp(Context c) { return value(c, "reward:" + NativeProgression.matchId(c) + ":xp"); }
    public static int matchTrophies(Context c) { return value(c, "reward:" + NativeProgression.matchId(c) + ":trophies"); }

    public static String matchRewardSummary(Context c) {
        int trophies = matchTrophies(c);
        return "+" + matchXp(c) + " XP  •  " + (trophies >= 0 ? "+" : "") + trophies + " كأس";
    }

    public static void reset(Context c) {
        SharedPreferences.Editor e = prefs(c).edit();
        for (String key : COUNTERS) if (!"xp".equals(key)) e.remove(key);
        for (String key : prefs(c).getAll().keySet()) if (key.startsWith("mode_")) e.remove(key);
        e.remove("totalEarnings").apply();
    }
}
