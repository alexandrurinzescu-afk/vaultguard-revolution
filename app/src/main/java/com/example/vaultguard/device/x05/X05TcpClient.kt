package com.example.vaultguard.device.x05

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.BufferedInputStream
import java.io.BufferedOutputStream
import java.net.InetSocketAddress
import java.net.Socket

/**
 * Minimal TCP client for X05 devices.
 *
 * The actual wire protocol is device/firmware specific; this class provides
 * a safe, cancel-friendly baseline (connect/send/receive) and leaves framing
 * decisions to the caller.
 */
class X05TcpClient(
    private val connectTimeoutMs: Int = 3_000,
    private val readTimeoutMs: Int = 3_000,
) {
    suspend fun ping(ip: String, port: Int = X05Endpoints.DEFAULT_TCP_PORT): Boolean = withContext(Dispatchers.IO) {
        try {
            Socket().use { s ->
                s.soTimeout = readTimeoutMs
                s.connect(InetSocketAddress(ip, port), connectTimeoutMs)
                true
            }
        } catch (_: Exception) {
            false
        }
    }

    suspend fun transactRaw(
        ip: String,
        port: Int = X05Endpoints.DEFAULT_TCP_PORT,
        request: ByteArray,
        maxResponseBytes: Int = 64 * 1024,
    ): ByteArray = withContext(Dispatchers.IO) {
        Socket().use { socket ->
            socket.soTimeout = readTimeoutMs
            socket.connect(InetSocketAddress(ip, port), connectTimeoutMs)

            val out = BufferedOutputStream(socket.getOutputStream())
            out.write(request)
            out.flush()

            val input = BufferedInputStream(socket.getInputStream())
            val buf = ByteArray(4096)
            val result = ArrayList<Byte>(minOf(maxResponseBytes, 4096))

            while (result.size < maxResponseBytes) {
                val read = input.read(buf)
                if (read <= 0) break
                for (i in 0 until read) result.add(buf[i])

                // Heuristic stop: if server responded less than buffer size, assume end.
                if (read < buf.size) break
            }

            result.toByteArray()
        }
    }
}

