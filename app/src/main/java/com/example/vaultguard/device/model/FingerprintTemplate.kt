package com.example.vaultguard.device.model

/**
 * Represents a fingerprint template captured from X05 (or compatible) devices.
 *
 * NOTE: Store encrypted at rest. Prefer keeping [encrypted] and not the raw bytes.
 */
data class FingerprintTemplate(
    val templateId: String,
    val algorithm: String? = null,
    val format: String? = null,
    val encrypted: EncryptedBlob,
)

