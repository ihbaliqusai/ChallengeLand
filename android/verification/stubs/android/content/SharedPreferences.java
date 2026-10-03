package android.content;

/** Only the preference operations exercised by the production currency store. */
public interface SharedPreferences {
    int getInt(String key, int fallback);
    boolean getBoolean(String key, boolean fallback);
    Editor edit();

    interface Editor {
        Editor putInt(String key, int value);
        Editor putBoolean(String key, boolean value);
        Editor remove(String key);
        void apply();
        boolean commit();
    }
}
