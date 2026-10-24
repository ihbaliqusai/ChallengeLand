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
        verifyStageChallenges();
        verifyBossStyles();
        verifyBossPacing();
        verifyCampaignDialogue();
        verifyStageBriefing();
        System.out.println("Campaign board regression checks passed");
    }

    private static void verifyStageBriefing() {
        String standard = String.join("\n", CampaignBoardRules.briefingMessages(false, 6, 1,
                "playerPick", 0, 0, 0, Arrays.asList("علوم"), "balanced", true, 1600, 2000));
        if (!standard.contains("اختر فئة واحدة") || !standard.contains("6 أسئلة")
                || !standard.contains("نصف النقاط") || !standard.contains("2000 لثلاث نجوم"))
            throw new AssertionError("presenter must explain picks, scoring and stars");
        if (standard.contains("ثانية") || standard.contains("أخطاء") || standard.contains("للفوز،"))
            throw new AssertionError("disabled constraints must not be announced");
        String challenge = String.join("\n", CampaignBoardRules.briefingMessages(true, 6, 3,
                "worldThemed", 150, 2, 2, Arrays.asList("علوم", "تاريخ"), "speed", false, 1800, 2400));
        for (String detail : Arrays.asList("سأختار لك 3 فئات", "150 ثانية", "2 أخطاء",
                "الخطأ التالي", "2 فئات مختلفة", "علوم، تاريخ", "غير متاح", "30 ثانية")) {
            if (!challenge.contains(detail)) throw new AssertionError("missing stage rule: " + detail);
        }
        String[] styles = {"specialist", "highValue", "mixed"};
        String[] descriptions = {"دقة أعلى", "الأعلى قيمة", "متخصصين وسريعين"};
        for (int i = 0; i < styles.length; i++) {
            String boss = String.join("\n", CampaignBoardRules.briefingMessages(true, 6, 3,
                    "random", 0, 0, 0, Arrays.asList(), styles[i], true, 0, 0));
            if (!boss.contains(descriptions[i])) throw new AssertionError("missing boss style " + styles[i]);
        }
    }

    private static void verifyBossPacing() {
        java.util.Set<Integer> delays = new java.util.HashSet<>();
        for (int seed = 0; seed < 200; seed++) {
            int normal = CampaignBoardRules.bossThinkTimeMs("1", "سؤال قصير", "balanced", false, new java.util.Random(seed));
            int speed = CampaignBoardRules.bossThinkTimeMs("1", "سؤال قصير", "speed", false, new java.util.Random(seed));
            int expert = CampaignBoardRules.bossThinkTimeMs("1", "سؤال قصير", "specialist", true, new java.util.Random(seed));
            int hard = CampaignBoardRules.bossThinkTimeMs("8", "سؤال أطول يحتاج إلى قراءة وتركيز", "balanced", false, new java.util.Random(seed));
            int unknown = CampaignBoardRules.bossThinkTimeMs(null, null, "unknown", false, new java.util.Random(seed));
            if (speed < 1800 || normal > 8000 || hard > 8000 || unknown < 1800)
                throw new AssertionError("boss timing must leave reading time and stay bounded");
            if (speed >= normal || expert >= normal || hard <= normal)
                throw new AssertionError("style, specialty and question complexity must affect thinking time");
            delays.add(normal);
        }
        if (delays.size() < 20) throw new AssertionError("bosses must not use a fixed response time");
    }

    private static void verifyCampaignDialogue() {
        String first = CampaignBoardRules.openingMessage(1, false, 1200, "stage", false);
        String next = CampaignBoardRules.openingMessage(2, false, 1400, "next", false);
        String retry = CampaignBoardRules.openingMessage(2, false, 1400, "retry", false);
        String boss = CampaignBoardRules.openingMessage(10, true, 0, "next", false);
        String resume = CampaignBoardRules.openingMessage(10, true, 0, "next", true);
        if (!first.contains("أهلاً") || !next.contains("المرحلة 2") || !next.contains("1400"))
            throw new AssertionError("opening must identify the stage and its objective");
        if (next.contains("أهلاً") || retry.contains("أهلاً") || !retry.contains("محاولة جديدة"))
            throw new AssertionError("continuing and retrying must not restart the welcome");
        if (!boss.contains("الزعماء") || !resume.contains("حيث توقفنا") || resume.contains("ننتقل"))
            throw new AssertionError("boss and resume dialogue must match the current situation");
    }

    private static void verifyStageChallenges() {
        if (!CampaignBoardRules.constraintFailure(2, 2, 2, 2, 1000, 999).isEmpty())
            throw new AssertionError("the allowed error count and category goal must pass");
        if (!"eliminated".equals(CampaignBoardRules.constraintFailure(3, 2, 2, 2, 0, 0)))
            throw new AssertionError("the next error must fail even with enough points");
        if (!"timeExpired".equals(CampaignBoardRules.constraintFailure(0, 0, 2, 2, 1000, 1000)))
            throw new AssertionError("the deadline is exclusive");
        if (!"timeExpired".equals(CampaignBoardRules.constraintFailure(0, 0, 2, 2, 1000, 1500)))
            throw new AssertionError("resuming with the same expired deadline cannot restart the clock");
        if (!"required_categories_not_completed".equals(
                CampaignBoardRules.constraintFailure(0, 0, 1, 2, 0, 0)))
            throw new AssertionError("points cannot replace the distinct-category requirement");
        if (!CampaignBoardRules.constraintFailure(99, 0, 0, 0, 0, 999).isEmpty())
            throw new AssertionError("legacy stages have no optional constraints");
        equal(2, CampaignBoardRules.themedCategoryCount(
                Arrays.asList("الأنمي", "nature", "movies", "nature"),
                Arrays.asList("أنمي", "nature", "أنمي")), "only distinct themed categories count, including aliases");
    }

    private static void verifyBossStyles() {
        for (int columns = 2; columns <= 8; columns++) {
            equal(2400, CampaignBoardRules.bossMaximumScore(columns, "highValue"), "hunters share the high-value supply with the player");
            ArrayList<int[]> shared = new ArrayList<>();
            for (int column = 0; column < columns; column++) {
                for (int row = 0; row < 6; row++) shared.add(new int[]{column, row});
            }
            int humanScore = 0;
            for (int turn = 0; turn < 6 * columns; turn++) {
                int[] chosen = CampaignBoardRules.pickBossCell(shared, "highValue", 0, new java.util.Random(turn));
                if (turn % columns == 0) humanScore += (chosen[1] % 3 + 1) * 200;
                shared.remove(chosen);
            }
            equal(CampaignBoardRules.bossMaximumScore(columns, "highValue"), humanScore, "six simulated hunter rounds reach the fair star ceiling");
        }
        String[] styles = {"specialist", "speed", "highValue"};
        for (int slot = 1; slot <= 7; slot++) {
            if (!styles[(slot - 1) % 3].equals(CampaignBoardRules.bossStyleForSlot("mixed", slot)))
                throw new AssertionError("mixed council must give each boss its own style");
            if (!"speed".equals(CampaignBoardRules.bossStyleForSlot("speed", slot)))
                throw new AssertionError("a uniform boss encounter keeps its style");
        }
        ArrayList<int[]> cells = new ArrayList<>();
        cells.add(new int[]{0, 0});
        cells.add(new int[]{0, 2});
        cells.add(new int[]{1, 1});
        cells.add(new int[]{1, 5});
        for (int seed = 0; seed < 50; seed++) {
            int[] expert = CampaignBoardRules.pickBossCell(cells, "specialist", 1, new java.util.Random(seed));
            equal(1, expert[0], "expert picks the specialty column");
            int[] hunter = CampaignBoardRules.pickBossCell(cells, "highValue", 0, new java.util.Random(seed));
            equal(2, hunter[1] % 3, "hunter prioritizes both rows worth 600");
            int[] fallback = CampaignBoardRules.pickBossCell(cells, "specialist", 8, new java.util.Random(seed));
            if (!cells.contains(fallback)) throw new AssertionError("exhausted specialty falls back to a remaining cell");
        }
        if (CampaignBoardRules.pickBossCell(new ArrayList<>(), "highValue", 0, new java.util.Random()) != null)
            throw new AssertionError("an empty board has no legal move");
        int baseline = CampaignBoardRules.campaignBotCorrectChance("5", 68);
        equal(baseline + 12, CampaignBoardRules.styledBotCorrectChance("5", 68, "specialist", true), "specialty bonus");
        equal(baseline - 8, CampaignBoardRules.styledBotCorrectChance("5", 68, "specialist", false), "outside-specialty weakness");
        equal(baseline, CampaignBoardRules.styledBotCorrectChance("5", 68, "balanced", true), "legacy skill unchanged");
        equal(97, CampaignBoardRules.styledBotCorrectChance("0", 99, "specialist", true), "accuracy has a ceiling");
        equal(18, CampaignBoardRules.styledBotCorrectChance("3", 1, "specialist", false), "accuracy has a floor");
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
