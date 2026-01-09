package com.example.vaultguard.device.x05

import com.example.vaultguard.device.model.DeviceStatus
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.util.concurrent.ConcurrentHashMap
import kotlin.math.min

/**
 * Manages one or more X05 devices reachable over the network.
 *
 * This is intentionally conservative: it keeps state, can probe connectivity,
 * and provides hooks to integrate the real SDK later.
 */
class X05DeviceManager(
    private val scope: CoroutineScope = CoroutineScope(Dispatchers.IO),
    private val tcp: X05TcpClient = X05TcpClient(),
    private val http: X05HttpClient = X05HttpClient(),
) {
    private val devices = ConcurrentHashMap<String, DeviceStatus>()
    private val monitorJobs = ConcurrentHashMap<String, Job>()

    private val _statuses = MutableStateFlow<List<DeviceStatus>>(emptyList())
    val statuses: StateFlow<List<DeviceStatus>> = _statuses.asStateFlow()

    fun registerDevice(deviceId: String, ip: String, tcpPort: Int = X05Endpoints.DEFAULT_TCP_PORT, httpPort: Int = X05Endpoints.DEFAULT_HTTP_PORT) {
        devices[deviceId] = DeviceStatus(
            deviceId = deviceId,
            ip = ip,
            tcpPort = tcpPort,
            httpPort = httpPort,
            state = DeviceStatus.State.OFFLINE,
        )
        publish()
    }

    fun unregisterDevice(deviceId: String) {
        monitorJobs.remove(deviceId)?.cancel()
        devices.remove(deviceId)
        publish()
    }

    fun startMonitoring(deviceId: String, initialDelayMs: Long = 0L) {
        if (monitorJobs.containsKey(deviceId)) return

        val job = scope.launch {
            if (initialDelayMs > 0) delay(initialDelayMs)

            var backoffMs = 1000L
            while (true) {
                val current = devices[deviceId] ?: break
                setState(deviceId, current.copy(state = DeviceStatus.State.CONNECTING, lastError = null))

                val tcpOk = tcp.ping(current.ip, current.tcpPort)
                if (tcpOk) {
                    setState(
                        deviceId,
                        current.copy(
                            state = DeviceStatus.State.ONLINE,
                            lastSeenEpochMs = System.currentTimeMillis(),
                            lastError = null,
                        )
                    )
                    backoffMs = 1000L
                } else {
                    setState(
                        deviceId,
                        current.copy(
                            state = DeviceStatus.State.OFFLINE,
                            lastSeenEpochMs = System.currentTimeMillis(),
                            lastError = "TCP ping failed",
                        )
                    )
                    backoffMs = min(backoffMs * 2, 30_000L)
                }

                delay(backoffMs)
            }
        }

        monitorJobs[deviceId] = job
    }

    fun stopMonitoring(deviceId: String) {
        monitorJobs.remove(deviceId)?.cancel()
    }

    suspend fun fetchConfig(deviceId: String): ByteArray {
        val current = devices[deviceId] ?: error("Unknown deviceId=$deviceId")
        X05Logger.i("GET config from ${current.ip}:${current.httpPort}${X05Endpoints.PATH_CONFIG}")
        return http.getConfig(current.ip, current.httpPort)
    }

    suspend fun uploadPayload(deviceId: String, payload: ByteArray, contentType: String = "application/octet-stream"): ByteArray {
        val current = devices[deviceId] ?: error("Unknown deviceId=$deviceId")
        X05Logger.i("POST upload to ${current.ip}:${current.httpPort}${X05Endpoints.PATH_UPLOAD} (${payload.size} bytes)")
        return http.upload(current.ip, current.httpPort, payload, contentType)
    }

    private fun setState(deviceId: String, status: DeviceStatus) {
        devices[deviceId] = status
        publish()
    }

    private fun publish() {
        _statuses.value = devices.values.sortedBy { it.deviceId }
    }
}

