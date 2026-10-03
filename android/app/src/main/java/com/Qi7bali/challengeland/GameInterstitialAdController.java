package com.qi7bali.landchallengeonline;

import android.util.Log;

import androidx.appcompat.app.AppCompatActivity;

import com.google.android.gms.ads.AdError;
import com.google.android.gms.ads.FullScreenContentCallback;
import com.google.android.gms.ads.LoadAdError;
import com.google.android.gms.ads.interstitial.InterstitialAd;
import com.google.android.gms.ads.interstitial.InterstitialAdLoadCallback;

final class GameInterstitialAdController {
    private final AppCompatActivity activity;
    private InterstitialAd interstitialAd;
    private boolean loading;
    private boolean showing;

    GameInterstitialAdController(AppCompatActivity activity) {
        this.activity = activity;
    }

    void loadIfNeeded(Runnable onDismissed) {
        try {
            if (interstitialAd != null || loading || activity.isFinishing() || activity.isDestroyed()) return;
            loading = true;
            NativeAdRuntime.loadInterstitial(activity,
                    activity.getResources().getString(R.string.interstitial_ad_id),
                    new InterstitialAdLoadCallback() {
                        @Override
                        public void onAdLoaded(InterstitialAd ad) {
                            loading = false;
                            if (activity.isFinishing() || activity.isDestroyed()) return;
                            interstitialAd = ad;
                            interstitialAd.setFullScreenContentCallback(new FullScreenContentCallback() {
                                @Override
                                public void onAdDismissedFullScreenContent() {
                                    interstitialAd = null;
                                    showing = false;
                                    if (onDismissed != null && !activity.isFinishing() && !activity.isDestroyed()) {
                                        onDismissed.run();
                                    }
                                }

                                @Override
                                public void onAdFailedToShowFullScreenContent(AdError error) {
                                    onAdDismissedFullScreenContent();
                                }
                            });
                        }

                        @Override
                        public void onAdFailedToLoad(LoadAdError error) {
                            interstitialAd = null;
                            loading = false;
                            Log.w("GameInterstitialAd", "Interstitial load failed: " + error);
                        }
                    });
        } catch (Exception e) {
            loading = false;
            Log.w("GameActivity", "initAdsIfNeeded failed", e);
        }
    }

    void showOrRun(Runnable fallback) {
        if (showing || activity.isFinishing() || activity.isDestroyed()) return;
        AppPrefs.recordInterstitialOpportunity(activity);
        if (interstitialAd != null && NativeAdRuntime.isForeground(activity) && AppPrefs.canShowInterstitialNow(activity)) {
            AppPrefs.markInterstitialShown(activity);
            showing = true;
            InterstitialAd ad = interstitialAd;
            interstitialAd = null;
            try {
                ad.show(activity);
            } catch (Exception error) {
                showing = false;
                if (fallback != null) fallback.run();
            }
        } else if (fallback != null) {
            fallback.run();
        }
    }
}
