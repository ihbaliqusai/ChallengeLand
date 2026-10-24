// Uses the same checksum-verified org.json jar as android/verification/run_checks.ps1.
const fs = require('node:fs');
const { resolve, join } = require('node:path');
const { tmpdir } = require('node:os');
const { createHash } = require('node:crypto');
const { execFileSync } = require('node:child_process');
const root = resolve(__dirname, '..'), output = join(root, 'build/question-history-store-tests');
const json = process.argv[2] || join(tmpdir(), 'challengeland-json-20240303.jar');
if (!fs.existsSync(json)) throw new Error('Run android/verification/run_checks.ps1 to prepare its org.json verification jar, or pass its path.');
if (createHash('sha256').update(fs.readFileSync(json)).digest('hex') !== '3cf6cd6892e32e2b4c1c39e0f52f5248a2f5b37646fdfbb79a66b46b618414ed')
  throw new Error('org.json verification checksum mismatch');
const stubs = {
  'android/os/Looper.java': `package android.os; public class Looper {public static Looper getMainLooper(){return new Looper();}}`,
  'android/os/Handler.java': `package android.os; public class Handler {public Handler(Looper looper){} public void postDelayed(Runnable action,long delay){action.run();}}`,
  'android/content/Context.java': `package android.content; public abstract class Context {
    public static final int MODE_PRIVATE=0;
    public abstract SharedPreferences getSharedPreferences(String name,int mode);
    public abstract java.io.File getNoBackupFilesDir();
    public Context getApplicationContext(){return this;}
  }`,
  'com/qi7bali/landchallengeonline/AppPrefs.java': `package com.qi7bali.landchallengeonline;
    public final class AppPrefs {
      public static String getUserId(android.content.Context c){return c.getSharedPreferences("User",0).getString("uid","guest_local");}
      public static void setUser(android.content.Context c,String uid,String name,String photo,int level,int score){c.getSharedPreferences("User",0).edit().putString("uid",uid).commit();}
    }`,
  'com/qi7bali/landchallengeonline/Data.java': `package com.qi7bali.landchallengeonline;
    public final class Data {public static boolean connected; public static boolean isNetworkAvailable(android.content.Context c){return connected;}}`,
  'com/google/firebase/auth/FirebaseUser.java': `package com.google.firebase.auth;
    public class FirebaseUser {private final String uid; FirebaseUser(String uid){this.uid=uid;} public String getUid(){return uid;} public boolean isAnonymous(){return false;}}`,
  'com/google/firebase/auth/FirebaseAuth.java': `package com.google.firebase.auth;
    public class FirebaseAuth {private static final FirebaseAuth instance=new FirebaseAuth(); private static String uid;
      public static FirebaseAuth getInstance(){return instance;} public static void setUid(String value){uid=value;}
      public FirebaseUser getCurrentUser(){return uid==null?null:new FirebaseUser(uid);}}`,
  'com/google/firebase/functions/FirebaseFunctions.java': `package com.google.firebase.functions;
    public class FirebaseFunctions {
      public interface Handler {Object apply(java.util.Map<String,Object> data) throws Exception;}
      public static Handler handler=data->{throw new IllegalStateException("Unexpected network request");};
      public static FirebaseFunctions getInstance(){return new FirebaseFunctions();}
      public Reference getHttpsCallable(String name){return new Reference();}
      public static class Result {private final Object data; Result(Object data){this.data=data;} public Object getData(){return data;}}
      public static class Reference {
        @SuppressWarnings("unchecked") public Task call(Object data){try{return new Task(new Result(handler.apply((java.util.Map<String,Object>)data)),null);}catch(Exception e){return new Task(null,e);}}
      }
      public static class Task {
        private final Result result; private final Exception error; Task(Result r,Exception e){result=r;error=e;}
        public Task addOnSuccessListener(java.util.function.Consumer<Result> listener){if(error==null)listener.accept(result);return this;}
        public Task addOnFailureListener(java.util.function.Consumer<Exception> listener){if(error!=null)listener.accept(error);return this;}
      }
    }`,
};
fs.mkdirSync(output, { recursive: true });
const inputs = Object.entries(stubs).map(([name, source]) => {
  const file = join(output, 'stubs', name); fs.mkdirSync(resolve(file, '..'), { recursive: true }); fs.writeFileSync(file, source); return file;
});
const native = join(root, 'android/app/src/main/java/com/Qi7bali/challengeland');
const jdk = process.env.JAVA_HOME;
const command = name => jdk ? join(jdk, 'bin', name + (process.platform === 'win32' ? '.exe' : '')) : name;
const classpath = output + (process.platform === 'win32' ? ';' : ':') + json;
execFileSync(command('javac'), ['-encoding', 'UTF-8', '-cp', classpath, '-d', output, ...inputs,
  join(root, 'android/verification/stubs/android/content/SharedPreferences.java'), join(root, 'android/verification/VerificationContext.java'),
  ...['Question.java', 'QuestionIdentity.java', 'QuestionHistory.java', 'ProgressionAccount.java'].map(name => join(native, name)),
  join(__dirname, 'question_history/QuestionHistoryStoreTest.java')], { stdio: 'inherit' });
execFileSync(command('java'), ['-cp', classpath, 'com.qi7bali.landchallengeonline.QuestionHistoryStoreTest'], { stdio: 'inherit' });
