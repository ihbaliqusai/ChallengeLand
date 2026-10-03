package com.qi7bali.landchallengeonline;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.LinkedHashMap;

/** Run with javac/java; no Android runtime or downloaded test dependencies needed. */
public final class CampaignBoardRulesCheck {
    public static void main(String[] args) {
        verifyScoreCeilings();
        verifyPlayerStatistics();
        verifyStars();
        verifyBotFairness();
        verifyDifficultyPool();
        verifyRelativeCellRisk();
        verifyCategoryAccess();
        System.out.println("Campaign board regression checks passed");
    }

    private static void verifyCategoryAccess() {
        LinkedHashMap<String, ArrayList<ArrayList<Question>>> eligible = new LinkedHashMap<>();
        for (String category : Arrays.asList("general", "nature", "capitals", "movies", "الأنمي")) {
            eligible.put(category, emptyTiers());
        }
        java.util.Set<String> unlocked = new java.util.HashSet<>(Arrays.asList("general", "nature", "capitals"));
        LinkedHashMap<String, ArrayList<ArrayList<Question>>> accessible =
                CampaignBoardRules.accessiblePool(eligible, unlocked::contains);
        equal(3, accessible.size(), "locked categories cannot enter the question pool");
        equal(5, eligible.size(), "locked tiles stay available to the existing purchase picker");
        for (int seed = 0; seed < 20; seed++) {
            ArrayList<String> themed = CampaignBoardRules.pickCategories(new ArrayList<>(accessible.keySet()),
                    Arrays.asList("movies", "الأنمي", "nature"), 3, new java.util.Random(seed));
            equal(3, themed.size(), "curated and boss boards top up with unlocked categories");
            if (!themed.get(0).equals("nature") || !unlocked.containsAll(themed)) {
                throw new AssertionError("themed auto-picks must respect unlocked ownership");
            }
            ArrayList<String> random = CampaignBoardRules.pickCategories(new ArrayList<>(accessible.keySet()),
                    null, 3, new java.util.Random(seed));
            if (!unlocked.containsAll(random)) throw new AssertionError("random auto-picks must never choose a locked category");
        }
        ArrayList<String> fallback = CampaignBoardRules.pickCategories(new ArrayList<>(accessible.keySet()),
                Arrays.asList("movies", "الأنمي"), 3, new java.util.Random(0));
        if (!unlocked.containsAll(fallback)) throw new AssertionError("empty unlocked theme must fall back to unlocked categories");
        ArrayList<String> savedBoard = new ArrayList<>(Arrays.asList("general", "nature", "capitals"));
        if (!CampaignBoardRules.canUseCategories(savedBoard, 3, accessible)) throw new AssertionError("owned board can resume");
        unlocked.remove("nature");
        accessible = CampaignBoardRules.accessiblePool(eligible, unlocked::contains);
        if (CampaignBoardRules.canUseCategories(savedBoard, 3, accessible)) throw new AssertionError("expired category must block resume and confirmation");
        equal(2, CampaignBoardRules.pickCategories(new ArrayList<>(accessible.keySet()), null, 3, new java.util.Random(0)).size(),
                "insufficient unlocked categories must not be padded with locked ones");
        if (CampaignBoardRules.canUseCategories(Arrays.asList("general", "movies"), 2, accessible)) throw new AssertionError("direct board creation cannot bypass a lock");
        if (CampaignBoardRules.canUseCategories(Arrays.asList("general", "general"), 2, accessible)) throw new AssertionError("duplicate choices cannot fill missing columns");
        if (CampaignBoardRules.canUseCategories(new ArrayList<>(), 0, accessible)) throw new AssertionError("malformed empty resume is rejected");
        if (!CategoryConfig.normalize("أنمي").equals(CategoryConfig.normalize("الأنمي"))) throw new AssertionError("anime purchase aliases must match");
        if (!CategoryConfig.isPremium("أنمي") || !CategoryConfig.isPremium("الأنمي")) throw new AssertionError("anime aliases must stay locked without ownership");
        if (!CategoryConfig.normalize("الانمي").equals(CategoryConfig.normalize("أنمي"))) throw new AssertionError("old rental keys must match the purchased alias");
        if (!"الأنمي".equals(CampaignBoardRules.resolveCategory("أنمي", Arrays.asList("الأنمي")))) throw new AssertionError("saved anime alias must resolve to the board category");
        if (CampaignBoardRules.resolveCategory("أنمي", Arrays.asList("general")) != null) throw new AssertionError("an alias cannot resolve to an inaccessible category");
    }

    private static void verifyBotFairness() {
        for (int value : new int[]{200, 400, 600}) {
            equal(value / 2, CampaignBoardRules.botAwardValue(value, true, true), "campaign boss pays for options");
            equal(value, CampaignBoardRules.botAwardValue(value, false, true), "other board modes retain their scoring");
            equal(value, CampaignBoardRules.botAwardValue(value, true, false), "unrevealed recall has full value");
        }
        for (int skill : new int[]{64, 80, 95}) {
            int previous = 100;
            for (String level : Arrays.asList("0", "1", "2", "4", "5", "6", "7", "8", "3")) {
                int chance = CampaignBoardRules.campaignBotCorrectChance(level, skill);
                if (chance > previous) throw new AssertionError("boss accuracy must fall with semantic difficulty");
                previous = chance;
            }
        }
    }

    private static void verifyScoreCeilings() {
        equal(3000, CampaignBoardRules.maximumScore(4, 5), "five-question mission");
        equal(3600, CampaignBoardRules.maximumScore(4, 6), "standard mission");
        equal(4200, CampaignBoardRules.maximumScore(4, 7), "seven-question mission");
        equal(3200, CampaignBoardRules.maximumScore(2, 6), "first boss has only four 600-point cells");
        equal(3600, CampaignBoardRules.maximumScore(3, 6), "second boss");
        equal(2400, CampaignBoardRules.maximumScore(1, 6), "single-category board");
        equal(2400, CampaignBoardRules.maximumScore(1, 99), "picks cannot exceed available cells");
        equal(0, CampaignBoardRules.maximumScore(0, 6), "empty board");
        equal(0, CampaignBoardRules.maximumScore(4, -1), "negative picks");
    }

    private static void verifyPlayerStatistics() {
        for (int count = 1; count <= 8; count++) {
            equal(6, CampaignBoardRules.playerTurns(count * 6, count), "boss errors exclude rivals' turns");
            equal(1, CampaignBoardRules.playerTurns(1, count), "human starts the round");
            equal(0, CampaignBoardRules.playerTurns(0, count), "no completed question");
        }
        equal(3, CampaignBoardRules.playerTurns(9, 4), "partial-round recovery");
    }

    private static void verifyStars() {
        equal(0, CampaignBoardRules.earnedStars(499, 500, 625, 775), "below pass target");
        equal(1, CampaignBoardRules.earnedStars(500, 500, 625, 775), "pass boundary");
        equal(2, CampaignBoardRules.earnedStars(625, 500, 625, 775), "second star boundary");
        equal(3, CampaignBoardRules.earnedStars(775, 500, 625, 775), "third star boundary");
        equal(3, CampaignBoardRules.earnedStars(3400, 2700, 3000, 3400), "clamped late-world stars");
    }

    private static void verifyDifficultyPool() {
        LinkedHashMap<String, ArrayList<ArrayList<Question>>> original = new LinkedHashMap<>();
        ArrayList<ArrayList<Question>> general = emptyTiers();
        for (int i = 0; i < 6; i++) general.get(0).add(question(i % 2 == 0 ? "0" : "1"));
        general.get(1).add(question("4"));
        general.get(2).add(question("8"));
        original.put("general", general);
        ArrayList<ArrayList<Question>> shortCategory = emptyTiers();
        for (int i = 0; i < 5; i++) shortCategory.get(0).add(question("0"));
        original.put("short", shortCategory);

        LinkedHashMap<String, ArrayList<ArrayList<Question>>> firstWorld =
                CampaignBoardRules.filterPool(original, Arrays.asList("0", " 1 ", null));
        equal(1, firstWorld.size(), "short categories cannot borrow unrelated questions");
        equal(3, firstWorld.get("general").get(0).size(), "lower world level has low-value cells");
        equal(6, firstWorld.get("general").get(1).size(), "middle values mix the two permitted levels");
        equal(3, firstWorld.get("general").get(2).size(), "upper world level has high-value cells");
        equal(1, original.get("general").get(2).size(), "shared pool remains unchanged");
        firstWorld.get("general").get(0).clear();
        equal(6, original.get("general").get(0).size(), "campaign buckets are independent");
        equal(0, CampaignBoardRules.filterPool(original, Arrays.asList("99")).size(), "unknown level never broadens difficulty");
        equal(1, CampaignBoardRules.filterPool(original, new ArrayList<>()).size(), "legacy empty filter allows full pool");
    }

    private static void verifyRelativeCellRisk() {
        for (java.util.List<String> levels : Arrays.asList(Arrays.asList("6", "7"), Arrays.asList("3", "8"))) {
            LinkedHashMap<String, ArrayList<ArrayList<Question>>> original = new LinkedHashMap<>();
            ArrayList<ArrayList<Question>> source = emptyTiers();
            for (String level : levels) {
                for (int i = 0; i < 6; i++) source.get(2).add(question(level));
            }
            original.put("late-world", source);
            ArrayList<ArrayList<Question>> relative = CampaignBoardRules.filterPool(original, levels).get("late-world");
            String lower = levels.contains("3") ? "8" : "6";
            String upper = levels.contains("3") ? "3" : "7";
            equal(6, relative.get(0).size(), "low-value question count");
            equal(12, relative.get(1).size(), "middle cells mix both levels");
            equal(6, relative.get(2).size(), "high-value question count");
            for (Question question : relative.get(0)) {
                if (!lower.equals(question.getLevel())) throw new AssertionError("low-value cell must have lower relative difficulty");
            }
            for (Question question : relative.get(2)) {
                if (!upper.equals(question.getLevel())) throw new AssertionError("high-value cell must have higher relative difficulty");
            }
            if (!relative.get(1).contains(relative.get(0).get(0))) {
                throw new AssertionError("mixed tier must share identity so a question cannot be picked twice");
            }
            ArrayList<ArrayList<Question>> oneBand = emptyTiers();
            for (int i = 0; i < 12; i++) oneBand.get(2).add(question(upper));
            original.put("missing-lower-band", oneBand);
            equal(1, CampaignBoardRules.filterPool(original, levels).size(), "categories need both low and high questions");
        }
    }

    private static ArrayList<ArrayList<Question>> emptyTiers() {
        ArrayList<ArrayList<Question>> tiers = new ArrayList<>();
        for (int i = 0; i < 3; i++) tiers.add(new ArrayList<>());
        return tiers;
    }

    private static Question question(String level) {
        Question question = new Question();
        question.setLevel(level);
        return question;
    }

    private static void equal(int expected, int actual, String reason) {
        if (expected != actual) throw new AssertionError(reason + ": expected " + expected + ", got " + actual);
    }
}
