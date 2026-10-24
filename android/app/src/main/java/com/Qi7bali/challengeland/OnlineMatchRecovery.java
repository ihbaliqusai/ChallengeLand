package com.qi7bali.landchallengeonline;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Bundle;

import org.json.JSONArray;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.Map;

/** Account-owned launch receipts and bot checkpoints survive Android process death. */
public final class OnlineMatchRecovery {
    private static final String PREFIX = "onlineRecovery:";
    private static final String ID = "onlineRecoveryId";

    private OnlineMatchRecovery() {}

    private static String identity(Activity activity) {
        Intent intent = activity.getIntent();
        String id = intent.getStringExtra(ID);
        if (id != null && !id.isEmpty()) return id;
        String room = intent.getStringExtra("roomId");
        String paid = intent.getStringExtra("stakeMatchId");
        String duel = intent.getStringExtra("duelSessionId");
        id = room != null && !room.isEmpty() ? "room:" + room + ":"
                + Math.max(1, intent.getIntExtra("roomRoundNumber", 1))
                : paid != null && !paid.isEmpty() ? "paid:" + paid
                : duel != null && !duel.isEmpty() ? "duel:" + duel
                : "bot:" + NativeProgression.fallbackId(activity);
        intent.putExtra(ID, id);
        return id;
    }

    static JSONObject read(Context context, String id) {
        if (id == null || id.isEmpty()) return null;
        String raw = ProgressionAccount.preferences(context).getString(PREFIX + id, null);
        try {
            JSONObject record = raw == null ? null : new JSONObject(raw);
            return record != null && ProgressionAccount.uid(context).equals(record.optString("uid"))
                    ? record : null;
        } catch (Exception ignored) {
            return null;
        }
    }

    private static void write(Context context, JSONObject record) {
        SharedPreferences storage = ProgressionAccount.preferences(context);
        ProgressionAccount.commitOrRollback(storage, storage.edit()
                .putString(PREFIX + record.optString("id"), record.toString()));
    }

    public static synchronized void track(Activity activity) {
        if (!"online".equals(activity.getIntent().getStringExtra("mode"))
                || !NativeProgression.activeAccount(activity)) return;
        try {
            String id = identity(activity);
            JSONObject record = read(activity, id);
            if (record != null && record.optBoolean("finished")) return;
            if (record == null) {
                record = new JSONObject();
                record.put("id", id);
                record.put("uid", ProgressionAccount.uid(activity));
                record.put("createdAt", System.currentTimeMillis());
            }
            JSONObject extras = new JSONObject();
            Bundle bundle = activity.getIntent().getExtras();
            if (bundle != null) for (String key : bundle.keySet()) {
                Object value = bundle.get(key);
                if (value instanceof String || value instanceof Boolean || value instanceof Number)
                    extras.put(key, value);
            }
            record.put("extras", extras);
            // Tracking runs before the activity has initialized its board fields.
            String roomId = extras.optString("roomId");
            String mode = roomId.isEmpty() ? "board" : extras.optString("matchMode", "battle");
            record.put("matchId", id.startsWith("duel:") ? id
                    : id.startsWith("paid:") ? "duel:" + extras.optString("stakeMatchId")
                    : !roomId.isEmpty() ? "room:" + roomId + ":" + mode + ":" + Math.max(1, extras.optInt("roomRoundNumber", 1))
                    : NativeProgression.fallbackId(activity));
            record.put("matchMode", mode);
            record.put("humanOnline", id.startsWith("duel:") || id.startsWith("paid:"));
            record.put("roomId", roomId);
            write(activity, record);
        } catch (org.json.JSONException error) {
            throw new IllegalStateException("Cannot save online match", error);
        }
    }

    public static synchronized JSONArray pending(Context context) {
        ArrayList<JSONObject> records = new ArrayList<>();
        for (Map.Entry<String, ?> entry : ProgressionAccount.preferences(context).getAll().entrySet()) {
            if (!entry.getKey().startsWith(PREFIX)) continue;
            JSONObject record = read(context, entry.getKey().substring(PREFIX.length()));
            if (record != null && !record.optBoolean("observed")) records.add(record);
        }
        records.sort((a, b) -> Long.compare(b.optLong("createdAt"), a.optLong("createdAt")));
        JSONArray result = new JSONArray();
        for (JSONObject record : records) {
            result.put(summary(record));
        }
        return result;
    }

    static JSONObject summary(JSONObject record) {
        // Board answers and launch credentials stay on the native side.
        JSONObject summary = new JSONObject();
        try {
            summary.put("id", record.optString("id"));
            summary.put("uid", record.optString("uid"));
            summary.put("roomId", record.optString("roomId"));
            summary.put("finished", record.optBoolean("finished"));
            summary.put("message", record.optString("message"));
        } catch (org.json.JSONException ignored) {}
        return summary;
    }

    public static synchronized boolean hasActiveMatch(Context context, String roomId) {
        JSONArray matches = pending(context);
        for (int i = 0; i < matches.length(); i++) {
            JSONObject match = matches.optJSONObject(i);
            if (match != null && !match.optBoolean("finished")
                    && (roomId == null || roomId.isEmpty()
                        || !roomId.equals(match.optString("roomId")))) return true;
        }
        return false;
    }

    static synchronized JSONObject finishSaved(Context context, String id, String message, boolean observed) {
        JSONObject record = read(context, id);
        if (record == null) throw new IllegalStateException("هذه المباراة لم تعد متاحة.");
        try {
            // A server result must never be overwritten by a delayed withdrawal.
            if (!record.optBoolean("finished")) {
                record.put("finished", true);
                record.put("message", message);
                record.remove("checkpoint");
            }
            record.put("observed", observed || record.optBoolean("observed"));
            write(context, record);
            return record;
        } catch (org.json.JSONException error) {
            throw new IllegalStateException(error);
        }
    }

    public static synchronized void updateLaunch(Activity activity) {
        if (NativeProgression.activeAccount(activity)
                && read(activity, activity.getIntent().getStringExtra(ID)) != null) track(activity);
    }

    public static synchronized boolean isFinished(Activity activity) {
        if (!"online".equals(activity.getIntent().getStringExtra("mode"))
                || !NativeProgression.activeAccount(activity)) return false;
        JSONObject record = read(activity, identity(activity));
        return record != null && record.optBoolean("finished");
    }

    public static synchronized void resume(Activity activity, String id) {
        JSONObject record = read(activity, id);
        if (record == null || record.optBoolean("finished"))
            throw new IllegalStateException("هذه المباراة لم تعد متاحة للمتابعة.");
        JSONObject extras = record.optJSONObject("extras");
        if (extras == null) throw new IllegalStateException("تعذر استعادة بيانات المباراة.");
        // Rooms resume through their lobby to refresh membership, host and seat state.
        if (!record.optString("roomId").isEmpty())
            throw new IllegalStateException("عُد إلى المباراة من غرفة اللعب.");
        Intent intent = new Intent(activity, GameActivity.class);
        java.util.Iterator<String> keys = extras.keys();
        while (keys.hasNext()) {
            String key = keys.next();
            Object value = extras.opt(key);
            if (value instanceof String) intent.putExtra(key, (String) value);
            else if (value instanceof Boolean) intent.putExtra(key, (Boolean) value);
            else if (value instanceof Integer) intent.putExtra(key, (Integer) value);
            else if (value instanceof Number) intent.putExtra(key, ((Number) value).longValue());
        }
        intent.putExtra("resumeOnlineMatch", true);
        activity.startActivity(intent);
    }

    public static synchronized void complete(Activity activity, String message, boolean observed) {
        if (!NativeProgression.activeAccount(activity)) return;
        String id = activity.getIntent().getStringExtra(ID);
        JSONObject record = read(activity, id);
        if (record == null || record.optBoolean("finished")) return;
        try {
            record.put("finished", true);
            record.put("observed", observed);
            record.put("message", message);
            record.remove("checkpoint");
            write(activity, record);
        } catch (org.json.JSONException error) {
            throw new IllegalStateException(error);
        }
    }

    public static synchronized void dismiss(Context context, String id) {
        JSONObject record = read(context, id);
        if (record == null) return;
        if (record.optBoolean("finished")) {
            try {
                record.put("observed", true);
                write(context, record);
            } catch (org.json.JSONException error) {
                throw new IllegalStateException(error);
            }
            return;
        }
        SharedPreferences storage = ProgressionAccount.preferences(context);
        ProgressionAccount.commitOrRollback(storage, storage.edit().remove(PREFIX + id));
    }

    static synchronized JSONObject botCheckpoint(Activity activity) {
        if (!NativeProgression.activeAccount(activity)) return null;
        JSONObject record = read(activity, identity(activity));
        return record == null ? null : record.optJSONObject("checkpoint");
    }

    static synchronized void saveBotCheckpoint(Activity activity, JSONObject checkpoint) {
        if (!NativeProgression.activeAccount(activity)) return;
        JSONObject record = read(activity, identity(activity));
        if (record == null || record.optBoolean("finished")) return;
        try {
            record.put("checkpoint", checkpoint);
            write(activity, record);
        } catch (org.json.JSONException error) {
            throw new IllegalStateException(error);
        }
    }
}
