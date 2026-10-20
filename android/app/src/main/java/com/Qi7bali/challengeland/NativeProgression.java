package com.qi7bali.landchallengeonline;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.os.Bundle;
import java.util.UUID;

/** Carries immutable match identity into result screens and through Android recreation. */
public final class NativeProgression {
    private NativeProgression() {}
    private static final String ID = "progressionMatchId";
    private static final String ACCOUNT = "progressionAccountUid";

    public static void restore(Activity a, Bundle state) {
        Intent i = a.getIntent();
        if (state != null) {
            if (state.containsKey(ID)) i.putExtra(ID, state.getString(ID));
            if (state.containsKey(ACCOUNT)) i.putExtra(ACCOUNT, state.getString(ACCOUNT));
            if (state.containsKey("economySessionId")) i.putExtra("economySessionId", state.getString("economySessionId"));
            if (state.containsKey("randomStakeId")) i.putExtra("randomStakeId", state.getString("randomStakeId"));
        }
        String matchId = i.getStringExtra(ID), account = i.getStringExtra(ACCOUNT);
        if (matchId == null || matchId.trim().isEmpty()) i.putExtra(ID, UUID.randomUUID().toString());
        if (account == null || account.trim().isEmpty()) i.putExtra(ACCOUNT, ProgressionAccount.uid(a));
    }

    public static void save(Activity a, Bundle state) {
        restore(a, null);
        state.putString(ID, a.getIntent().getStringExtra(ID));
        state.putString(ACCOUNT, a.getIntent().getStringExtra(ACCOUNT));
        state.putString("economySessionId", a.getIntent().getStringExtra("economySessionId"));
        state.putString("randomStakeId", a.getIntent().getStringExtra("randomStakeId"));
    }

    public static String fallbackId(Activity a) {
        restore(a, null);
        return a.getIntent().getStringExtra(ID);
    }

    public static boolean activeAccount(Context c) {
        if (!(c instanceof Activity)) return true;
        String owner = ((Activity)c).getIntent().getStringExtra(ACCOUNT);
        return owner == null || owner.equals(ProgressionAccount.uid(c));
    }

    public static String matchId(Context c) {
        if (c instanceof ProgressionMatchHost) return ((ProgressionMatchHost)c).progressionMatchId();
        if (c instanceof Activity) return fallbackId((Activity)c);
        throw new IllegalArgumentException("Match progress requires a stable match identity");
    }

    public static String mode(Context c) {
        if (c instanceof ProgressionMatchHost) return ((ProgressionMatchHost)c).progressionMode();
        return c instanceof Activity ? ((Activity)c).getIntent().getStringExtra("progressionMode") : "offline";
    }

    public static boolean online(Context c) {
        if (c instanceof ProgressionMatchHost) return ((ProgressionMatchHost)c).progressionOnline();
        return c instanceof Activity && ((Activity)c).getIntent().getBooleanExtra("progressionOnline", false);
    }

    public static boolean humanOnline(Context c) {
        if (!online(c)) return false;
        if (c instanceof ProgressionMatchHost) return ((ProgressionMatchHost)c).progressionHumanOpponents();
        return c instanceof Activity && ((Activity)c).getIntent().getBooleanExtra("progressionHumanOnline", false);
    }

    public static String answerId(Context c) {
        return c instanceof ProgressionMatchHost ? ((ProgressionMatchHost)c).progressionAnswerId() : "";
    }

    public static void copyToResult(Activity a, Intent result) {
        result.putExtra("economySessionId", a.getIntent().getStringExtra("economySessionId"));
        result.putExtra("economyMatchId", a.getIntent().getStringExtra("economyMatchId"));
        result.putExtra(ID, matchId(a));
        result.putExtra(ACCOUNT, a.getIntent().getStringExtra(ACCOUNT));
        result.putExtra("progressionMode", mode(a));
        result.putExtra("progressionOnline", online(a));
        result.putExtra("progressionHumanOnline", humanOnline(a));
    }
}
