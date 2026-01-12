package com.vaultguard.security.keystore.crypto

import com.vaultguard.security.keystore.utils.Constants
import org.junit.Assert.assertEquals
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.security.SecureRandom
import javax.crypto.KeyGenerator

class AesGcmCryptoTest {
    private fun newAesKey() = KeyGenerator.getInstance("AES").apply { init(Constants.KEY_SIZE_BITS) }.generateKey()

    @Test
    fun encryptDecrypt_roundTrip() {
        val key = newAesKey()
        val plaintext = "vaultguard-aesgcm-test".toByteArray(Charsets.UTF_8)
        val iv = AesGcmCrypto.generateIv(SecureRandom())

        val ct = AesGcmCrypto.encrypt(plaintext = plaintext, key = key, iv = iv)
        val pt = AesGcmCrypto.decrypt(ciphertext = ct, key = key, iv = iv)

        assertArrayEquals(plaintext, pt)
    }

    @Test
    fun encrypt_samePlaintextDifferentIv_producesDifferentCiphertext() {
        val key = newAesKey()
        val plaintext = ByteArray(64) { 0x2A }

        val ct1 = AesGcmCrypto.encrypt(plaintext, key, AesGcmCrypto.generateIv())
        val ct2 = AesGcmCrypto.encrypt(plaintext, key, AesGcmCrypto.generateIv())

        // It is overwhelmingly likely different due to different IVs; also length should match.
        assertEquals(ct1.size, ct2.size)
        assertTrue(!ct1.contentEquals(ct2))
    }

    @Test
    fun decrypt_withCorruptedCiphertext_fails() {
        val key = newAesKey()
        val plaintext = "hello".toByteArray(Charsets.UTF_8)
        val iv = AesGcmCrypto.generateIv()
        val ct = AesGcmCrypto.encrypt(plaintext, key, iv).copyOf()

        // Corrupt one byte
        ct[ct.size / 2] = (ct[ct.size / 2].toInt() xor 0x01).toByte()

        var threw = false
        try {
            AesGcmCrypto.decrypt(ct, key, iv)
        } catch (_: Throwable) {
            threw = true
        }
        assertTrue(threw)
    }

    @Test
    fun encrypt_rejectsInvalidIvLength() {
        val key = newAesKey()
        val badIv = ByteArray(8) { 1 }

        var threw = false
        try {
            AesGcmCrypto.encrypt("x".toByteArray(), key, badIv)
        } catch (_: IllegalArgumentException) {
            threw = true
        }
        assertTrue(threw)
    }
}

