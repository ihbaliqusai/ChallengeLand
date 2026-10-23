package com.qi7bali.landchallengeonline;

public final class BackgroundAnswerPolicyCheck {
    private static int assertions;
    private static final long START = 50_000L;
    private static final long WALL = 1_800_000_000_000L;

    private static void check(boolean value, String label) {
        assertions++;
        if (!value) throw new AssertionError(label);
    }

    public static void main(String[] args) {
        BackgroundAnswerPolicy p = new BackgroundAnswerPolicy();
        p.leave("", START, WALL);
        p.resume(START + 60_000, WALL + 60_000);
        check(p.violations == 0, "no penalty outside an unanswered question");

        p.leave("q1", START, WALL);
        p.resume(START + 9_999, WALL + 9_999);
        check(p.violations == 0, "return before ten seconds");
        p.leave("q1", START + 20_000, WALL + 20_000);
        p.resume(START + 30_000, WALL + 30_000);
        check(p.violations == 0, "exactly ten seconds is allowed, short absences are not cumulative");

        p.leave("q1", START + 40_000, WALL + 40_000);
        p.evaluate(START + 50_001, WALL + 50_001);
        check(p.violations == 1 && p.pendingQuestion.equals("q1"), "first millisecond beyond grace closes the captured question");
        p.evaluate(START + 70_000, WALL + 70_000);
        p.resume(START + 80_000, WALL + 80_000);
        check(p.violations == 1 && p.pendingQuestion.equals("q1"), "background deadline and return cannot double count");
        p.acknowledge();
        p.leave("q1", START + 90_000, WALL + 90_000);
        p.resume(START + 120_000, WALL + 120_000);
        check(p.violations == 1, "same question cannot produce a second violation");

        p.leave("q2", START + 130_000, WALL + 130_000);
        p.resume(START + 140_001, WALL + 140_001);
        check(p.violations == 2 && !p.disqualified(), "second question does not end participation");
        p.acknowledge();
        p.leave("q3", START + 150_000, WALL + 150_000);
        p.resume(START + 160_001, WALL + 160_001);
        check(p.violations == 3 && p.disqualified(), "third violation ends participation");
        p.acknowledge();
        p.leave("q4", START + 170_000, WALL + 170_000);
        p.resume(START + 190_000, WALL + 190_000);
        check(p.violations == 3 && p.disqualified(), "terminal state stays terminal after acknowledgement");

        BackgroundAnswerPolicy clock = new BackgroundAnswerPolicy();
        clock.leave("clock", START, WALL);
        clock.resume(START + 11_000, WALL - 86_400_000);
        check(clock.violations == 1, "changing the wall clock cannot extend the grace");
        BackgroundAnswerPolicy restart = new BackgroundAnswerPolicy();
        restart.leave("restart", START, WALL);
        restart.resume(1_000, WALL + 11_000);
        check(restart.violations == 1, "elapsed clock rollback after reboot still expires the question");
        BackgroundAnswerPolicy foreground = new BackgroundAnswerPolicy();
        foreground.leave("short", START, WALL);
        foreground.resume(START + 2_000, WALL + 2_000);
        foreground.evaluate(START + 60_000, WALL + 60_000);
        check(foreground.violations == 0, "foreground thinking time never counts as background");
        System.out.println("Background answer policy: " + assertions + " checks passed");
    }
}
