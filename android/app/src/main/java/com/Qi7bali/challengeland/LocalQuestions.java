package com.qi7bali.landchallengeonline;

import android.content.Context;
import android.content.res.AssetManager;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.Random;

import io.flutter.FlutterInjector;

public class LocalQuestions {

    /** Category used for questions that have no (or an empty) Category field.
     *  Must match a file name under assets/categories (منوعات.png). */
    public static final String FALLBACK_CATEGORY = "منوعات";
    public static ArrayList<Question> load(Context context) {
        final ArrayList<Question> questions = new ArrayList<>();
        final ArrayList<Question> allQuestions0 = new ArrayList<>();
        final ArrayList<Question> allQuestions1 = new ArrayList<>();
        final ArrayList<Question> allQuestions2 = new ArrayList<>();
        final ArrayList<Question> allQuestions3 = new ArrayList<>();
        try {
            AssetManager assets = context.getAssets();
            InputStream inputStream = openQuestionsStream(assets);
            ByteArrayOutputStream output = new ByteArrayOutputStream();
            byte[] buffer = new byte[4096];
            int n;
            while ((n = inputStream.read(buffer)) >= 0) {
                output.write(buffer, 0, n);
            }
            inputStream.close();

            JSONArray array = new JSONArray(output.toString(StandardCharsets.UTF_8.name()));
            for (int i = 0; i < array.length(); i++) {
                JSONObject item = array.getJSONObject(i);
                Question q = parseQuestion(item);
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
        } catch (Exception ignored) {
        }
        return questions;
    }

    public static ArrayList<Question> loadAll(Context context) {
        final ArrayList<Question> questions = new ArrayList<>();
        try {
            AssetManager assets = context.getAssets();
            InputStream inputStream = openQuestionsStream(assets);
            ByteArrayOutputStream output = new ByteArrayOutputStream();
            byte[] buffer = new byte[4096];
            int n;
            while ((n = inputStream.read(buffer)) >= 0) {
                output.write(buffer, 0, n);
            }
            inputStream.close();

            JSONArray array = new JSONArray(output.toString(StandardCharsets.UTF_8.name()));
            for (int i = 0; i < array.length(); i++) {
                JSONObject item = array.getJSONObject(i);
                questions.add(parseQuestion(item));
            }
        } catch (Exception ignored) {
        }
        return questions;
    }

    /** Parses a single question record, defaulting Category to the fallback bucket. */
    private static Question parseQuestion(JSONObject item) {
        Question q = new Question();
        q.setQ(item.optString("Q"));
        q.setR(item.optString("R"));
        q.setW1(item.optString("W1"));
        q.setW2(item.optString("W2"));
        q.setW3(item.optString("W3"));
        q.setLevel(item.optString("Level"));
        String category = item.optString("Category", FALLBACK_CATEGORY);
        if (category == null || category.trim().isEmpty()) {
            category = FALLBACK_CATEGORY;
        }
        q.setCategory(category.trim());
        return q;
    }

    /**
     * Maps a difficulty Level ("0".."8") to one of three board tiers:
     * 0 = easy (value 200), 1 = medium (value 400), 2 = hard (value 600).
     * The split is not a plain range: level 3 sits in the hard tier while 4 & 5
     * stay medium (per the configured difficulty distribution).
     *   200 -> levels 0, 1
     *   400 -> levels 2, 4, 5
     *   600 -> levels 3, 6, 7, 8
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
                return 0; // 200 (easy)
            case 2:
            case 4:
            case 5:
                return 1; // 400 (medium)
            default:
                return 2; // 600 (hard): levels 3, 6, 7, 8 (and any out-of-range)
        }
    }

    /**
     * Loads every question grouped by Category and then by board tier, for the
     * offline board ("التحدي") mode. The returned map preserves first-seen
     * category order; each value is a 3-element list indexed by tier
     * (0=easy/25, 1=medium/50, 2=hard/75).
     */
    public static LinkedHashMap<String, ArrayList<ArrayList<Question>>> loadBoardPool(Context context) {
        final LinkedHashMap<String, ArrayList<ArrayList<Question>>> pool = new LinkedHashMap<>();
        try {
            AssetManager assets = context.getAssets();
            InputStream inputStream = openQuestionsStream(assets);
            ByteArrayOutputStream output = new ByteArrayOutputStream();
            byte[] buffer = new byte[4096];
            int n;
            while ((n = inputStream.read(buffer)) >= 0) {
                output.write(buffer, 0, n);
            }
            inputStream.close();

            JSONArray array = new JSONArray(output.toString(StandardCharsets.UTF_8.name()));
            for (int i = 0; i < array.length(); i++) {
                Question q = parseQuestion(array.getJSONObject(i));
                String category = q.getCategory();
                ArrayList<ArrayList<Question>> tiers = pool.get(category);
                if (tiers == null) {
                    tiers = new ArrayList<>();
                    tiers.add(new ArrayList<Question>());
                    tiers.add(new ArrayList<Question>());
                    tiers.add(new ArrayList<Question>());
                    pool.put(category, tiers);
                }
                tiers.get(tierForLevel(q.getLevel())).add(q);
            }
        } catch (Exception ignored) {
        }
        return pool;
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
        try {
            String flutterAssetPath = FlutterInjector.instance()
                    .flutterLoader()
                    .getLookupKeyForAsset("assets/questions.json");
            return assets.open(flutterAssetPath);
        } catch (Exception ignored) {
            return assets.open("questions.json");
        }
    }
}
