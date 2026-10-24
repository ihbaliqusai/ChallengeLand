package com.qi7bali.landchallengeonline;

import android.content.Context;
import android.content.SharedPreferences;

import org.json.JSONObject;

final class CampaignProgressStore {
    private static final String PREF = "CampaignActiveProgress";
    private static final String KEY_STAGE_ID = "active_stage_id";
    private static final String KEY_RECORD = "active_stage_record";

    private CampaignProgressStore() {}

    static void save(Context context, String stageId, JSONObject record) {
        if (context == null || stageId == null || stageId.trim().isEmpty() || record == null) return;
        try {
            SharedPreferences sp = context.getSharedPreferences(PREF, Context.MODE_PRIVATE);
            sp.edit()
                    .putString(KEY_STAGE_ID, stageId.trim())
                    .putString(KEY_RECORD, record.toString())
                    .apply();
        } catch (Exception ignored) {}
    }

    static JSONObject get(Context context, String stageId) {
        if (context == null || stageId == null || stageId.trim().isEmpty()) return null;
        try {
            SharedPreferences sp = context.getSharedPreferences(PREF, Context.MODE_PRIVATE);
            String savedStageId = sp.getString(KEY_STAGE_ID, "");
            if (!stageId.trim().equals(savedStageId)) {
                return null;
            }
            String recordStr = sp.getString(KEY_RECORD, null);
            if (recordStr == null || recordStr.trim().isEmpty()) return null;
            return new JSONObject(recordStr);
        } catch (Exception ignored) {
            return null;
        }
    }

    static void clear(Context context) {
        if (context == null) return;
        try {
            SharedPreferences sp = context.getSharedPreferences(PREF, Context.MODE_PRIVATE);
            sp.edit().clear().apply();
        } catch (Exception ignored) {}
    }
}
