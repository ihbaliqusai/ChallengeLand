package com.qi7bali.landchallengeonline;

import android.content.Context;
import android.content.SharedPreferences;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.RandomAccessFile;
import java.nio.channels.FileLock;
import java.nio.charset.StandardCharsets;

import java.util.Arrays;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

/** Durable per-installation contributions, independent of restored cloud totals. */
public final class ProgressionSyncState {
    private ProgressionSyncState() {}

    private static final Set<String> ADDITIVE = new HashSet<>(Arrays.asList(
            "xp", "gamesPlayed", "wins", "losses", "draws", "abandoned",
            "correctAnswers", "wrongAnswers", "totalEarnings", "onlineWins",
            "trophiesEarned", "trophiesLost", "blitzFinishes", "eliminationWins",
            "survivalWins", "seriesWins", "teamBattleWins", "localTeamsPlayed",
            "offlineBoardPlayed", "offlineBoardWins", "friendMatchesPlayed",
            "randomMatchesPlayed", "trophies"));
    private static final Set<String> MAXIMUM = new HashSet<>(Arrays.asList(
            "bestStreak", "bestWinStreak", "highestMoney", "bestTrophies"));

    private static boolean additive(String key) {
        return ADDITIVE.contains(key) || key.startsWith("mode_");
    }

    /** Android excludes this directory from backup and device transfer. */
    private static String installationId(Context context) {
        try {
            File directory = context.getNoBackupFilesDir();
            if (directory == null || (!directory.isDirectory() && !directory.mkdirs())) {
                throw new IOException("Installation identity directory is unavailable");
            }
            File epoch = new File(directory, "progression-installation-v1");
            File lockFile = new File(directory, "progression-installation-v1.lock");
            // A lock also prevents two Android processes from choosing separate
            // identities during the first launch of the same installation.
            try (RandomAccessFile lockStorage = new RandomAccessFile(lockFile, "rw");
                 FileLock ignored = lockStorage.getChannel().lock()) {
                if (epoch.exists()) {
                    byte[] bytes = new byte[37];
                    int count = 0;
                    try (FileInputStream input = new FileInputStream(epoch)) {
                        int read;
                        while (count < bytes.length && (read = input.read(bytes, count, bytes.length - count)) != -1) {
                            count += read;
                        }
                    }
                    if (count != 36) throw new IOException("Installation identity is invalid");
                    String persisted = new String(bytes, 0, count, StandardCharsets.US_ASCII);
                    try {
                        if (!UUID.fromString(persisted).toString().equals(persisted)) {
                            throw new IOException("Installation identity is invalid");
                        }
                    } catch (IllegalArgumentException invalid) {
                        throw new IOException("Installation identity is invalid", invalid);
                    }
                    return persisted;
                }
                String created = UUID.randomUUID().toString();
                File pending = File.createTempFile("progression-installation-", ".tmp", directory);
                try {
                    try (FileOutputStream output = new FileOutputStream(pending)) {
                        output.write(created.getBytes(StandardCharsets.US_ASCII));
                        output.getFD().sync();
                    }
                    if (!pending.renameTo(epoch)) throw new IOException("Cannot commit installation identity");
                    return created;
                } finally {
                    if (pending.exists()) pending.delete();
                }
            }
        } catch (IOException | SecurityException failure) {
            // Sending an ephemeral ID would create an unrecoverable cloud
            // stream. Defer synchronization until the durable file is usable.
            throw new IllegalStateException("Cannot persist progression installation identity", failure);
        }
    }

    public static synchronized Map<String, Object> capture(Context context) {
        String installation = installationId(context);
        String uid = ProgressionAccount.uid(context);
        SharedPreferences storage = ProgressionAccount.preferences(context);
        Map<String, Integer> stats = PlayerStats.snapshot(context);
        Map<String, Long> contributions = new HashMap<>();
        SharedPreferences.Editor editor = storage.edit();
        boolean sameInstallation = installation.equals(storage.getString("sync_installationId", ""));
        boolean initialized = sameInstallation && storage.getBoolean("sync_initialized", false);
        String deviceId = sameInstallation ? storage.getString("sync_deviceId", "") : "";
        if (!sameInstallation) {
            // Restored preferences describe another installation's stream.
            // Keep all player statistics and receipts, but start contributions
            // from the restored totals rather than replaying the other device.
            for (String key : storage.getAll().keySet()) {
                if (key.startsWith("sync_contribution_") || key.startsWith("sync_observed_")) editor.remove(key);
            }
        }
        if (deviceId.isEmpty()) {
            deviceId = UUID.randomUUID().toString();
            editor.putString("sync_deviceId", deviceId);
        }
        for (Map.Entry<String, Integer> entry : stats.entrySet()) {
            String key = entry.getKey();
            if (!additive(key)) continue;
            long current = entry.getValue();
            // The existing account snapshot is the legacy/cloud baseline, not
            // a new contribution from this installation. Launch initializes
            // this checkpoint before the first game can award progression.
            long previous = storage.getLong("sync_observed_" + key, current);
            long delta = current - previous;
            if (!key.equals("trophies")) delta = Math.max(0L, delta);
            long total = initialized ? storage.getLong("sync_contribution_" + key, 0L) + delta : 0L;
            contributions.put(key, total);
            editor.putLong("sync_contribution_" + key, total);
            editor.putLong("sync_observed_" + key, current);
        }
        ProgressionAccount.commitOrRollback(storage, editor
                .putString("sync_installationId", installation)
                .putBoolean("sync_initialized", true));
        Map<String, Object> result = new HashMap<>();
        result.put("accountUid", uid);
        result.put("deviceId", deviceId);
        result.put("stats", stats);
        result.put("contributions", contributions);
        return result;
    }

    public static synchronized boolean hydrate(Context context, String uid,
            Map<String, Number> cloudStats, Map<String, Number> acknowledged) {
        if (uid == null || !uid.equals(ProgressionAccount.uid(context))) return false;
        Map<String, Object> current = capture(context);
        @SuppressWarnings("unchecked")
        Map<String, Long> contributions = (Map<String, Long>) current.get("contributions");
        @SuppressWarnings("unchecked")
        Map<String, Integer> nativeStats = (Map<String, Integer>) current.get("stats");
        Map<String, Integer> restored = new HashMap<>();
        for (Map.Entry<String, Number> entry : cloudStats.entrySet()) {
            String key = entry.getKey();
            long value = entry.getValue().longValue();
            if (additive(key)) {
                Number acknowledgedValue = acknowledged.get(key);
                long pending = contributions.getOrDefault(key, 0L) -
                        (acknowledgedValue == null ? 0L : acknowledgedValue.longValue());
                if (!key.equals("trophies")) pending = Math.max(0L, pending);
                value += pending;
            } else if (MAXIMUM.contains(key)) {
                value = Math.max(value, nativeStats.getOrDefault(key, 0));
            }
            restored.put(key, (int) Math.max(0L, Math.min(Integer.MAX_VALUE, value)));
        }
        // Capture and hydration run on the same platform thread. The durable
        // observed totals are rebased with the actual native hydration; new
        // rewards during a network round-trip remain pending contributions.
        SharedPreferences storage = ProgressionAccount.preferences(context);
        SharedPreferences.Editor editor = storage.edit();
        PlayerStats.writeHydration(editor, restored);
        PlayerProgress.writeHydration(editor, restored);
        for (Map.Entry<String, Integer> entry : restored.entrySet()) {
            if (additive(entry.getKey())) {
                editor.putLong("sync_observed_" + entry.getKey(), entry.getValue());
            }
        }
        ProgressionAccount.commitOrRollback(storage, editor);
        PlayerProgress.checkProgressionAchievements(context);
        return true;
    }
}
