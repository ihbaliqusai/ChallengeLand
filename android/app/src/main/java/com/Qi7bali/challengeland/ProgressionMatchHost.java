package com.qi7bali.landchallengeonline;

/** Game-specific identity; a resumed match and each of its answers keep their IDs. */
public interface ProgressionMatchHost {
    String progressionMatchId();
    String progressionMode();
    String progressionAnswerId();
    boolean progressionOnline();
    boolean progressionHumanOpponents();
}
