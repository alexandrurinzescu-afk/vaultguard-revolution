package com.example.vaultguard.device.model

data class DeviceStatus(
    val deviceId: String,
    val ip: String,
    val tcpPort: Int = 10010,
    val httpPort: Int = 9000,
    val state: State = State.UNKNOWN,
    /**
     * Epoch millis (use Long for Android compatibility without desugaring).
     */
    val lastSeenEpochMs: Long? = null,
    val lastError: String? = null,
) {
    enum class State {
        UNKNOWN,
        OFFLINE,
        CONNECTING,
        ONLINE,
        DEGRADED,
        ERROR,
    }
}

