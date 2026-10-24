-dontwarn com.squareup.okhttp.Cache
-dontwarn com.squareup.okhttp.CacheControl$Builder
-dontwarn com.squareup.okhttp.CacheControl
-dontwarn com.squareup.okhttp.Call
-dontwarn com.squareup.okhttp.OkHttpClient
-dontwarn com.squareup.okhttp.Request$Builder
-dontwarn com.squareup.okhttp.Request
-dontwarn com.squareup.okhttp.Response
-dontwarn com.squareup.okhttp.ResponseBody

# Google Play Billing & In-App Purchase
-keep class com.android.billingclient.** { *; }
-keep interface com.android.billingclient.** { *; }
-keep class com.qi7bali.landchallengeonline.PlayBillingManager { *; }
-keep class io.flutter.plugins.inapppurchase.** { *; }
