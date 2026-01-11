package com.vaultguard.security.keystore

import android.content.Context
import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import com.vaultguard.security.keystore.exceptions.KeystoreException
import com.vaultguard.security.keystore.models.EncryptionResult
import com.vaultguard.security.keystore.utils.Constants
import java.security.KeyStore
import java.security.SecureRandom
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * KeystoreManager MVP (2.1.1)
 *
 * - AES/GCM/NoPadding
 * - 256-bit key stored in Android Keystore (key material never leaves)
 * - Per-encryption random 12-byte IV (GCM)
 * - User authentication required for key use (30s window)
 */
class KeystoreManager(
    context: Context,
    /**
     * If false, the generated key will not require user authentication.
     * This is intended for instrumented tests and non-interactive environments only.
     */
    private val requireUserAuth: Boolean = true,
) {
    @Suppress("unused")
    private val appContext = context.applicationContext

    private val secureRandom = SecureRandom()

    fun generateKey(alias: String = Constants.DEFAULT_KEY_ALIAS) {
        try {
            // Rotation-friendly: overwrite existing alias.
            if (keyExists(alias)) deleteKey(alias)
            createAesKey(alias)
        } catch (t: Throwable) {
            throw KeystoreException("Failed to generate key for alias=$alias", t)
        }
    }

    fun encrypt(data: ByteArray, alias: String = Constants.DEFAULT_KEY_ALIAS): EncryptionResult {
        try {
            val key = getOrCreateAesKey(alias)
            val cipher = Cipher.getInstance(Constants.AES_MODE)

            // Force 12-byte IV for GCM.
            val iv = ByteArray(Constants.GCM_IV_BYTES)
            secureRandom.nextBytes(iv)
            val spec = GCMParameterSpec(Constants.GCM_TAG_BITS, iv)

            cipher.init(Cipher.ENCRYPT_MODE, key, spec)
            val ciphertext = cipher.doFinal(data)

            return EncryptionResult(
                encryptedData = ciphertext,
                iv = iv,
            )
        } catch (t: Throwable) {
            throw KeystoreException("Encryption failed for alias=$alias", t)
        }
    }

    fun decrypt(
        encryptedData: ByteArray,
        iv: ByteArray,
        alias: String = Constants.DEFAULT_KEY_ALIAS,
    ): ByteArray {
        try {
            val key = getOrCreateAesKey(alias)
            val cipher = Cipher.getInstance(Constants.AES_MODE)
            val spec = GCMParameterSpec(Constants.GCM_TAG_BITS, iv)
            cipher.init(Cipher.DECRYPT_MODE, key, spec)
            return cipher.doFinal(encryptedData)
        } catch (t: Throwable) {
            throw KeystoreException("Decryption failed for alias=$alias", t)
        }
    }

    fun deleteKey(alias: String = Constants.DEFAULT_KEY_ALIAS) {
        try {
            val ks = keyStore()
            if (ks.containsAlias(alias)) {
                ks.deleteEntry(alias)
            }
        } catch (t: Throwable) {
            throw KeystoreException("Failed to delete key for alias=$alias", t)
        }
    }

    fun keyExists(alias: String = Constants.DEFAULT_KEY_ALIAS): Boolean {
        return try {
            keyStore().containsAlias(alias)
        } catch (_: Throwable) {
            false
        }
    }

    private fun getOrCreateAesKey(alias: String): SecretKey {
        val ks = keyStore()
        val existing = ks.getKey(alias, null) as? SecretKey
        if (existing != null) return existing
        return createAesKey(alias)
    }

    private fun createAesKey(alias: String): SecretKey {
        val keyGenerator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, Constants.ANDROID_KEYSTORE)
        val builder = KeyGenParameterSpec.Builder(
            alias,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
        )
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(Constants.KEY_SIZE_BITS)
            .setRandomizedEncryptionRequired(true)
            .setUserAuthenticationRequired(requireUserAuth)

        if (requireUserAuth) {
            // Require biometric authentication for key usage.
            // API 30+: use parameters; older: validity duration.
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                builder.setUserAuthenticationParameters(
                    Constants.AUTH_VALIDITY_SECONDS,
                    KeyProperties.AUTH_BIOMETRIC_STRONG,
                )
            } else {
                @Suppress("DEPRECATION")
                builder.setUserAuthenticationValidityDurationSeconds(Constants.AUTH_VALIDITY_SECONDS)
            }
        }

        keyGenerator.init(builder.build())
        return keyGenerator.generateKey()
    }

    private fun keyStore(): KeyStore {
        return KeyStore.getInstance(Constants.ANDROID_KEYSTORE).apply { load(null) }
    }
}

