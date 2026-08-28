package com.qi7bali.landchallengeonline;

final class RoundRankEntry {
    final String playerId;
    final long elapsedMs;

    RoundRankEntry(String playerId, long elapsedMs) {
        this.playerId = playerId;
        this.elapsedMs = elapsedMs;
    }
}
