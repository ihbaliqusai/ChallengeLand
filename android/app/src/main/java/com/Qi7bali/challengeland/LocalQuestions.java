package com.qi7bali.landchallengeonline;

import android.content.Context;
import android.content.res.AssetManager;
import android.util.JsonReader;
import android.util.JsonToken;
import android.util.Log;

import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.Random;

import io.flutter.FlutterInjector;

public class LocalQuestions {
    private static volatile ArrayList<Question> cachedQuestions;
    private static volatile LinkedHashMap<String, ArrayList<ArrayList<Question>>> cachedBoardPool;
    private static final java.util.concurrent.ExecutorService LOADER =
            java.util.concurrent.Executors.newSingleThreadExecutor();

    public static boolean isPrepared() {
        return cachedQuestions != null && cachedBoardPool != null;
    }

    public static void preload(Context context, Runnable ready) {
        if (isPrepared()) {
            if (ready != null) {
                if (android.os.Looper.myLooper() == android.os.Looper.getMainLooper()) ready.run();
                else new android.os.Handler(android.os.Looper.getMainLooper()).post(ready);
            }
            return;
        }
        Context app = context.getApplicationContext();
        LOADER.execute(() -> {
            android.os.Process.setThreadPriority(android.os.Process.THREAD_PRIORITY_BACKGROUND);
            long started = android.os.SystemClock.elapsedRealtime();
            int count = loadAll(app).size();
            loadBoardPool(app);
            Log.d("LocalQuestions", "Preloaded " + count + " questions and board pool in "
                    + (android.os.SystemClock.elapsedRealtime() - started) + "ms off the UI thread");
            if (ready != null) {
                new android.os.Handler(android.os.Looper.getMainLooper()).post(ready);
            }
        });
    }

    /** Category used for questions that have no (or an empty) Category field.
     *  Must match a file name under assets/categories (منوعات.png). */
    public static final String FALLBACK_CATEGORY = "منوعات";

    /**
     * Categories temporarily hidden from gameplay until more content is added.
     */
    public static boolean isCategoryHidden(String category) {
        if (category == null) return false;
        String trimmed = category.trim();
        return trimmed.equals("دقة ملاحظة") || trimmed.equals("دقه ملاحظه");
    }

    public static ArrayList<Question> load(Context context) {
        return load(context, QuestionHistory.snapshot(context));
    }

    static ArrayList<Question> load(Context context, java.util.Set<String> excluded) {
        final ArrayList<Question> questions = new ArrayList<>();
        final ArrayList<Question> allQuestions0 = new ArrayList<>();
        final ArrayList<Question> allQuestions1 = new ArrayList<>();
        final ArrayList<Question> allQuestions2 = new ArrayList<>();
        final ArrayList<Question> allQuestions3 = new ArrayList<>();
        try {
            for (Question q : QuestionSelection.unseen(loadAll(context), excluded, new Random())) {
                if (isCategoryHidden(q.getCategory())) {
                    continue;
                }
                switch (q.getLevel()) {
                    case "0":
                        allQuestions0.add(q);
                        break;
                    case "1":
                        allQuestions1.add(q);
                        break;
                    case "2":
                        allQuestions2.add(q);
                        break;
                    case "3":
                        allQuestions3.add(q);
                        break;
                }
            }
            populate(questions, allQuestions0, 3);
            populate(questions, allQuestions1, 3);
            populate(questions, allQuestions2, 5);
            populate(questions, allQuestions3, 39);
            // Never launch a shortened classic ladder after a difficulty band
            // is depleted; that can make its fixed win conditions unreachable.
            if (questions.size() < 50) questions.clear();
        } catch (Exception ignored) {
        }
        return questions;
    }

    public static ArrayList<Question> loadAll(Context context) {
        ArrayList<Question> cached = cachedQuestions;
        if (cached != null) return cached;
        synchronized (LocalQuestions.class) {
            if (cachedQuestions != null) return cachedQuestions;
            final ArrayList<Question> questions = new ArrayList<>(21200);
            try (InputStream inputStream = openQuestionsStream(context.getAssets());
                 InputStreamReader isr = new InputStreamReader(inputStream, StandardCharsets.UTF_8);
                 JsonReader reader = new JsonReader(isr)) {
                reader.beginArray();
                while (reader.hasNext()) {
                    Question q = readQuestion(reader);
                    if (!isCategoryHidden(q.getCategory())) {
                        questions.add(q);
                    }
                }
                reader.endArray();
            } catch (Exception e) {
                Log.e("LocalQuestions", "Failed to stream questions.json", e);
            }
            if (!questions.isEmpty()) {
                questions.trimToSize();
                cachedQuestions = questions;
            }
            return questions;
        }
    }

    /** Parses a single question record streaming tokens directly without intermediate JSON objects. */
    private static Question readQuestion(JsonReader reader) throws java.io.IOException {
        Question q = new Question();
        String qText = "";
        String r = "";
        String w1 = "";
        String w2 = "";
        String w3 = "";
        String level = "";
        String img = "";
        String category = FALLBACK_CATEGORY;
        ArrayList<String> clubPath = null;

        reader.beginObject();
        while (reader.hasNext()) {
            String name = reader.nextName();
            if (reader.peek() == JsonToken.NULL) {
                reader.nextNull();
                continue;
            }
            switch (name) {
                case "Q":
                    qText = reader.nextString();
                    break;
                case "R":
                    r = reader.nextString();
                    break;
                case "W1":
                    w1 = reader.nextString();
                    break;
                case "W2":
                    w2 = reader.nextString();
                    break;
                case "W3":
                    w3 = reader.nextString();
                    break;
                case "Level":
                    level = reader.nextString();
                    break;
                case "Img":
                    img = reader.nextString();
                    break;
                case "Category":
                    String cat = reader.nextString();
                    if (cat != null && !cat.trim().isEmpty()) {
                        category = cat.trim();
                    }
                    break;
                case "ClubPath":
                    if (reader.peek() == JsonToken.BEGIN_ARRAY) {
                        reader.beginArray();
                        clubPath = new ArrayList<>();
                        while (reader.hasNext()) {
                            if (reader.peek() == JsonToken.STRING) {
                                String club = reader.nextString().trim();
                                if (!club.isEmpty()) {
                                    clubPath.add(club);
                                }
                            } else {
                                reader.skipValue();
                            }
                        }
                        reader.endArray();
                    } else {
                        reader.skipValue();
                    }
                    break;
                default:
                    reader.skipValue();
                    break;
            }
        }
        reader.endObject();

        q.setQ(qText);
        q.setR(r);
        q.setW1(w1);
        q.setW2(w2);
        q.setW3(w3);
        q.setLevel(level);
        q.setImg(img == null ? "" : img);
        q.setCategory(category);
        if (clubPath != null) {
            q.setClubPath(clubPath);
        }
        return q;
    }

    /**
     * Maps a difficulty Level ("0".."8") to one of three board tiers:
     * 0 = easy (value 200), 1 = medium (value 400), 2 = hard (value 600).
     * Follows the standardized difficulty distribution:
     *   200 (easy)   -> levels "0", "1", "2"
     *   400 (medium) -> levels "4", "5", "6"
     *   600 (hard)   -> levels "3", "7", "8"
     */
    public static int tierForLevel(String level) {
        int lv;
        try {
            lv = Integer.parseInt(level == null ? "0" : level.trim());
        } catch (Exception e) {
            lv = 0;
        }
        switch (lv) {
            case 0:
            case 1:
            case 2:
                return 0; // 200 (easy)
            case 4:
            case 5:
            case 6:
                return 1; // 400 (medium)
            default:
                return 2; // 600 (hard): levels 3, 7, 8 (and any out-of-range)
        }
    }

    /**
     * Loads every question grouped by Category and then by board tier, for the
     * offline board ("التحدي") mode. The returned map preserves first-seen
     * category order; each value is a 3-element list indexed by tier
     * (0=easy/25, 1=medium/50, 2=hard/75).
     */
    public static LinkedHashMap<String, ArrayList<ArrayList<Question>>> loadBoardPool(Context context) {
        LinkedHashMap<String, ArrayList<ArrayList<Question>>> cached = cachedBoardPool;
        if (cached != null) return cached;
        synchronized (LocalQuestions.class) {
            if (cachedBoardPool != null) return cachedBoardPool;
            final LinkedHashMap<String, ArrayList<ArrayList<Question>>> pool = new LinkedHashMap<>();
            try {
                for (Question q : loadAll(context)) {
                    if (isCategoryHidden(q.getCategory())) {
                        continue;
                    }
                    String category = q.getCategory();
                    ArrayList<ArrayList<Question>> tiers = pool.get(category);
                    if (tiers == null) {
                        tiers = new ArrayList<>(3);
                        tiers.add(new ArrayList<Question>());
                        tiers.add(new ArrayList<Question>());
                        tiers.add(new ArrayList<Question>());
                        pool.put(category, tiers);
                    }
                    tiers.get(tierForLevel(q.getLevel())).add(q);
                }
            } catch (Exception ignored) {
            }
            if (!pool.isEmpty()) {
                cachedBoardPool = pool;
            }
            return pool;
        }
    }

    private static void populate(ArrayList<Question> questions, ArrayList<Question> subList, int count) {
        if (subList.isEmpty()) return;
        ArrayList<Integer> used = new ArrayList<>();
        Random random = new Random();
        for (int i = 0; i < count && used.size() < subList.size(); i++) {
            int idx;
            do {
                idx = random.nextInt(subList.size());
            } while (used.contains(idx));
            used.add(idx);
            questions.add(subList.get(idx));
        }
    }

    private static InputStream openQuestionsStream(AssetManager assets) throws Exception {
        String flutterAssetPath = FlutterInjector.instance()
                .flutterLoader()
                .getLookupKeyForAsset("assets/questions.json");
        return assets.open(flutterAssetPath);
    }
}
