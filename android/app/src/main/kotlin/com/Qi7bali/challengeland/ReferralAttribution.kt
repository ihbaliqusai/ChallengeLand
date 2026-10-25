package com.qi7bali.landchallengeonline

import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.AtomicFile
import com.android.installreferrer.api.InstallReferrerClient
import com.android.installreferrer.api.InstallReferrerStateListener
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.security.MessageDigest
import java.util.Locale
import java.util.UUID

/** Install attribution is a convenience, not a server-verifiable installation receipt. */
internal class ReferralAttribution(context: Context) {
    private val context = context.applicationContext
    private val main = Handler(Looper.getMainLooper())
    // Do not restore pending invitations or the fallback installation ID from Android backup.
    private val file = AtomicFile(File(this.context.noBackupFilesDir, "referral-attribution-v1.json"))
    private var cachedState: JSONObject? = null
    private val state: JSONObject
        get() = cachedState ?: loadState().also { cachedState = it }

    private fun loadState(): JSONObject =
        if (file.baseFile.exists() || File(file.baseFile.path + ".bak").exists()) {
            file.openRead().use { JSONObject(it.readBytes().toString(Charsets.UTF_8)) }.also {
                check(UUID.fromString(it.getString("installation")).toString() == it.getString("installation"))
            }
        } else {
            JSONObject().put("installation", UUID.randomUUID().toString()).also(::persist)
        }
    private var client: InstallReferrerClient? = null
    private var inFlight = false
    private val listeners = mutableListOf<() -> Unit>()

    val installId: String by lazy {
        val raw = Settings.Secure.getString(this.context.contentResolver, Settings.Secure.ANDROID_ID)
        if (!raw.isNullOrBlank() && raw != "9774d56d682e549c") {
            // Android scopes this value to the app signing key, Android user and device.
            // Only the app-scoped digest leaves the native layer, never the original value.
            val bytes = MessageDigest.getInstance("SHA-256")
                .digest("${this.context.packageName}:referrals:v1:$raw".toByteArray(Charsets.UTF_8))
            "android_" + bytes.joinToString("") { "%02x".format(it.toInt() and 0xff) }
        } else "install_" + state.getString("installation")
    }

    private fun persist(value: JSONObject) {
        val stream = file.startWrite()
        try {
            stream.write(value.toString().toByteArray(Charsets.UTF_8))
            file.finishWrite(stream)
        } catch (error: Exception) {
            file.failWrite(stream)
            throw error
        }
    }

    private fun update(change: (JSONObject) -> Unit) {
        val changed = JSONObject(state.toString())
        change(changed)
        persist(changed)
        cachedState = changed
    }

    private fun normalized(raw: String?): String? = raw?.trim()?.uppercase(Locale.ROOT)
        ?.takeIf { it.matches(Regex("CL-[A-Z0-9]{6,32}")) }

    fun captureLink(uri: Uri?) {
        if (uri?.scheme != "challengeland" || uri.host != "invite") return
        capture(uri.getQueryParameter("code"))
    }

    private fun capture(raw: String?) {
        val code = normalized(raw) ?: return
        val consumed = state.optJSONArray("consumed") ?: JSONArray()
        if ((0 until consumed.length()).any { consumed.optString(it) == code }) return
        // A pending explicit link wins over the asynchronously retrieved Play referrer.
        update { it.put("code", code) }
    }

    fun clear(code: String): Boolean {
        val clean = normalized(code) ?: return false
        if (state.optString("code") != clean) return false
        val old = state.optJSONArray("consumed") ?: JSONArray()
        val consumed = JSONArray()
        for (index in maxOf(0, old.length() - 9) until old.length()) consumed.put(old.optString(index))
        consumed.put(clean)
        update { it.put("consumed", consumed).remove("code") }
        return true
    }

    private fun snapshot(): Map<String, Any> = mapOf(
        "code" to state.optString("code", ""),
        "installId" to installId,
        "installedAtMillis" to context.packageManager.getPackageInfo(context.packageName, 0).firstInstallTime
    )

    fun pending(callback: (Map<String, Any>) -> Unit, onError: () -> Unit) {
        val finish = {
            try { callback(snapshot()) }
            catch (_: Exception) { onError() }
        }
        if (state.optString("code").isNotEmpty() || state.optBoolean("fetched")) {
            finish()
            return
        }
        listeners.add(finish)
        start()
    }

    fun start() {
        if (state.optBoolean("fetched") || inFlight) return
        inFlight = true
        val connection = InstallReferrerClient.newBuilder(context).build()
        client = connection
        try {
            connection.startConnection(object : InstallReferrerStateListener {
                override fun onInstallReferrerSetupFinished(responseCode: Int) {
                    main.post {
                        if (client !== connection) return@post
                        try {
                            if (responseCode == InstallReferrerClient.InstallReferrerResponse.OK) {
                                val raw = connection.installReferrer.installReferrer
                                val code = Uri.parse("https://referral.invalid/?$raw").getQueryParameter("cl_referral")
                                if (state.optString("code").isEmpty()) capture(code)
                                update { it.put("fetched", true) }
                            } else if (responseCode == InstallReferrerClient.InstallReferrerResponse.FEATURE_NOT_SUPPORTED) {
                                update { it.put("fetched", true) }
                            }
                        } catch (_: Exception) {
                            // Keep a transient Play failure retryable on the next request.
                        } finally {
                            complete(connection)
                        }
                    }
                }

                override fun onInstallReferrerServiceDisconnected() {
                    main.post { complete(connection) }
                }
            })
            // Sideloaded builds and unavailable stores must never block startup or manual codes.
            main.postDelayed({ complete(connection) }, 4000)
        } catch (_: Exception) {
            complete(connection)
        }
    }

    private fun complete(connection: InstallReferrerClient) {
        if (client !== connection) return
        client = null
        inFlight = false
        try { connection.endConnection() } catch (_: Exception) { }
        val waiting = listeners.toList()
        listeners.clear()
        waiting.forEach { it() }
    }

    fun close() {
        client?.let(::complete)
    }
}
