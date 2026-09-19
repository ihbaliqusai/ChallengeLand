package com.qi7bali.landchallengeonline;

import android.app.Activity;
import android.util.Log;

import androidx.annotation.NonNull;

import com.google.android.gms.ads.AdError;
import com.google.android.gms.ads.AdRequest;
import com.google.android.gms.ads.FullScreenContentCallback;
import com.google.android.gms.ads.LoadAdError;
import com.google.android.gms.ads.MobileAds;
import com.google.android.gms.ads.OnUserEarnedRewardListener;
import com.google.android.gms.ads.rewarded.RewardItem;
import com.google.android.gms.ads.rewarded.RewardedAd;
import com.google.android.gms.ads.rewarded.RewardedAdLoadCallback;

/**
 * Controller for loading and showing AdMob rewarded ads in native game activities.
 * Used for unlocking categories for 24h, second chances, and post-game reward doubling.
 */
public final class GameRewardedAdController {
    private static final String TAG = "GameRewardedAd";
    private final Activity activity;
    private RewardedAd rewardedAd;
    private boolean isLoading = false;

    public interface RewardCallback {
        void onRewardEarned(RewardItem reward);
        void onAdClosed(boolean userEarnedReward);
        void onAdFailedToLoad(String errorReason);
    }

    public GameRewardedAdController(Activity activity) {
        this.activity = activity;
    }

    public void preload() {
        if (rewardedAd != null || isLoading) return;
        isLoading = true;
        try {
            MobileAds.initialize(activity, status -> {});
            String adUnitId = activity.getString(R.string.rewarded_ad_id);
            AdRequest adRequest = new AdRequest.Builder().build();

            RewardedAd.load(activity, adUnitId, adRequest, new RewardedAdLoadCallback() {
                @Override
                public void onAdLoaded(@NonNull RewardedAd ad) {
                    rewardedAd = ad;
                    isLoading = false;
                    Log.d(TAG, "RewardedAd successfully loaded.");
                }

                @Override
                public void onAdFailedToLoad(@NonNull LoadAdError loadAdError) {
                    rewardedAd = null;
                    isLoading = false;
                    Log.w(TAG, "RewardedAd failed to load: " + loadAdError.getMessage());
                }
            });
        } catch (Exception e) {
            isLoading = false;
            Log.w(TAG, "Failed initializing or loading rewarded ad", e);
        }
    }

    public boolean isLoaded() {
        return rewardedAd != null;
    }

    public void show(@NonNull RewardCallback callback) {
        if (rewardedAd != null) {
            final boolean[] earned = {false};
            rewardedAd.setFullScreenContentCallback(new FullScreenContentCallback() {
                @Override
                public void onAdDismissedFullScreenContent() {
                    rewardedAd = null;
                    preload(); // Preload next
                    callback.onAdClosed(earned[0]);
                }

                @Override
                public void onAdFailedToShowFullScreenContent(@NonNull AdError adError) {
                    rewardedAd = null;
                    preload();
                    callback.onAdFailedToLoad("فشل عرض الإعلان: " + adError.getMessage());
                }
            });

            rewardedAd.show(activity, new OnUserEarnedRewardListener() {
                @Override
                public void onUserEarnedReward(@NonNull RewardItem rewardItem) {
                    earned[0] = true;
                    callback.onRewardEarned(rewardItem);
                }
            });
        } else {
            // Attempt on-demand load and show
            isLoading = true;
            try {
                String adUnitId = activity.getString(R.string.rewarded_ad_id);
                AdRequest adRequest = new AdRequest.Builder().build();
                RewardedAd.load(activity, adUnitId, adRequest, new RewardedAdLoadCallback() {
                    @Override
                    public void onAdLoaded(@NonNull RewardedAd ad) {
                        rewardedAd = ad;
                        isLoading = false;
                        show(callback);
                    }

                    @Override
                    public void onAdFailedToLoad(@NonNull LoadAdError loadAdError) {
                        rewardedAd = null;
                        isLoading = false;
                        callback.onAdFailedToLoad("تعذر تحميل الإعلان حالياً، تحقق من اتصال الإنترنت.");
                    }
                });
            } catch (Exception e) {
                isLoading = false;
                callback.onAdFailedToLoad("حدث خطأ أثناء تحميل الإعلان.");
            }
        }
    }
}
