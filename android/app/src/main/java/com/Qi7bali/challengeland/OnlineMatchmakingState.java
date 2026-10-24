package com.qi7bali.landchallengeonline;

import java.util.Map;

/** Both queue seats are claimed atomically, including simultaneous mutual searches. */
final class OnlineMatchmakingState {
    private OnlineMatchmakingState() {}

    static boolean claim(Map<String, Object> queue, String me, String other,
                         String sessionId, long now) {
        if (me.equals(other)) return false;
        Map<String, Object> theirs = OnlineDuelState.map(queue.get(other));
        Map<String, Object> mine = OnlineDuelState.map(queue.get(me));
        int myStake = amount(mine), theirStake = amount(theirs);
        if (myStake < 0 || theirStake < 0 || myStake != theirStake) return false;
        if ("matched".equals(mine.get("status")) && "matched".equals(theirs.get("status"))
                && other.equals(mine.get("acceptedBy")) && me.equals(theirs.get("acceptedBy"))) return true;
        if (!available(theirs, me, now) || !available(mine, other, now)) return false;
        mine.put("acceptedBy", other);
        theirs.put("acceptedBy", me);
        mine.put("status", "matched");
        theirs.put("status", "matched");
        mine.put("sessionId", sessionId);
        theirs.put("sessionId", sessionId);
        queue.put(me, mine);
        queue.put(other, theirs);
        return true;
    }

    private static int amount(Map<String, Object> request) {
        Object value = request.get("stakeCoins");
        if (value == null) return 0; // Older clients participate in the free queue only.
        if (!(value instanceof Number)) return -1;
        long amount = ((Number) value).longValue();
        return amount == ((Number) value).doubleValue() && amount <= Integer.MAX_VALUE
                && validAmount((int) amount) ? (int) amount : -1;
    }

    static boolean validAmount(int amount) {
        return amount == 0 || amount == 50 || amount == 100 || amount == 250
                || amount == 500 || amount == 1000 || amount == 2500 || amount == 5000;
    }

    private static boolean available(Map<String, Object> request, String claimant, long now) {
        Object created = request.get("createdAt");
        String target = String.valueOf(request.getOrDefault("targetId", ""));
        String accepted = String.valueOf(request.getOrDefault("acceptedBy", "0"));
        return !request.isEmpty() && "waiting".equals(request.get("status"))
                && (accepted.isEmpty() || "0".equals(accepted))
                && (target.isEmpty() || target.equals(claimant))
                && created instanceof Number && now - ((Number) created).longValue() < 120_000L;
    }
}
