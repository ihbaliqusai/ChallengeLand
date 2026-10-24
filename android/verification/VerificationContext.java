package com.qi7bali.landchallengeonline;

import android.content.Context;
import android.content.SharedPreferences;
import java.io.File;
import java.io.IOException;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;

/** Account-aware memory backend with Android's apply-before-disk-failure behavior. */
final class VerificationContext extends Context {
    private final Map<String, VerificationPreferences> namespaces = new HashMap<>();
    private final File noBackupDirectory;

    VerificationContext() {
        this(freshInstallationDirectory());
    }

    VerificationContext(File noBackupDirectory) {
        this.noBackupDirectory = noBackupDirectory;
    }

    private static File freshInstallationDirectory() {
        try { return java.nio.file.Files.createTempDirectory("challengeland-no-backup-").toFile(); }
        catch (IOException failure) { throw new AssertionError(failure); }
    }

    @Override public File getNoBackupFilesDir() { return noBackupDirectory; }

    void restorePreferencesFrom(VerificationContext source) {
        for (Map.Entry<String, VerificationPreferences> entry : source.namespaces.entrySet()) {
            namespace(entry.getKey()).values.putAll(entry.getValue().getAll());
        }
    }

    @Override public synchronized SharedPreferences getSharedPreferences(String name, int mode) {
        return namespace(name);
    }

    synchronized VerificationPreferences namespace(String name) {
        return namespaces.computeIfAbsent(name, ignored -> new VerificationPreferences());
    }

    VerificationPreferences account() {
        return (VerificationPreferences) ProgressionAccount.preferences(this);
    }

    void switchAccount(String uid) {
        AppPrefs.setUser(this, uid, uid, "", 1, 0);
    }
}

final class VerificationPreferences implements SharedPreferences {
    final Map<String, Object> values = new HashMap<>();
    Map<String, Object> lastCommit = new HashMap<>();
    boolean failNextCommit;
    int failOnCommit = -1;
    int commits;

    @Override public synchronized int getInt(String key, int fallback) {
        return (Integer) values.getOrDefault(key, fallback);
    }
    @Override public synchronized long getLong(String key, long fallback) {
        return (Long) values.getOrDefault(key, fallback);
    }
    @Override public synchronized float getFloat(String key, float fallback) {
        return (Float) values.getOrDefault(key, fallback);
    }
    @Override public synchronized boolean getBoolean(String key, boolean fallback) {
        return (Boolean) values.getOrDefault(key, fallback);
    }
    @Override public synchronized String getString(String key, String fallback) {
        return (String) values.getOrDefault(key, fallback);
    }
    @SuppressWarnings("unchecked")
    @Override public synchronized Set<String> getStringSet(String key, Set<String> fallback) {
        return new HashSet<>((Set<String>) values.getOrDefault(key, fallback));
    }
    @Override public synchronized Map<String, ?> getAll() { return new HashMap<>(values); }
    @Override public synchronized boolean contains(String key) { return values.containsKey(key); }

    @Override public Editor edit() {
        return new Editor() {
            final Map<String, Object> updates = new HashMap<>();
            boolean clear;
            @Override public Editor putInt(String key, int value) { updates.put(key, value); return this; }
            @Override public Editor putLong(String key, long value) { updates.put(key, value); return this; }
            @Override public Editor putFloat(String key, float value) { updates.put(key, value); return this; }
            @Override public Editor putBoolean(String key, boolean value) { updates.put(key, value); return this; }
            @Override public Editor putString(String key, String value) { updates.put(key, value); return this; }
            @Override public Editor putStringSet(String key, Set<String> value) {
                updates.put(key, new HashSet<>(value)); return this;
            }
            @Override public Editor clear() { clear = true; return this; }
            @Override public Editor remove(String key) { updates.put(key, null); return this; }
            @Override public void apply() {
                synchronized (VerificationPreferences.this) {
                    if (clear) values.clear();
                    for (Map.Entry<String, Object> entry : updates.entrySet()) {
                        if (entry.getValue() == null) values.remove(entry.getKey());
                        else values.put(entry.getKey(), entry.getValue());
                    }
                }
            }
            @Override public boolean commit() {
                synchronized (VerificationPreferences.this) {
                    lastCommit = new HashMap<>(updates);
                    apply(); // Android changes memory before reporting the disk result.
                    commits++;
                    if (!failNextCommit && failOnCommit != commits) return true;
                    failNextCommit = false;
                    return false;
                }
            }
        };
    }
}
