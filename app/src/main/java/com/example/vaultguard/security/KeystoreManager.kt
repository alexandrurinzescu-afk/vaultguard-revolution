package com.example.vaultguard.security

import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import com.example.vaultguard.device.model.EncryptedBlob
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * Android Keystore based encryption helper.
 *
 * Intended for sensitive payloads like biometric templates.
 * Uses AES-GCM with a per-encryption IV.
 */
object KeystoreManager {
    private const val ANDROID_KEYSTORE = "AndroidKeyStore"
    private const val AES_MODE = "AES/GCM/NoPadding"
    private const val GCM_TAG_BITS = 128

    /**
     * Encrypt arbitrary bytes using a keystore-backed AES key.
     */
    fun encryptBytes(
        plaintext: ByteArray,
        keyAlias: String = "vaultguard_bio_aes",
    ): EncryptedBlob {
        val key = getOrCreateAesKey(keyAlias)
        val cipher = Cipher.getInstance(AES_MODE)
        cipher.init(Cipher.ENCRYPT_MODE, key)
        val ciphertext = cipher.doFinal(plaintext)
        val iv = cipher.iv
        return EncryptedBlob(iv = iv, ciphertext = ciphertext)
    }

    /**
     * Decrypt bytes previously encrypted with [encryptBytes].
     */
    fun decryptBytes(
        encrypted: EncryptedBlob,
        keyAlias: String = "vaultguard_bio_aes",
    ): ByteArray {
        val key = getOrCreateAesKey(keyAlias)
        val cipher = Cipher.getInstance(AES_MODE)
        val spec = GCMParameterSpec(GCM_TAG_BITS, encrypted.iv)
        cipher.init(Cipher.DECRYPT_MODE, key, spec)
        return cipher.doFinal(encrypted.ciphertext)
    }

    private fun getOrCreateAesKey(alias: String): SecretKey {
        val ks = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
        val existing = ks.getKey(alias, null) as? SecretKey
        if (existing != null) return existing

        val keyGenerator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, ANDROID_KEYSTORE)
        val spec = KeyGenParameterSpec.Builder(
            alias,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
        )
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(256)
            .setUserAuthenticationRequired(false)
            .build()

        keyGenerator.init(spec)
        return keyGenerator.generateKey()
    }
}
