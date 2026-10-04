package com.qi7bali.landchallengeonline;

import android.content.Context;
import android.content.SharedPreferences;
import java.util.Map;
import java.util.Set;

/** The result ledger, XP, statistics and inventory belong to an account, never a device. */
public final class ProgressionAccount {
    private ProgressionAccount() {}

    public static String uid(Context c) {
        String uid = AppPrefs.getUserId(c);
        return uid == null || uid.trim().isEmpty() ? "guest_local" : uid.trim();
    }

    public static synchronized SharedPreferences preferences(Context c) {
        String uid = uid(c);
        SharedPreferences p = c.getSharedPreferences("PlayerProgress_v2_" + uid, Context.MODE_PRIVATE);
        if (p.getBoolean("accountInitialized", false)) return p;
        SharedPreferences migration = c.getSharedPreferences("ProgressionMigration", Context.MODE_PRIVATE);
        String owner = migration.getString("legacyOwner", "");
        SharedPreferences.Editor e = p.edit();
        // The first account seen by this upgrade owns the old device snapshot.
        // Claim before copying so another account can never import the same XP.
        if (owner == null || owner.isEmpty()) {
            commitOrRollback(migration, migration.edit().putString("legacyOwner", uid));
            owner = uid;
        }
        if (uid.equals(owner)) {
            copy(c.getSharedPreferences("PlayerProgress", Context.MODE_PRIVATE).getAll(), e);
            copy(c.getSharedPreferences("PlayerStats", Context.MODE_PRIVATE).getAll(), e);
        }
        commitOrRollback(p, e.putBoolean("accountInitialized", true));
        return p;
    }

    @SuppressWarnings("unchecked")
    private static void copy(Map<String, ?> values, SharedPreferences.Editor e) {
        for (Map.Entry<String, ?> item : values.entrySet()) {
            Object v = item.getValue(); String k = item.getKey();
            if (v instanceof Integer) e.putInt(k, (Integer) v);
            else if (v instanceof Long) e.putLong(k, (Long) v);
            else if (v instanceof Boolean) e.putBoolean(k, (Boolean) v);
            else if (v instanceof String) e.putString(k, (String) v);
            else if (v instanceof Float) e.putFloat(k, (Float) v);
            else if (v instanceof Set) e.putStringSet(k, (Set<String>) v);
        }
    }

    /** SharedPreferences updates memory even when commit reports a disk failure. */
    public static void commitOrRollback(SharedPreferences p, SharedPreferences.Editor editor) {
        Map<String, ?> previous = p.getAll();
        if (editor.commit()) return;
        SharedPreferences.Editor rollback = p.edit().clear();
        copy(previous, rollback);
        rollback.commit();
        throw new IllegalStateException("Cannot persist player progression");
    }
}
