package com.qi7bali.landchallengeonline;

import android.app.AlarmManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;

import java.util.TimeZone;

public final class NotificationScheduler {
    private static final int DAILY_REMINDER_REQUEST = 7401;
    static final String ACTION_REMINDER = "com.qi7bali.landchallengeonline.DAILY_REWARD_REMINDER";
    static final String PREFS = "DailyPlayReminder";
    static final String LAST_DELIVERED_DAY = "lastDeliveredDay";

    private NotificationScheduler() {}

    public static void scheduleDailyReminder(Context context) {
        if (!AppPrefs.isNotificationsEnabled(context)) {
            cancelDailyReminder(context);
            return;
        }
        DailyReminderReceiver.createChannel(context);
        AlarmManager alarmManager = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
        if (alarmManager == null) {
            return;
        }

        String lastDay = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .getString(LAST_DELIVERED_DAY, "");
        alarmManager.setAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                DailyReminderPolicy.nextTriggerAt(System.currentTimeMillis(), TimeZone.getDefault(), lastDay),
                reminderIntent(context)
        );
    }

    public static void cancelDailyReminder(Context context) {
        AlarmManager alarmManager = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
        if (alarmManager != null) {
            alarmManager.cancel(reminderIntent(context));
        }
        android.app.NotificationManager manager = context.getSystemService(android.app.NotificationManager.class);
        if (manager != null) manager.cancel(DAILY_REMINDER_REQUEST);
    }

    private static PendingIntent reminderIntent(Context context) {
        Intent intent = new Intent(context, DailyReminderReceiver.class);
        intent.setAction(ACTION_REMINDER);
        return PendingIntent.getBroadcast(
                context,
                DAILY_REMINDER_REQUEST,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
        );
    }
}
