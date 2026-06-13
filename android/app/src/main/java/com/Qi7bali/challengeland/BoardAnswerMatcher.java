package net.androidgaming.millionaire2024;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;

/**
 * Fuzzy answer matcher for the offline board ("سين جيم") typed-answer mode.
 *
 * <p>"Balanced" policy: it tolerates a small spelling slip (scaled to the answer
 * length), and accepts a distinctive part of a multi-word answer (e.g. a surname
 * typed for a full name, or the key word written inside a longer sentence). At the
 * same time it refuses anything that looks at least as much like one of the three
 * wrong options, so a near-miss can never sneak through as correct.</p>
 */
final class BoardAnswerMatcher {

    private BoardAnswerMatcher() {
    }

    // Connective/particle tokens ignored when comparing the *parts* of an answer.
    private static final Set<String> STOPWORDS = new HashSet<>(Arrays.asList(
            "و", "من", "في", "على", "عن", "الى", "ابن", "بن", "ابو", "ام", "ال",
            "the", "of", "a", "an", "el", "le", "la"
    ));

    // Ratio-based acceptance for a single distinctive word (handles spelling /
    // transliteration variance, e.g. "سينشي" for "شينيتشي"): the input must reach
    // this similarity to one of the answer's words AND beat every wrong option's
    // words by the margin, so an ambiguous near-miss can never pass.
    private static final double TOKEN_PARTIAL_SIM = 0.5;
    private static final double TOKEN_PARTIAL_MARGIN = 0.1;
    // Short inputs match short words by coincidence, so the ratio path only trusts
    // typed words of at least this length.
    private static final int TOKEN_PARTIAL_MIN_LEN = 4;

    // Spelled-out Arabic numbers -> digits, so "أربعة"/"٤"/"4" all compare equal.
    // Keys are stored already-normalized (ة→ه, أإآ→ا, ى→ي, ؤ→و, ئ→ي, no diacritics).
    private static final Map<String, String> NUMBER_WORDS = new HashMap<>();
    static {
        putNumberWord("0", "صفر");
        putNumberWord("1", "واحد", "واحده", "احد", "احدي");
        putNumberWord("2", "اثنان", "اثنين", "اثنتان", "اثنتين", "اتنين");
        putNumberWord("3", "ثلاثه", "ثلاث", "تلاته");
        putNumberWord("4", "اربعه", "اربع");
        putNumberWord("5", "خمسه", "خمس");
        putNumberWord("6", "سته", "ست");
        putNumberWord("7", "سبعه", "سبع");
        putNumberWord("8", "ثمانيه", "ثماني", "ثمان", "تمانيه");
        putNumberWord("9", "تسعه", "تسع");
        putNumberWord("10", "عشره", "عشر");
        putNumberWord("20", "عشرون", "عشرين");
        putNumberWord("30", "ثلاثون", "ثلاثين");
        putNumberWord("40", "اربعون", "اربعين");
        putNumberWord("50", "خمسون", "خمسين");
        putNumberWord("60", "ستون", "ستين");
        putNumberWord("70", "سبعون", "سبعين");
        putNumberWord("80", "ثمانون", "ثمانين");
        putNumberWord("90", "تسعون", "تسعين");
        putNumberWord("100", "مايه", "ميه");
        putNumberWord("1000", "الف");
        putNumberWord("1000000", "مليون");
        putNumberWord("1000000000", "مليار");
    }

    private static void putNumberWord(String digits, String... words) {
        for (String w : words) {
            NUMBER_WORDS.put(w, digits);
        }
    }

    /** Returns true when {@code typed} should count as the right answer for {@code q}. */
    static boolean isCorrect(String typed, Question q) {
        if (q == null) {
            return false;
        }
        String nt = normalize(typed);
        if (nt.isEmpty()) {
            return false;
        }
        String right = normalize(q.R);
        if (right.isEmpty()) {
            return false;
        }

        List<String> wrongs = new ArrayList<>();
        addWrong(wrongs, q.W1);
        addWrong(wrongs, q.W2);
        addWrong(wrongs, q.W3);

        // Exact (after normalization) is always accepted.
        if (nt.equals(right)) {
            return true;
        }

        double simRight = similarity(nt, right);
        double simWrongBest = 0.0;
        for (String w : wrongs) {
            simWrongBest = Math.max(simWrongBest, similarity(nt, w));
        }
        // Never accept input that resembles a wrong option at least as much.
        boolean clearlyRight = simRight > simWrongBest;

        // 1) Whole-answer spelling tolerance, scaled to its length.
        int dist = levenshtein(nt, right);
        if (dist <= allowedEdits(right.length()) && clearlyRight) {
            return true;
        }

        // 2) Partial answer: a distinctive word, or most of the answer's words.
        return partialMatch(nt, right, wrongs);
    }

    private static void addWrong(List<String> list, String s) {
        String n = normalize(s);
        if (!n.isEmpty()) {
            list.add(n);
        }
    }

    /** Balanced edit budget: always allow one slip, more for longer answers. */
    private static int allowedEdits(int len) {
        if (len <= 4) {
            return 1;
        }
        if (len <= 8) {
            return 2;
        }
        return Math.max(2, Math.round(len * 0.22f));
    }

    private static boolean partialMatch(String nt, String right, List<String> wrongs) {
        List<String> rTokens = distinctiveTokens(right);
        if (rTokens.isEmpty()) {
            return false;
        }
        List<String> ntTokens = tokens(nt);

        // (a) A distinctive word of the answer appears in the input and is unique to
        //     the right answer: a surname typed for a full name, or the key word
        //     written inside a longer sentence.
        for (String tok : rTokens) {
            if (tok.length() < 3) {
                continue;
            }
            if (!appearsIn(tok, nt, ntTokens)) {
                continue;
            }
            if (tokenAppearsIn(tok, wrongs)) {
                continue;
            }
            if (rTokens.size() == 1 || tok.length() >= 4) {
                return true;
            }
        }

        // (a2) A close *rendering* of a distinctive word (ratio-based, tolerant of
        //      heavier spelling/transliteration drift, e.g. "سينشي" for "شينيتشي"),
        //      accepted only when it is clearly closer to a word of the answer than
        //      to any wrong option's words.
        List<String> candidates = new ArrayList<>(ntTokens.size() + 1);
        candidates.add(nt);
        candidates.addAll(ntTokens);
        List<String> longCandidates = new ArrayList<>();
        for (String c : candidates) {
            if (c.length() >= TOKEN_PARTIAL_MIN_LEN) {
                longCandidates.add(c);
            }
        }
        if (!longCandidates.isEmpty()) {
            for (String tok : rTokens) {
                if (tok.length() < TOKEN_PARTIAL_MIN_LEN) {
                    continue;
                }
                double bestRight = maxSimilarity(longCandidates, tok);
                if (bestRight < TOKEN_PARTIAL_SIM) {
                    continue;
                }
                double bestWrong = 0.0;
                for (String w : wrongs) {
                    for (String wt : distinctiveTokens(w)) {
                        if (wt.length() >= 3) {
                            bestWrong = Math.max(bestWrong, maxSimilarity(longCandidates, wt));
                        }
                    }
                }
                if (bestRight >= bestWrong + TOKEN_PARTIAL_MARGIN) {
                    return true;
                }
            }
        }

        if (rTokens.size() < 2) {
            return false;
        }

        // (b) The input covers at least half of the answer's distinctive words, and
        //     does not cover any wrong option just as strongly (avoid ambiguous input).
        int coveredRight = countCovered(nt, ntTokens, rTokens);
        if (coveredRight < Math.ceil(rTokens.size() / 2.0)) {
            return false;
        }
        for (String w : wrongs) {
            List<String> wTokens = distinctiveTokens(w);
            if (wTokens.isEmpty()) {
                continue;
            }
            if (countCovered(nt, ntTokens, wTokens) >= coveredRight) {
                return false;
            }
        }
        return true;
    }

    private static int countCovered(String nt, List<String> ntTokens, List<String> targetTokens) {
        int covered = 0;
        for (String tok : targetTokens) {
            if (appearsIn(tok, nt, ntTokens)) {
                covered++;
            }
        }
        return covered;
    }

    /** True when {@code tok} shows up in the input as a substring or a near-equal word. */
    private static boolean appearsIn(String tok, String nt, List<String> ntTokens) {
        if (nt.contains(tok)) {
            return true;
        }
        for (String w : ntTokens) {
            if (fuzzyEquals(w, tok)) {
                return true;
            }
        }
        return false;
    }

    private static boolean tokenAppearsIn(String tok, List<String> answers) {
        for (String a : answers) {
            if (a.contains(tok)) {
                return true;
            }
            for (String w : tokens(a)) {
                if (fuzzyEquals(w, tok)) {
                    return true;
                }
            }
        }
        return false;
    }

    /** Word-level equality with a tiny spelling budget (1 edit, 2 for longer words). */
    private static boolean fuzzyEquals(String a, String b) {
        if (a.equals(b)) {
            return true;
        }
        int maxLen = Math.max(a.length(), b.length());
        if (maxLen == 0) {
            return true;
        }
        int budget = maxLen <= 4 ? 1 : 2;
        return levenshtein(a, b) <= budget;
    }

    private static List<String> tokens(String s) {
        List<String> out = new ArrayList<>();
        for (String t : s.split(" ")) {
            if (!t.isEmpty()) {
                out.add(t);
            }
        }
        return out;
    }

    private static List<String> distinctiveTokens(String s) {
        List<String> out = new ArrayList<>();
        for (String t : tokens(s)) {
            if (t.length() >= 2 && !STOPWORDS.contains(t)) {
                out.add(t);
            }
        }
        if (out.isEmpty()) {
            out.addAll(tokens(s)); // fall back to all tokens for tiny answers
        }
        return out;
    }

    private static double similarity(String a, String b) {
        int maxLen = Math.max(a.length(), b.length());
        if (maxLen == 0) {
            return 1.0;
        }
        return 1.0 - (double) levenshtein(a, b) / maxLen;
    }

    /** Best similarity between {@code target} and any of the candidate strings. */
    private static double maxSimilarity(List<String> candidates, String target) {
        double best = 0.0;
        for (String c : candidates) {
            best = Math.max(best, similarity(c, target));
        }
        return best;
    }

    /**
     * Arabic-aware normalization for free typed text: lower-cases Latin, strips
     * diacritics/tatweel, unifies alef/hamza/teh-marbuta/alef-maqsura forms, and
     * reduces any punctuation to single spaces between words.
     */
    static String normalize(String s) {
        if (s == null) {
            return "";
        }
        String t = s.trim().toLowerCase(Locale.ROOT);
        StringBuilder b = new StringBuilder(t.length());
        for (int i = 0; i < t.length(); i++) {
            char c = t.charAt(i);
            if (c >= 'ً' && c <= 'ْ') {
                continue; // harakat incl. shadda
            }
            if (c == 'ٰ' || c == 'ـ') {
                continue; // superscript alef, tatweel
            }
            if (c >= '٠' && c <= '٩') {
                c = (char) ('0' + (c - '٠')); // Arabic-Indic digits -> ASCII
            } else if (c >= '۰' && c <= '۹') {
                c = (char) ('0' + (c - '۰')); // Extended (Persian) digits -> ASCII
            }
            if (c == 'أ' || c == 'إ' || c == 'آ' || c == 'ٱ') {
                c = 'ا';
            } else if (c == 'ة') {
                c = 'ه';
            } else if (c == 'ى') {
                c = 'ي';
            } else if (c == 'ؤ') {
                c = 'و';
            } else if (c == 'ئ') {
                c = 'ي';
            }
            b.append(isWordChar(c) ? c : ' ');
        }
        // collapse runs of whitespace into single spaces
        StringBuilder out = new StringBuilder(b.length());
        boolean prevSpace = true;
        for (int i = 0; i < b.length(); i++) {
            char c = b.charAt(i);
            if (c == ' ') {
                if (!prevSpace) {
                    out.append(' ');
                }
                prevSpace = true;
            } else {
                out.append(c);
                prevSpace = false;
            }
        }
        // Map spelled-out numbers to digits so "أربعة"/"٤" both match "4".
        String collapsed = out.toString().trim();
        if (collapsed.isEmpty()) {
            return collapsed;
        }
        StringBuilder mapped = new StringBuilder(collapsed.length());
        for (String tok : collapsed.split(" ")) {
            String digits = NUMBER_WORDS.get(tok);
            if (mapped.length() > 0) {
                mapped.append(' ');
            }
            mapped.append(digits != null ? digits : tok);
        }
        return mapped.toString();
    }

    private static boolean isWordChar(char c) {
        if (c >= '0' && c <= '9') {
            return true;
        }
        if (c >= 'a' && c <= 'z') {
            return true;
        }
        return c >= 'ء' && c <= 'ي'; // Arabic letters (post-normalization)
    }

    private static int levenshtein(String a, String b) {
        int la = a.length();
        int lb = b.length();
        if (la == 0) {
            return lb;
        }
        if (lb == 0) {
            return la;
        }
        int[] prev = new int[lb + 1];
        int[] cur = new int[lb + 1];
        for (int j = 0; j <= lb; j++) {
            prev[j] = j;
        }
        for (int i = 1; i <= la; i++) {
            cur[0] = i;
            char ca = a.charAt(i - 1);
            for (int j = 1; j <= lb; j++) {
                int cost = (ca == b.charAt(j - 1)) ? 0 : 1;
                cur[j] = Math.min(Math.min(cur[j - 1] + 1, prev[j] + 1), prev[j - 1] + cost);
            }
            int[] tmp = prev;
            prev = cur;
            cur = tmp;
        }
        return prev[lb];
    }
}
