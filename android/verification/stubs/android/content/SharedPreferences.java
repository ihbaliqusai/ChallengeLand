package android.content;

/** Only the preference operations exercised by the production currency store. */
public interface SharedPreferences {
    int getInt(String key, int fallback);
    boolean getBoolean(String key, boolean fallback);
    default String getString(String key, String fallback) { return fallback; }
    default long getLong(String key, long fallback) { return fallback; }
    default float getFloat(String key, float fallback) { return fallback; }
    default java.util.Set<String> getStringSet(String key, java.util.Set<String> fallback) { return fallback; }
    default java.util.Map<String, ?> getAll() { return new java.util.HashMap<>(); }
    default boolean contains(String key) { return getAll().containsKey(key); }
    Editor edit();

    interface Editor {
        Editor putInt(String key, int value);
        Editor putBoolean(String key, boolean value);
        default Editor putString(String key, String value) { return this; }
        default Editor putLong(String key, long value) { return this; }
        default Editor putFloat(String key, float value) { return this; }
        default Editor putStringSet(String key, java.util.Set<String> value) { return this; }
        default Editor clear() { return this; }
        Editor remove(String key);
        void apply();
        boolean commit();
    }
}
