package com.qi7bali.landchallengeonline;

import android.app.Activity;
import android.content.SharedPreferences;
import org.json.JSONObject;

public final class OnlineMatchRecoveryCheck {
    private static int assertions;

    private static final class Game extends Activity {
        private final VerificationContext device;
        Game(VerificationContext device) {
            this.device = device;
            getIntent().putExtra("mode", "online").putExtra("matchMode", "board");
            NativeProgression.restore(this, null);
        }
        @Override public SharedPreferences getSharedPreferences(String name, int mode) {
            return device.getSharedPreferences(name, mode);
        }
        @Override public java.io.File getNoBackupFilesDir() { return device.getNoBackupFilesDir(); }
    }

    private static void check(boolean condition, String label) {
        assertions++;
        if (!condition) throw new AssertionError(label);
    }

    public static void main(String[] args) throws Exception {
        VerificationContext device = new VerificationContext();
        device.switchAccount("alice");
        Game bot = new Game(device);
        bot.getIntent().putExtra("stakeCoins", 100).putExtra("randomStakeId", "reservation")
                .putExtra("meOwner", true).putExtra("opponentsJson", "[{\"bot\":true}]");
        OnlineMatchRecovery.track(bot);
        String botId = OnlineMatchRecovery.pending(device).getJSONObject(0).getString("id");
        check(OnlineMatchRecovery.hasActiveMatch(device, null), "unfinished bot blocks a new launch");
        check(OnlineMatchRecovery.read(device, botId).getString("matchId")
                .equals(NativeProgression.fallbackId(bot)), "bot loss uses its original progression identity");
        JSONObject board = new JSONObject("{\"state\":{\"turnIndex\":5,\"scores\":[400,200],\"cells\":[{\"consumed\":true}]}}");
        OnlineMatchRecovery.saveBotCheckpoint(bot, board);
        bot.getIntent().putExtra("economySessionId", "paid-once");
        OnlineMatchRecovery.updateLaunch(bot);
        check(OnlineMatchRecovery.botCheckpoint(bot).getJSONObject("state").getInt("turnIndex") == 5,
                "refreshing launch preserves turn checkpoint");
        check(!OnlineMatchRecovery.pending(device).getJSONObject(0).has("checkpoint"),
                "summary excludes board answers");

        Game reopenedApp = new Game(device);
        OnlineMatchRecovery.resume(reopenedApp, botId);
        android.content.Intent launch = reopenedApp.lastStartedIntent;
        check(launch != null && launch.getBooleanExtra("resumeOnlineMatch", false), "relaunch after process death");
        check(launch.getIntExtra("stakeCoins", 0) == 100, "stake amount type preserved");
        check("reservation".equals(launch.getStringExtra("randomStakeId")), "same stake receipt");
        check("paid-once".equals(launch.getStringExtra("economySessionId")), "same admission receipt");
        check(bot.getIntent().getStringExtra("progressionMatchId").equals(launch.getStringExtra("progressionMatchId")),
                "same result identity prevents duplicate rewards");
        check(launch.getBooleanExtra("meOwner", false), "player role preserved");

        Game human = new Game(device);
        human.getIntent().putExtra("duelSessionId", "existing-duel");
        OnlineMatchRecovery.track(human);
        OnlineMatchRecovery.track(human);
        check(OnlineMatchRecovery.pending(device).length() == 2, "legacy multiple saves stay available for explicit resolution");
        check("duel:existing-duel".equals(OnlineMatchRecovery.read(device, "duel:existing-duel").getString("matchId")),
                "human identity is stable before activity board initialization");
        OnlineMatchRecovery.resume(reopenedApp, "duel:existing-duel");
        check("existing-duel".equals(reopenedApp.lastStartedIntent.getStringExtra("duelSessionId")),
                "human match resumes reserved session");
        OnlineMatchRecovery.complete(human, "خسرت المباراة بسبب المغادرة", false);
        JSONObject terminal = null;
        for (int i = 0; i < OnlineMatchRecovery.pending(device).length(); i++) {
            JSONObject candidate = OnlineMatchRecovery.pending(device).getJSONObject(i);
            if (candidate.getString("id").equals("duel:existing-duel")) terminal = candidate;
        }
        check(terminal != null && terminal.getBoolean("finished"), "background result is retained");
        check(terminal.getString("message").contains("خسرت"), "loss explanation is durable");
        try {
            OnlineMatchRecovery.resume(reopenedApp, "duel:existing-duel");
            throw new AssertionError("terminal match cannot restart");
        } catch (IllegalStateException expected) { assertions++; }

        device.switchAccount("bob");
        check(OnlineMatchRecovery.pending(device).length() == 0, "account isolation");
        OnlineMatchRecovery.saveBotCheckpoint(bot, new JSONObject());
        OnlineMatchRecovery.updateLaunch(bot);
        check(OnlineMatchRecovery.pending(device).length() == 0, "stale activity cannot save into another account");
        try {
            OnlineMatchRecovery.resume(reopenedApp, botId);
            throw new AssertionError("wrong account cannot resume");
        } catch (IllegalStateException expected) { assertions++; }
        device.switchAccount("alice");
        check(OnlineMatchRecovery.botCheckpoint(bot).getJSONObject("state").getInt("turnIndex") == 5,
                "original account checkpoint survives account switch");
        OnlineMatchRecovery.dismiss(device, "duel:existing-duel");
        check(OnlineMatchRecovery.pending(device).length() == 1, "acknowledgement clears only its result");
        OnlineMatchRecovery.complete(bot, "انتهت", true);
        OnlineMatchRecovery.updateLaunch(bot);
        check(OnlineMatchRecovery.pending(device).length() == 0, "pause cannot recreate an observed result");
        check(OnlineMatchRecovery.isFinished(bot), "Android recreation cannot restart a finished bot match");
        OnlineMatchRecovery.track(bot);
        check(OnlineMatchRecovery.pending(device).length() == 0, "observed match stays finished on recreation");
        Game room = new Game(device);
        room.getIntent().putExtra("roomId", "room-1");
        OnlineMatchRecovery.track(room);
        check(!OnlineMatchRecovery.hasActiveMatch(device, "room-1"), "next round of the same room is allowed");
        check(OnlineMatchRecovery.hasActiveMatch(device, "different-room"), "another room requires withdrawal");
        try {
            OnlineMatchRecovery.resume(reopenedApp, "room:room-1:1");
            throw new AssertionError("room recovery must refresh membership through lobby");
        } catch (IllegalStateException expected) { assertions++; }
        device.account().failNextCommit = true;
        try {
            OnlineMatchRecovery.finishSaved(device, "room:room-1:1", "خسرت", true);
            throw new AssertionError("failed withdrawal must not allow a new match");
        } catch (IllegalStateException expected) { assertions++; }
        check(OnlineMatchRecovery.hasActiveMatch(device, null), "failed commit keeps the previous match active");
        OnlineMatchRecovery.finishSaved(device, "room:room-1:1", "خسرت بسبب الانسحاب", true);
        check(!OnlineMatchRecovery.hasActiveMatch(device, null), "confirmed withdrawal releases the active match");
        check(OnlineMatchRecovery.isFinished(room), "withdrawn activity cannot restart on recreation");
        OnlineMatchRecovery.complete(room, "فزت", false);
        check(OnlineMatchRecovery.read(device, "room:room-1:1").getString("message").contains("خسرت"),
                "late activity completion cannot overwrite a withdrawal result");
        OnlineMatchRecovery.track(room);
        check(!OnlineMatchRecovery.hasActiveMatch(device, null), "old pause callbacks cannot recreate withdrawn recovery");
        OnlineMatchRecovery.finishSaved(device, "room:room-1:1", "نتيجة متأخرة", false);
        check(OnlineMatchRecovery.pending(device).length() == 0, "late inspection cannot resurrect an acknowledged result");
        System.out.println("Online recovery checks passed (" + assertions + " assertions)");
    }
}
