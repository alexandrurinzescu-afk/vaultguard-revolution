package com.example.vaultguard.tier

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.net.HttpURLConnection
import java.net.URL

/**
 * Sprint 0.1.2: minimal backend client using HttpURLConnection (no extra deps).
 */
class EntitlementsApiClient(
    private val baseUrl: String = EntitlementsConfig.BASE_URL,
    private val connectTimeoutMs: Int = 3_000,
    private val readTimeoutMs: Int = 5_000,
) {
    data class EntitlementsDto(
        val userId: String,
        val tier: String,
        val features: List<String>,
        val issuedAt: String?,
    )

    suspend fun getEntitlements(userId: String): EntitlementsDto = withContext(Dispatchers.IO) {
        val url = URL("$baseUrl/api/user/entitlements?userId=$userId")
        val conn = (url.openConnection() as HttpURLConnection).apply {
            requestMethod = "GET"
            connectTimeout = connectTimeoutMs
            readTimeout = readTimeoutMs
            useCaches = false
            doInput = true
        }
        try {
            val body = readBody(conn)
            if (conn.responseCode !in 200..299) {
                throw IllegalStateException("HTTP ${conn.responseCode}: $body")
            }
            parseEntitlements(body)
        } finally {
            conn.disconnect()
        }
    }

    suspend fun mockPurchase(userId: String, tier: String): EntitlementsDto = withContext(Dispatchers.IO) {
        val url = URL("$baseUrl/api/mock/purchase")
        val payload = JSONObject().put("userId", userId).put("tier", tier).toString().toByteArray()
        val conn = (url.openConnection() as HttpURLConnection).apply {
            requestMethod = "POST"
            connectTimeout = connectTimeoutMs
            readTimeout = readTimeoutMs
            useCaches = false
            doInput = true
            doOutput = true
            setRequestProperty("Content-Type", "application/json")
            setRequestProperty("Content-Length", payload.size.toString())
        }
        try {
            conn.outputStream.use { it.write(payload) }
            val body = readBody(conn)
            if (conn.responseCode !in 200..299) {
                throw IllegalStateException("HTTP ${conn.responseCode}: $body")
            }
            parseEntitlements(body)
        } finally {
            conn.disconnect()
        }
    }

    private fun parseEntitlements(json: String): EntitlementsDto {
        val obj = JSONObject(json)
        val features = mutableListOf<String>()
        val arr = obj.optJSONArray("features") ?: JSONArray()
        for (i in 0 until arr.length()) features.add(arr.optString(i))
        return EntitlementsDto(
            userId = obj.optString("userId"),
            tier = obj.optString("tier"),
            features = features,
            issuedAt = obj.optString("issuedAt").takeIf { it.isNotBlank() },
        )
    }

    private fun readBody(conn: HttpURLConnection): String {
        val stream = if (conn.responseCode in 200..299) conn.inputStream else conn.errorStream
        val out = ByteArrayOutputStream()
        stream?.use { s ->
            val buf = ByteArray(4096)
            while (true) {
                val read = s.read(buf)
                if (read <= 0) break
                out.write(buf, 0, read)
            }
        }
        return out.toString(Charsets.UTF_8.name())
    }
}

