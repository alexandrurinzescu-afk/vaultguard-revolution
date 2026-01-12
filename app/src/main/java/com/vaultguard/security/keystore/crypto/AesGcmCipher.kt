package com.vaultguard.security.keystore.crypto

import com.vaultguard.security.keystore.exceptions.KeystoreException
import com.vaultguard.security.keystore.models.EncryptionResult
import com.vaultguard.security.keystore.utils.Constants
import java.security.SecureRandom
import javax.crypto.Cipher
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * Pure AES-GCM crypto helpers (JVM-testable).
 *
 * NOTE: This does NOT manage keys. Key creation / storage stays in Android Keystore.
 */
object AesGcmCipher {

    fun encrypt(
        plaintext: ByteArray,
        key: SecretKey,
        secureRandom: SecureRandom = SecureRandom(),
    ): EncryptionResult {
        try {
            val cipher = Cipher.getInstance(Constants.AES_MODE)

            // Force 12-byte IV for GCM.
            val iv = ByteArray(Constants.GCM_IV_BYTES)
            secureRandom.nextBytes(iv)
            val spec = GCMParameterSpec(Constants.GCM_TAG_BITS, iv)

            cipher.init(Cipher.ENCRYPT_MODE, key, spec)
            val ciphertext = cipher.doFinal(plaintext)

            return EncryptionResult(
                encryptedData = ciphertext,
                iv = iv,
            )
        } catch (t: Throwable) {
            throw KeystoreException("AES-GCM encryption failed", t)
        }
    }

    fun decrypt(
        ciphertext: ByteArray,
        iv: ByteArray,
        key: SecretKey,
    ): ByteArray {
        try {
            if (iv.size != Constants.GCM_IV_BYTES) {
                throw KeystoreException("Invalid IV length: expected=${Constants.GCM_IV_BYTES}, got=${iv.size}")
            }
            val cipher = Cipher.getInstance(Constants.AES_MODE)
            val spec = GCMParameterSpec(Constants.GCM_TAG_BITS, iv)
            cipher.init(Cipher.DECRYPT_MODE, key, spec)
            return cipher.doFinal(ciphertext)
        } catch (t: Throwable) {
            // Keep message stable for tests while preserving root cause.
            if (t is KeystoreException) throw t
            throw KeystoreException("AES-GCM decryption failed", t)
        }
    }
}

