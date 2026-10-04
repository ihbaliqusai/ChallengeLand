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
        System.out.println("Currency claim regression checks passed");
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
