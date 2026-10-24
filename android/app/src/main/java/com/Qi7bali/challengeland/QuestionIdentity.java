package com.qi7bali.landchallengeonline;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.text.Normalizer;
import java.util.Locale;

/** Content identity shared with the server. Never use object identity or a bank offset. */
final class QuestionIdentity {
    private QuestionIdentity() {}

    static String normalize(String value) {
        String text = Normalizer.normalize(value == null ? "" : value, Normalizer.Form.NFKC)
                .toLowerCase(Locale.ROOT).replaceAll("[\\u0640\\u064b-\\u065f\\u0670\\u06d6-\\u06ed]", "")
                .replaceAll("[أإآٱ]", "ا").replace('ى', 'ي');
        StringBuilder result = new StringBuilder();
        for (int i = 0; i < text.length(); i++) {
            char c = text.charAt(i);
            if (c >= '٠' && c <= '٩') c = (char) ('0' + c - '٠');
            if (c >= '۰' && c <= '۹') c = (char) ('0' + c - '۰');
            result.append(c);
        }
        return result.toString().replaceAll("[\\u0000-\\u0020\\u007f\\u00a0\\u1680\\u2000-\\u200b\\u2028\\u2029\\u202f\\u205f\\u3000\\ufeff؟?!،؛;'\"“”‘’«»()\\[\\]{}\\\\…]", "");
    }

    static String key(Question question) {
        if (question == null) return "";
        if (question.contentKey != null) return question.contentKey;
        StringBuilder clubs = new StringBuilder();
        for (String club : question.getClubPath()) {
            if (clubs.length() > 0) clubs.append('>');
            clubs.append(normalize(club));
        }
        String payload = "q1|" + normalize(question.getQ()) + "|"
                + (question.getImg() == null ? "" : question.getImg().trim()) + "|" + clubs;
        try {
            byte[] digest = MessageDigest.getInstance("SHA-256").digest(payload.getBytes(StandardCharsets.UTF_8));
            StringBuilder hex = new StringBuilder();
            for (byte b : digest) hex.append(String.format(Locale.ROOT, "%02x", b & 255));
            question.contentKey = hex.toString();
            return question.contentKey;
        } catch (java.security.NoSuchAlgorithmException impossible) {
            throw new IllegalStateException(impossible);
        }
    }
}
