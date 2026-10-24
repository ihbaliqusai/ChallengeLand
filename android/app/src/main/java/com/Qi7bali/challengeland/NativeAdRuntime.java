package com.qi7bali.landchallengeonline;

import android.app.Activity;
import android.content.Context;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import androidx.lifecycle.Lifecycle;
import androidx.lifecycle.LifecycleOwner;
import com.google.android.gms.ads.AdRequest;
import com.google.android.gms.ads.LoadAdError;
import com.google.android.gms.ads.MobileAds;
import com.google.android.gms.ads.interstitial.InterstitialAd;
import com.google.android.gms.ads.interstitial.InterstitialAdLoadCallback;
import com.google.android.ump.UserMessagingPlatform;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/** Keep SDK initialization off the Android UI thread and use app context. */
final class NativeAdRuntime {
    private static final ExecutorService INIT = Executors.newSingleThreadExecutor();
    private static final Handler MAIN = new Handler(Looper.getMainLooper());

    static void whenReady(Context context, Runnable ready, Runnable failed) {
        Context app = context.getApplicationContext();
        INIT.execute(() -> {
            try {
                MobileAds.initialize(app, status -> MAIN.post(ready));
            } catch (Exception error) {
                Log.w("NativeAdRuntime", "Initialization failed", error);
                MAIN.post(failed);
            }
        });
    }

    static boolean isForeground(Activity activity) {
        if (activity.isFinishing() || activity.isDestroyed()) return false;
        return activity instanceof LifecycleOwner
                ? ((LifecycleOwner) activity).getLifecycle().getCurrentState().isAtLeast(Lifecycle.State.RESUMED)
                : activity.hasWindowFocus();
    }

    static void loadInterstitial(Activity activity, String id, InterstitialAdLoadCallback callback) {
        if (!UserMessagingPlatform.getConsentInformation(activity).canRequestAds()) {
            callback.onAdFailedToLoad(new LoadAdError(0, "Consent is not ready", MobileAds.ERROR_DOMAIN, null, null));
            return;
        }
        whenReady(activity, () -> {
            if (activity.isFinishing() || activity.isDestroyed()) return;
            InterstitialAd.load(activity, id, new AdRequest.Builder().build(), callback);
        }, () -> callback.onAdFailedToLoad(new LoadAdError(0, "SDK initialization failed", MobileAds.ERROR_DOMAIN, null, null)));
    }
}
