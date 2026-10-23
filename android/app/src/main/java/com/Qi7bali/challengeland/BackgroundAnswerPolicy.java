package com.qi7bali.landchallengeonline;

import java.util.HashSet;
import java.util.Set;

/** Match-scoped rules, independent of Android lifecycle and network callbacks. */
final class BackgroundAnswerPolicy {
    static final long GRACE_MS = 10_000L;
    static final int MAX_VIOLATIONS = 3;

    int violations;
    final Set<String> penalizedQuestions = new HashSet<>();
    String awayQuestion = "";
    long awayElapsed;
    long awayWall;
    String pendingQuestion = "";
    int notifiedViolations;

    void leave(String question, long elapsed, long wall) {
        if (question == null || question.isEmpty() || !awayQuestion.isEmpty()
                || !pendingQuestion.isEmpty() || penalizedQuestions.contains(question)
                || violations >= MAX_VIOLATIONS) return;
        awayQuestion = question;
        awayElapsed = elapsed;
        awayWall = wall;
    }

    void evaluate(long elapsed, long wall) {
        if (awayQuestion.isEmpty()) return;
        // Use the monotonic clock during a boot, including time in deep sleep.
        // Persisted wall time is only a fallback after a device restart.
        boolean sameBoot = elapsed >= awayElapsed;
        long duration = sameBoot ? elapsed - awayElapsed : Math.max(0L, wall - awayWall);
        if (duration <= GRACE_MS) return;
        if (penalizedQuestions.add(awayQuestion)) {
            violations = Math.min(MAX_VIOLATIONS, violations + 1);
            pendingQuestion = awayQuestion;
        }
        awayQuestion = "";
    }

    void resume(long elapsed, long wall) {
        evaluate(elapsed, wall);
        awayQuestion = "";
    }

    boolean disqualified() { return violations >= MAX_VIOLATIONS; }
    void acknowledge() { pendingQuestion = ""; }
}
