package com.qi7bali.landchallengeonline;

import android.app.Activity;
import android.content.SharedPreferences;
import java.util.HashMap;
import java.util.Map;
import org.json.JSONObject;

/** Exercises the actual durable round journal without authentication or network calls. */
public final class EconomyRoundLedgerCheck {
    private static int assertions;

    public static void main(String[] args) throws Exception {
        VerificationContext device = new VerificationContext();
        device.switchAccount("round_owner");
        SharedPreferences ledger = wallet(device, "round_owner");
        String session = "match_room_one_key";

        Round first = new Round(device, "room:one:battle:1");
        answers(first, 7, 2);
        GameEconomy.queueRound(first, session);
        equal(pendingCount(ledger), 1, "first round is durably queued");
        Map.Entry<String, ?> firstEntry = pending(ledger);
        JSONObject report = new JSONObject(firstEntry.getValue().toString());
        equal(report.getString("action"), "progressRound", "journal invokes the round endpoint");
        equal(report.getString("sessionId"), session, "round uses the paid match session");
        equal(report.getString("roundId"), "room:one:battle:1", "identity preserves the round number");
        equal(report.getInt("correct"), 7, "round records correct answers");
        equal(report.getInt("answered"), 9, "round includes wrong answers in activity");
        check(report.getString("operationId").matches("round_[a-f0-9]{64}"), "operation ID is valid and fixed length");

        Round recreated = new Round(device, "room:one:battle:1");
        GameEconomy.queueRound(recreated, session);
        equal(pendingCount(ledger), 1, "result recreation cannot queue a second copy");
        ledger.edit().putBoolean("finished:" + session, true)
                .putString("pending:" + session, "{\"action\":\"finish\",\"sessionId\":\"" + session + "\"}").commit();
        Round second = new Round(device, "room:one:battle:2");
        answers(second, 5, 1);
        GameEconomy.queueRound(second, session);
        equal(pendingCount(ledger), 2, "later round survives an already finished resource session");
        check(pending(ledger).getKey().startsWith("pendingRound:"), "rounds flush before the final match journal");
        ledger.edit().remove("finished:" + session).commit();

        for (int i = 0; i < 2; i++) {
            Map.Entry<String, ?> entry = pending(ledger);
            JSONObject payload = new JSONObject(entry.getValue().toString());
            GameEconomy.markPendingComplete(ledger, entry.getKey(), data(payload));
            check(ledger.getBoolean("reportedRound:" + payload.getString("operationId"), false), "successful report retains a delivery receipt");
            check(!ledger.getBoolean("finished:" + session, false), "round acknowledgement does not end the shared match");
        }
        equal(pendingCount(ledger), 0, "successful round reports leave no pending copies");
        equal(pending(ledger).getKey(), "pending:" + session, "final match is sent after every round");
        GameEconomy.queueRound(first, session);
        GameEconomy.queueRound(second, session);
        equal(pendingCount(ledger), 0, "success receipts prevent report replay after restart");
        GameEconomy.markPendingComplete(ledger, "pending:" + session, Map.of("sessionId", session));
        check(ledger.getBoolean("finished:" + session, false), "final acknowledgement marks only the resource session finished");
        check(pending(ledger) == null, "fully acknowledged journal is empty");

        Round empty = new Round(device, "room:empty:battle:1");
        GameEconomy.queueRound(empty, "empty_match");
        equal(pendingCount(ledger), 0, "lobby without answers earns no weekly activity");
        Round wrongOnly = new Round(device, "room:wrong:battle:1");
        answers(wrongOnly, 0, 4);
        GameEconomy.queueRound(wrongOnly, "wrong_match");
        JSONObject wrongReport = new JSONObject(pending(ledger).getValue().toString());
        equal(wrongReport.getInt("answered"), 4, "played rounds with wrong answers still count as activity");
        equal(wrongReport.getInt("correct"), 0, "wrong answers never become correct answers");

        device.switchAccount("another_owner");
        SharedPreferences secondWallet = wallet(device, "another_owner");
        check(pending(secondWallet) == null, "a second account cannot inherit pending reports");
        check(pending(ledger) != null, "account switch preserves the original owner's journal");
        Map.Entry<String, ?> oldPending = pending(ledger);
        JSONObject oldPayload = new JSONObject(oldPending.getValue().toString());
        GameEconomy.markPendingComplete(ledger, oldPending.getKey(), data(oldPayload));
        check(!secondWallet.getBoolean("reportedRound:" + oldPayload.getString("operationId"), false),
                "late acknowledgement cannot write its receipt to the new account");
        check(ledger.getBoolean("reportedRound:" + oldPayload.getString("operationId"), false),
                "late acknowledgement remains bound to its captured account preferences");
        System.out.println("Economy round journal checks passed (" + assertions + " assertions)");
    }

    private static SharedPreferences wallet(VerificationContext device, String uid) {
        return device.getSharedPreferences("Economy_v1_" + uid, 0);
    }
    private static Map.Entry<String, ?> pending(SharedPreferences ledger) throws Exception {
        return GameEconomy.nextPending(ledger);
    }
    private static long pendingCount(SharedPreferences ledger) {
        return ledger.getAll().keySet().stream().filter(key -> key.startsWith("pendingRound:")).count();
    }
    private static Map<String, Object> data(JSONObject payload) {
        Map<String, Object> data = new HashMap<>();
        for (String key : payload.keySet()) data.put(key, payload.get(key));
        return data;
    }
    private static void answers(Round round, int correct, int wrong) {
        ProgressionAccount.preferences(round).edit()
                .putInt("session:" + round.id + ":correct", correct)
                .putInt("session:" + round.id + ":wrong", wrong).commit();
    }
    private static void equal(Object actual, Object expected, String message) {
        // Number wrappers differ for the stream count and JSON integer paths.
        check(actual instanceof Number && expected instanceof Number
                ? ((Number) actual).longValue() == ((Number) expected).longValue()
                : expected.equals(actual), message + ": expected " + expected + ", got " + actual);
    }
    private static void check(boolean condition, String message) {
        assertions++;
        if (!condition) throw new AssertionError(message);
    }
    private static final class Round extends Activity implements ProgressionMatchHost {
        final VerificationContext device;
        final String id;
        Round(VerificationContext device, String id) { this.device = device; this.id = id; }
        @Override public SharedPreferences getSharedPreferences(String name, int mode) {
            return device.getSharedPreferences(name, mode);
        }
        @Override public java.io.File getNoBackupFilesDir() { return device.getNoBackupFilesDir(); }
        @Override public String progressionMatchId() { return id; }
        @Override public String progressionMode() { return "battle"; }
        @Override public String progressionAnswerId() { return ""; }
        @Override public boolean progressionOnline() { return true; }
        @Override public boolean progressionHumanOpponents() { return true; }
    }
}
