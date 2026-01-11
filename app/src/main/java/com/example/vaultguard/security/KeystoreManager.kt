package com.example.vaultguard.security

import android.content.Context
import com.example.vaultguard.device.model.EncryptedBlob
import com.vaultguard.security.keystore.KeystoreManager as VaultKeystoreManager
import com.vaultguard.security.keystore.utils.Constants

/**
 * Android Keystore based encryption helper.
 *
 * Intended for sensitive payloads like biometric templates.
 *
 * Deprecated: unified implementation lives in `com.vaultguard.security.keystore.KeystoreManager`.
 * This wrapper exists only for compatibility inside the legacy `com.example.vaultguard.*` package tree.
 */
@Deprecated(
    message = "Use com.vaultguard.security.keystore.KeystoreManager (via KeystoreOps / SecureStorage) instead.",
)
object KeystoreManager {
    private const val DEFAULT_ALIAS = "vaultguard_bio_aes"

    /**
     * Encrypt arbitrary bytes using a keystore-backed AES key.
     */
    fun encryptBytes(
        context: Context,
        plaintext: ByteArray,
        keyAlias: String = DEFAULT_ALIAS,
    ): EncryptedBlob {
        // Legacy behavior: do NOT require user authentication (old implementation had authRequired=false).
        // New code should use `com.vaultguard.security.*` which enforces biometric gating.
        val km = VaultKeystoreManager(context, requireUserAuth = false)
        val r = km.encrypt(plaintext, alias = keyAlias)
        return EncryptedBlob(iv = r.iv, ciphertext = r.encryptedData)
    }

    /**
     * Decrypt bytes previously encrypted with [encryptBytes].
     */
    fun decryptBytes(
        context: Context,
        encrypted: EncryptedBlob,
        keyAlias: String = DEFAULT_ALIAS,
    ): ByteArray {
        // Must match encryptBytes() legacy behavior.
        val km = VaultKeystoreManager(context, requireUserAuth = false)
        return km.decrypt(
            encryptedData = encrypted.ciphertext,
            iv = encrypted.iv,
            alias = keyAlias,
        )
    }
}
