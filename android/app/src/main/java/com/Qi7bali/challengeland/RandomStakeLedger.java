package com.qi7bali.landchallengeonline;

import android.content.Context;
import android.content.SharedPreferences;

/** Durable, account-scoped reservations for the legacy random/bot match wallet. */
final class RandomStakeLedger {
    private RandomStakeLedger() {}
    static boolean validAmount(int amount) {
        return OnlineMatchmakingState.validAmount(amount);
    }
    private static String key(String id) { return "randomStake:" + id; }

    static boolean reserve(Context c, String id, int amount) {
        synchronized (PlayerProgress.class) {
            if (id == null || id.isEmpty() || !validAmount(amount) || amount == 0) return false;
            SharedPreferences p = ProgressionAccount.preferences(c);
            String k = key(id), status = p.getString(k + ":status", "");
            if (!status.isEmpty()) return "pending".equals(status) && p.getInt(k, 0) == amount;
            // A process killed while searching cannot leave an unstarted reservation behind.
            String old = p.getString("randomStakePending", "");
            if (!old.isEmpty()) cancel(c, old);
            int balance = PlayerProgress.getCoins(c);
            if (balance < amount || (long) balance + amount > Integer.MAX_VALUE) return false;
            ProgressionAccount.commitOrRollback(p, p.edit().putInt("coins", balance - amount)
                    .putInt(k, amount).putString(k + ":status", "pending")
                    .putString("randomStakePending", id));
            return true;
        }
    }

    static boolean activate(Context c, String id) {
        synchronized (PlayerProgress.class) {
            SharedPreferences p = ProgressionAccount.preferences(c);
            String k = key(id), status = p.getString(k + ":status", "");
            if ("active".equals(status) || "settled".equals(status)) return true;
            if (!"pending".equals(status)) return false;
            ProgressionAccount.commitOrRollback(p, p.edit().putString(k + ":status", "active")
                    .remove("randomStakePending"));
            return true;
        }
    }

    static void cancel(Context c, String id) {
        synchronized (PlayerProgress.class) {
            SharedPreferences p = ProgressionAccount.preferences(c);
            String k = key(id);
            if (!"pending".equals(p.getString(k + ":status", ""))) return;
            int coins = ProgressionRules.safeAdd(PlayerProgress.getCoins(c), p.getInt(k, 0));
            ProgressionAccount.commitOrRollback(p, p.edit().putInt("coins", coins)
                    .putString(k + ":status", "cancelled").remove("randomStakePending"));
        }
    }

    static boolean settle(Context c, String id, boolean win, boolean draw) {
        synchronized (PlayerProgress.class) {
            SharedPreferences p = ProgressionAccount.preferences(c);
            String k = key(id), status = p.getString(k + ":status", "");
            if ("settled".equals(status)) return false;
            if (!"active".equals(status)) throw new IllegalStateException("Match stake is not reserved");
            int amount = p.getInt(k, 0), payout = draw ? amount : win ? amount * 2 : 0;
            int coins = ProgressionRules.safeAdd(PlayerProgress.getCoins(c), payout);
            ProgressionAccount.commitOrRollback(p, p.edit().putInt("coins", coins)
                    .putString(k + ":status", "settled"));
            return true;
        }
    }
}
