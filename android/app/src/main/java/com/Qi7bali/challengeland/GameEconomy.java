package com.qi7bali.landchallengeonline;

import android.app.Activity;
import android.content.Context;
import android.content.SharedPreferences;
import com.google.firebase.auth.FirebaseAuth;
import com.google.firebase.firestore.FirebaseFirestore;
import com.google.firebase.functions.FirebaseFunctions;
import org.json.JSONObject;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

/** Server-owned resource wallet; preferences are a display cache, never spending authority. */
public final class GameEconomy {
    private GameEconomy() {}
    public interface Callback { void complete(Map<String, Object> value, String error); }
    private static final java.util.WeakHashMap<Activity, Boolean> admitted = new java.util.WeakHashMap<>();
    private static final java.util.WeakHashMap<Activity, Boolean> admitting = new java.util.WeakHashMap<>();
    private static final Set<String> flushingAccounts = new HashSet<>();
    public static boolean ensure(Activity a, boolean campaign, int order, ArrayList<String> categories, Runnable next) {
        // Preserve the existing first-stage guest tutorial before account creation.
        // Registered progression and purchases always use the server wallet.
        if (campaign && order == 1 && "guest_local".equals(ProgressionAccount.uid(a))) return true;
        String savedId = a.getIntent().getStringExtra("economySessionId");
        if (savedId == null) savedId = identity(a);
        final boolean previouslyAdmitted = Boolean.TRUE.equals(admitted.get(a)) || (prefs(a).getBoolean("admitted:" + savedId, false)
                && (!campaign || !prefs(a).getBoolean("finished:" + savedId, false)));
        boolean covered = true;
        for (String category : categories) if (!sessionHasCategory(a, category)) { covered = false; break; }
        if (previouslyAdmitted && covered) {
            a.getIntent().putExtra("economySessionId", savedId);
            admitted.put(a, true);
            return true;
        }
        if (Boolean.TRUE.equals(admitting.get(a))) return false;
        admitting.put(a, true);
        if (previouslyAdmitted && !campaign) {
            final String sessionId = savedId;
            Map<String, Object> extension = new HashMap<>(); extension.put("action", "extend");
            extension.put("sessionId", sessionId); extension.put("categories", categories);
            request(a, extension, (value, error) -> {
                admitting.remove(a);
                if (a.isFinishing() || a.isDestroyed()) return;
                if (error != null) { showFailure(a, error, next); return; }
                prefs(a).edit().putString("session:" + sessionId, new JSONObject((Map<?, ?>) value.get("session")).toString()).commit();
                clearSelection(a); admitted.put(a, true); next.run();
            });
            return false;
        }
        begin(a, campaign, order, categories, (value, error) -> {
            if (a.isFinishing() || a.isDestroyed()) {
                if (error == null) cancelUnstarted(a);
                return;
            }
            if (error != null) { admitting.remove(a); showFailure(a, error, next); return; }
            String id = a.getIntent().getStringExtra("economySessionId");
            Map<String, Object> commit = new HashMap<>(); commit.put("action", "commit");
            commit.put("operationId", "commit_" + id); commit.put("sessionId", id);
            request(a, commit, (v, failure) -> {
                admitting.remove(a);
                if (a.isFinishing() || a.isDestroyed()) return;
                if (failure != null) { showFailure(a, failure, next); return; }
                prefs(a).edit().putBoolean("admitted:" + id, true).commit();
                admitted.put(a, true); next.run();
            });
        });
        return false;
    }
    private static void showFailure(Activity a, String error, Runnable retry) {
        new android.app.AlertDialog.Builder(a).setTitle("رصيد اللعب").setMessage(error)
            .setPositiveButton("إعادة المحاولة", (d, w) -> retry.run())
            .setNeutralButton("المتجر", (d, w) -> a.startActivity(new android.content.Intent(a, StoreActivity.class)))
            .setNegativeButton("رجوع", (d, w) -> a.finish()).setCancelable(false).show();
    }
    private static SharedPreferences prefs(Context c) {
        return c.getSharedPreferences("Economy_v1_" + ProgressionAccount.uid(c), Context.MODE_PRIVATE);
    }
    public static JSONObject state(Context c) {
        try { return new JSONObject(prefs(c).getString("state", "{}")); }
        catch (Exception e) { return new JSONObject(); }
    }
    public static long serverTime(Context c) {
        SharedPreferences p = prefs(c);
        long elapsed = android.os.SystemClock.elapsedRealtime() - p.getLong("anchorElapsed", 0);
        return p.getLong("anchorTime", System.currentTimeMillis()) + Math.max(0, elapsed);
    }
    public static boolean hasAccess(Context c, String category) {
        JSONObject s = state(c);
        String key = CategoryConfig.normalize(category);
        org.json.JSONArray owned = s.optJSONArray("owned");
        if (owned != null) for (int i = 0; i < owned.length(); i++) if (CategoryConfig.normalize(owned.optString(i)).equals(key)) return true;
        JSONObject rentals = s.optJSONObject("rentals");
        return rentals != null && rentals.optLong(key) > serverTime(c);
    }
    /** Selection permits are not ownership; they are consumed atomically when a match starts. */
    public static boolean selectable(Context c, String category) {
        JSONObject s = state(c);
        JSONObject ads = s.optJSONObject("adPermits");
        return (ads != null && ads.optInt(CategoryConfig.normalize(category)) > 0)
                || prefs(c).getStringSet("selectedTickets", new HashSet<>()).contains(CategoryConfig.normalize(category));
    }
    public static boolean selectTicket(Context c, String category) {
        Set<String> selected = new HashSet<>(prefs(c).getStringSet("selectedTickets", new HashSet<>()));
        if (!selected.contains(CategoryConfig.normalize(category)) && selected.size() >= state(c).optInt("tickets")) return false;
        selected.add(CategoryConfig.normalize(category));
        prefs(c).edit().putStringSet("selectedTickets", selected).apply();
        return true;
    }
    public static void clearSelection(Context c) { prefs(c).edit().remove("selectedTickets").apply(); }
    public static boolean sessionHasCategory(Activity a, String category) {
        String id = a.getIntent().getStringExtra("economySessionId");
        if (id == null) {
            id = identity(a);
            if (!prefs(a).contains("session:" + id)) return false;
            a.getIntent().putExtra("economySessionId", id);
        }
        try {
            org.json.JSONArray categories = new JSONObject(prefs(a).getString("session:" + id, "{}")).optJSONArray("categories");
            if (categories != null) for (int i = 0; i < categories.length(); i++) if (CategoryConfig.normalize(categories.optString(i)).equals(CategoryConfig.normalize(category))) return true;
        } catch (Exception ignored) {}
        return false;
    }
    public static void request(Context c, Map<String, Object> data, Callback callback) {
        String uid = ProgressionAccount.uid(c);
        final SharedPreferences accountPrefs = prefs(c);
        com.google.firebase.auth.FirebaseUser user = FirebaseAuth.getInstance().getCurrentUser();
        if (user == null || user.isAnonymous() || !uid.equals(user.getUid())) { callback.complete(null, "سجّل الدخول لحفظ أرصدتك."); return; }
        Map<String, Object> request = new HashMap<>(data);
        request.put("expectedUid", uid);
        if (!"state".equals(request.get("action")) && !request.containsKey("operationId")) request.put("operationId", UUID.randomUUID().toString());
        if ("state".equals(request.get("action")) || "login".equals(request.get("action"))) {
            Map.Entry<String, ?> entry = nextPending(accountPrefs);
            if (entry != null) {
                try {
                    JSONObject json = new JSONObject(entry.getValue().toString());
                    Map<String, Object> terminal = new HashMap<>();
                    java.util.Iterator<String> fields = json.keys();
                    while (fields.hasNext()) { String field = fields.next(); terminal.put(field, json.get(field)); }
                    request(c, terminal, (v, error) -> {
                        if (error != null) callback.complete(null, error);
                        else {
                            markPendingComplete(accountPrefs, entry.getKey(), terminal);
                            request(c, data, callback);
                        }
                    });
                    return;
                } catch (Exception error) { callback.complete(null, "تعذر استعادة نتيجة المباراة."); return; }
            }
        }
        final boolean paid = "buy".equals(request.get("action")) || "rent".equals(request.get("action")) || "own".equals(request.get("action"));
        String pending = accountPrefs.getString("pendingPurchase", "");
        if (!pending.isEmpty()) {
            try {
                JSONObject json = new JSONObject(pending);
                if (!json.optString("operationId").equals(request.get("operationId"))) {
                    Map<String, Object> previous = new HashMap<>();
                    java.util.Iterator<String> fields = json.keys();
                    while (fields.hasNext()) { String field = fields.next(); previous.put(field, json.get(field)); }
                    request(c, previous, (v, error) -> {
                        if (error != null) callback.complete(null, error);
                        else if (paid) callback.complete(null, "تمت استعادة عملية الشراء السابقة. راجع رصيدك ثم أعد تأكيد طلبك الجديد.");
                        else request(c, data, callback);
                    });
                    return;
                }
            } catch (Exception error) { callback.complete(null, "تعذر استعادة عملية الشراء السابقة."); return; }
        }
        if (paid && pending.isEmpty()) {
            if (!accountPrefs.edit().putString("pendingPurchase", new JSONObject(request).toString()).putBoolean("purchaseSynced", false).commit()) {
                callback.complete(null, "تعذر حفظ طلب الشراء."); return;
            }
        }
        Runnable send = () -> FirebaseFunctions.getInstance("us-central1").getHttpsCallable("gameEconomy").call(request)
                .addOnSuccessListener(response -> {
                    if (!uid.equals(ProgressionAccount.uid(c))) { callback.complete(null, "تغيّر الحساب. حاول مجدداً."); return; }
                    if (!(response.getData() instanceof Map)) { callback.complete(null, "استجابة الرصيد غير صالحة."); return; }
                    @SuppressWarnings("unchecked") Map<String, Object> value = (Map<String, Object>) response.getData();
                    boolean currentResponse = true;
                    if (value.get("state") instanceof Map) {
                        @SuppressWarnings("unchecked") Map<String, Object> wallet = (Map<String, Object>) value.get("state");
                        JSONObject json = new JSONObject(wallet);
                        currentResponse = json.optLong("revision") >= state(c).optLong("revision");
                        if (currentResponse) {
                            accountPrefs.edit().putString("state", json.toString()).putLong("anchorTime", json.optLong("serverTimeMillis"))
                                    .putLong("anchorElapsed", android.os.SystemClock.elapsedRealtime()).apply();
                        }
                    }
                    if (currentResponse && value.get("currency") instanceof Map) {
                        Map<?, ?> currency = (Map<?, ?>) value.get("currency");
                        PlayerProgress.setCurrency(c, ((Number) currency.get("coins")).intValue(), ((Number) currency.get("gems")).intValue());
                    }
                    if (paid) accountPrefs.edit().remove("pendingPurchase").remove("purchaseSynced").commit();
                    callback.complete(value, null);
                }).addOnFailureListener(e -> {
                    if (paid && e instanceof com.google.firebase.functions.FirebaseFunctionsException) {
                        com.google.firebase.functions.FirebaseFunctionsException.Code code = ((com.google.firebase.functions.FirebaseFunctionsException)e).getCode();
                        if (code != com.google.firebase.functions.FirebaseFunctionsException.Code.UNAVAILABLE
                                && code != com.google.firebase.functions.FirebaseFunctionsException.Code.DEADLINE_EXCEEDED
                                && code != com.google.firebase.functions.FirebaseFunctionsException.Code.INTERNAL
                                && code != com.google.firebase.functions.FirebaseFunctionsException.Code.UNKNOWN) {
                            accountPrefs.edit().remove("pendingPurchase").remove("purchaseSynced").commit();
                        }
                    }
                    callback.complete(null, errorMessage(e));
                });
        // Legacy coins/gems still use the existing account snapshot; resource credits
        // and the debit are committed together by the callable, never by this client.
        if (paid && !accountPrefs.getBoolean("purchaseSynced", false)) {
            Map<String, Object> currency = new HashMap<>();
            currency.put("coins", PlayerProgress.getCoins(c)); currency.put("gems", PlayerProgress.getGems(c));
            FirebaseFirestore.getInstance().collection("users").document(uid).set(currency, com.google.firebase.firestore.SetOptions.merge())
                    .addOnSuccessListener(v -> {
                        accountPrefs.edit().putBoolean("purchaseSynced", true).commit(); send.run();
                    }).addOnFailureListener(e -> callback.complete(null, "تعذر مزامنة المحفظة."));
        } else send.run();
    }
    public static void refresh(Context c, Callback callback) {
        Map<String, Object> data = new HashMap<>(); data.put("action", "state"); request(c, data, callback);
    }
    public static void begin(Activity a, boolean campaign, int order, ArrayList<String> categories, Callback callback) {
        String id = a.getIntent().getStringExtra("economySessionId");
        if (id == null) {
            id = identity(a);
            a.getIntent().putExtra("economySessionId", id);
        }
        final String sessionId = id;
        Map<String, Object> data = new HashMap<>(); data.put("action", "begin"); data.put("operationId", id);
        data.put("mode", campaign ? "campaign" : "challenge"); data.put("stageOrder", campaign ? order : 0); data.put("categories", categories);
        // Reuse the original request across room rounds and activity recreation.
        try {
            JSONObject old = new JSONObject(prefs(a).getString("begin:" + id, "{}"));
            if (old.has("categories")) {
                ArrayList<String> original = new ArrayList<>();
                org.json.JSONArray array = old.getJSONArray("categories");
                for (int i = 0; i < array.length(); i++) original.add(array.getString(i));
                data.put("categories", original);
            } else prefs(a).edit().putString("begin:" + id, new JSONObject(data).toString()).commit();
        } catch (Exception ignored) {}
        request(a, data, (value, error) -> {
            if (error == null && value.get("session") instanceof Map) {
                prefs(a).edit().putString("session:" + sessionId, new JSONObject((Map<?, ?>) value.get("session")).toString()).apply();
                clearSelection(a);
            }
            callback.complete(value, error);
        });
    }
    public static void commit(Activity a) {
        String id = a.getIntent().getStringExtra("economySessionId");
        if (id == null) return;
        Map<String, Object> data = new HashMap<>(); data.put("action", "commit"); data.put("operationId", "commit_" + id); data.put("sessionId", id);
        request(a, data, (v, e) -> {});
    }
    private static void cancelUnstarted(Activity a) {
        String id = a.getIntent().getStringExtra("economySessionId");
        if (id == null) return;
        Map<String, Object> data = new HashMap<>(); data.put("action", "cancel");
        data.put("operationId", "cancel_" + id); data.put("sessionId", id);
        request(a, data, (v, error) -> {});
    }
    public static void finish(Activity a, boolean won) {
        String id = a.getIntent().getStringExtra("economySessionId");
        if (id == null) return;
        boolean campaign = "campaign".equals(NativeProgression.mode(a));
        // A room spends one key, but every completed round contributes to weekly play.
        // Queue its result even when an earlier round already finished the resource session.
        if (!campaign) queueRound(a, id);
        if (prefs(a).getBoolean("finished:" + id, false) || prefs(a).contains("pending:" + id)) { flush(a); return; }
        Map<String, Object> data = new HashMap<>(); data.put("action", "finish"); data.put("operationId", "finish_" + id); data.put("sessionId", id); data.put("won", won);
        if (!campaign) data.put("roundProgressVersion", 1);
        data.put("correct", ProgressionAccount.preferences(a).getInt("session:" + NativeProgression.matchId(a) + ":correct", 0));
        prefs(a).edit().putString("pending:" + id, new JSONObject(data).toString()).commit();
        flush(a);
    }
    private static void queueRound(Activity a, String sessionId) {
        String roundId = NativeProgression.matchId(a);
        SharedPreferences progress = ProgressionAccount.preferences(a);
        int correct = Math.max(0, progress.getInt("session:" + roundId + ":correct", 0));
        int wrong = Math.max(0, progress.getInt("session:" + roundId + ":wrong", 0));
        long answered = (long) correct + wrong;
        if (answered == 0) return;
        String operationId = "round_" + roundHash(sessionId + "|" + roundId);
        SharedPreferences accountPrefs = prefs(a);
        if (accountPrefs.getBoolean("reportedRound:" + operationId, false)
                || accountPrefs.contains("pendingRound:" + operationId)) return;
        Map<String, Object> data = new HashMap<>();
        data.put("action", "progressRound"); data.put("operationId", operationId);
        data.put("sessionId", sessionId); data.put("roundId", roundId);
        data.put("correct", Math.min(1000, correct));
        data.put("answered", (int) Math.min(1000, answered));
        accountPrefs.edit().putString("pendingRound:" + operationId, new JSONObject(data).toString()).commit();
    }
    private static String roundHash(String value) {
        try {
            byte[] digest = java.security.MessageDigest.getInstance("SHA-256")
                    .digest(value.getBytes(java.nio.charset.StandardCharsets.UTF_8));
            StringBuilder hex = new StringBuilder(64);
            for (byte b : digest) hex.append(String.format(java.util.Locale.ROOT, "%02x", b & 0xff));
            return hex.toString();
        } catch (java.security.NoSuchAlgorithmException impossible) { throw new IllegalStateException(impossible); }
    }
    private static Map.Entry<String, ?> nextPending(SharedPreferences accountPrefs) {
        Map.Entry<String, ?> terminal = null;
        for (Map.Entry<String, ?> entry : accountPrefs.getAll().entrySet()) {
            if (entry.getKey().startsWith("pendingRound:")) return entry;
            if (entry.getKey().startsWith("pending:")) terminal = entry;
        }
        return terminal;
    }
    private static void markPendingComplete(SharedPreferences accountPrefs, String key, Map<String, Object> data) {
        SharedPreferences.Editor editor = accountPrefs.edit().remove(key);
        if (key.startsWith("pendingRound:")) editor.putBoolean("reportedRound:" + data.get("operationId"), true);
        else editor.putBoolean("finished:" + data.get("sessionId"), true);
        editor.commit();
    }
    public static void flush(Context c) {
        String uid = ProgressionAccount.uid(c);
        SharedPreferences accountPrefs = prefs(c);
        Map.Entry<String, ?> entry = nextPending(accountPrefs);
        if (entry == null || !flushingAccounts.add(uid)) return;
        try {
            JSONObject json = new JSONObject(entry.getValue().toString());
            Map<String, Object> data = new HashMap<>(); java.util.Iterator<String> keys = json.keys();
            while (keys.hasNext()) { String key = keys.next(); data.put(key, json.get(key)); }
            request(c, data, (v, error) -> {
                flushingAccounts.remove(uid);
                if (error == null) {
                    markPendingComplete(accountPrefs, entry.getKey(), data);
                    if (uid.equals(ProgressionAccount.uid(c))) flush(c);
                }
            });
        } catch (Exception ignored) { flushingAccounts.remove(uid); }
    }
    private static String identity(Activity a) {
        String id = NativeProgression.matchId(a);
        String room = a.getIntent().getStringExtra("roomId");
        String match = a.getIntent().getStringExtra("economyMatchId");
        if (room != null && !room.isEmpty()) id = "room_" + (match == null || match.isEmpty() ? room : match);
        return "match_" + id.replaceAll("[^A-Za-z0-9_-]", "_");
    }
    private static String errorMessage(Exception error) {
        if (error instanceof com.google.firebase.functions.FirebaseFunctionsException) {
            com.google.firebase.functions.FirebaseFunctionsException.Code code = ((com.google.firebase.functions.FirebaseFunctionsException)error).getCode();
            switch (code) {
                case NOT_FOUND: case UNIMPLEMENTED: return "خدمة الأرصدة غير متاحة حالياً. حاول لاحقاً.";
                case UNAUTHENTICATED: return "سجّل الدخول لحفظ أرصدتك.";
                case UNAVAILABLE: case DEADLINE_EXCEEDED: return "تعذر الاتصال بخدمة الأرصدة. تحقق من الاتصال وحاول مجدداً.";
                case INTERNAL: case UNKNOWN: return "تعذر إتمام العملية حالياً. حاول مجدداً.";
                default: if (error.getMessage() != null) return error.getMessage();
            }
        }
        return "تعذر تحديث الرصيد. تحقق من الاتصال وحاول مجدداً.";
    }
}
