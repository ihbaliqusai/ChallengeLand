package com.qi7bali.landchallengeonline;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.*;

public final class QuestionSelectionTest {
    private static void check(boolean condition, String message) {
        if (!condition) throw new AssertionError(message);
    }
    private static Question question(String text, String category, String level) {
        Question q = new Question(); q.setQ(text); q.setCategory(category); q.setLevel(level); return q;
    }
    private static String decode(String value) { return new String(Base64.getDecoder().decode(value), StandardCharsets.UTF_8); }

    public static void main(String[] args) throws Exception {
        ArrayList<Question> bank = new ArrayList<>();
        for (String line : Files.readAllLines(Path.of(args[0]), StandardCharsets.UTF_8)) {
            String[] fields = line.split("\t", -1);
            Question q = question(decode(fields[1]), decode(fields[3]), fields[4]);
            q.setImg(decode(fields[2]));
            ArrayList<String> clubs = new ArrayList<>();
            for (int i = 5; i < fields.length; i++) clubs.add(decode(fields[i]));
            q.setClubPath(clubs);
            check(fields[0].equals(QuestionIdentity.key(q)), "Server/native identity mismatch: " + q.getQ());
            bank.add(q);
        }
        System.out.println("Matched Java/server identities for " + bank.size() + " canonical questions and edge cases.");

        Question original = question("ما عاصمة إيطاليا؟", "جغرافيا", "0");
        Question copy = question("مَا عاصمة ايطاليا", "عواصم", "8");
        check(QuestionIdentity.key(original).equals(QuestionIdentity.key(copy)), "Content copies need the same identity");
        check(QuestionSelection.unseen(Arrays.asList(original, copy), new HashSet<>(), new Random(1)).size() == 1,
                "Duplicate objects were both selected");
        check(QuestionSelection.pick(Arrays.asList(copy), Set.of(QuestionIdentity.key(original)), new HashSet<>(), new Random(1)) == null,
                "Fallback revived a seen question");
        String previousKey = QuestionIdentity.key(copy); copy.setImg("new.png");
        check(!previousKey.equals(QuestionIdentity.key(copy)), "Changing media must invalidate the identity cache");

        ArrayList<Question> small = new ArrayList<>();
        for (int i = 0; i < 120; i++) small.add(question("Question " + i, "test", "0"));
        Set<String> lifetime = new HashSet<>();
        String[] modes = {"campaign", "campaign replay", "local teams", "offline board", "classic", "battle", "series", "blitz", "survival", "elimination"};
        Random random = new Random(9);
        for (int game = 0; game < 20; game++) {
            Set<Question> used = new HashSet<>();
            ArrayList<Question> selected = new ArrayList<>();
            for (int cell = 0; cell < 6; cell++) {
                Question chosen = QuestionSelection.pick(small, lifetime, used, random);
                check(chosen != null, "Premature exhaustion in " + modes[game % modes.length]);
                selected.add(chosen);
            }
            for (Question chosen : selected) check(lifetime.add(QuestionIdentity.key(chosen)), "Repeated lifetime question");
            // Simulate a process restart between games; history is data, not object references.
            lifetime = new HashSet<>(Arrays.asList(String.join(",", lifetime).split(",")));
        }
        check(lifetime.size() == 120, "History was truncated");
        check(QuestionSelection.pick(small, lifetime, new HashSet<>(), random) == null, "Exhaustion reset history");
        small.add(question("A newly added question", "test", "0"));
        check(QuestionSelection.unseen(small, lifetime, random).size() == 1, "Bank updates reset prior history");

        LinkedHashMap<String, ArrayList<ArrayList<Question>>> pool = new LinkedHashMap<>();
        for (Question q : bank) {
            ArrayList<ArrayList<Question>> tiers = pool.computeIfAbsent(q.getCategory(), name ->
                    new ArrayList<>(Arrays.asList(new ArrayList<>(), new ArrayList<>(), new ArrayList<>())));
            int level;
            try { level = Integer.parseInt(q.getLevel()); } catch (NumberFormatException e) { level = 0; }
            tiers.get(level <= 2 ? 0 : level >= 4 && level <= 6 ? 1 : 2).add(q);
        }
        Set<String> campaignHistory = new HashSet<>();
        int boards = 0;
        for (int stage = 0; stage < 100; stage++) {
            List<String> levels = stage < 25 ? Arrays.asList("0", "1") : stage < 50 ? Arrays.asList("1", "2", "4")
                    : stage < 75 ? Arrays.asList("2", "4", "5", "6") : Arrays.asList("4", "5", "6", "7", "8", "3");
            Map<String, ArrayList<ArrayList<Question>>> eligible = CampaignBoardRules.filterPool(pool, levels);
            ArrayList<String> categories = new ArrayList<>(eligible.keySet()); Collections.shuffle(categories, random);
            Set<Question> used = new HashSet<>();
            ArrayList<Question> selected = new ArrayList<>();
            for (String category : categories.subList(0, Math.min(4, categories.size()))) {
                for (int row : new int[]{0, 3, 2, 5, 1, 4}) {
                    Question chosen = QuestionSelection.pick(eligible.get(category).get(row % 3), campaignHistory, used, random);
                    if (chosen == null) for (ArrayList<Question> tier : eligible.get(category)) {
                        chosen = QuestionSelection.pick(tier, campaignHistory, used, random); if (chosen != null) break;
                    }
                    if (chosen == null) for (ArrayList<ArrayList<Question>> tiers : eligible.values()) {
                        for (ArrayList<Question> tier : tiers) {
                            chosen = QuestionSelection.pick(tier, campaignHistory, used, random); if (chosen != null) break;
                        }
                        if (chosen != null) break;
                    }
                    if (chosen == null) break;
                    check(levels.contains(chosen.getLevel()), "Campaign fallback escaped allowed levels");
                    selected.add(chosen);
                }
            }
            for (Question chosen : selected) check(campaignHistory.add(QuestionIdentity.key(chosen)), "Campaign repeated a prior stage");
            boards++;
        }
        check(campaignHistory.size() > 1500, "Campaign simulation did not exercise enough questions");
        System.out.println("Passed lifetime, replay, fallback, exhaustion, bank-update and " + boards
                + " campaign board checks (" + campaignHistory.size() + " distinct campaign questions).");
    }
}
