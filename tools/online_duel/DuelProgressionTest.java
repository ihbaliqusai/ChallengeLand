package com.qi7bali.landchallengeonline;

import android.app.Activity;
import android.content.SharedPreferences;
import android.os.Handler;
import com.google.firebase.auth.FirebaseAuth;
import com.google.firebase.database.FirebaseDatabase;
import java.io.File;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

public final class DuelProgressionTest {
    private static int checks;
    private static File root;

    private static void check(boolean condition, String message) {
        checks++;
        if (!condition) throw new AssertionError(message);
    }

    private static final class Preferences implements SharedPreferences {
        final Map<String, Object> values = new HashMap<>();
        boolean failNextCommit;
        @Override public Map<String, ?> getAll() { return new HashMap<>(values); }
        @Override public int getInt(String key, int fallback) { return (Integer) values.getOrDefault(key, fallback); }
        @Override public long getLong(String key, long fallback) { return (Long) values.getOrDefault(key, fallback); }
        @Override public boolean getBoolean(String key, boolean fallback) { return (Boolean) values.getOrDefault(key, fallback); }
        @Override public String getString(String key, String fallback) { return (String) values.getOrDefault(key, fallback); }
        @Override public boolean contains(String key) { return values.containsKey(key); }
        @Override public Editor edit() {
            return new Editor() {
                final Map<String, Object> pending = new HashMap<>();
                final Set<String> removed = new HashSet<>();
                boolean clear;
                @Override public Editor putInt(String key, int value) { pending.put(key, value); return this; }
                @Override public Editor putLong(String key, long value) { pending.put(key, value); return this; }
                @Override public Editor putBoolean(String key, boolean value) { pending.put(key, value); return this; }
                @Override public Editor putString(String key, String value) { pending.put(key, value); return this; }
                @Override public Editor putFloat(String key, float value) { pending.put(key, value); return this; }
                @Override public Editor putStringSet(String key, Set<String> value) { pending.put(key, value); return this; }
                @Override public Editor remove(String key) { removed.add(key); return this; }
                @Override public Editor clear() { clear = true; return this; }
                @Override public void apply() { commit(); }
                @Override public boolean commit() {
                    if (clear) values.clear();
                    for (String key : removed) values.remove(key);
                    values.putAll(pending);
                    if (!failNextCommit) return true;
                    failNextCommit = false;
                    return false;
                }
            };
        }
    }

    private static final class Match extends Activity implements ProgressionMatchHost {
        final Map<String, Preferences> storage = new HashMap<>();
        final File directory = new File(root, UUID.randomUUID().toString());
        String id = "duel:session-1", mode = "board", answer = "first";
        boolean online = true, human = true;
        Match() { getIntent().putExtra("progressionAccountUid", "alice"); }
        @Override public SharedPreferences getSharedPreferences(String name, int ignored) {
            return storage.computeIfAbsent(name, key -> new Preferences());
        }
        @Override public File getNoBackupFilesDir() { return directory; }
        @Override public String progressionMatchId() { return id; }
        @Override public String progressionMode() { return mode; }
        @Override public String progressionAnswerId() { return answer; }
        @Override public boolean progressionOnline() { return online; }
        @Override public boolean progressionHumanOpponents() { return human; }
        Preferences preferences() { return (Preferences) ProgressionAccount.preferences(this); }
    }

    @SuppressWarnings("unchecked")
    private static Map<String, Long> contributions(Match match) {
        return (Map<String, Long>) ProgressionSyncState.capture(match).get("contributions");
    }

    private static Match acceptedMatch() {
        Match match = new Match();
        OnlineDuelResultStore.track(match, "session-1", "bob");
        return match;
    }

    private static Map<String, Object> terminal(String reason, String winner) {
        Map<String, Object> board = new HashMap<>();
        board.put("ownerId", "alice");
        board.put("joinerId", "bob");
        board.put("phase", "finished");
        board.put("finishReason", reason);
        board.put("winnerId", winner);
        return board;
    }

    private static void recoveryChecks() {
        FirebaseDatabase database = FirebaseDatabase.getInstance();
        Match beforeCrash = new Match();
        beforeCrash.id = "duel:crashed-session";
        beforeCrash.preferences().edit().putInt("trophies", 80).commit();
        contributions(beforeCrash);
        OnlineDuelResultStore.track(beforeCrash, "crashed-session", "bob");
        check(beforeCrash.preferences().contains("pendingDuel:crashed-session"), "session is durable before process death");
        OnlineDuelResultStore.clearCompleted(beforeCrash, "crashed-session");
        check(beforeCrash.preferences().contains("pendingDuel:crashed-session"), "no clearing before a result receipt");
        Match reopened = new Match();
        reopened.id = "duel:a-different-visible-match";
        reopened.storage.putAll(beforeCrash.storage);
        database.values.put("Games/crashed-session/board", terminal("forfeit", "bob"));
        int[] completions = {0};
        OnlineDuelResultStore.replayPending(reopened, () -> completions[0]++);
        check(completions[0] == 1, "recovery completion is delivered exactly once");
        check(PlayerStats.getLosses(reopened) == 1 && PlayerStats.getTrophies(reopened) == 70,
                "crashed loser is penalized on the next startup snapshot");
        check(reopened.preferences().getString("match:duel:crashed-session", "").equals(ProgressionRules.LOSS),
                "recovery receipt belongs to the original session");
        check(PlayerStats.matchOutcome(reopened).isEmpty(), "recovery cannot finish a different visible match");
        check(!reopened.preferences().contains("pendingDuel:crashed-session"), "pending identity removed after receipt commit");
        int reads = database.reads;
        OnlineDuelResultStore.replayPending(reopened, () -> completions[0]++);
        check(database.reads == reads && PlayerStats.getLosses(reopened) == 1, "second startup cannot replay loss twice");

        Match foreign = new Match();
        OnlineDuelResultStore.track(foreign, "foreign-board", "bob");
        Map<String, Object> wrongPlayers = terminal("forfeit", "bob");
        wrongPlayers.put("ownerId", "charlie");
        database.values.put("Games/foreign-board/board", wrongPlayers);
        OnlineDuelResultStore.replayPending(foreign, () -> {});
        check(PlayerStats.getGamesPlayed(foreign) == 0, "unrelated terminal cannot penalize the account");
        check(foreign.preferences().contains("pendingDuel:foreign-board"), "unrelated terminal does not discard pending identity");

        Match changedAccount = new Match();
        OnlineDuelResultStore.track(changedAccount, "account-session", "bob");
        database.values.put("Games/account-session/board", terminal("forfeit", "bob"));
        FirebaseAuth.getInstance().setUid("bob");
        OnlineDuelResultStore.replayPending(changedAccount, () -> {});
        check(PlayerStats.getGamesPlayed(changedAccount) == 0, "Firebase/account binding mismatch blocks replay");
        FirebaseAuth.getInstance().setUid("alice");

        Match slow = new Match();
        slow.preferences().edit().putInt("trophies", 80).commit();
        OnlineDuelResultStore.track(slow, "slow-session", "bob");
        database.values.put("Games/slow-session/board", terminal("forfeit", "bob"));
        database.deferReads = true;
        int[] timedCompletions = {0};
        OnlineDuelResultStore.replayPending(slow, () -> timedCompletions[0]++);
        check(timedCompletions[0] == 0, "snapshot waits for a bounded recovery read");
        Handler.fireTimeouts();
        check(timedCompletions[0] == 1, "offline snapshot completes on timeout");
        check(slow.preferences().contains("pendingDuel:slow-session"), "timeout retains pending identity");
        database.completePending("Games/slow-session/board");
        check(PlayerStats.getLosses(slow) == 0 && timedCompletions[0] == 1,
                "a timed-out callback cannot mutate progression behind the captured snapshot");
        database.deferReads = false;
        OnlineDuelResultStore.replayPending(slow, () -> timedCompletions[0]++);
        check(PlayerStats.getLosses(slow) == 1 && PlayerStats.getTrophies(slow) == 70,
                "later reconnect replay applies the retained loss");

        Match normal = new Match();
        normal.id = "duel:normal-session";
        OnlineDuelResultStore.track(normal, "normal-session", "bob");
        PlayerStats.recordCorrectAnswer(normal, false);
        database.values.put("Games/normal-session/board", terminal("completed", "alice"));
        OnlineDuelResultStore.replayPending(normal, () -> {});
        check(PlayerStats.getWins(normal) == 1 && PlayerStats.getTrophies(normal) == 30,
                "normal result interrupted after gameplay can also recover");
        check(!normal.preferences().contains("pendingDuel:normal-session"), "normal receipt also clears pending identity");
    }

    public static void main(String[] args) {
        root = new File(args[0], "installations");
        check(ProgressionRules.onlineDuelForfeitTrophyDelta(false, 0, 0, 0, 0) == -10,
                "a first-game forfeit must lose trophies");
        check(ProgressionRules.onlineDuelForfeitTrophyDelta(false, 8, 0, 0, 0) == -18,
                "experienced-player loss uses existing penalty");
        check(ProgressionRules.onlineDuelForfeitTrophyDelta(true, 0, 1, 0, 0) == 30,
                "human winner receives existing base award without fabricated accuracy");
        check(ProgressionRules.trophyDelta("board", ProgressionRules.WIN, true, 0, 1, 0, 0) == 0,
                "normal empty lobby still receives no trophies");

        Match loss = acceptedMatch();
        loss.preferences().edit().putInt("trophies", 80).commit();
        contributions(loss); // Same checkpoint used before opening a real match.
        PlayerStats.recordOnlineDuelForfeit(loss, false, 0);
        check(PlayerStats.getGamesPlayed(loss) == 1, "zero-answer forfeit is one completed match");
        check(PlayerStats.getLosses(loss) == 1, "forfeit is counted as a loss");
        check(PlayerStats.getAbandoned(loss) == 0, "loss is not hidden in abandoned counter");
        check(PlayerStats.getTrophies(loss) == 70, "loss commits offline immediately");
        check(PlayerStats.getTrophiesLost(loss) == 10, "actual loss is retained in trophy history");
        check(PlayerStats.getTotalAnswered(loss) == 0, "no fake answer for eligibility");
        check(PlayerStats.snapshot(loss).get("xp") == 0, "no zero-answer XP fabricated");
        check(ProgressionRules.LOSS.equals(PlayerStats.matchOutcome(loss)), "durable outcome is loss");
        check(contributions(loss).get("trophies") == -10L, "negative trophy contribution survives offline sync");
        PlayerStats.recordOnlineDuelForfeit(loss, false, 0);
        PlayerStats.recordOnlineDuelForfeit(loss, true, 999);
        check(PlayerStats.getGamesPlayed(loss) == 1, "duplicate terminal callbacks do not count twice");
        check(PlayerStats.getTrophies(loss) == 70, "duplicate/reversed result cannot change trophies");
        check(contributions(loss).get("trophies") == -10L, "retry captures do not replay trophy loss");
        Match recreated = new Match();
        recreated.storage.putAll(loss.storage);
        PlayerStats.recordOnlineDuelForfeit(recreated, false, 0);
        check(PlayerStats.getLosses(recreated) == 1, "activity recreation retains match receipt");

        Match win = acceptedMatch();
        PlayerStats.recordOnlineDuelForfeit(win, true, 0);
        check(PlayerStats.getWins(win) == 1, "zero-answer remaining player wins by forfeit");
        check(PlayerStats.getTrophies(win) == 30, "winner receives human online trophy award");
        check(PlayerStats.snapshot(win).get("onlineWins") == 1, "online-win counter follows authoritative winner");
        check(PlayerStats.getTotalAnswered(win) == 0, "winner's answer history stays accurate");
        PlayerStats.recordGameEnd(win, ProgressionRules.LOSS, 0);
        check(PlayerStats.getWins(win) == 1 && PlayerStats.getLosses(win) == 0,
                "score-derived result cannot overwrite the existing forfeit winner");

        for (int invalid = 0; invalid < 5; invalid++) {
            Match empty = new Match();
            if (invalid == 1) empty.online = false;
            if (invalid == 2) empty.human = false;
            if (invalid == 3) empty.mode = "campaign";
            if (invalid == 4) empty.id = "unaccepted-lobby";
            if (invalid == 0) PlayerStats.recordGameEnd(empty, ProgressionRules.WIN, 100);
            else PlayerStats.recordOnlineDuelForfeit(empty, true, 100);
            check(PlayerStats.getGamesPlayed(empty) == 0, "invalid/empty lobby cannot grant progression " + invalid);
            check(PlayerStats.getTrophies(empty) == 0, "invalid/empty lobby cannot grant trophies " + invalid);
            check(PlayerStats.matchOutcome(empty).isEmpty(), "invalid/empty lobby receives no match receipt " + invalid);
        }

        Match uncreated = new Match();
        PlayerStats.recordOnlineDuelForfeit(uncreated, false, 0);
        check(PlayerStats.getGamesPlayed(uncreated) == 0 && PlayerStats.getLosses(uncreated) == 0,
                "allocated ID without a committed session cannot be penalized");

        Match accountChanged = new Match();
        AppPrefs.uid = "bob";
        PlayerStats.recordOnlineDuelForfeit(accountChanged, false, 0);
        check(PlayerStats.getGamesPlayed(accountChanged) == 0, "old match cannot penalize another account");
        AppPrefs.uid = "alice";

        Match floor = acceptedMatch();
        floor.preferences().edit().putInt("trophies", 4).putInt("gamesPlayed", 8).commit();
        PlayerStats.recordOnlineDuelForfeit(floor, false, 0);
        check(PlayerStats.getTrophies(floor) == 0, "trophy balance never goes below zero");
        check(PlayerStats.matchTrophies(floor) == -4, "receipt stores actual clamped penalty");

        Match answered = new Match();
        PlayerStats.recordCorrectAnswer(answered, false);
        answered.answer = "second";
        PlayerStats.recordWrongAnswer(answered);
        PlayerStats.recordOnlineDuelForfeit(answered, false, 0);
        check(PlayerStats.getCorrectAnswers(answered) == 1 && PlayerStats.getWrongAnswers(answered) == 1,
                "forfeit preserves already-recorded answers");
        check(PlayerStats.snapshot(answered).get("xp") == 43, "answered loss preserves normal completion XP");

        Match failed = acceptedMatch();
        failed.preferences().edit().putInt("trophies", 80).commit();
        failed.preferences().failNextCommit = true;
        boolean threw = false;
        try { PlayerStats.recordOnlineDuelForfeit(failed, false, 0); }
        catch (IllegalStateException expected) { threw = true; }
        check(threw, "failed disk commit is surfaced");
        check(PlayerStats.getTrophies(failed) == 80 && PlayerStats.matchOutcome(failed).isEmpty(),
                "failed commit rolls back penalty and receipt together");
        PlayerStats.recordOnlineDuelForfeit(failed, false, 0);
        check(PlayerStats.getTrophies(failed) == 70 && PlayerStats.getLosses(failed) == 1,
                "retry after failed commit awards exactly once");
        recoveryChecks();
        System.out.println("Duel progression checks passed: " + checks);
    }
}
