package com.maqwati.smsgateway.integration

import android.content.Context
import android.telephony.SmsManager
import android.telephony.SubscriptionManager
import java.net.HttpURLConnection
import java.net.URL
import java.security.KeyStore
import java.security.Signature
import java.util.Base64
import java.util.UUID

/**
 * Reference integration for a privately installed Android SMS gateway APK.
 * Not wired to an Android application yet.
 * Requires SEND_SMS permission, user consent, device enrollment and a background worker.
 */
class GatewayApiClient(
    private val baseUrl: String,
    private val deviceId: String,
    private val keyAlias: String,
) {
    private fun post(path: String, json: String): String {
        val timestamp = System.currentTimeMillis().toString()
        val nonce = UUID.randomUUID().toString()
        val canonical = listOf("POST", path, timestamp, nonce, json).joinToString("\n")
        val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        val privateKey = keyStore.getKey(keyAlias, null) as java.security.PrivateKey
        val signature = Signature.getInstance("SHA256withRSA").apply {
            initSign(privateKey)
            update(canonical.toByteArray(Charsets.UTF_8))
        }.sign()
        val conn = URL(baseUrl.trimEnd('/') + path).openConnection() as HttpURLConnection
        try {
            conn.requestMethod = "POST"
            conn.connectTimeout = 10_000
            conn.readTimeout = 10_000
            conn.doOutput = true
            conn.setRequestProperty("Content-Type", "application/json")
            conn.setRequestProperty("X-Device-Id", deviceId)
            conn.setRequestProperty("X-Timestamp", timestamp)
            conn.setRequestProperty("X-Nonce", nonce)
            conn.setRequestProperty("X-Signature", Base64.getEncoder().encodeToString(signature))
            conn.outputStream.use { it.write(json.toByteArray(Charsets.UTF_8)) }
            val stream = if (conn.responseCode in 200..299) conn.inputStream else conn.errorStream
            val result = stream.bufferedReader().use { it.readText() }
            if (conn.responseCode !in 200..299) throw IllegalStateException("Gateway HTTP ${conn.responseCode}: $result")
            return result
        } finally { conn.disconnect() }
    }

    fun poll(): String = post("/v1/gateway/poll", "{}")
    fun heartbeat(): String = post("/v1/gateway/heartbeat", "{}")
    fun result(jobId: String, status: String, simSlot: Int): String {
        require(status in setOf("sent", "failed", "delivered"))
        return post("/v1/gateway/result",
            """{"jobId":"$jobId","status":"$status","simSlot":$simSlot}""")
    }

    /**
     * Call from a foreground/background worker with correct permissions.
     * IMPORTANT: use a sent PendingIntent callback before reporting 'sent'.
     * Do not call result(sent) immediately after this method returns.
     */
    fun sendViaSubscription(context: Context, subscriptionId: Int, recipient: String, message: String) {
        val manager = context.getSystemService(SubscriptionManager::class.java)
        require(manager.activeSubscriptionInfoList?.any { it.subscriptionId == subscriptionId } == true) {
            "Selected SIM subscription is not active"
        }
        @Suppress("DEPRECATION")
        val sms = SmsManager.getSmsManagerForSubscriptionId(subscriptionId)
        val parts = sms.divideMessage(message)
        // Replace null sentIntents with per-part PendingIntents to confirm send status.
        sms.sendMultipartTextMessage(recipient, null, parts, null, null)
    }
}
