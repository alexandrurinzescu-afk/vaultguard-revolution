package com.example.vaultguard.security

import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertArrayEquals
import org.junit.Test
import org.junit.runner.RunWith
import java.nio.charset.StandardCharsets

@RunWith(AndroidJUnit4::class)
class KeystoreManagerInstrumentedTest {

    @Test
    fun encryptDecrypt_roundTrip() {
        val plaintext = "vaultguard-keystore-test".toByteArray(StandardCharsets.UTF_8)
        val encrypted = KeystoreManager.encryptBytes(plaintext, keyAlias = "vaultguard_test_aes")
        val decrypted = KeystoreManager.decryptBytes(encrypted, keyAlias = "vaultguard_test_aes")
        assertArrayEquals(plaintext, decrypted)
    }
}

