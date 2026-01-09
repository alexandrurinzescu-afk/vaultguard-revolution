package com.example.vaultguard.device.x05

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.ByteArrayOutputStream
import java.net.HttpURLConnection
import java.net.URL

/**
 * Minimal HTTP client for X05 endpoints.
 *
 * Uses HttpURLConnection to avoid extra deps. If the device requires TLS/cert pinning,
 * add a dedicated client (OkHttp) behind the same interface.
 */
class X05HttpClient(
    private val connectTimeoutMs: Int = 3_000,
    private val readTimeoutMs: Int = 5_000,
) {
    suspend fun getConfig(ip: String, port: Int = X05Endpoints.DEFAULT_HTTP_PORT): ByteArray =
        request(ip, port, "GET", X05Endpoints.PATH_CONFIG, null, null)

    suspend fun upload(
        ip: String,
        port: Int = X05Endpoints.DEFAULT_HTTP_PORT,
        payload: ByteArray,
        contentType: String = "application/octet-stream",
    ): ByteArray = request(ip, port, "POST", X05Endpoints.PATH_UPLOAD, payload, contentType)

    private suspend fun request(
        ip: String,
        port: Int,
        method: String,
        path: String,
        body: ByteArray?,
        contentType: String?,
    ): ByteArray = withContext(Dispatchers.IO) {
        val url = URL("http://$ip:$port$path")
        val conn = (url.openConnection() as HttpURLConnection).apply {
            requestMethod = method
            connectTimeout = connectTimeoutMs
            readTimeout = readTimeoutMs
            useCaches = false
            doInput = true
            if (body != null) {
                doOutput = true
                setRequestProperty("Content-Type", contentType ?: "application/octet-stream")
                setRequestProperty("Content-Length", body.size.toString())
            }
        }

        try {
            if (body != null) {
                conn.outputStream.use { it.write(body) }
            }

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
            out.toByteArray()
        } finally {
            conn.disconnect()
        }
    }
}

