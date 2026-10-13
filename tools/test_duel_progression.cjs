// Runs production progression code against an in-memory Android preference store.
const { mkdirSync, writeFileSync } = require('node:fs');
const { resolve, join } = require('node:path');
const { execFileSync } = require('node:child_process');
const root = resolve(__dirname, '..');
const output = join(root, 'build', 'duel-progression-tests');
mkdirSync(output, { recursive: true });
const sources = {
  'android/content/Context.java': `package android.content;
    public abstract class Context {
      public static final int MODE_PRIVATE = 0;
      public abstract SharedPreferences getSharedPreferences(String name, int mode);
      public Context getApplicationContext() { return this; }
      public abstract java.io.File getNoBackupFilesDir();
    }`,
  'android/content/SharedPreferences.java': `package android.content;
    import java.util.Map; import java.util.Set;
    public interface SharedPreferences {
      Map<String, ?> getAll(); int getInt(String key, int fallback);
      long getLong(String key, long fallback); boolean getBoolean(String key, boolean fallback);
      String getString(String key, String fallback); boolean contains(String key); Editor edit();
      interface Editor {
        Editor putInt(String key, int value); Editor putLong(String key, long value);
        Editor putBoolean(String key, boolean value); Editor putString(String key, String value);
        Editor putFloat(String key, float value); Editor putStringSet(String key, Set<String> value);
        Editor remove(String key); Editor clear(); void apply(); boolean commit();
      }
    }`,
  'android/content/ContextWrapper.java': `package android.content;
    public class ContextWrapper extends Context {
      private final Context base;
      public ContextWrapper(Context base) { this.base = base; }
      public SharedPreferences getSharedPreferences(String name, int mode) { return base.getSharedPreferences(name, mode); }
      public Context getApplicationContext() { return base.getApplicationContext(); }
      public java.io.File getNoBackupFilesDir() { return base.getNoBackupFilesDir(); }
    }`,
  'android/content/Intent.java': `package android.content;
    public class Intent {
      private final java.util.Map<String,Object> values = new java.util.HashMap<>();
      public Intent putExtra(String key, String value) { values.put(key,value); return this; }
      public Intent putExtra(String key, boolean value) { values.put(key,value); return this; }
      public String getStringExtra(String key) { return (String) values.get(key); }
      public boolean getBooleanExtra(String key, boolean fallback) {
        Object value = values.get(key); return value instanceof Boolean ? (Boolean)value : fallback;
      }
    }`,
  'android/app/Activity.java': `package android.app;
    public abstract class Activity extends android.content.Context {
      private final android.content.Intent intent = new android.content.Intent();
      public android.content.Intent getIntent() { return intent; }
    }`,
  'android/os/Bundle.java': `package android.os;
    public class Bundle extends java.util.HashMap<String,String> {
      public String getString(String key) { return get(key); }
      public void putString(String key, String value) { put(key,value); }
    }`,
  'android/os/Looper.java': `package android.os;
    public class Looper { public static Looper getMainLooper() { return new Looper(); } }`,
  'android/os/Handler.java': `package android.os;
    public class Handler {
      private static final java.util.List<Runnable> timers = new java.util.ArrayList<>();
      public Handler(Looper ignored) {}
      public void postDelayed(Runnable callback, long delay) { timers.add(callback); }
      public void removeCallbacks(Runnable callback) { timers.remove(callback); }
      public static void fireTimeouts() {
        java.util.List<Runnable> due = new java.util.ArrayList<>(timers); timers.clear();
        for (Runnable callback : due) callback.run();
      }
    }`,
  'com/google/firebase/auth/FirebaseUser.java': `package com.google.firebase.auth;
    public class FirebaseUser {
      private final String uid;
      public FirebaseUser(String uid) { this.uid = uid; }
      public String getUid() { return uid; }
    }`,
  'com/google/firebase/auth/FirebaseAuth.java': `package com.google.firebase.auth;
    public class FirebaseAuth {
      private static final FirebaseAuth instance = new FirebaseAuth();
      private FirebaseUser user = new FirebaseUser("alice");
      public static FirebaseAuth getInstance() { return instance; }
      public FirebaseUser getCurrentUser() { return user; }
      public void setUid(String uid) { user = uid == null ? null : new FirebaseUser(uid); }
    }`,
  'com/google/firebase/database/DataSnapshot.java': `package com.google.firebase.database;
    public class DataSnapshot {
      private final Object value;
      public DataSnapshot(Object value) { this.value = value; }
      public DataSnapshot child(String key) {
        return new DataSnapshot(value instanceof java.util.Map ? ((java.util.Map<?,?>)value).get(key) : null);
      }
      public Object getValue() { return value; }
      public <T> T getValue(Class<T> type) { return value == null ? null : type.cast(value); }
    }`,
  'com/google/firebase/database/FirebaseDatabase.java': `package com.google.firebase.database;
    import java.util.*; import java.util.function.Consumer;
    public class FirebaseDatabase {
      private static final FirebaseDatabase instance = new FirebaseDatabase();
      public final Map<String,Object> values = new HashMap<>();
      public final Map<String,Task> pending = new HashMap<>();
      public boolean deferReads; public int reads;
      public static FirebaseDatabase getInstance() { return instance; }
      public Reference getReference(String path) { return new Reference(path); }
      public void completePending(String path) { pending.remove(path).complete(values.get(path)); }
      public final class Reference {
        private final String path;
        Reference(String path) { this.path = path; }
        public Reference child(String name) { return new Reference(path + "/" + name); }
        public Task get() {
          reads++; Task task = new Task();
          if (deferReads) pending.put(path, task); else task.complete(values.get(path));
          return task;
        }
      }
      public static final class Task {
        private boolean complete; private DataSnapshot result;
        private Consumer<Task> listener;
        public Task addOnCompleteListener(Consumer<Task> listener) {
          this.listener = listener; if (complete) listener.accept(this); return this;
        }
        public boolean isSuccessful() { return complete; }
        public DataSnapshot getResult() { return result; }
        public void complete(Object value) {
          result = new DataSnapshot(value); complete = true; if (listener != null) listener.accept(this);
        }
      }
    }`,
  'com/qi7bali/landchallengeonline/AppPrefs.java': `package com.qi7bali.landchallengeonline;
    public final class AppPrefs {
      static String uid = "alice";
      public static String getUserId(android.content.Context context) { return uid; }
    }`,
  'com/qi7bali/landchallengeonline/PlayerProgress.java': `package com.qi7bali.landchallengeonline;
    public final class PlayerProgress {
      public static int getLevel(android.content.Context context) { return 1; }
      public static void checkProgressionAchievements(android.content.Context context) {}
      public static void writeHydration(android.content.SharedPreferences.Editor editor,
          java.util.Map<String,Integer> values) {}
    }`,
};
const inputs = [];
for (const [relative, source] of Object.entries(sources)) {
  const target = join(output, 'stubs', relative);
  mkdirSync(resolve(target, '..'), { recursive: true });
  writeFileSync(target, source);
  inputs.push(target);
}
const jdk = process.env.JAVA_HOME;
const command = name => jdk ? join(jdk, 'bin', name + (process.platform === 'win32' ? '.exe' : '')) : name;
const native = join(root, 'android/app/src/main/java/com/Qi7bali/challengeland');
execFileSync(command('javac'), ['-encoding', 'UTF-8', '-d', output, ...inputs,
  ...['PlayerStats', 'ProgressionRules', 'ProgressionAccount', 'NativeProgression',
      'ProgressionMatchHost', 'ProgressionSyncState', 'OnlineDuelResultStore',
      'OnlineDuelState'].map(name => join(native, name + '.java')),
  join(__dirname, 'online_duel/DuelProgressionTest.java')], { stdio: 'inherit' });
execFileSync(command('java'), ['-cp', output,
  'com.qi7bali.landchallengeonline.DuelProgressionTest', output], { stdio: 'inherit' });
