package com.qi7bali.landchallengeonline;

import android.content.Context;
import android.content.SharedPreferences;
import com.google.firebase.auth.FirebaseAuth;
import com.google.firebase.functions.FirebaseFunctions;
import java.util.ArrayList;
import java.util.Collection;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

/** One durable account ledger for every native mode, with an offline upload queue. */
public final class QuestionHistory {
    public static final String EXHAUSTED = "لا توجد أسئلة جديدة كافية لهذه المحاولة. اختر فئات أخرى أو انتظر إضافة أسئلة جديدة.";
    public interface Ready { void run(Set<String> excluded); }
    public interface Failure { void run(Exception error); }
    public interface QuestionsReady { void run(ArrayList<Question> questions); }
    private QuestionHistory() {}

    private static void failed(Failure failure, Exception error) {
        String message = error.getMessage();
        if (message == null || !message.matches("(?s).*[\\u0600-\\u06ff].*"))
            message = "تعذر مزامنة سجل الأسئلة. تحقق من الاتصال وحاول مجددًا.";
        failure.run(new IllegalStateException(message, error));
    }

    private static SharedPreferences preferences(Context context) {
        return context.getSharedPreferences("QuestionHistory_v1_" + ProgressionAccount.uid(context), Context.MODE_PRIVATE);
    }

    public static synchronized Set<String> snapshot(Context context) {
        SharedPreferences p = preferences(context);
        if (!p.getBoolean("savedGamesImported", false)) {
            SharedPreferences migration = context.getSharedPreferences("QuestionHistoryMigration", Context.MODE_PRIVATE);
            String owner = migration.getString("savedGamesOwner", "");
            if (owner.isEmpty()) {
                ProgressionAccount.commitOrRollback(migration, migration.edit().putString("savedGamesOwner", ProgressionAccount.uid(context)));
                owner = ProgressionAccount.uid(context);
            }
            Set<String> merged = new HashSet<>(p.getStringSet("keys", new HashSet<>()));
            Set<String> pending = new HashSet<>(p.getStringSet("pending", new HashSet<>()));
            if (owner.equals(ProgressionAccount.uid(context))) {
                for (String name : new String[]{"OfflineBoardGames", "LocalTeamsBoardGames", "CampaignActiveProgress"}) {
                    for (Object raw : context.getSharedPreferences(name, Context.MODE_PRIVATE).getAll().values()) {
                        if (!(raw instanceof String)) continue;
                        try { collectSavedKeys(new org.json.JSONTokener((String) raw).nextValue(), merged); }
                        catch (org.json.JSONException ignored) { /* Older/incomplete saves may not be JSON. */ }
                    }
                }
                pending.addAll(merged);
            }
            ProgressionAccount.commitOrRollback(p, p.edit().putStringSet("keys", merged)
                    .putStringSet("pending", pending).putBoolean("savedGamesImported", true));
        }
        // A guest's questions follow them into their first account on this device.
        // The ownership claim prevents importing them into unrelated accounts.
        if (!"guest_local".equals(ProgressionAccount.uid(context)) && !p.getBoolean("guestImported", false)) {
            SharedPreferences migration = context.getSharedPreferences("QuestionHistoryMigration", Context.MODE_PRIVATE);
            String owner = migration.getString("guestOwner", "");
            if (owner.isEmpty()) {
                ProgressionAccount.commitOrRollback(migration, migration.edit().putString("guestOwner", ProgressionAccount.uid(context)));
                owner = ProgressionAccount.uid(context);
            }
            Set<String> merged = new HashSet<>(p.getStringSet("keys", new HashSet<>()));
            Set<String> pending = new HashSet<>(p.getStringSet("pending", new HashSet<>()));
            if (owner.equals(ProgressionAccount.uid(context))) {
                Set<String> guest = context.getSharedPreferences("QuestionHistory_v1_guest_local", Context.MODE_PRIVATE)
                        .getStringSet("keys", new HashSet<>());
                merged.addAll(guest);
                pending.addAll(guest);
            }
            ProgressionAccount.commitOrRollback(p, p.edit().putStringSet("keys", merged)
                    .putStringSet("pending", pending).putBoolean("guestImported", true));
        }
        return new HashSet<>(p.getStringSet("keys", new HashSet<>()));
    }

    private static void collectSavedKeys(Object value, Set<String> keys) {
        if (value instanceof org.json.JSONObject) {
            org.json.JSONObject json = (org.json.JSONObject) value;
            if (!json.optString("Q", "").trim().isEmpty()) {
                Question q = new Question(); q.setQ(json.optString("Q")); q.setImg(json.optString("Img", ""));
                org.json.JSONArray path = json.optJSONArray("ClubPath");
                ArrayList<String> clubs = new ArrayList<>();
                if (path != null) for (int i = 0; i < path.length(); i++) clubs.add(path.optString(i));
                q.setClubPath(clubs);
                keys.add(QuestionIdentity.key(q));
            }
            java.util.Iterator<String> names = json.keys();
            while (names.hasNext()) collectSavedKeys(json.opt(names.next()), keys);
        } else if (value instanceof org.json.JSONArray) {
            org.json.JSONArray array = (org.json.JSONArray) value;
            for (int i = 0; i < array.length(); i++) collectSavedKeys(array.opt(i), keys);
        }
    }

    private static boolean connectedAccount(Context context) {
        com.google.firebase.auth.FirebaseUser user = FirebaseAuth.getInstance().getCurrentUser();
        return user != null && !user.isAnonymous() && user.getUid().equals(ProgressionAccount.uid(context));
    }

    private static Map<String, Object> request(String action, String gameId, String roomId) {
        Map<String, Object> data = new HashMap<>();
        data.put("action", action);
        if (roomId != null && !roomId.isEmpty()) data.put("roomId", roomId);
        else if (gameId != null && !gameId.isEmpty()) data.put("gameId", gameId);
        return data;
    }

    public static void prepare(Context context, String gameId, String roomId, Ready ready, Failure failure) {
        final Context app = context.getApplicationContext();
        final String account = ProgressionAccount.uid(app);
        try {
            if (!"guest_local".equals(account) && !connectedAccount(app)) {
                failure.run(new IllegalStateException("تغير حساب اللاعب. أعد تسجيل الدخول.")); return;
            }
            Set<String> local = snapshot(app);
            boolean multiplayer = (gameId != null && !gameId.isEmpty()) || (roomId != null && !roomId.isEmpty());
            if (!connectedAccount(app) || !Data.isNetworkAvailable(app)) {
                if (multiplayer) { failure.run(new IllegalStateException("تعذر مزامنة سجل أسئلة المباراة. تحقق من الاتصال.")); return; }
                if (!"guest_local".equals(account) && !preferences(app).getBoolean("cloudInitialized", false)) {
                    failure.run(new IllegalStateException("اتصل بالإنترنت مرة واحدة لمزامنة سجل أسئلتك قبل اللعب دون اتصال.")); return;
                }
                ready.run(local);
                return;
            }
            ArrayList<String> pending = new ArrayList<>(preferences(app).getStringSet("pending", new HashSet<>()));
            upload(app, account, gameId, roomId, pending, ready, failure);
        } catch (Exception error) { failure.run(error); }
    }

    @SuppressWarnings("unchecked")
    private static void upload(Context app, String account, String gameId, String roomId,
                               ArrayList<String> pending, Ready ready, Failure failure) {
        ArrayList<String> batch = new ArrayList<>(pending.subList(0, Math.min(1000, pending.size())));
        Map<String, Object> data = request("prepare", gameId, roomId);
        data.put("keys", batch);
        FirebaseFunctions.getInstance().getHttpsCallable("questionHistory").call(data)
                .addOnSuccessListener(result -> {
                    try {
                        if (!account.equals(ProgressionAccount.uid(app))) throw new IllegalStateException("تغير حساب اللاعب.");
                        Map<String, Object> response = (Map<String, Object>) result.getData();
                        synchronized (QuestionHistory.class) {
                            SharedPreferences p = preferences(app);
                            Set<String> own = snapshot(app);
                            own.addAll((Collection<String>) response.get("ownKeys"));
                            Set<String> remaining = new HashSet<>(p.getStringSet("pending", new HashSet<>()));
                            remaining.removeAll(batch);
                            ProgressionAccount.commitOrRollback(p, p.edit().putStringSet("keys", own)
                                    .putStringSet("pending", remaining).putBoolean("cloudInitialized", true));
                        }
                        pending.subList(0, batch.size()).clear();
                        if (!pending.isEmpty()) upload(app, account, gameId, roomId, pending, ready, failure);
                        else {
                            Set<String> excluded = snapshot(app);
                            excluded.addAll((Collection<String>) response.get("keys"));
                            ready.run(excluded);
                        }
                    } catch (Exception error) { failure.run(error); }
                }).addOnFailureListener(error -> failed(failure, error));
    }

    public static void reserve(Context context, String gameId, String roomId, Collection<Question> questions,
                               Runnable ready, Failure failure) {
        final Context app = context.getApplicationContext();
        final String account = ProgressionAccount.uid(app);
        if (!"guest_local".equals(account) && !connectedAccount(app)) {
            failure.run(new IllegalStateException("تغير حساب اللاعب. أعد تسجيل الدخول.")); return;
        }
        final ArrayList<String> keys = new ArrayList<>();
        for (Question q : questions) if (q != null) keys.add(QuestionIdentity.key(q));
        if (keys.isEmpty() || new HashSet<>(keys).size() != keys.size()) {
            failure.run(new IllegalStateException(EXHAUSTED)); return;
        }
        Runnable complete = () -> {
            try {
                if (!account.equals(ProgressionAccount.uid(app))) throw new IllegalStateException("تغير حساب اللاعب.");
                synchronized (QuestionHistory.class) {
                    Set<String> current = snapshot(app);
                    for (String key : keys) if (current.contains(key))
                        throw new IllegalStateException("تغير سجل الأسئلة. أعد المحاولة لاختيار أسئلة جديدة.");
                    remember(app, keys);
                }
                ready.run();
            } catch (Exception error) { failure.run(error); }
        };
        boolean multiplayer = (gameId != null && !gameId.isEmpty()) || (roomId != null && !roomId.isEmpty());
        if (!connectedAccount(app) || !Data.isNetworkAvailable(app)) {
            if (multiplayer) {
                failure.run(new IllegalStateException("تعذر حجز أسئلة المباراة. تحقق من الاتصال.")); return;
            }
            complete.run();
            return;
        }
        if (!multiplayer) {
            complete.run();
            Map<String, Object> data = request("reserve", gameId, roomId);
            data.put("keys", keys);
            data.put("operationId", UUID.randomUUID().toString());
            FirebaseFunctions.getInstance().getHttpsCallable("questionHistory").call(data)
                    .addOnSuccessListener(result -> {
                        synchronized (QuestionHistory.class) {
                            SharedPreferences p = preferences(app);
                            Set<String> pending = new HashSet<>(p.getStringSet("pending", new HashSet<>()));
                            pending.removeAll(keys);
                            ProgressionAccount.commitOrRollback(p, p.edit().putStringSet("pending", pending));
                        }
                    });
            return;
        }
        Map<String, Object> data = request("reserve", gameId, roomId);
        data.put("keys", keys);
        data.put("operationId", UUID.randomUUID().toString());
        FirebaseFunctions.getInstance().getHttpsCallable("questionHistory").call(data)
                .addOnSuccessListener(result -> complete.run()).addOnFailureListener(error -> failed(failure, error));
    }

    public static void record(Context context, Question question) {
        if (question != null) remember(context, java.util.Collections.singleton(QuestionIdentity.key(question)));
    }

    public static void recordAll(Context context, Collection<Question> questions) {
        ArrayList<String> keys = new ArrayList<>();
        for (Question q : questions) if (q != null) keys.add(QuestionIdentity.key(q));
        remember(context, keys);
    }

    public static void admitRoom(Context context, String roomId, Runnable ready, Failure failure) {
        final String account = ProgressionAccount.uid(context);
        prepare(context, "", "", excluded -> FirebaseFunctions.getInstance().getHttpsCallable("questionHistory")
                .call(request("admit", "", roomId)).addOnSuccessListener(result -> {
                    if (!account.equals(ProgressionAccount.uid(context))) { failure.run(new IllegalStateException("تغير حساب اللاعب.")); return; }
                    ready.run();
                }).addOnFailureListener(error -> failed(failure, error)), failure);
    }

    public static void registerRoom(Context context, String roomId, Runnable ready, Failure failure) {
        final String account = ProgressionAccount.uid(context);
        // Register only after every pending offline batch has been uploaded.
        prepare(context, "", "", excluded -> FirebaseFunctions.getInstance().getHttpsCallable("questionHistory")
                .call(request("ready", "", roomId)).addOnSuccessListener(result -> {
                    if (!account.equals(ProgressionAccount.uid(context))) { failure.run(new IllegalStateException("تغير حساب اللاعب.")); return; }
                    ready.run();
                }).addOnFailureListener(error -> failed(failure, error)), failure);
    }

    @SuppressWarnings("unchecked")
    public static void allocateClassic(Context context, String gameId, String roomId, QuestionsReady ready, Failure failure) {
        final Context app = context.getApplicationContext();
        final String account = ProgressionAccount.uid(app);
        Runnable allocate = () -> requestClassic(app, account, gameId, roomId, ready, failure, 30);
        if (roomId != null && !roomId.isEmpty()) registerRoom(app, roomId, allocate, failure);
        else prepare(app, gameId, "", excluded -> allocate.run(), failure);
    }

    @SuppressWarnings("unchecked")
    private static void requestClassic(Context app, String account, String gameId, String roomId,
                                       QuestionsReady ready, Failure failure, int retries) {
        if (!account.equals(ProgressionAccount.uid(app))) { failure.run(new IllegalStateException("تغير حساب اللاعب.")); return; }
            Map<String, Object> data = request("allocate", gameId, roomId);
            data.put("operationId", UUID.nameUUIDFromBytes(("classic|" + gameId).getBytes(java.nio.charset.StandardCharsets.UTF_8)).toString());
            FirebaseFunctions.getInstance().getHttpsCallable("questionHistory").call(data)
                    .addOnSuccessListener(result -> {
                        try {
                            if (!account.equals(ProgressionAccount.uid(app))) throw new IllegalStateException("تغير حساب اللاعب.");
                            Map<String, Object> response = (Map<String, Object>) result.getData();
                            if (Boolean.TRUE.equals(response.get("waiting"))) {
                                if (retries <= 0) { failure.run(new IllegalStateException("بانتظار مزامنة أسئلة جميع اللاعبين. حاول مجددًا بعد جاهزيتهم.")); return; }
                                new android.os.Handler(android.os.Looper.getMainLooper()).postDelayed(() ->
                                        requestClassic(app, account, gameId, roomId, ready, failure, retries - 1), 400);
                                return;
                            }
                            ArrayList<Question> selected = new ArrayList<>();
                            for (Map<String, Object> item : (Collection<Map<String, Object>>) response.get("questions")) {
                                Question q = new Question();
                                q.setQ((String) item.get("text"));
                                q.setCategory((String) item.get("category"));
                                q.setLevel(String.valueOf(item.get("level")));
                                q.setImg((String) item.getOrDefault("img", ""));
                                q.setClubPath(new ArrayList<>((Collection<String>) item.getOrDefault("clubPath", new ArrayList<String>())));
                                java.util.List<String> answers = (java.util.List<String>) item.get("answers");
                                q.setR(answers.get(0)); q.setW1(answers.get(1)); q.setW2(answers.get(2)); q.setW3(answers.get(3));
                                selected.add(q);
                            }
                            ArrayList<String> keys = new ArrayList<>();
                            for (Question q : selected) keys.add(QuestionIdentity.key(q));
                            remember(app, keys);
                            ready.run(selected);
                        } catch (Exception error) { failure.run(error); }
                    }).addOnFailureListener(error -> failed(failure, error));
    }

    private static synchronized void remember(Context context, Collection<String> keys) {
        SharedPreferences p = preferences(context);
        Set<String> all = snapshot(context);
        Set<String> pending = new HashSet<>(p.getStringSet("pending", new HashSet<>()));
        int previousSize = all.size();
        for (String key : keys) if (all.add(key)) pending.add(key);
        if (all.size() == previousSize) return;
        ProgressionAccount.commitOrRollback(p, p.edit().putStringSet("keys", all).putStringSet("pending", pending));
    }
}
