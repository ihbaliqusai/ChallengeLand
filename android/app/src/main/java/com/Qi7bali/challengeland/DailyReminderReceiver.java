package com.qi7bali.landchallengeonline;

import android.Manifest;
import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.os.Build;
import java.util.TimeZone;

public class DailyReminderReceiver extends BroadcastReceiver {
    // Retain the channel ID so existing system preferences survive upgrades.
    private static final String CHANNEL_ID = "daily_rewards";
    private static final int NOTIFICATION_ID = 7401;

    public static void createChannel(Context context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return;
        NotificationManager manager = context.getSystemService(NotificationManager.class);
        if (manager == null) return;
        NotificationChannel channel = new NotificationChannel(
                CHANNEL_ID, "دعوة اللعب اليومية", NotificationManager.IMPORTANCE_DEFAULT);
        channel.setDescription("تذكير يومي للعودة إلى أرض التحدي واللعب");
        manager.createNotificationChannel(channel);
    }

    @Override
    public void onReceive(Context context, Intent intent) {
        String action = intent == null ? null : intent.getAction();
        if (Intent.ACTION_BOOT_COMPLETED.equals(action)
                || Intent.ACTION_MY_PACKAGE_REPLACED.equals(action)
                || Intent.ACTION_TIME_CHANGED.equals(action)
                || Intent.ACTION_TIMEZONE_CHANGED.equals(action)) {
            NotificationScheduler.scheduleDailyReminder(context);
            return;
        }
        if (!NotificationScheduler.ACTION_REMINDER.equals(action)) return;
        if (!AppPrefs.isNotificationsEnabled(context)) {
            NotificationScheduler.cancelDailyReminder(context);
            return;
        }
        // Restore tomorrow's alarm even if notification permission is disabled.
        try {
            showReminder(context);
        } finally {
            NotificationScheduler.scheduleDailyReminder(context);
        }
    }

    private void showReminder(Context context) {
        NotificationManager manager = context.getSystemService(NotificationManager.class);
        if (manager == null || !manager.areNotificationsEnabled()) return;
        if (Build.VERSION.SDK_INT >= 33
                && context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS)
                != PackageManager.PERMISSION_GRANTED) return;
        createChannel(context);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O
                && manager.getNotificationChannel(CHANNEL_ID).getImportance() == NotificationManager.IMPORTANCE_NONE) return;

        SharedPreferences prefs = context.getSharedPreferences(NotificationScheduler.PREFS, Context.MODE_PRIVATE);
        String today = DailyReminderPolicy.dayKey(System.currentTimeMillis(), TimeZone.getDefault());
        if (today.equals(prefs.getString(NotificationScheduler.LAST_DELIVERED_DAY, ""))) return;

        Intent launch = new Intent(context, MainActivity.class);
        launch.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
        PendingIntent content = PendingIntent.getActivity(context, NOTIFICATION_ID, launch,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
        String message = "التحدي بانتظارك! ادخل أرض التحدي، اختبر معلوماتك وتحدَّ أصدقاءك اليوم.";
        Notification.Builder builder = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O
                ? new Notification.Builder(context, CHANNEL_ID) : new Notification.Builder(context);
        Notification notification = builder.setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle("حان وقت اللعب في أرض التحدي!")
                .setContentText(message)
                .setStyle(new Notification.BigTextStyle().bigText(message))
                .setContentIntent(content)
                .setAutoCancel(true)
                .setShowWhen(true)
                .build();
        try {
            manager.notify(NOTIFICATION_ID, notification);
            prefs.edit().putString(NotificationScheduler.LAST_DELIVERED_DAY, today).apply();
        } catch (SecurityException ignored) {
            // Permission can be revoked between checking and posting.
        }
    }
}
