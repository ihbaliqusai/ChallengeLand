package com.qi7bali.landchallengeonline;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.Base64;

/** Exercises the actual Android matcher without Android framework stubs. */
public final class BoardAnswerMatcherCheck {
    public static void main(String[] args) throws Exception {
        int checks = 0;
        for (String line : Files.readAllLines(Paths.get(args[0]), StandardCharsets.UTF_8)) {
            String[] encoded = line.split("\t", -1);
            String[] values = new String[6];
            for (int i = 0; i < values.length; i++) values[i] = new String(Base64.getDecoder().decode(encoded[i]), StandardCharsets.UTF_8);
            Question q = new Question();
            q.setR(values[1]); q.setW1(values[2]); q.setW2(values[3]); q.setW3(values[4]);
            if (encoded.length > 7) q.Q = new String(Base64.getDecoder().decode(encoded[7]), StandardCharsets.UTF_8);
            boolean actual = BoardAnswerMatcher.isCorrect(values[0], q);
            if (actual != Boolean.parseBoolean(encoded[6])) throw new AssertionError("Case " + checks + ": " + values[0] + " / " + q.getR());
            if (!BoardAnswerMatcher.normalize(values[0]).equals(values[5])) throw new AssertionError("Normalization differs from server: " + values[0]);
            checks++;
        }
        System.out.println("Android answer matching and server normalization parity: " + checks + " cases passed.");
    }
}
