package com.qi7bali.landchallengeonline;

import android.content.Context;
import android.content.SharedPreferences;
import android.util.Log;

import com.google.firebase.database.DataSnapshot;
import com.google.firebase.database.DatabaseError;
import com.google.firebase.database.DatabaseReference;
import com.google.firebase.database.FirebaseDatabase;
import com.google.firebase.database.ValueEventListener;

import org.json.JSONArray;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Random;

final class LocalTeamsGameStore {
    static final String STATUS_IN_PROGRESS = "in_progress";
    static final String STATUS_FINISHED = "finished";
    static final String PHASE_SETUP = "setup";
    static final String PHASE_CATEGORY_SELECT = "category_select";
    static final String PHASE_BOARD = "board";
    static final String PHASE_QUESTION = "question";
    static final String PHASE_FINISHED = "finished";

    private static final String PREF = "LocalTeamsBoardGames";
    private static final String KEY_GAMES = "games";
    private static final int MAX_RECORDS = 60;

    private LocalTeamsGameStore() {}

    static String newGameId() {
        return String.format(
                Locale.US,
                "lt_%d_%04d",
                System.currentTimeMillis(),
                new Random().nextInt(10000)
        );
    }

    static JSONObject get(Context context, String id) {
        if (id == null || id.trim().isEmpty()) return null;
        JSONArray array = readArray(context);
        for (int i = 0; i < array.length(); i++) {
            JSONObject item = array.optJSONObject(i);
            if (item != null && id.equals(item.optString("id"))) {
                try {
                    return new JSONObject(item.toString());
                } catch (Exception ignored) {
                    return item;
                }
            }
        }
        return null;
    }

    static ArrayList<JSONObject> all(Context context) {
        JSONArray array = readArray(context);
        ArrayList<JSONObject> list = new ArrayList<>();
        for (int i = 0; i < array.length(); i++) {
            JSONObject item = array.optJSONObject(i);
            if (item != null) {
                try {
                    list.add(new JSONObject(item.toString()));
                } catch (Exception ignored) {
                    list.add(item);
                }
            }
        }
        Collections.sort(list, new Comparator<JSONObject>() {
            @Override
            public int compare(JSONObject a, JSONObject b) {
                return Long.compare(b.optLong("updatedAt", 0L), a.optLong("updatedAt", 0L));
            }
        });
        return list;
    }

    static void upsert(Context context, JSONObject record) {
        if (record == null) return;
        String id = record.optString("id", "").trim();
        if (id.isEmpty()) return;
        JSONArray current = readArray(context);
        JSONArray next = new JSONArray();
        boolean replaced = false;
        for (int i = 0; i < current.length(); i++) {
            JSONObject item = current.optJSONObject(i);
            if (item == null) continue;
            if (id.equals(item.optString("id"))) {
                next.put(record);
                replaced = true;
            } else {
                next.put(item);
            }
        }
        if (!replaced) {
            next.put(record);
        }
        writeArray(context, prune(next));
        syncToCloud(record);
    }

    static boolean delete(Context context, String id) {
        if (id == null || id.trim().isEmpty()) return false;
        String targetId = id.trim();
        JSONObject existing = get(context, targetId);
        if (existing != null) {
            String tvCode = existing.optString("tvCode", "").trim();
            if (!tvCode.isEmpty()) {
                try {
                    FirebaseDatabase.getInstance().getReference("TvMatches").child(tvCode).removeValue();
                } catch (Exception ignored) {}
            }
        }
        JSONArray current = readArray(context);
        JSONArray next = new JSONArray();
        boolean removed = false;
        for (int i = 0; i < current.length(); i++) {
            JSONObject item = current.optJSONObject(i);
            if (item == null) continue;
            if (targetId.equals(item.optString("id"))) {
                removed = true;
            } else {
                next.put(item);
            }
        }
        if (removed) {
            writeArray(context, next);
        }
        return removed;
    }

    static int clearFinished(Context context) {
        JSONArray current = readArray(context);
        JSONArray next = new JSONArray();
        int removedCount = 0;
        for (int i = 0; i < current.length(); i++) {
            JSONObject item = current.optJSONObject(i);
            if (item == null) continue;
            if (STATUS_FINISHED.equals(item.optString("status"))) {
                removedCount++;
                String tvCode = item.optString("tvCode", "").trim();
                if (!tvCode.isEmpty()) {
                    try {
                        FirebaseDatabase.getInstance().getReference("TvMatches").child(tvCode).removeValue();
                    } catch (Exception ignored) {}
                }
            } else {
                next.put(item);
            }
        }
        if (removedCount > 0) {
            writeArray(context, next);
        }
        return removedCount;
    }

    static void clearAll(Context context) {
        writeArray(context, new JSONArray());
    }

    static String generateTvCode() {
        int code = 1000 + new Random().nextInt(9000);
        return String.valueOf(code);
    }

    static String getOrAssignTvCode(Context context, JSONObject record) {
        if (record == null) return "";
        String code = record.optString("tvCode", "").trim();
        if (code.isEmpty()) {
            code = generateTvCode();
            try {
                record.put("tvCode", code);
                upsert(context, record);
            } catch (Exception ignored) {}
        }
        return code;
    }

    static JSONObject baseRecord(String id) {
        long now = System.currentTimeMillis();
        JSONObject record = new JSONObject();
        try {
            record.put("id", id == null || id.trim().isEmpty() ? newGameId() : id.trim());
            record.put("tvCode", generateTvCode());
            record.put("createdAt", now);
            record.put("updatedAt", now);
            record.put("status", STATUS_IN_PROGRESS);
            record.put("phase", PHASE_SETUP);
            record.put("teamAName", "الفريق الأول");
            record.put("teamBName", "الفريق الثاني");
            record.put("scoreA", 0);
            record.put("scoreB", 0);
            record.put("winnerSlot", -2);
            record.put("winnerName", "");
            record.put("turnIndex", 0);
            record.put("totalTurns", 0);
        } catch (Exception ignored) {
        }
        return record;
    }

    static boolean isFinished(JSONObject record) {
        return record != null && STATUS_FINISHED.equals(record.optString("status"));
    }

    static boolean isInProgress(JSONObject record) {
        return record != null && STATUS_IN_PROGRESS.equals(record.optString("status"));
    }

    static String statusLabel(JSONObject record) {
        if (record == null) return "";
        String status = record.optString("status");
        if (STATUS_FINISHED.equals(status)) {
            int winner = record.optInt("winnerSlot", -2);
            if (winner < 0) return "منتهية - تعادل";
            return "منتهية - الفائز " + record.optString("winnerName", "");
        }
        String phase = record.optString("phase");
        if (PHASE_SETUP.equals(phase)) return "قيد الإعداد";
        if (PHASE_CATEGORY_SELECT.equals(phase)) return "بانتظار اختيار الفئات";
        if (PHASE_QUESTION.equals(phase)) return "قيد الإجابة";
        return "قيد اللعب";
    }

    static void syncToCloud(final JSONObject record) {
        if (record == null) return;
        try {
            String tvCode = record.optString("tvCode", "").trim();
            if (tvCode.isEmpty()) return;
            Map<String, Object> map = jsonToMap(record);
            FirebaseDatabase.getInstance().getReference("TvMatches").child(tvCode).setValue(map);
        } catch (Exception e) {
            Log.w("LocalTeamsGameStore", "Failed to sync to cloud: " + e.getMessage());
        }
    }

    static void fetchFromCloud(final Context context, final String tvCode, final OnCloudSyncListener listener) {
        if (tvCode == null || tvCode.trim().isEmpty()) {
            if (listener != null) listener.onSync(null);
            return;
        }
        DatabaseReference ref = FirebaseDatabase.getInstance().getReference("TvMatches").child(tvCode.trim());
        ref.addListenerForSingleValueEvent(new ValueEventListener() {
            @Override
            public void onDataChange(DataSnapshot snapshot) {
                if (snapshot.exists() && snapshot.getValue() instanceof Map) {
                    try {
                        JSONObject cloudRecord = mapToJson((Map<?, ?>) snapshot.getValue());
                        String id = cloudRecord.optString("id", "");
                        if (!id.isEmpty()) {
                            JSONObject localRecord = get(context, id);
                            long cloudUpdated = cloudRecord.optLong("updatedAt", 0L);
                            long localUpdated = localRecord != null ? localRecord.optLong("updatedAt", 0L) : 0L;
                            if (cloudUpdated >= localUpdated) {
                                upsert(context, cloudRecord);
                                if (listener != null) listener.onSync(cloudRecord);
                                return;
                            }
                        }
                    } catch (Exception ignored) {}
                }
                if (listener != null) listener.onSync(null);
            }

            @Override
            public void onCancelled(DatabaseError error) {
                if (listener != null) listener.onSync(null);
            }
        });
    }

    interface OnCloudSyncListener {
        void onSync(JSONObject record);
    }

    private static Map<String, Object> jsonToMap(JSONObject json) throws org.json.JSONException {
        Map<String, Object> map = new HashMap<>();
        Iterator<String> keys = json.keys();
        while (keys.hasNext()) {
            String key = keys.next();
            Object value = json.opt(key);
            if (value == null || value == JSONObject.NULL) {
                continue;
            } else if (value instanceof JSONObject) {
                map.put(key, jsonToMap((JSONObject) value));
            } else if (value instanceof JSONArray) {
                map.put(key, jsonToList((JSONArray) value));
            } else {
                map.put(key, value);
            }
        }
        return map;
    }

    private static List<Object> jsonToList(JSONArray array) throws org.json.JSONException {
        List<Object> list = new ArrayList<>();
        for (int i = 0; i < array.length(); i++) {
            Object value = array.opt(i);
            if (value == null || value == JSONObject.NULL) {
                list.add("");
            } else if (value instanceof JSONObject) {
                list.add(jsonToMap((JSONObject) value));
            } else if (value instanceof JSONArray) {
                list.add(jsonToList((JSONArray) value));
            } else {
                list.add(value);
            }
        }
        return list;
    }

    static JSONObject mapToJson(Map<?, ?> map) {
        if (map == null) return new JSONObject();
        try {
            JSONObject out = new JSONObject();
            for (Map.Entry<?, ?> entry : map.entrySet()) {
                String key = String.valueOf(entry.getKey());
                Object val = entry.getValue();
                if (val instanceof Map) {
                    out.put(key, mapToJson((Map<?, ?>) val));
                } else if (val instanceof List) {
                    out.put(key, listToJson((List<?>) val));
                } else {
                    out.put(key, val);
                }
            }
            return out;
        } catch (Exception e) {
            return new JSONObject();
        }
    }

    static JSONArray listToJson(List<?> list) {
        JSONArray arr = new JSONArray();
        if (list == null) return arr;
        try {
            for (Object item : list) {
                if (item instanceof Map) {
                    arr.put(mapToJson((Map<?, ?>) item));
                } else if (item instanceof List) {
                    arr.put(listToJson((List<?>) item));
                } else {
                    arr.put(item);
                }
            }
        } catch (Exception ignored) {}
        return arr;
    }

    private static JSONArray readArray(Context context) {
        SharedPreferences prefs = context.getSharedPreferences(PREF, Context.MODE_PRIVATE);
        String raw = prefs.getString(KEY_GAMES, "[]");
        try {
            return new JSONArray(raw == null || raw.trim().isEmpty() ? "[]" : raw);
        } catch (Exception ignored) {
            return new JSONArray();
        }
    }

    private static void writeArray(Context context, JSONArray array) {
        context.getSharedPreferences(PREF, Context.MODE_PRIVATE)
                .edit()
                .putString(KEY_GAMES, array == null ? "[]" : array.toString())
                .apply();
    }

    private static JSONArray prune(JSONArray array) {
        ArrayList<JSONObject> items = new ArrayList<>();
        for (int i = 0; i < array.length(); i++) {
            JSONObject item = array.optJSONObject(i);
            if (item != null) items.add(item);
        }
        Collections.sort(items, new Comparator<JSONObject>() {
            @Override
            public int compare(JSONObject a, JSONObject b) {
                return Long.compare(b.optLong("updatedAt", 0L), a.optLong("updatedAt", 0L));
            }
        });
        JSONArray out = new JSONArray();
        for (int i = 0; i < items.size() && i < MAX_RECORDS; i++) {
            out.put(items.get(i));
        }
        return out;
    }
}
