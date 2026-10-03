package com.qi7bali.landchallengeonline

import android.os.Handler
import android.os.Looper
import android.util.Log
import com.google.firebase.FirebaseApp
import com.google.firebase.auth.FirebaseAuth
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.net.SocketTimeoutException
import java.net.UnknownHostException
import java.security.MessageDigest
import java.util.concurrent.Executors

/** Uses the callable HTTPS protocol without trusting a locally supplied receipt or reward. */
class CommerceVerifier {
    private val executor = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    @Volatile private var closed = false

    companion object {
        fun accountBinding(uid: String): String = MessageDigest.getInstance("SHA-256")
            .digest(uid.toByteArray(Charsets.UTF_8)).joinToString("") { "%02x".format(it) }
    }

    fun call(name: String, data: JSONObject, callback: (String?, JSONObject?, String?) -> Unit) {
        if (closed) return
        val auth = FirebaseAuth.getInstance()
        val user = auth.currentUser
        if (user == null || user.isAnonymous) {
            callback(null, null, "Sign in to protect and restore your purchases.")
            return
        }
        val accountUid = user.uid
        user.getIdToken(false).addOnCompleteListener { task ->
            if (closed) return@addOnCompleteListener
            val token = if (task.isSuccessful) task.result?.token else null
            if (token.isNullOrBlank()) {
                callback(accountUid, null, "Could not authenticate your purchase. Please sign in again.")
                return@addOnCompleteListener
            }
            executor.execute {
                var connection: HttpURLConnection? = null
                try {
                    val projectId = FirebaseApp.getInstance().options.projectId
                        ?: error("The purchase service is not configured.")
                    connection = URL("https://us-central1-$projectId.cloudfunctions.net/$name")
                        .openConnection() as HttpURLConnection
                    connection.requestMethod = "POST"
                    connection.connectTimeout = 15_000
                    connection.readTimeout = 25_000
                    connection.doOutput = true
                    connection.setRequestProperty("Content-Type", "application/json; charset=utf-8")
                    connection.setRequestProperty("Authorization", "Bearer $token")
                    connection.outputStream.use {
                        it.write(JSONObject().put("data", data).toString().toByteArray(Charsets.UTF_8))
                    }
                    val code = connection.responseCode
                    val stream = if (code in 200..299) connection.inputStream else connection.errorStream
                    val body = stream?.bufferedReader(Charsets.UTF_8)?.use { it.readText() }.orEmpty()
                    check(body.length <= 1_048_576) { "Invalid purchase service response." }
                    // Missing Functions and IAM failures return HTML, not callable JSON.
                    // Classify HTTP before parsing so a 404 cannot look like bad connectivity.
                    val envelope = try { JSONObject(body) } catch (_: Exception) { null }
                    if (envelope == null && code == 404) {
                        error("commerce/backend-not-configured: The purchase service has not been deployed.")
                    }
                    if (envelope == null && code == 403) {
                        error("commerce/backend-access-denied: The purchase service is not accessible.")
                    }
                    val error = envelope?.optJSONObject("error")
                    if (code !in 200..299 || error != null) {
                        val message = error?.optString("message")?.takeIf { it.isNotBlank() }
                            ?: "commerce/backend-unavailable: Purchase service is unavailable ($code)."
                        error(message)
                    }
                    val response = envelope?.optJSONObject("result") ?: envelope?.optJSONObject("data")
                        ?: error("commerce/backend-invalid-response: Invalid purchase service response.")
                    main.post { if (!closed) callback(accountUid, response, null) }
                } catch (exception: Exception) {
                    val message = when (exception) {
                        is SocketTimeoutException -> "commerce/timeout: Purchase verification timed out. Please try again."
                        is UnknownHostException -> "commerce/network: Could not connect to the purchase service."
                        else -> exception.message ?: "commerce/backend-unavailable: Purchase verification failed."
                    }
                    // Never log the request, Firebase token, receipt, or an API error body.
                    Log.w("CommerceVerifier", "$name failed (${exception.javaClass.simpleName}).")
                    main.post { if (!closed) callback(accountUid, null, message) }
                } finally {
                    connection?.disconnect()
                }
            }
        }
    }

    fun close() { closed = true; executor.shutdown() }
}
