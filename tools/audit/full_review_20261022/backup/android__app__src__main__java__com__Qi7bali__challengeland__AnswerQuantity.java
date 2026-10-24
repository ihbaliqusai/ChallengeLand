package com.qi7bali.landchallengeonline;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;

/** Scalar Arabic/English numbers with optional units; mirrors answer_quantity.js. */
final class AnswerQuantity {
    private AnswerQuantity() {}

    private static final Set<String> QUALIFIERS = new HashSet<>(Arrays.asList(AnswerQuantityVocabulary.QUALIFIERS.split(" ")));
    private static final class Token {
        final double value;
        final String kind;
        final boolean teen;
        Token(double value, String kind) { this(value, kind, false); }
        Token(double value, String kind, boolean teen) { this.value = value; this.kind = kind; this.teen = teen; }
    }
    static final class Quantity {
        final double value;
        final String unit;
        Quantity(double value, String unit) { this.value = value; this.unit = unit; }
    }

    private static boolean numericWord(String word) {
        return AnswerQuantityVocabulary.SMALL.containsKey(word) || AnswerQuantityVocabulary.HUNDREDS.containsKey(word)
                || AnswerQuantityVocabulary.SCALES.containsKey(word) || AnswerQuantityVocabulary.EXPAND.containsKey(word);
    }
    private static String withoutArticle(String word) {
        if (word.startsWith("ال") && (numericWord(word.substring(2)) || AnswerQuantityVocabulary.UNITS.containsKey(word.substring(2)))) return word.substring(2);
        return word;
    }
    private static Token numberToken(String word) {
        if (word.matches("\\d+(?:\\.\\d+)?")) return new Token(Double.parseDouble(word), "digit");
        String value = AnswerQuantityVocabulary.SMALL.get(word);
        if (value != null) return new Token(Double.parseDouble(value), "small", word.equals("عشر") || word.equals("عشره"));
        value = AnswerQuantityVocabulary.HUNDREDS.get(word);
        if (value != null) return new Token(Double.parseDouble(value), "hundred");
        value = AnswerQuantityVocabulary.SCALES.get(word);
        if (value != null) return new Token(Double.parseDouble(value), "scale");
        return word.equals("و") || word.equals("and") ? new Token(0, "and") : null;
    }
    private static boolean isSmall(Token token) { return token.kind.equals("small") || token.kind.equals("digit"); }
    private static Double underHundred(List<Token> parts) {
        if (parts.size() == 1 && isSmall(parts.get(0))) return parts.get(0).value;
        boolean joined = false;
        if (parts.size() == 3 && parts.get(1).kind.equals("and")) {
            joined = true;
            parts = Arrays.asList(parts.get(0), parts.get(2));
        }
        if (parts.size() != 2 || !isSmall(parts.get(0)) || !isSmall(parts.get(1))) return null;
        if (parts.get(0).kind.equals("digit") && parts.get(1).kind.equals("digit")) return null;
        double a = parts.get(0).value, b = parts.get(1).value;
        if (a % 1 != 0 || b % 1 != 0) return null;
        if (a >= 20 && a <= 90 && a % 10 == 0 && b >= 1 && b <= 9) return a + b;
        if (a >= 1 && a <= 9 && (parts.get(1).teen && !joined || joined && b >= 20 && b <= 90 && b % 10 == 0)) return a + b;
        return null;
    }
    private static Double underThousand(List<Token> parts) {
        int index = -1;
        for (int i = 0; i < parts.size(); i++) if (parts.get(i).kind.equals("hundred")) { index = i; break; }
        if (index < 0) return underHundred(parts);
        double head = parts.get(index).value;
        if (index == 1 && head == 100 && parts.get(0).value >= 1 && parts.get(0).value <= 9) head *= parts.get(0).value;
        else if (index != 0) return null;
        List<Token> tail = parts.subList(index + 1, parts.size());
        if (!tail.isEmpty() && tail.get(0).kind.equals("and")) {
            if (tail.size() == 1) return null;
            tail = tail.subList(1, tail.size());
        }
        if (tail.isEmpty()) return head;
        Double rest = underHundred(tail);
        return rest != null && rest < 100 ? head + rest : null;
    }
    private static Double numericValue(List<Token> parts) {
        double total = 0, previousScale = Double.POSITIVE_INFINITY;
        int start = 0;
        for (int i = 0; i < parts.size(); i++) {
            if (!parts.get(i).kind.equals("scale")) continue;
            double scale = parts.get(i).value;
            if (scale >= previousScale) return null;
            List<Token> group = parts.subList(start, i);
            Double coefficient = group.isEmpty() ? (start == 0 ? Double.valueOf(1) : null) : underThousand(group);
            if (coefficient == null || coefficient <= 0 || coefficient >= scale) return null;
            total += coefficient * scale;
            previousScale = scale;
            start = i + 1;
            if (start < parts.size() && parts.get(start).kind.equals("and")) start++;
        }
        if (start < parts.size()) {
            Double tail = underThousand(parts.subList(start, parts.size()));
            if (tail == null || tail >= previousScale) return null;
            total += tail;
        } else if (start == 0 || parts.get(parts.size() - 1).kind.equals("and")) return null;
        return !Double.isNaN(total) && !Double.isInfinite(total) && Math.abs(total) <= 9007199254740991d ? total : null;
    }

    static Quantity parse(String value) {
        if (value == null) return null;
        String text = value.trim().toLowerCase(Locale.ROOT).replaceAll("(?:^|\\s)(?:ال)?عُشْ?ر(?=\\s|$)", " 0.1")
                .replaceAll("[\\u064b-\\u0652\\u0670\\u0640]", "");
        StringBuilder folded = new StringBuilder();
        for (int i = 0; i < text.length(); i++) {
            char c = text.charAt(i);
            if (c >= '٠' && c <= '٩') c = (char) ('0' + c - '٠');
            else if (c >= '۰' && c <= '۹') c = (char) ('0' + c - '۰');
            if ("أإآٱ".indexOf(c) >= 0) c = 'ا';
            else if (c == 'ة') c = 'ه';
            else if (c == 'ى' || c == 'ئ') c = 'ي';
            else if (c == 'ؤ') c = 'و';
            folded.append(c);
        }
        text = folded.toString().replace("٬", "").replaceAll("(?<=\\d),(?=\\d{3}(?:\\D|$))", "")
                .replaceAll("(?<=\\d)[٫,](?=\\d)", ".").replaceAll("[−–]", "-")
                .replaceAll("(?<=[a-z])-(?=[a-z])", " ")
                .replace("$", " usd ").replace("€", " eur ").replace("£", " gbp ").replaceAll("[%٪]", " percent ")
                .replace("°c", " celsius ").replace("°f", " fahrenheit ").replace("°", " degree ")
                .replaceAll("(?<=\\d)(?=[a-zء-ي])|(?<=[a-zء-ي])(?=\\d)", " ").replaceAll("\\s+", " ").trim()
                .replaceAll("[.!?؟،,؛;]+$", "").trim();
        for (java.util.Map.Entry<String, String> phrase : AnswerQuantityVocabulary.UNITPHRASES.entrySet()) text = text.replace(phrase.getKey(), phrase.getValue());
        if (text.isEmpty() || text.matches(".*[^a-zء-ي0-9 .+\\-].*")) return null;
        List<String> words = new ArrayList<>();
        for (String raw : text.trim().split(" +")) {
            String word = withoutArticle(raw);
            boolean joined = !numericWord(word) && word.startsWith("و") && numericWord(withoutArticle(word.substring(1)));
            if (joined) { words.add("و"); word = withoutArticle(word.substring(1)); }
            String expansion = AnswerQuantityVocabulary.EXPAND.get(word);
            words.addAll(Arrays.asList((expansion != null ? expansion : word).split(" ")));
        }
        if (words.isEmpty()) return null;
        double sign = 1;
        if (Arrays.asList("-", "سالب", "ناقص", "negative", "minus", "+", "موجب", "positive", "plus").contains(words.get(0))) {
            if (Arrays.asList("-", "سالب", "ناقص", "negative", "minus").contains(words.get(0))) sign = -1;
            words.remove(0);
        } else if (words.get(0).matches("^[+-]\\d.*")) {
            if (words.get(0).charAt(0) == '-') sign = -1;
            words.set(0, words.get(0).substring(1));
        }
        String unit = null;
        boolean ended = false;
        List<Token> parts = new ArrayList<>();
        for (String word : words) {
            Token token = numberToken(word);
            String nextUnit = AnswerQuantityVocabulary.UNITS.get(word);
            if (token != null && nextUnit != null && !parts.isEmpty()) {
                List<Token> extended = new ArrayList<>(parts);
                extended.add(token);
                if (numericValue(extended) == null) token = null;
            }
            if (token != null) {
                if (ended) return null;
                parts.add(token);
            } else {
                if (nextUnit != null) {
                    if (unit != null && !nextUnit.equals(unit)) {
                        if (unit.equals("year") && (nextUnit.equals("ce") || nextUnit.equals("ah"))) unit = nextUnit;
                        else if (!(nextUnit.equals("year") && (unit.equals("ce") || unit.equals("ah")))) return null;
                    } else unit = nextUnit;
                } else if (!QUALIFIERS.contains(word)) return null;
                if (!parts.isEmpty()) ended = true;
            }
        }
        if (parts.isEmpty()) return null;
        Double amount = numericValue(parts);
        return amount == null ? null : new Quantity(sign * amount, unit);
    }

    /** null means this is not a scalar quantity, so ordinary text rules apply. */
    private static boolean compatibleUnits(String a, String b) {
        return a == null || b == null || a.equals(b)
                || a.equals("year") && (b.equals("ce") || b.equals("ah"))
                || b.equals("year") && (a.equals("ce") || a.equals("ah"));
    }

    static Boolean matches(String typed, String right, String questionText, String... wrongs) {
        Quantity expected = parse(right);
        if (expected == null) return null;
        if (expected.unit == null && !right.matches(".*[0-9٠-٩۰-۹].*")
                && BoardAnswerMatcher.normalize(questionText).matches(".*(?:وحده|ما (?:هو )?اسم|ما هي اسم|unit|\\bname\\b).*")) return null;
        Quantity actual = parse(typed);
        if (actual == null || actual.value != expected.value || !compatibleUnits(actual.unit, expected.unit)) return false;
        for (String wrong : wrongs) {
            Quantity option = parse(wrong);
            if (option != null && option.value == actual.value
                    && compatibleUnits(option.unit, actual.unit)) return false;
        }
        return true;
    }
}
