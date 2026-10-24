package com.qi7bali.landchallengeonline;

import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Intent;
import android.content.SharedPreferences;
import android.net.Uri;
import androidx.core.app.NotificationCompat;
import androidx.core.app.NotificationManagerCompat;
import com.google.firebase.auth.FirebaseAuth;
import com.google.firebase.auth.FirebaseUser;
import com.google.firebase.messaging.FirebaseMessagingService;
import com.google.firebase.messaging.RemoteMessage;
import java.util.Map;

public final class DuelMessagingService extends FirebaseMessagingService {
    @Override public void onNewToken(String token) { DuelNotifications.sync(this); }

    @Override public void onMessageReceived(RemoteMessage message) {
        Map<String, String> data = message.getData();
        FirebaseUser user = FirebaseAuth.getInstance().getCurrentUser();
        boolean friendRequest = "friend_request".equals(data.get("type"));
        boolean socialInvite = "social_invite".equals(data.get("type"));
        boolean social = friendRequest || socialInvite;
        if ((!social && !"duel_invite".equals(data.get("type"))) || user == null
                || !user.getUid().equals(data.get("recipientUid"))
                || !AppPrefs.isNotificationsEnabled(this)
                || !NotificationManagerCompat.from(this).areNotificationsEnabled()) return;
        String code = data.get("friendCode"), id = data.get("inviteId");
        if (id == null || (!social && (code == null || !code.matches("[A-Za-z0-9]{4,128}")))) return;
        try {
            if (Long.parseLong(data.getOrDefault("expiresAt", "0")) < System.currentTimeMillis()) return;
        } catch (NumberFormatException error) { return; }
        SharedPreferences prefs = getSharedPreferences("DuelPush", MODE_PRIVATE);
        if (id.equals(prefs.getString("lastInviteId", ""))) return;
        DuelNotifications.createChannel(this);
        Intent intent = new Intent(this, MainActivity.class);
        intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP | Intent.FLAG_ACTIVITY_SINGLE_TOP);
        if (social) intent.putExtra("launchAction", "social:requests");
        else intent.setData(new Uri.Builder().scheme("challengeland").authority("friend")
                .appendQueryParameter("code", code).build());
        intent.putExtra("duelRecipientUid", user.getUid());
        PendingIntent tap = PendingIntent.getActivity(this, id.hashCode(), intent,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
        NotificationCompat.Builder notification = new NotificationCompat.Builder(this, DuelNotifications.CHANNEL)
                .setSmallIcon(R.mipmap.ic_launcher).setContentTitle(friendRequest ? "طلب صداقة جديد" : "دعوة لعب جديدة ⚔️")
                .setContentText(data.getOrDefault("senderName", "لاعب") + (friendRequest ? " أرسل لك طلب صداقة" : " يدعوك إلى تحدي 1 ضد 1"))
                .setAutoCancel(true).setContentIntent(tap).setPriority(NotificationCompat.PRIORITY_HIGH);
        try {
            getSystemService(NotificationManager.class).notify(id, 7503, notification.build());
            prefs.edit().putString("lastInviteId", id).apply();
        } catch (SecurityException ignored) { /* Android permission can change during delivery. */ }
    }
}
