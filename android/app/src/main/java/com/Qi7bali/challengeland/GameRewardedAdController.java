package com.qi7bali.landchallengeonline;

import android.app.Activity;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import androidx.annotation.NonNull;
import com.google.android.gms.ads.AdError;
import com.google.android.gms.ads.AdRequest;
import com.google.android.gms.ads.FullScreenContentCallback;
import com.google.android.gms.ads.LoadAdError;
import com.google.android.gms.ads.MobileAds;
import com.google.android.gms.ads.rewarded.RewardItem;
import com.google.android.gms.ads.rewarded.RewardedAd;
import com.google.android.gms.ads.rewarded.RewardedAdLoadCallback;
import com.google.android.ump.UserMessagingPlatform;

/** Rewarded ads for category rentals, second chances and reward doubling. */
public final class GameRewardedAdController {
    private static final String TAG = "GameRewardedAd";
    private final Activity activity;
    private final Handler handler = new Handler(Looper.getMainLooper());
    private RewardedAd rewardedAd;
    private boolean isLoading;
    private boolean isShowing;
    private RewardCallback pendingCallback;
    private final Runnable loadTimeout = () -> failPending(
            "استغرق تحميل الإعلان وقتاً طويلاً. حاول مرة أخرى.");

    public interface RewardCallback {
        void onRewardEarned(RewardItem reward);
        void onAdClosed(boolean userEarnedReward);
        void onAdFailedToLoad(String errorReason);
    }

    public GameRewardedAdController(Activity activity) {
        this.activity = activity;
    }

    private boolean activityAvailable() {
        return !activity.isFinishing() && !activity.isDestroyed();
    }

    public void preload() {
        if (!activityAvailable() || rewardedAd != null || isLoading) return;
        // The Flutter entry point gathers UMP consent before opening the game.
        if (!UserMessagingPlatform.getConsentInformation(activity).canRequestAds()) {
            Log.w(TAG, "Ad requests blocked by consent status.");
            failPending("الإعلانات غير متاحة قبل استكمال إعدادات الخصوصية. أعد فتح التطبيق وحاول مجدداً.");
            return;
        }
        isLoading = true;
        try {
            NativeAdRuntime.whenReady(activity, () -> {
                if (!activityAvailable()) {
                    isLoading = false;
                    clearPending();
                    return;
                }
                try {
                    RewardedAd.load(activity, activity.getString(R.string.rewarded_ad_id),
                            new AdRequest.Builder().build(), new RewardedAdLoadCallback() {
                        @Override
                        public void onAdLoaded(@NonNull RewardedAd ad) {
                            isLoading = false;
                            if (!activityAvailable()) {
                                clearPending();
                                return;
                            }
                            rewardedAd = ad;
                            Log.d(TAG, "Rewarded ad loaded: " + ad.getResponseInfo());
                            RewardCallback callback = clearPending();
                            if (callback != null) show(callback);
                        }

                        @Override
                        public void onAdFailedToLoad(@NonNull LoadAdError error) {
                            rewardedAd = null;
                            isLoading = false;
                            Log.w(TAG, "Rewarded load failed: " + error);
                            failPending(loadErrorMessage(error));
                        }
                    });
                } catch (Exception error) {
                    onRequestException(error);
                }
            }, () -> onRequestException(new IllegalStateException("SDK initialization failed")));
        } catch (Exception error) {
            onRequestException(error);
        }
    }

    private void onRequestException(Exception error) {
        isLoading = false;
        Log.w(TAG, "Rewarded request failed", error);
        failPending("تعذر تجهيز الإعلان حالياً. حاول مرة أخرى لاحقاً.");
    }

    private String loadErrorMessage(LoadAdError error) {
        if (MobileAds.ERROR_DOMAIN.equals(error.getDomain())) {
            // A server rejection can also use code 3; preserve that distinction.
            if (error.getMessage().contains("HTTP response code: 403")) {
                return "خدمة الإعلانات لم تقبل الطلب حالياً. حاول مرة أخرى لاحقاً.";
            }
            if (error.getCode() == AdRequest.ERROR_CODE_NETWORK_ERROR) {
                return "تعذر الاتصال بخدمة الإعلانات. تحقق من اتصالك وحاول مجدداً.";
            }
            if (error.getCode() == AdRequest.ERROR_CODE_NO_FILL) {
                return "لا يوجد إعلان متاح حالياً. حاول مرة أخرى لاحقاً.";
            }
        }
        return "تعذر تحميل الإعلان حالياً. حاول مرة أخرى لاحقاً.";
    }

    private RewardCallback clearPending() {
        handler.removeCallbacks(loadTimeout);
        RewardCallback callback = pendingCallback;
        pendingCallback = null;
        return callback;
    }

    private void failPending(String message) {
        RewardCallback callback = clearPending();
        if (callback != null && activityAvailable()) callback.onAdFailedToLoad(message);
    }

    public boolean isLoaded() {
        return rewardedAd != null;
    }

    public void show(@NonNull RewardCallback callback) {
        if (!activityAvailable()) return;
        if (!NativeAdRuntime.isForeground(activity)) {
            callback.onAdFailedToLoad("عد إلى اللعبة وحاول عرض الإعلان مجددًا.");
            return;
        }
        if (isShowing || pendingCallback != null) {
            callback.onAdFailedToLoad("الإعلان قيد التحميل أو العرض. يرجى الانتظار.");
            return;
        }
        if (rewardedAd == null) {
            pendingCallback = callback;
            handler.postDelayed(loadTimeout, 20_000);
            preload(); // Reuses an in-flight preload.
            return;
        }

        final RewardedAd ad = rewardedAd;
        rewardedAd = null;
        isShowing = true;
        final boolean[] earned = {false};
        ad.setFullScreenContentCallback(new FullScreenContentCallback() {
            @Override
            public void onAdDismissedFullScreenContent() {
                isShowing = false;
                if (activityAvailable()) {
                    callback.onAdClosed(earned[0]);
                    preload();
                }
            }

            @Override
            public void onAdFailedToShowFullScreenContent(@NonNull AdError error) {
                isShowing = false;
                Log.w(TAG, "Rewarded show failed: " + error);
                if (activityAvailable()) {
                    callback.onAdFailedToLoad("تعذر عرض الإعلان حالياً. حاول مرة أخرى لاحقاً.");
                    preload();
                }
            }
        });
        try {
            ad.show(activity, reward -> {
                if (earned[0] || !activityAvailable()) return;
                earned[0] = true;
                callback.onRewardEarned(reward);
            });
        } catch (Exception error) {
            isShowing = false;
            Log.w(TAG, "Rewarded presentation failed", error);
            callback.onAdFailedToLoad("تعذر عرض الإعلان حالياً. حاول مرة أخرى لاحقاً.");
            preload();
        }
    }
}
