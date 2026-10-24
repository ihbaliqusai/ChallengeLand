package com.qi7bali.landchallengeonline;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.Comparator;
import java.util.Collections;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.Random;
import java.util.function.Predicate;

/** Campaign-only board rules. Kept independent of Android for regression checks. */
final class CampaignBoardRules {
    private static final List<String> DIFFICULTY_ORDER = Arrays.asList("0", "1", "2", "4", "5", "6", "7", "8", "3");
    private static final int[] BOT_BASE_CHANCES = {90, 78, 62, 40, 34, 28, 24, 20, 18};
    private CampaignBoardRules() {}

    static String bossStyleForSlot(String style, int slot) {
        if (!"mixed".equals(style)) return style;
        return new String[]{"specialist", "speed", "highValue"}[Math.floorMod(slot - 1, 3)];
    }

    static int bossMaximumScore(int columns, String style) {
        return "highValue".equals(style) ? 2400 : maximumScore(columns, 6);
    }

    /** Zero disables a rule. Exactly the permitted error count is still playable. */
    static String constraintFailure(int wrong, int maxWrong, int categoryWins,
                                    int requiredCategories, long deadline, long now) {
        if (deadline > 0 && now >= deadline) return "timeExpired";
        if (maxWrong > 0 && wrong > maxWrong) return "eliminated";
        if (categoryWins < requiredCategories) return "required_categories_not_completed";
        return "";
    }

    static int styledBotCorrectChance(String level, int intelligence, String style, boolean specialty) {
        int chance = campaignBotCorrectChance(level, intelligence);
        if ("specialist".equals(style)) chance += specialty ? 12 : -8;
        return Math.max(18, Math.min(97, chance));
    }

    /** Leave time to read, with quicker specialists and occasional hesitation. */
    static int bossThinkTimeMs(String level, String text, String style, boolean specialty, Random random) {
        int rank = DIFFICULTY_ORDER.indexOf(level == null ? "" : level.trim());
        int readingMs = Math.min(1600, (text == null ? 0 : text.length()) * 12);
        int delay = 2200 + Math.max(0, rank) * 180 + readingMs + random.nextInt(1801);
        if (random.nextInt(6) == 0) delay += 1200;
        if ("speed".equals(style)) delay = delay * 3 / 4;
        if ("specialist".equals(style) && specialty) delay -= 450;
        return Math.max(1800, Math.min(8000, delay));
    }

    static String openingMessage(int order, boolean boss, int target, String entry, boolean resumed) {
        String stage = "المرحلة " + Math.max(1, order);
        if (resumed) return "نتابع من حيث توقفنا.. أكمل هذه المرحلة!";
        String opening = "retry".equals(entry) ? "محاولة جديدة في " + stage + ".. "
                : "next".equals(entry) ? "أحسنت! ننتقل إلى " + stage + ".. "
                : order <= 1 ? "أهلاً بك في تحدي المراحل.. " : "نكمل الرحلة مع " + stage + ".. ";
        return opening + (boss ? "تفوّق على الزعماء لفتح الطريق التالي!"
                : target > 0 ? "هدفك " + target + " نقطة. مستعد؟" : "اجمع النجوم وافتح الطريق التالي!");
    }

    /** Short presenter lines, using the same effective rules as native play. */
    static ArrayList<String> briefingMessages(boolean boss, int picks, int columns,
            String categoryPolicy, int seconds, int maxWrong, int requiredCategories,
            List<String> worldCategories, String bossStyle, boolean revealAllowed,
            int twoStarScore, int threeStarScore) {
        ArrayList<String> messages = new ArrayList<>();
        String categories = columns == 1 ? "فئة واحدة" : columns == 2 ? "فئتين" : columns + " فئات";
        messages.add(("playerPick".equals(categoryPolicy) ? "اختر " : "سأختار لك ") + categories
                + "، ولديك " + Math.max(1, picks) + " أسئلة.");
        messages.add(revealAllowed
                ? "اكتب الإجابة للنقاط كاملة؛ كشف الخيارات يمنح نصف النقاط."
                : "أجب بالكتابة؛ كشف خيارات الإجابة غير متاح في هذه المرحلة.");
        if (seconds > 0) {
            messages.add("لديك " + seconds + " ثانية لإنهاء اللوحة؛ الوقت يستمر عند المغادرة.");
        }
        if (maxWrong > 0) {
            messages.add("المسموح " + maxWrong + " أخطاء؛ الخطأ التالي ينهي المحاولة.");
        }
        if (requiredCategories > 0) {
            messages.add("للفوز، أجب صحيحًا في " + requiredCategories + " فئات مختلفة من فئات العالم.");
            // Separate names into readable bubbles instead of shrinking a long list.
            String names = "فئات العالم: ";
            for (String category : worldCategories) {
                if (names.length() + category.length() > 65) {
                    messages.add(names);
                    names = "";
                }
                names += (names.isEmpty() || names.endsWith(": ") ? "" : "، ") + category;
            }
            if (!names.equals("فئات العالم: ") && !names.isEmpty()) messages.add(names);
        }
        if (boss) {
            if ("specialist".equals(bossStyle)) {
                messages.add("الزعيم متخصص: يفضّل فئته ويجيب فيها بدقة أعلى.");
            } else if ("speed".equals(bossStyle)) {
                messages.add("الزعيم سريع؛ مهلة إجابتك عن كل سؤال 30 ثانية.");
            } else if ("highValue".equals(bossStyle)) {
                messages.add("احذر صيّاد النقاط؛ يفضّل الأسئلة الأعلى قيمة.");
            } else if ("mixed".equals(bossStyle)) {
                messages.add("تواجه زعماء متخصصين وسريعين وصيّادي نقاط معًا!");
            }
        }
        if (twoStarScore > 0 && threeStarScore > 0) {
            messages.add("بعد الفوز: " + twoStarScore + " نقطة لنجمتين، و" + threeStarScore + " لثلاث نجوم.");
        }
        return messages;
    }

    /** Prefer the specialty column or the largest value; fall back when exhausted. */
    static int[] pickBossCell(List<int[]> remaining, String style, int specialtyColumn, Random random) {
        if (remaining.isEmpty()) return null;
        ArrayList<int[]> preferred = new ArrayList<>();
        int highestValue = 0;
        for (int[] cell : remaining) {
            if ("specialist".equals(style) && cell[0] == specialtyColumn) preferred.add(cell);
            if ("highValue".equals(style)) {
                int value = (cell[1] % 3 + 1) * 200;
                if (value > highestValue) { highestValue = value; preferred.clear(); }
                if (value == highestValue) preferred.add(cell);
            }
        }
        List<int[]> choices = preferred.isEmpty() ? remaining : preferred;
        return choices.get(random.nextInt(choices.size()));
    }

    static int themedCategoryCount(List<String> chosen, List<String> themed) {
        Set<String> matching = new HashSet<>();
        for (String category : themed) {
            String resolved = resolveCategory(category, chosen);
            if (resolved != null) matching.add(resolved);
        }
        return matching.size();
    }

    static int playerTurns(int completedTurns, int playerCount) {
        int count = Math.max(1, playerCount);
        int turns = Math.max(0, completedTurns);
        return turns / count + (turns % count == 0 ? 0 : 1);
    }

    /** Every category has two cells at each of 200, 400 and 600 points. */
    static int maximumScore(int columns, int picks) {
        int cellsPerValue = Math.max(0, columns) * 2;
        int remaining = Math.max(0, picks);
        int score = 0;
        for (int value = 600; value >= 200; value -= 200) {
            int taken = Math.min(cellsPerValue, remaining);
            score += taken * value;
            remaining -= taken;
        }
        return score;
    }

    static int earnedStars(int score, int target, int twoStarScore, int threeStarScore) {
        if (score < Math.max(1, target)) return 0;
        if (score >= threeStarScore) return 3;
        if (score >= twoStarScore) return 2;
        return 1;
    }

    static int botAwardValue(int cellValue, boolean campaignBoard, boolean optionsRevealed) {
        return campaignBoard && optionsRevealed ? cellValue / 2 : cellValue;
    }

    static int campaignBotCorrectChance(String level, int intelligence) {
        int rank = DIFFICULTY_ORDER.indexOf(level == null ? "" : level.trim());
        int base = rank >= 0 ? BOT_BASE_CHANCES[rank] : 60;
        return Math.max(18, Math.min(97, base + (intelligence - 68) / 2));
    }

    static LinkedHashMap<String, ArrayList<ArrayList<Question>>> accessiblePool(
            Map<String, ArrayList<ArrayList<Question>>> eligible, Predicate<String> isUnlocked) {
        LinkedHashMap<String, ArrayList<ArrayList<Question>>> accessible = new LinkedHashMap<>();
        if (eligible == null) return accessible;
        for (Map.Entry<String, ArrayList<ArrayList<Question>>> entry : eligible.entrySet()) {
            if (isUnlocked.test(entry.getKey())) accessible.put(entry.getKey(), entry.getValue());
        }
        return accessible;
    }

    static ArrayList<String> pickCategories(List<String> unlocked, List<String> themed, int count, Random random) {
        if (count <= 0) return new ArrayList<>();
        ArrayList<String> preferred = new ArrayList<>();
        if (themed != null) {
            for (String category : themed) {
                String available = resolveCategory(category, unlocked);
                if (available != null && !preferred.contains(available)) preferred.add(available);
            }
        }
        Collections.shuffle(preferred, random);
        ArrayList<String> chosen = new ArrayList<>(preferred.subList(0, Math.min(count, preferred.size())));
        ArrayList<String> remaining = new ArrayList<>(unlocked);
        Collections.shuffle(remaining, random);
        for (String category : remaining) {
            if (chosen.size() >= count) break;
            if (!chosen.contains(category)) chosen.add(category);
        }
        return chosen;
    }

    static String resolveCategory(String category, java.util.Collection<String> available) {
        if (category == null) return null;
        String trimmed = category.trim();
        if (available.contains(trimmed)) return trimmed;
        String normalized = CategoryConfig.normalize(trimmed);
        for (String candidate : available) {
            if (CategoryConfig.normalize(candidate).equals(normalized)) return candidate;
        }
        return null;
    }

    static boolean canUseCategories(List<String> selected, int required, Map<String, ?> accessible) {
        return required > 0 && selected != null && selected.size() == required
                && new HashSet<>(selected).size() == required && accessible.keySet().containsAll(selected);
    }

    /** Build stage-relative tiers without mutating the shared question pool. */
    static LinkedHashMap<String, ArrayList<ArrayList<Question>>> filterPool(
            Map<String, ArrayList<ArrayList<Question>>> source, List<String> levels) {
        Set<String> allowed = new HashSet<>();
        if (levels != null) {
            for (String level : levels) {
                if (level != null && !level.trim().isEmpty()) allowed.add(level.trim());
            }
        }
        LinkedHashMap<String, ArrayList<ArrayList<Question>>> filtered = new LinkedHashMap<>();
        if (source == null) return filtered;
        // Legacy level 3 is the final millionaire difficulty, above the newer 4..8
        // bands. Use that semantic order instead of numeric sorting.
        List<String> levelOrder = new ArrayList<>(allowed);
        levelOrder.sort(Comparator.comparingInt(level -> {
            int rank = DIFFICULTY_ORDER.indexOf(level);
            return rank >= 0 ? rank : DIFFICULTY_ORDER.size();
        }));
        for (Map.Entry<String, ArrayList<ArrayList<Question>>> entry : source.entrySet()) {
            ArrayList<ArrayList<Question>> tiers = new ArrayList<>();
            for (int tier = 0; tier < 3; tier++) tiers.add(new ArrayList<>());
            int size = 0;
            for (int originalTier = 0; originalTier < entry.getValue().size(); originalTier++) {
                ArrayList<Question> original = entry.getValue().get(originalTier);
                for (Question question : original) {
                    if (question == null) continue;
                    String level = question.getLevel() == null ? "" : question.getLevel().trim();
                    if (!allowed.isEmpty() && !allowed.contains(level)) continue;
                    size++;
                    if (allowed.isEmpty()) {
                        tiers.get(Math.min(2, originalTier)).add(question);
                        continue;
                    }
                    int rank = levelOrder.indexOf(level);
                    int relativeTier = levelOrder.size() == 2 ? rank * 2
                            : Math.min(2, rank * 3 / levelOrder.size());
                    tiers.get(relativeTier).add(question);
                    // With two levels, medium cells mix both. Sharing question
                    // objects keeps the board's used-set from drawing duplicates.
                    if (levelOrder.size() == 2) tiers.get(1).add(question);
                }
            }
            boolean hasBothEnds = levelOrder.size() < 2
                    || (tiers.get(0).size() >= 2 && tiers.get(2).size() >= 2);
            if (size >= 6 && hasBothEnds) filtered.put(entry.getKey(), tiers);
        }
        return filtered;
    }
}
