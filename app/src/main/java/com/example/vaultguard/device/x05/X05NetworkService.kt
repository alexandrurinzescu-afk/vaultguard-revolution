package com.example.vaultguard.device.x05

/**
 * Convenience wrapper around TCP + HTTP clients.
 *
 * This matches the integration spec naming (X05NetworkService) and keeps the
 * actual protocol details in the dedicated clients.
 */
class X05NetworkService(
    private val tcpClient: X05TcpClient = X05TcpClient(),
    private val httpClient: X05HttpClient = X05HttpClient(),
) {
    suspend fun tcpPing(ip: String, port: Int = X05Endpoints.DEFAULT_TCP_PORT): Boolean =
        tcpClient.ping(ip, port)

    suspend fun tcpTransactRaw(ip: String, port: Int = X05Endpoints.DEFAULT_TCP_PORT, request: ByteArray): ByteArray =
        tcpClient.transactRaw(ip, port, request)

    suspend fun httpGetConfig(ip: String, port: Int = X05Endpoints.DEFAULT_HTTP_PORT): ByteArray =
        httpClient.getConfig(ip, port)

    suspend fun httpUpload(ip: String, port: Int = X05Endpoints.DEFAULT_HTTP_PORT, payload: ByteArray): ByteArray =
        httpClient.upload(ip, port, payload)
}

