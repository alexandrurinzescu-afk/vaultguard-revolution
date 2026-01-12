package com.vaultguard.security.keystore.crypto

import com.vaultguard.security.keystore.utils.Constants
import java.security.SecureRandom
import javax.crypto.Cipher
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * Pure JVM crypto helper for AES/GCM/NoPadding.
 *
 * This is intentionally Android-free so it can be unit-tested under `src/test`.
 * Android Keystore integration remains in [com.vaultguard.security.keystore.KeystoreManager].
 */
object AesGcmCrypto {
    fun generateIv(secureRandom: SecureRandom = SecureRandom()): ByteArray {
        val iv = ByteArray(Constants.GCM_IV_BYTES)
        secureRandom.nextBytes(iv)
        return iv
    }

    fun encrypt(
        plaintext: ByteArray,
        key: SecretKey,
        iv: ByteArray,
    ): ByteArray {
        require(iv.size == Constants.GCM_IV_BYTES) {
            "IV must be ${Constants.GCM_IV_BYTES} bytes for GCM (got ${iv.size})"
        }
        val cipher = Cipher.getInstance(Constants.AES_MODE)
        val spec = GCMParameterSpec(Constants.GCM_TAG_BITS, iv)
        cipher.init(Cipher.ENCRYPT_MODE, key, spec)
        return cipher.doFinal(plaintext)
    }

    fun decrypt(
        ciphertext: ByteArray,
        key: SecretKey,
        iv: ByteArray,
    ): ByteArray {
        require(iv.size == Constants.GCM_IV_BYTES) {
            "IV must be ${Constants.GCM_IV_BYTES} bytes for GCM (got ${iv.size})"
        }
        val cipher = Cipher.getInstance(Constants.AES_MODE)
        val spec = GCMParameterSpec(Constants.GCM_TAG_BITS, iv)
        cipher.init(Cipher.DECRYPT_MODE, key, spec)
        return cipher.doFinal(ciphertext)
    }
}

