package com.qi7bali.landchallengeonline;

import android.content.Context;
import android.content.SharedPreferences;

import java.util.HashSet;
import java.util.Set;

public final class AppPrefs {
    public static final String PREF_USER = "UserInfo";
    public static final String PREF_SETTINGS = "AppSettings";
    public static final String PREF_ROOM = "RoomBridge";
    public static final String PREF_PURCHASES = "PurchaseDeliveries";
    public static final String PREF_ADS = "AdPrefs";
    private static final String KEY_PENDING_ROOM_MATCH_RESULT = "pendingRoomMatchResult";
    private static final String KEY_PENDING_CAMPAIGN_STAGE_RESULT = "pending_campaign_stage_result";
    private static final String KEY_DELIVERED_PURCHASES = "deliveredPurchaseKeys";
    private static final String KEY_INTERSTITIAL_LAST_SHOWN_AT = "interstitialLastShownAt";
    private static final String KEY_INTERSTITIAL_PENDING_OPPORTUNITIES = "interstitialPendingOpportunities";
    private static final long INTERSTITIAL_COOLDOWN_MS = 4L * 60L * 1000L;
    private static final int INTERSTITIAL_REQUIRED_OPPORTUNITIES = 3;

    private AppPrefs() {}

    private static SharedPreferences userPrefs(Context c) {
        return c.getSharedPreferences(PREF_USER, Context.MODE_PRIVATE);
    }

    private static SharedPreferences settingsPrefs(Context c) {
        return c.getSharedPreferences(PREF_SETTINGS, Context.MODE_PRIVATE);
    }

    private static SharedPreferences roomPrefs(Context c) {
        return c.getSharedPreferences(PREF_ROOM, Context.MODE_PRIVATE);
    }

    private static SharedPreferences purchasePrefs(Context c) {
        return c.getSharedPreferences(PREF_PURCHASES, Context.MODE_PRIVATE);
    }

    private static SharedPreferences adPrefs(Context c) {
        return c.getSharedPreferences(PREF_ADS, Context.MODE_PRIVATE);
    }

    public static void ensureGuestUser(Context c) {
        SharedPreferences p = userPrefs(c);
        if (p.getString("userID", "").isEmpty()) {
            setUser(c, "guest_local", "ضيف", "", 1, 0);
        }
    }

    public static void setUser(Context c, String id, String name, String photo, int level, int score) {
        // Capture the old identity's legacy character data before changing UID.
        if (!java.util.Objects.equals(id, getUserId(c))) characterPrefs(c);
        userPrefs(c).edit()
                .putString("userID", id)
                .putString("userName", name)
                .putString("userPhoto", photo)
                .putInt("userLevel", level)
                .putInt("userScore", score)
                .apply();
    }

    public static void setGuestUser(Context c) {
        setUser(c, "guest_local", "ضيف", "", 1, 0);
    }

    public static String getUserId(Context c) { return userPrefs(c).getString("userID", ""); }
    public static String getUserName(Context c) { return userPrefs(c).getString("userName", "ضيف"); }
    public static String getUserPhoto(Context c) { return userPrefs(c).getString("userPhoto", ""); }
    public static int getUserLevel(Context c) { return PlayerProgress.getLevel(c); }
    public static int getUserScore(Context c) { return userPrefs(c).getInt("userScore", 0); }

    // ── Character selection ─────────────────────────────────────────────────
    /** Default character (index 1 = Omar) used until the player picks one. */
    public static final int DEFAULT_CHARACTER = 1;

    private static synchronized SharedPreferences characterPrefs(Context c) {
        String uid = getUserId(c);
        if (uid == null || uid.trim().isEmpty()) uid = "guest_local";
        SharedPreferences state = c.getSharedPreferences("CharacterState_v1_" + uid, Context.MODE_PRIVATE);
        if (state.getBoolean("initialized", false)) return state;
        SharedPreferences migration = c.getSharedPreferences("CharacterMigration", Context.MODE_PRIVATE);
        String owner = migration.getString("legacyOwner", "");
        if (owner == null || owner.isEmpty()) {
            ProgressionAccount.commitOrRollback(migration, migration.edit().putString("legacyOwner", uid));
            owner = uid;
        }
        SharedPreferences.Editor editor = state.edit().putBoolean("initialized", true);
        if (uid.equals(owner)) {
            SharedPreferences legacy = userPrefs(c);
            int selected = legacy.getInt("selectedCharacter", -1);
            editor.putInt("selectedCharacter", CharacterUnlocks.isValid(selected) ? selected : -1);
            editor.putStringSet("unlockedCharacters", validCharacterPurchases(
                    legacy.getStringSet("unlockedCharacters", new HashSet<String>())));
        }
        ProgressionAccount.commitOrRollback(state, editor);
        return state;
    }

    private static Set<String> validCharacterPurchases(Set<String> values) {
        Set<String> valid = new HashSet<>();
        if (values != null) for (String value : values) {
            try {
                int index = Integer.parseInt(value);
                if (CharacterUnlocks.isValid(index)) valid.add(String.valueOf(index));
            } catch (NumberFormatException ignored) { }
        }
        return valid;
    }

    /** The chosen roster index, or -1 when the player has not picked. */
    public static int getSelectedCharacter(Context c) {
        return characterPrefs(c).getInt("selectedCharacter", -1);
    }

    /** The character to actually render in-game (never -1). */
    public static int getEffectiveCharacter(Context c) {
        int index = getSelectedCharacter(c);
        return CharacterUnlocks.isValid(index) ? index : DEFAULT_CHARACTER;
    }

    public static void setSelectedCharacter(Context c, int index) {
        if (index != -1 && !CharacterUnlocks.isValid(index)) return;
        characterPrefs(c).edit().putInt("selectedCharacter", index).apply();
    }

    public static Set<String> getUnlockedCharacters(Context c) {
        return new HashSet<>(characterPrefs(c).getStringSet("unlockedCharacters", new HashSet<String>()));
    }

    public static boolean isCharacterPurchased(Context c, int index) {
        return getUnlockedCharacters(c).contains(String.valueOf(index));
    }

    public static void unlockCharacter(Context c, int index) {
        if (!CharacterUnlocks.isValid(index)) return;
        Set<String> set = getUnlockedCharacters(c);
        set.add(String.valueOf(index));
        characterPrefs(c).edit().putStringSet("unlockedCharacters", set).apply();
    }

    public static void setUnlockedCharacters(Context c, Set<String> characters) {
        characterPrefs(c).edit().putStringSet("unlockedCharacters", validCharacterPurchases(characters)).apply();
    }

    public static void clearUnlockedCharacters(Context c) {
        characterPrefs(c).edit().remove("unlockedCharacters").apply();
    }

    // ==========================================
    // Category Unlocks & Rewarded Ad Rentals
    // ==========================================
    private static final String KEY_UNLOCKED_CATEGORIES = "unlockedCategories";
    private static final String KEY_CATEGORY_RENTALS = "categoryRentalsJson";

    public static Set<String> getUnlockedCategories(Context c) {
        return new HashSet<>(userPrefs(c).getStringSet(KEY_UNLOCKED_CATEGORIES, new HashSet<String>()));
    }

    public static boolean isCategoryUnlocked(Context c, String category) {
        if (category == null || category.trim().isEmpty()) return true;
        if (CategoryConfig.isCoreFree(category)) return true;
        if (isVip(c) || VerifiedCommerceStore.hasAllCategories(c)) return true;
        if (GameEconomy.hasAccess(c, category) || GameEconomy.selectable(c, category)
                || (c instanceof android.app.Activity && GameEconomy.sessionHasCategory((android.app.Activity)c, category))) return true;

        String norm = CategoryConfig.normalize(category);
        for (String u : getUnlockedCategories(c)) {
            if (CategoryConfig.normalize(u).equals(norm)) return true;
        }

        // Check active rental
        long expiry = getCategoryRentalExpiry(c, category);
        return expiry > System.currentTimeMillis();
    }

    public static long getCategoryRentalExpiry(Context c, String category) {
        if (category == null || category.trim().isEmpty()) return 0L;
        String norm = CategoryConfig.normalize(category);
        try {
            String jsonStr = userPrefs(c).getString(KEY_CATEGORY_RENTALS, "{}");
            org.json.JSONObject obj = new org.json.JSONObject(jsonStr);
            org.json.JSONObject economyRentals = GameEconomy.state(c).optJSONObject("rentals");
            long expiry = Math.max(obj.optLong(norm, 0L), economyRentals == null ? 0L : economyRentals.optLong(norm));
            java.util.Iterator<String> keys = obj.keys();
            while (keys.hasNext()) {
                String key = keys.next();
                if (CategoryConfig.normalize(key).equals(norm)) expiry = Math.max(expiry, obj.optLong(key, 0L));
            }
            return expiry;
        } catch (Exception e) {
            return 0L;
        }
    }

    public static int getRemainingRentalHours(Context c, String category) {
        long expiry = getCategoryRentalExpiry(c, category);
        long diffMs = expiry - System.currentTimeMillis();
        if (diffMs <= 0) return 0;
        return (int) Math.ceil((double) diffMs / (3600.0 * 1000.0));
    }

    public static boolean unlockCategoryPermanently(Context c, String category, int gemCost) {
        if (category == null || category.trim().isEmpty()) return false;
        if (gemCost > 0) {
            if (!PlayerProgress.spendGems(c, gemCost)) {
                return false;
            }
        }
        Set<String> set = getUnlockedCategories(c);
        set.add(category.trim());
        userPrefs(c).edit().putStringSet(KEY_UNLOCKED_CATEGORIES, set).apply();
        return true;
    }

    public static void setUnlockedCategories(Context c, Set<String> categories) {
        userPrefs(c).edit().putStringSet(KEY_UNLOCKED_CATEGORIES, categories != null ? categories : new HashSet<String>()).apply();
    }

    public static void clearUnlockedCategories(Context c) {
        userPrefs(c).edit().remove(KEY_UNLOCKED_CATEGORIES).remove(KEY_CATEGORY_RENTALS).apply();
    }

    /** Legacy entry point cannot grant a timed rental from an ad. */
    public static boolean rentCategoryWithAd(Context c, String category, int durationHours) {
        return false;
    }

    public static java.util.Map<String, Long> getActiveRentals(Context c) {
        java.util.Map<String, Long> map = new java.util.HashMap<>();
        try {
            String jsonStr = userPrefs(c).getString(KEY_CATEGORY_RENTALS, "{}");
            org.json.JSONObject obj = new org.json.JSONObject(jsonStr);
            long now = System.currentTimeMillis();
            java.util.Iterator<String> keys = obj.keys();
            while (keys.hasNext()) {
                String key = keys.next();
                long expiry = obj.optLong(key, 0L);
                if (expiry > now) {
                    map.put(key, expiry);
                }
            }
        } catch (Exception ignored) {}
        return map;
    }

    public static boolean isVip(Context c) {
        return VerifiedCommerceStore.isVip(c);
    }

    public static void setVip(Context c, boolean vip) {
        // Purchase entitlements are written exclusively after server verification.
        settingsPrefs(c).edit().remove("isVip").apply();
        purchasePrefs(c).edit().remove("vip_pass_active").apply();
    }

    public static boolean isAdFree(Context c) {
        return VerifiedCommerceStore.isAdFree(c);
    }

    public static void setSoundEnabled(Context c, boolean enabled) {
        settingsPrefs(c).edit().putBoolean("soundEnabled", enabled).apply();
    }

    public static boolean isSoundEnabled(Context c) {
        return settingsPrefs(c).getBoolean("soundEnabled", true);
    }

    public static void setMusicEnabled(Context c, boolean enabled) {
        settingsPrefs(c).edit().putBoolean("musicEnabled", enabled).apply();
    }

    public static boolean isMusicEnabled(Context c) {
        return settingsPrefs(c).getBoolean("musicEnabled", false);
    }

    public static void setHapticEnabled(Context c, boolean enabled) {
        settingsPrefs(c).edit().putBoolean("hapticEnabled", enabled).apply();
    }

    public static boolean isHapticEnabled(Context c) {
        return settingsPrefs(c).getBoolean("hapticEnabled", true);
    }

    public static void setNotificationsEnabled(Context c, boolean enabled) {
        settingsPrefs(c).edit().putBoolean("notificationsEnabled", enabled).apply();
    }

    public static boolean isNotificationsEnabled(Context c) {
        return settingsPrefs(c).getBoolean("notificationsEnabled", true);
    }

    public static void setLanguageCode(Context c, String languageCode) {
        String safeCode = "en".equals(languageCode) ? "en" : "ar";
        settingsPrefs(c).edit().putString("languageCode", safeCode).apply();
    }

    public static String getLanguageCode(Context c) {
        String code = settingsPrefs(c).getString("languageCode", "ar");
        return "en".equals(code) ? "en" : "ar";
    }

    public static void setDialogsEnabled(Context c, boolean enabled) {
        settingsPrefs(c).edit().putBoolean("dialogsEnabled", enabled).apply();
    }

    public static boolean isDialogsEnabled(Context c) {
        return settingsPrefs(c).getBoolean("dialogsEnabled", true);
    }

    public static int getCoins(Context c) { return PlayerProgress.getCoins(c); }
    public static int getGems(Context c) { return PlayerProgress.getGems(c); }
    public static int getXp(Context c) { return PlayerProgress.getXp(c); }
    public static int getLevel(Context c) { return PlayerProgress.getLevel(c); }
    public static int getInventory5050(Context c) { return PlayerProgress.getInventory5050(c); }
    public static int getInventoryAudience(Context c) { return PlayerProgress.getInventoryAudience(c); }
    public static int getInventoryCall(Context c) { return PlayerProgress.getInventoryCall(c); }

    public static void setPendingRoomMatchResult(Context c, String payload) {
        roomPrefs(c).edit().putString(KEY_PENDING_ROOM_MATCH_RESULT, payload).apply();
    }

    public static String consumePendingRoomMatchResult(Context c) {
        SharedPreferences prefs = roomPrefs(c);
        String payload = prefs.getString(KEY_PENDING_ROOM_MATCH_RESULT, "");
        prefs.edit().remove(KEY_PENDING_ROOM_MATCH_RESULT).apply();
        return payload == null ? "" : payload;
    }

    public static String getPendingRoomMatchResult(Context c) {
        String payload = roomPrefs(c).getString(KEY_PENDING_ROOM_MATCH_RESULT, "");
        return payload == null ? "" : payload;
    }

    public static void clearPendingRoomMatchResult(Context c) {
        roomPrefs(c).edit().remove(KEY_PENDING_ROOM_MATCH_RESULT).apply();
    }

    private static String campaignResultKey(Context c) {
        return KEY_PENDING_CAMPAIGN_STAGE_RESULT + "_" + ProgressionAccount.uid(c);
    }

    private static boolean campaignResultOwned(Context c, String payload) {
        if (payload == null || payload.trim().isEmpty()) return false;
        try {
            org.json.JSONObject result = new org.json.JSONObject(payload);
            String owner = result.optString("accountUid", "").trim();
            return owner.isEmpty() || owner.equals(ProgressionAccount.uid(c));
        } catch (Exception invalidPayload) {
            return false;
        }
    }

    private static String availableCampaignResultKey(Context c, SharedPreferences prefs) {
        String scopedKey = campaignResultKey(c);
        if (campaignResultOwned(c, prefs.getString(scopedKey, ""))) return scopedKey;
        if (campaignResultOwned(c, prefs.getString(KEY_PENDING_CAMPAIGN_STAGE_RESULT, ""))) {
            return KEY_PENDING_CAMPAIGN_STAGE_RESULT;
        }
        return "";
    }

    public static synchronized void setPendingCampaignStageResult(Context c, String payload) {
        if (!campaignResultOwned(c, payload)) {
            throw new IllegalArgumentException("Campaign result does not belong to the active account");
        }
        SharedPreferences prefs = roomPrefs(c);
        ProgressionAccount.commitOrRollback(prefs, prefs.edit().putString(campaignResultKey(c), payload));
    }

    public static synchronized String consumePendingCampaignStageResult(Context c) {
        SharedPreferences prefs = roomPrefs(c);
        String key = availableCampaignResultKey(c, prefs);
        if (key.isEmpty()) return "";
        String payload = prefs.getString(key, "");
        ProgressionAccount.commitOrRollback(prefs, prefs.edit().remove(key));
        return payload == null ? "" : payload;
    }

    public static String getPendingCampaignStageResult(Context c) {
        SharedPreferences prefs = roomPrefs(c);
        String key = availableCampaignResultKey(c, prefs);
        if (key.isEmpty()) return "";
        String payload = prefs.getString(key, "");
        return payload == null ? "" : payload;
    }

    public static synchronized void clearPendingCampaignStageResult(Context c) {
        SharedPreferences prefs = roomPrefs(c);
        String key = availableCampaignResultKey(c, prefs);
        if (!key.isEmpty()) ProgressionAccount.commitOrRollback(prefs, prefs.edit().remove(key));
    }

    public static boolean isPurchaseDelivered(Context c, String deliveryKey) {
        if (deliveryKey == null || deliveryKey.trim().isEmpty()) {
            return false;
        }
        Set<String> delivered = purchasePrefs(c).getStringSet(KEY_DELIVERED_PURCHASES, new HashSet<>());
        return delivered != null && delivered.contains(deliveryKey);
    }

    public static void markPurchaseDelivered(Context c, String deliveryKey) {
        if (deliveryKey == null || deliveryKey.trim().isEmpty()) {
            return;
        }
        Set<String> delivered = purchasePrefs(c).getStringSet(KEY_DELIVERED_PURCHASES, new HashSet<>());
        HashSet<String> next = new HashSet<>();
        if (delivered != null) {
            next.addAll(delivered);
        }
        next.add(deliveryKey);
        purchasePrefs(c).edit().putStringSet(KEY_DELIVERED_PURCHASES, next).apply();
    }

    public static void recordInterstitialOpportunity(Context c) {
        SharedPreferences prefs = adPrefs(c);
        int current = prefs.getInt(KEY_INTERSTITIAL_PENDING_OPPORTUNITIES, 0);
        int next = Math.min(INTERSTITIAL_REQUIRED_OPPORTUNITIES, current + 1);
        prefs.edit().putInt(KEY_INTERSTITIAL_PENDING_OPPORTUNITIES, next).apply();
    }

    public static boolean canShowInterstitialNow(Context c) {
        if (isAdFree(c)) return false;
        SharedPreferences prefs = adPrefs(c);
        int pending = prefs.getInt(KEY_INTERSTITIAL_PENDING_OPPORTUNITIES, 0);
        if (pending < INTERSTITIAL_REQUIRED_OPPORTUNITIES) {
            return false;
        }
        long lastShownAt = prefs.getLong(KEY_INTERSTITIAL_LAST_SHOWN_AT, 0L);
        return lastShownAt <= 0L
                || (System.currentTimeMillis() - lastShownAt) >= INTERSTITIAL_COOLDOWN_MS;
    }

    public static void markInterstitialShown(Context c) {
        adPrefs(c).edit()
                .putLong(KEY_INTERSTITIAL_LAST_SHOWN_AT, System.currentTimeMillis())
                .putInt(KEY_INTERSTITIAL_PENDING_OPPORTUNITIES, 0)
                .apply();
    }

    public static void resetLocalProgress(Context c) {
        PlayerStats.reset(c);
        VerifiedCommerceStore.resetGameplayProgress(c);
        setGuestUser(c);
        adPrefs(c).edit()
                .remove(KEY_INTERSTITIAL_LAST_SHOWN_AT)
                .remove(KEY_INTERSTITIAL_PENDING_OPPORTUNITIES)
                .apply();
    }
}
