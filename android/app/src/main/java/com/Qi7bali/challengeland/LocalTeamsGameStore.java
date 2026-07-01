package net.androidgaming.millionaire2024;

import android.content.Context;
import android.content.SharedPreferences;

import org.json.JSONArray;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.Locale;
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
    }

    static JSONObject baseRecord(String id) {
        long now = System.currentTimeMillis();
        JSONObject record = new JSONObject();
        try {
            record.put("id", id == null || id.trim().isEmpty() ? newGameId() : id.trim());
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
