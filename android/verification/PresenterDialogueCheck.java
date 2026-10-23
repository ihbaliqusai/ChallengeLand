package com.qi7bali.landchallengeonline;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.PriorityQueue;

/** Deterministic reading/transition checks, with no Android runtime or wall-clock sleeps. */
public final class PresenterDialogueCheck {
    private static final class Task implements Comparable<Task> {
        final long at;
        final int order;
        final Runnable action;
        Task(long at, int order, Runnable action) {
            this.at = at;
            this.order = order;
            this.action = action;
        }
        public int compareTo(Task other) {
            int result = Long.compare(at, other.at);
            return result != 0 ? result : Integer.compare(order, other.order);
        }
    }

    private static final class Harness {
        long now;
        int order;
        final PriorityQueue<Task> tasks = new PriorityQueue<>();
        final ArrayList<String> events = new ArrayList<>();
        final PresenterDialogue dialogue = new PresenterDialogue(() -> now, this::post);
        void post(Runnable action, long delayMs) {
            tasks.add(new Task(now + delayMs, order++, action));
        }
        void advance(long ms) {
            long target = now + ms;
            int count = 0;
            while (!tasks.isEmpty() && tasks.peek().at <= target) {
                if (++count > 10000) throw new AssertionError("scheduler did not settle");
                Task task = tasks.poll();
                now = task.at;
                task.action.run();
            }
            now = target;
        }
        void show(String text, int requestedMs, boolean blocking, long actualTypingMs) {
            dialogue.show(text, requestedMs, blocking, () -> {
                events.add("show:" + text);
                post(dialogue::textCompleted, actualTypingMs);
            }, () -> events.add("hide:" + text));
        }
    }

    public static void main(String[] args) {
        verifyReadingBudget();
        verifyCompleteTextBeforeReading();
        verifyDelayedTyping();
        verifySequentialBubblesAndStaleTimers();
        verifyPromptWaitsForPlayer();
        verifyPausePreservesReadingTime();
        verifyCoalescedTransitions();
        verifyLiveFeedbackDoesNotBlockAnswers();
        verifyBlockingThenLiveCaption();
        verifyDisposalCancelsTransitions();
        verifyCampaignBriefing();
        System.out.println("Presenter dialogue checks passed (11 scenarios)");
    }

    private static void verifyReadingBudget() {
        for (String text : Arrays.asList("إجابة صحيحة!", "السؤال التالي\nبالتوفيق!", "", "  ", "أحسنت 🏆")) {
            long typingMs = (text.length() + 1L) * PresenterDialogue.CHARACTER_DELAY_MS;
            check(PresenterDialogue.visibleTimeMs(text, 1) >= typingMs + 2500,
                    "short bubbles need 2.5 seconds after typing");
        }
        String longText = String.join(" ", java.util.Collections.nCopies(80, "معلومات"));
        check(PresenterDialogue.readingTimeMs(longText) >= 80 * 330L,
                "long instructions must scale with word count without a short cap");
        check(PresenterDialogue.readingTimeMs("كلمة\nثانية\tثالثة")
                        == PresenterDialogue.readingTimeMs("كلمة ثانية ثالثة"),
                "line breaks count as word separators");
        check(PresenterDialogue.visibleTimeMs("نص قصير", 8000) >= 9000,
                "an existing longer presentation must not be shortened");
    }

    private static void verifyCompleteTextBeforeReading() {
        Harness h = new Harness();
        String text = "لا تتجاوز عدد الأخطاء المسموح في هذه المرحلة";
        long typing = (text.length() + 1L) * PresenterDialogue.CHARACTER_DELAY_MS;
        long read = PresenterDialogue.readingTimeMs(text);
        h.show(text, 1, true, typing);
        check(h.dialogue.defer(() -> h.events.add("next-question")), "question must wait");
        h.advance(typing + read - 1);
        check(h.events.size() == 1, "dialogue cannot disappear during the reading allowance");
        h.advance(1);
        check(h.events.equals(Arrays.asList("show:" + text, "hide:" + text, "next-question")),
                "next question follows the completed reading allowance");
    }

    private static void verifyDelayedTyping() {
        Harness h = new Harness();
        h.show("نص", 1, true, 10000);
        h.advance(12499);
        check(h.events.size() == 1, "slow rendering must not consume the reading allowance");
        h.advance(1);
        check(h.events.size() == 2, "reading starts after actual final-character delivery");
    }

    private static void verifySequentialBubblesAndStaleTimers() {
        Harness h = new Harness();
        h.show("الأولى", 1, true, 5000);
        h.show("الثانية", 1, true, 500);
        h.dialogue.defer(() -> h.events.add("next-turn"));
        h.advance(7499);
        check(h.events.equals(Arrays.asList("show:الأولى")), "new messages must not interrupt the current one");
        h.advance(1);
        check(h.events.equals(Arrays.asList("show:الأولى", "hide:الأولى", "show:الثانية")),
                "second bubble starts only after the first has been read");
        h.advance(2999);
        check(h.events.size() == 3, "old hide callbacks cannot hide the newer bubble");
        h.advance(1);
        check(h.events.get(h.events.size() - 1).equals("next-turn"),
                "turn advances after all queued messages have been read");
    }

    private static void verifyPromptWaitsForPlayer() {
        Harness h = new Harness();
        h.show("هل تريد المتابعة؟", 0, true, 100);
        h.show("نبدأ", 1, true, 100);
        h.advance(60000);
        check(h.events.size() == 1, "confirmations must never close automatically");
        h.dialogue.dismissPrompt();
        check(h.events.size() == 2, "next message must not change the selected tag during the click");
        h.advance(0);
        check(h.events.get(2).equals("show:نبدأ"), "the next bubble follows the player's choice");
    }

    private static void verifyPausePreservesReadingTime() {
        Harness h = new Harness();
        h.show("نص", 1, true, 100);
        h.advance(1100);
        h.dialogue.pause();
        h.advance(60000);
        check(h.events.size() == 1, "reading time cannot elapse in the background");
        h.dialogue.resume();
        h.advance(1499);
        check(h.events.size() == 1, "remaining reading time must survive resume");
        h.advance(1);
        check(h.events.size() == 2, "dialogue closes after the remaining visible time");
    }

    private static void verifyCoalescedTransitions() {
        Harness h = new Harness();
        h.show("نص", 1, true, 100);
        h.dialogue.defer("turn", () -> h.events.add("obsolete-transition"));
        h.dialogue.defer("turn", () -> h.events.add("next-turn"));
        h.advance(10000);
        check(h.events.equals(Arrays.asList("show:نص", "hide:نص", "next-turn")),
                "repeated notifications must not advance the same turn twice");
    }

    private static void verifyLiveFeedbackDoesNotBlockAnswers() {
        Harness h = new Harness();
        h.show("إجابة صحيحة!", 700, false, 300);
        check(!h.dialogue.defer(() -> h.events.add("answer")),
                "Blitz and live captions must allow the next answer while remaining readable");
        check(h.dialogue.deferAll("result", () -> h.events.add("show-result")),
                "end-of-match results must still wait for the live caption");
        h.advance(2799);
        check(h.events.size() == 1, "live feedback still has its complete reading allowance");
        h.advance(1);
        check(h.events.equals(Arrays.asList("show:إجابة صحيحة!", "hide:إجابة صحيحة!", "show-result")),
                "live caption is fully read before the result covers it");
    }

    private static void verifyBlockingThenLiveCaption() {
        Harness h = new Harness();
        h.show("نص", 1, true, 100);
        h.show("إجابة صحيحة!", 1, false, 100);
        h.dialogue.defer(() -> h.events.add("next-question"));
        h.advance(2600);
        check(h.events.equals(Arrays.asList("show:نص", "hide:نص", "show:إجابة صحيحة!", "next-question")),
                "nonblocking feedback cannot hold a ready question behind its caption");
    }

    private static void verifyDisposalCancelsTransitions() {
        Harness h = new Harness();
        h.show("نص", 1, true, 100);
        h.dialogue.defer(() -> h.events.add("next-question"));
        h.dialogue.dispose();
        h.advance(60000);
        check(h.events.size() == 1, "destroyed activities cannot receive stale transitions");
    }

    private static void verifyCampaignBriefing() {
        for (String style : Arrays.asList("balanced", "specialist", "speed", "highValue", "mixed")) {
            Harness h = new Harness();
            List<String> lines = CampaignBoardRules.briefingMessages(true, 6, 4, "worldThemed",
                    180, 2, 3, Arrays.asList("العلوم", "التاريخ", "الرياضة"), style, false, 1800, 2400);
            long total = 0;
            for (String line : lines) {
                long typing = (line.length() + 1L) * PresenterDialogue.CHARACTER_DELAY_MS;
                h.show(line, 2200, true, typing);
                total += PresenterDialogue.visibleTimeMs(line, 2200);
            }
            h.dialogue.defer(() -> h.events.add("start-stage-timer"));
            h.advance(total - 1);
            check(!h.events.contains("start-stage-timer"), "stage timer must wait for every rule: " + style);
            h.advance(1);
            check(h.events.size() == lines.size() * 2 + 1, "every campaign line must appear and finish");
            check(h.events.get(h.events.size() - 1).equals("start-stage-timer"),
                    "stage starts only after the last line's reading allowance");
        }
    }

    private static void check(boolean condition, String message) {
        if (!condition) throw new AssertionError(message);
    }
}
