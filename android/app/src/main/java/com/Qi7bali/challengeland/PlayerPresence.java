package com.qi7bali.landchallengeonline;

import android.app.Activity;
import android.app.Application;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import android.util.Log;
import com.google.firebase.auth.FirebaseAuth;
import com.google.firebase.firestore.FieldValue;
import com.google.firebase.firestore.FirebaseFirestore;
import com.google.firebase.firestore.ListenerRegistration;
import com.google.firebase.database.FirebaseDatabase;
import com.google.firebase.database.DataSnapshot;
import com.google.firebase.database.DatabaseError;
import com.google.firebase.database.ValueEventListener;
import java.util.HashMap;
import java.util.Map;

/** Foreground lease spans Flutter and native matches. A crashed client expires
 * after 75 seconds even when it cannot publish its final away event. */
public final class PlayerPresence implements Application.ActivityLifecycleCallbacks {
    private static PlayerPresence instance;
    private final Application app;
    private final Handler handler = new Handler(Looper.getMainLooper());
    private int resumed;
    private int resumedMain;
    private int nativeGames;
    private boolean flutterBusy;
    private boolean returningFromGame;
    private Long serverAnchor;
    private long elapsedAnchor;
    private boolean discoverable = true;
    private String uid;
    private ListenerRegistration settings;
    private final Runnable beat = new Runnable() {
        @Override public void run() {
            publish();
            if (resumed > 0) handler.postDelayed(this, 25000);
        }
    };

    private PlayerPresence(Application application) {
        app = application;
        app.registerActivityLifecycleCallbacks(this);
        FirebaseDatabase.getInstance().getReference(".info/serverTimeOffset")
            .addValueEventListener(new ValueEventListener() {
                @Override public void onDataChange(DataSnapshot snapshot) {
                    Long offset = snapshot.getValue(Long.class);
                    if (offset != null) {
                        serverAnchor = System.currentTimeMillis() + offset;
                        elapsedAnchor = SystemClock.elapsedRealtime();
                    }
                }
                @Override public void onCancelled(DatabaseError error) {}
            });
        FirebaseAuth.getInstance().addAuthStateListener(auth -> bind(
            auth.getCurrentUser() == null || auth.getCurrentUser().isAnonymous()
                ? null : auth.getCurrentUser().getUid()));
    }

    public static void initialize(Application app) {
        if (instance == null) instance = new PlayerPresence(app);
    }

    public static void setFlutterBusy(boolean busy) {
        if (instance == null) return;
        instance.flutterBusy = busy;
        instance.publish();
    }

    public static Long serverTime() {
        return instance == null || instance.serverAnchor == null ? null :
            instance.serverAnchor + SystemClock.elapsedRealtime() - instance.elapsedAnchor;
    }

    private void bind(String account) {
        if (settings != null) settings.remove();
        uid = account;
        flutterBusy = false;
        returningFromGame = false;
        discoverable = true;
        if (account == null) return;
        settings = FirebaseFirestore.getInstance().collection("social_settings")
            .document(account).addSnapshotListener((snapshot, error) -> {
                if (!account.equals(uid)) return;
                if (snapshot != null && snapshot.exists()) {
                    discoverable = !Boolean.FALSE.equals(snapshot.getBoolean("discoverable"));
                }
                publish();
            });
        publish();
    }

    private void publish() {
        String account = uid;
        if (account == null) return;
        Map<String, Object> data = new HashMap<>();
        data.put("uid", account);
        data.put("heartbeatAt", FieldValue.serverTimestamp());
        data.put("state", resumed == 0 || (resumedMain == 0 && nativeGames == 0) ? "away" :
            (nativeGames > 0 || flutterBusy ? "in_match" : "available"));
        data.put("discoverable", discoverable);
        FirebaseFirestore db = FirebaseFirestore.getInstance();
        if (returningFromGame && resumedMain > 0 && nativeGames == 0 && !flutterBusy) {
            // Release the caller's preparation reservation on an actual game
            // return, together with the new available heartbeat.
            db.batch().set(db.collection("player_presence").document(account), data)
                .delete(db.collection("social_reservations").document(account))
                .commit().addOnSuccessListener(ignored -> {
                    if (account.equals(uid)) returningFromGame = false;
                }).addOnFailureListener(error -> Log.d("PlayerPresence", "Return update unavailable"));
        } else {
            db.collection("player_presence").document(account).set(data)
                .addOnFailureListener(error -> Log.d("PlayerPresence", "Presence update unavailable"));
        }
    }

    private boolean game(Activity activity) {
        return activity instanceof BaseGameActivity || activity instanceof GameActivity ||
            activity instanceof OpponentActivity || activity.getClass().getSimpleName().contains("Room");
    }
    @Override public void onActivityResumed(Activity activity) {
        resumed++;
        if (activity.getClass().getSimpleName().equals("MainActivity")) resumedMain++;
        if (game(activity)) { nativeGames++; returningFromGame = true; }
        handler.removeCallbacks(beat);
        handler.post(beat);
    }
    @Override public void onActivityPaused(Activity activity) {
        resumed = Math.max(0, resumed - 1);
        if (activity.getClass().getSimpleName().equals("MainActivity")) resumedMain = Math.max(0, resumedMain - 1);
        if (game(activity)) nativeGames = Math.max(0, nativeGames - 1);
        handler.removeCallbacks(beat);
        // Avoid a false away transition between two activities.
        handler.postDelayed(beat, 1000);
    }
    @Override public void onActivityCreated(Activity a, Bundle b) {}
    @Override public void onActivityStarted(Activity a) {}
    @Override public void onActivityStopped(Activity a) {}
    @Override public void onActivitySaveInstanceState(Activity a, Bundle b) {}
    @Override public void onActivityDestroyed(Activity a) {}
}
