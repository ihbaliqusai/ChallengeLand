package com.qi7bali.landchallengeonline;

import android.content.Context;

/** Exercises the actual compiled PlayerProgress store against an in-memory backend. */
public final class CurrencyClaimsCheck {
    public static void main(String[] args) {
        VerificationContext context = new VerificationContext();
        context.account().values.put("coins", 500);
        context.account().values.put("gems", 10);
        check(PlayerProgress.grantCurrencyOnce(context, "stage_1", 122, 2), "first payout succeeds");
        balance(context, 622, 12);
        check(context.account().lastCommit.size() == 3, "claim and both balances share one commit");
        check(!PlayerProgress.grantCurrencyOnce(context, "stage_1", 122, 2), "retry does not pay twice");
        balance(context, 622, 12);
        check(PlayerProgress.grantCurrencyOnce(context, "stage_2", 20, 3), "distinct claim succeeds");
        balance(context, 642, 15);

        context.account().failNextCommit = true;
        try {
            PlayerProgress.grantCurrencyOnce(context, "retry_after_disk_failure", 100, 1);
            throw new AssertionError("failed disk write must report failure");
        } catch (IllegalStateException expected) {
            balance(context, 642, 15);
            check(!context.account().getBoolean("currencyClaim:retry_after_disk_failure", false), "failed claim remains retryable");
        }
        check(PlayerProgress.grantCurrencyOnce(context, "retry_after_disk_failure", 100, 1), "retry after failure succeeds");
        balance(context, 742, 16);
        check(!PlayerProgress.grantCurrencyOnce(context, "retry_after_disk_failure", 100, 1), "successful retry is deduplicated");

        VerificationContext capped = new VerificationContext();
        capped.account().values.put("coins", Integer.MAX_VALUE - 1);
        capped.account().values.put("gems", 10);
        check(PlayerProgress.grantCurrencyOnce(capped, "cap", 100, -50), "bounded payout succeeds");
        balance(capped, Integer.MAX_VALUE, 0);
        verifyConcurrentRetries();
        verifyRandomStakes();
        System.out.println("Currency claim regression checks passed");
    }

    private static void verifyRandomStakes() {
        VerificationContext c = new VerificationContext();
        c.switchAccount("alice");
        PlayerProgress.setCurrency(c, 1000, 10);
        check(!RandomStakeLedger.reserve(c, "bad", 15), "retired stake rejected");
        check(!RandomStakeLedger.reserve(c, "poor", 2500), "insufficient balance rejected");
        balance(c, 1000, 10);
        check(RandomStakeLedger.reserve(c, "win", 250), "reserve full contribution before play");
        balance(c, 750, 10);
        check(RandomStakeLedger.reserve(c, "win", 250), "reservation retry is idempotent");
        check(!RandomStakeLedger.reserve(c, "win", 500), "amount cannot change on retry");
        check(RandomStakeLedger.activate(c, "win"), "activate reservation");
        RandomStakeLedger.cancel(c, "win");
        balance(c, 750, 10);
        check(RandomStakeLedger.settle(c, "win", true, false), "winner receives pot");
        balance(c, 1250, 10);
        check(!RandomStakeLedger.settle(c, "win", true, false), "result recreation cannot pay again");
        check(RandomStakeLedger.reserve(c, "loss", 250), "reserve next match");
        RandomStakeLedger.activate(c, "loss");
        RandomStakeLedger.settle(c, "loss", false, false);
        balance(c, 1000, 10);
        check(RandomStakeLedger.reserve(c, "draw", 500), "reserve draw");
        RandomStakeLedger.activate(c, "draw");
        RandomStakeLedger.settle(c, "draw", false, true);
        balance(c, 1000, 10);
        check(RandomStakeLedger.reserve(c, "cancel", 500), "reserve cancellable search");
        RandomStakeLedger.cancel(c, "cancel");
        RandomStakeLedger.cancel(c, "cancel");
        balance(c, 1000, 10);
        check(RandomStakeLedger.reserve(c, "killed_search", 500), "reserve before process death");
        check(RandomStakeLedger.reserve(c, "new_search", 50), "new search refunds unstarted old hold");
        balance(c, 950, 10);
        c.switchAccount("bob");
        RandomStakeLedger.cancel(c, "new_search");
        balance(c, 0, 0);
        c.switchAccount("alice");
        RandomStakeLedger.cancel(c, "new_search");
        balance(c, 1000, 10);
        c.account().failNextCommit = true;
        try {
            RandomStakeLedger.reserve(c, "disk_retry", 100);
            throw new AssertionError("failed reservation must report failure");
        } catch (IllegalStateException expected) { balance(c, 1000, 10); }
        check(RandomStakeLedger.reserve(c, "disk_retry", 100), "reservation retries after disk failure");
        RandomStakeLedger.activate(c, "disk_retry");
        c.account().failNextCommit = true;
        try {
            RandomStakeLedger.settle(c, "disk_retry", true, false);
            throw new AssertionError("failed payout must report failure");
        } catch (IllegalStateException expected) { balance(c, 900, 10); }
        check(RandomStakeLedger.settle(c, "disk_retry", true, false), "payout retries after disk failure");
        balance(c, 1100, 10);
    }

    private static void verifyConcurrentRetries() {
        VerificationContext context = new VerificationContext();
        java.util.concurrent.atomic.AtomicInteger grants = new java.util.concurrent.atomic.AtomicInteger();
        Thread[] retries = new Thread[8];
        for (int i = 0; i < retries.length; i++) {
            retries[i] = new Thread(() -> {
                if (PlayerProgress.grantCurrencyOnce(context, "same_attempt", 100, 2)) grants.incrementAndGet();
            });
            retries[i].start();
        }
        for (Thread retry : retries) {
            try { retry.join(); }
            catch (InterruptedException exception) { throw new AssertionError(exception); }
        }
        check(grants.get() == 1, "simultaneous retries apply one grant");
        balance(context, 100, 2);
    }

    private static void balance(Context context, int coins, int gems) {
        check(PlayerProgress.getCoins(context) == coins, "coin balance");
        check(PlayerProgress.getGems(context) == gems, "gem balance");
    }

    private static void check(boolean condition, String message) {
        if (!condition) throw new AssertionError(message);
    }

}
