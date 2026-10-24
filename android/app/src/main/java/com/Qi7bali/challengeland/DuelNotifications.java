package com.qi7bali.landchallengeonline;

import android.Manifest;
import android.app.Activity;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.content.Context;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.os.Build;
import android.util.Log;
import androidx.core.app.NotificationManagerCompat;
import com.google.firebase.auth.FirebaseAuth;
import com.google.firebase.auth.FirebaseUser;
import com.google.firebase.functions.FirebaseFunctions;
import com.google.firebase.messaging.FirebaseMessaging;
import java.util.HashMap;

public final class DuelNotifications {
    public static final String CHANNEL = "friend_duel_invites";
    private static boolean initialized;
    private static String previousUid;
    private static java.lang.ref.WeakReference<Activity> currentActivity = new java.lang.ref.WeakReference<>(null);
    private static final java.util.Set<String> inviteAttempts = new java.util.HashSet<>();
    private DuelNotifications() {}

    public static synchronized void initialize(Context context) {
        Context app = context.getApplicationContext();
        createChannel(app);
        if (initialized) return;
        initialized = true;
        FirebaseAuth.getInstance().addAuthStateListener(auth -> {
            FirebaseUser user = auth.getCurrentUser();
            String uid = user == null ? null : user.getUid();
            if (previousUid != null && !previousUid.equals(uid)) {
                FirebaseMessaging.getInstance().deleteToken().addOnCompleteListener(task -> sync(app));
            } else sync(app);
            previousUid = uid;
            Activity activity = currentActivity.get();
            if (user != null && activity != null && !activity.isFinishing())
                activity.runOnUiThread(() -> resume(activity));
        });
    }

    public static void resume(Activity activity) {
        currentActivity = new java.lang.ref.WeakReference<>(activity);
        initialize(activity);
        SharedPreferences prefs = activity.getSharedPreferences("DuelPush", Context.MODE_PRIVATE);
        if (AppPrefs.isNotificationsEnabled(activity)
                && Build.VERSION.SDK_INT >= 33
                && activity.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
                && !prefs.getBoolean("permissionAsked", false)) {
            prefs.edit().putBoolean("permissionAsked", true).apply();
            activity.requestPermissions(new String[]{Manifest.permission.POST_NOTIFICATIONS}, 7502);
        }
        sync(activity);
    }

    public static void sync(Context context) {
        Context app = context.getApplicationContext();
        FirebaseUser user = FirebaseAuth.getInstance().getCurrentUser();
        if (user == null || user.isAnonymous()) return;
        String uid = user.getUid();
        FirebaseMessaging.getInstance().getToken().addOnSuccessListener(token -> {
            FirebaseUser current = FirebaseAuth.getInstance().getCurrentUser();
            if (current == null || !uid.equals(current.getUid())) return;
            HashMap<String, Object> data = new HashMap<>();
            data.put("token", token);
            data.put("enabled", AppPrefs.isNotificationsEnabled(app)
                    && NotificationManagerCompat.from(app).areNotificationsEnabled());
            FirebaseFunctions.getInstance("us-central1").getHttpsCallable("registerDuelDevice").call(data)
                    .addOnFailureListener(error -> Log.w("DuelPush", "Device registration unavailable"));
        }).addOnFailureListener(error -> Log.w("DuelPush", "Push token unavailable"));
    }

    public static void createChannel(Context context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return;
        NotificationManager manager = context.getSystemService(NotificationManager.class);
        NotificationChannel channel = new NotificationChannel(CHANNEL, "دعوات تحدي الأصدقاء",
                NotificationManager.IMPORTANCE_HIGH);
        channel.setDescription("إشعارات دعوات اللعب من اللاعبين الآخرين");
        manager.createNotificationChannel(channel);
    }

    public static void sendInvite(String targetId, String searchId) {
        if (targetId == null || searchId == null || searchId.isEmpty()) return;
        String key = targetId + ":" + searchId;
        synchronized (inviteAttempts) {
            if (inviteAttempts.contains(key)) return;
            if (inviteAttempts.size() >= 128) inviteAttempts.clear();
            inviteAttempts.add(key);
        }
        HashMap<String, Object> data = new HashMap<>();
        data.put("targetId", targetId);
        data.put("searchId", searchId);
        FirebaseFunctions.getInstance("us-central1").getHttpsCallable("sendDuelInvite").call(data)
                .addOnFailureListener(error -> {
                    synchronized (inviteAttempts) { inviteAttempts.remove(key); }
                    Log.w("DuelPush", "Invite notification unavailable");
                });
    }
}
