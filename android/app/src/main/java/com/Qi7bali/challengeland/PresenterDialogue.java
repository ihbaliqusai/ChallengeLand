package com.qi7bali.landchallengeonline;

import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.function.LongSupplier;

/** Serializes presenter bubbles and gives the fully revealed text time to be read. */
final class PresenterDialogue {
    static final int CHARACTER_DELAY_MS = 18;
    static final int MIN_READING_MS = 2500;
    private static final int WORD_READING_MS = 330;

    interface Scheduler {
        void postDelayed(Runnable action, long delayMs);
    }

    private static final class Line {
        final boolean blocking;
        final boolean timed;
        final long readingMs;
        final long visibleMs;
        final Runnable show;
        final Runnable hide;
        long deadline;
        boolean textComplete;

        Line(CharSequence text, int requestedMs, boolean blocking, Runnable show, Runnable hide) {
            this.blocking = blocking;
            timed = requestedMs > 0;
            readingMs = readingTimeMs(text);
            visibleMs = visibleTimeMs(text, requestedMs);
            this.show = show;
            this.hide = hide;
        }
    }

    private final LongSupplier clock;
    private final Scheduler scheduler;
    private final ArrayDeque<Line> pending = new ArrayDeque<>();
    private final LinkedHashMap<Object, Runnable> continuations = new LinkedHashMap<>();
    private final LinkedHashMap<Object, Runnable> terminalContinuations = new LinkedHashMap<>();
    private Line current;
    private boolean paused;
    private long pausedAt;
    private boolean disposed;

    PresenterDialogue(LongSupplier clock, Scheduler scheduler) {
        this.clock = clock;
        this.scheduler = scheduler;
    }

    static long readingTimeMs(CharSequence text) {
        String message = text == null ? "" : text.toString().trim();
        int words = message.isEmpty() ? 0 : message.split("\\s+").length;
        int characters = message.codePointCount(0, message.length());
        return Math.max(MIN_READING_MS, Math.max(words * (long) WORD_READING_MS, characters * 35L));
    }

    static long visibleTimeMs(CharSequence text, int requestedMs) {
        if (requestedMs <= 0) return 0; // Confirmation/rules wait for the player's choice.
        int length = text == null ? 0 : text.length();
        return Math.max(requestedMs + 1000L,
                (length + 1L) * CHARACTER_DELAY_MS + readingTimeMs(text));
    }

    void show(CharSequence text, int requestedMs, boolean blocking, Runnable show, Runnable hide) {
        if (disposed) return;
        pending.add(new Line(text, requestedMs, blocking, show, hide));
        startNext();
    }

    private void startNext() {
        if (disposed || paused || current != null) return;
        current = pending.poll();
        if (current == null) {
            releaseContinuations();
            return;
        }
        Line line = current;
        line.deadline = clock.getAsLong() + line.visibleMs;
        line.show.run();
        if (line.timed) scheduleFinish(line);
        releaseContinuations();
    }

    private void releaseContinuations() {
        if (current != null && current.blocking) return;
        for (Line line : pending) if (line.blocking) return;
        ArrayList<Runnable> ready = new ArrayList<>(continuations.values());
        continuations.clear();
        if (current == null && pending.isEmpty()) {
            ready.addAll(terminalContinuations.values());
            terminalContinuations.clear();
        }
        for (Runnable action : ready) scheduler.postDelayed(action, 0);
    }

    /** Called by Typewriter after the last character actually reaches the view. */
    void textCompleted() {
        if (current == null || disposed) return;
        current.textComplete = true;
        if (current.timed) {
            long completedAt = paused ? pausedAt : clock.getAsLong();
            current.deadline = Math.max(current.deadline, completedAt + current.readingMs);
            scheduleFinish(current);
        }
    }

    private void scheduleFinish(Line line) {
        scheduler.postDelayed(() -> {
            if (disposed || paused || current != line || !line.textComplete) return;
            if (clock.getAsLong() < line.deadline) {
                scheduleFinish(line);
                return;
            }
            finishCurrent();
        }, Math.max(0, line.deadline - clock.getAsLong()));
    }

    private void finishCurrent() {
        Line line = current;
        current = null;
        line.hide.run();
        startNext();
    }

    void dismissPrompt() {
        if (current != null && !current.timed) {
            Line line = current;
            current = null;
            line.hide.run();
            // Keep the selected prompt/tag stable until its click handler returns.
            scheduler.postDelayed(this::startNext, 0);
        }
    }

    /** A phase callback must call this before changing questions, turns or screens. */
    boolean defer(Runnable action) {
        return defer(action, action);
    }

    boolean defer(Object key, Runnable action) {
        if (disposed) return true;
        boolean blocking = current != null && current.blocking;
        for (Line line : pending) blocking |= line.blocking;
        if (!blocking) return false;
        continuations.put(key, action);
        return true;
    }

    /** Results must also wait for nonblocking live captions before covering them. */
    boolean deferAll(Object key, Runnable action) {
        if (disposed) return true;
        if (current == null && pending.isEmpty()) return false;
        terminalContinuations.put(key, action);
        return true;
    }

    void pause() {
        if (paused || disposed) return;
        paused = true;
        pausedAt = clock.getAsLong();
    }

    void resume() {
        if (!paused || disposed) return;
        paused = false;
        if (current != null && current.timed) {
            current.deadline += Math.max(0, clock.getAsLong() - pausedAt);
            scheduleFinish(current);
        }
        startNext();
    }

    void dispose() {
        disposed = true;
        current = null;
        pending.clear();
        continuations.clear();
        terminalContinuations.clear();
    }
}
