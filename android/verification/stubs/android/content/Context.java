package android.content;

/** JVM verification stand-in; excluded from Android app source sets. */
public abstract class Context {
    public static final int MODE_PRIVATE = 0;
    public abstract SharedPreferences getSharedPreferences(String name, int mode);
    public abstract java.io.File getNoBackupFilesDir();
}
