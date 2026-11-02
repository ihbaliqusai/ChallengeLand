package com.qi7bali.landchallengeonline

import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import com.google.android.gms.tasks.Task
import com.google.android.gms.tasks.Tasks
import com.google.firebase.remoteconfig.FirebaseRemoteConfig
import com.google.firebase.remoteconfig.FirebaseRemoteConfigSettings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/** Cached policy first; network fetching never blocks Android's UI thread. */
class AppUpdateController(
    private val activity: FlutterActivity,
    messenger: BinaryMessenger
) : DefaultLifecycleObserver {
    private val channel = MethodChannel(messenger, "challengeland/app-update")
    private val config = FirebaseRemoteConfig.getInstance()
    private var disposed = false
    private var refreshing: Task<Boolean>? = null
    private val ready = Tasks.whenAll(
        config.ensureInitialized(),
        config.setDefaultsAsync(mapOf(
            ENABLED to false, MINIMUM_BUILD to 0L, MESSAGE to DEFAULT_MESSAGE
        )),
        config.setConfigSettingsAsync(FirebaseRemoteConfigSettings.Builder()
            .setMinimumFetchIntervalInSeconds(300)
            .setFetchTimeoutInSeconds(5)
            .build())
    )

    init {
        activity.lifecycle.addObserver(this)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getPolicy" -> ready.addOnCompleteListener {
                    if (!disposed) result.success(snapshot())
                }
                "refreshPolicy" -> {
                    val pending = refreshing
                    val task = if (pending != null && !pending.isComplete) pending else {
                        ready.continueWithTask {
                            if (call.argument<Boolean>("force") == true) {
                                config.fetch(0).continueWithTask { fetched ->
                                    if (!fetched.isSuccessful) throw fetched.exception
                                        ?: IllegalStateException("Policy fetch failed")
                                    config.activate()
                                }
                            } else config.fetchAndActivate()
                        }.also { refreshing = it }
                    }
                    task.addOnCompleteListener { fetched ->
                        // A failed fetch keeps the last activated policy. It must
                        // never dismiss a previously known required update.
                        if (!disposed) result.success(snapshot(fetched.isSuccessful))
                    }
                }
                "openStore" -> result.success(openStore())
                else -> result.notImplemented()
            }
        }
    }

    @Suppress("DEPRECATION")
    private fun installedVersion() = if (Build.VERSION.SDK_INT >= 33) {
        activity.packageManager.getPackageInfo(activity.packageName,
            android.content.pm.PackageManager.PackageInfoFlags.of(0))
    } else activity.packageManager.getPackageInfo(activity.packageName, 0)

    private fun snapshot(fetchSucceeded: Boolean = true): Map<String, Any> {
        val installed = installedVersion()
        val build = if (Build.VERSION.SDK_INT >= 28) installed.longVersionCode
            else @Suppress("DEPRECATION") installed.versionCode.toLong()
        val enabled = config.getValue(ENABLED)
        val minimum = config.getValue(MINIMUM_BUILD)
        val verified = enabled.source == FirebaseRemoteConfig.VALUE_SOURCE_REMOTE &&
            minimum.source == FirebaseRemoteConfig.VALUE_SOURCE_REMOTE
        return mapOf(
            "installedBuild" to build,
            "installedVersion" to (installed.versionName ?: ""),
            "enabled" to (verified && config.getBoolean(ENABLED)),
            "minimumBuild" to config.getLong(MINIMUM_BUILD),
            "remotePolicy" to verified,
            "message" to config.getString(MESSAGE).trim().take(300).ifEmpty { DEFAULT_MESSAGE },
            "fetchSucceeded" to fetchSucceeded
        )
    }

    fun requiresUpdate(): Boolean {
        val policy = snapshot()
        val installed = policy["installedBuild"] as Long
        val minimum = policy["minimumBuild"] as Long
        return policy["enabled"] == true && installed > 0 &&
            minimum in 1..Int.MAX_VALUE.toLong() && installed < minimum
    }

    private fun openStore(): Boolean {
        // Store destination belongs to this app, never to a remotely supplied URL.
        val packageName = activity.packageName
        try {
            activity.startActivity(Intent(Intent.ACTION_VIEW,
                Uri.parse("market://details?id=$packageName")).setPackage("com.android.vending"))
            return true
        } catch (_: Exception) { /* Devices without Play Store use its web listing. */ }
        return try {
            activity.startActivity(Intent(Intent.ACTION_VIEW,
                Uri.parse("https://play.google.com/store/apps/details?id=$packageName")))
            true
        } catch (_: Exception) { false }
    }

    override fun onDestroy(owner: LifecycleOwner) {
        disposed = true
        channel.setMethodCallHandler(null)
        activity.lifecycle.removeObserver(this)
    }

    companion object {
        const val ENABLED = "force_update_enabled"
        const val MINIMUM_BUILD = "min_android_build"
        const val MESSAGE = "force_update_message_ar"
        const val DEFAULT_MESSAGE = "يتوفر تحديث ضروري لمتابعة اللعب. حدّث اللعبة للحصول على أحدث التحسينات."
    }
}
