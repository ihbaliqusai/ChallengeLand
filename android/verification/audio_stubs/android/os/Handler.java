package android.os;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;

/** A deterministic main-thread scheduler for real fade callbacks. */
public final class Handler {
    private static final List<Pending> QUEUE = new ArrayList<>();
    private static long nextSequence;
    private static final class Pending {
        final Handler handler;
        final Runnable action;
        final long time;
        final long sequence = nextSequence++;
        Pending(Handler handler, Runnable action, long time) {
            this.handler = handler;
            this.action = action;
            this.time = time;
        }
    }
    public Handler(Looper looper) {}
    public boolean postDelayed(Runnable action, long delay) {
        QUEUE.add(new Pending(this, action, SystemClock.now + delay));
        return true;
    }
    public void removeCallbacks(Runnable action) {
        QUEUE.removeIf(pending -> pending.handler == this && pending.action == action);
    }
    public void removeCallbacksAndMessages(Object token) {
        QUEUE.removeIf(pending -> pending.handler == this);
    }
    public static void advanceBy(long millis) {
        long target = SystemClock.now + millis;
        while (true) {
            Pending next = QUEUE.stream().filter(pending -> pending.time <= target)
                    .min(Comparator.comparingLong((Pending pending) -> pending.time)
                            .thenComparingLong(pending -> pending.sequence)).orElse(null);
            if (next == null) break;
            QUEUE.remove(next);
            SystemClock.now = next.time;
            next.action.run();
        }
        SystemClock.now = target;
    }
    public static int pendingCount() { return QUEUE.size(); }
    public static void reset() {
        QUEUE.clear();
        nextSequence = 0;
        SystemClock.now = 0;
    }
}
