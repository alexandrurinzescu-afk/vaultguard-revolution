package com.example.vaultguard.device.model

/**
 * Simple container for encrypted bytes.
 *
 * - [iv]: initialization vector (12 bytes recommended for AES-GCM).
 * - [ciphertext]: ciphertext including GCM authentication tag (as produced by Cipher#doFinal).
 */
data class EncryptedBlob(
    val iv: ByteArray,
    val ciphertext: ByteArray,
)

