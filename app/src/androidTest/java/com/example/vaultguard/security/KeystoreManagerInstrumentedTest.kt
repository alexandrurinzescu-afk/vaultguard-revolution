package com.example.vaultguard.security

import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.vaultguard.security.keystore.KeystoreManager
import org.junit.Assert.assertArrayEquals
import org.junit.Test
import org.junit.runner.RunWith
import java.nio.charset.StandardCharsets

@RunWith(AndroidJUnit4::class)
class KeystoreManagerInstrumentedTest {

    @Test
    fun encryptDecrypt_roundTrip() {
        val context = ApplicationProvider.getApplicationContext<android.content.Context>()
        val plaintext = "vaultguard-keystore-test".toByteArray(StandardCharsets.UTF_8)

        // Tests must be non-interactive, so disable user-auth requirement for this key.
        val km = KeystoreManager(context, requireUserAuth = false)
        km.generateKey(alias = "vaultguard_test_aes")
        val encrypted = km.encrypt(plaintext, alias = "vaultguard_test_aes")
        val decrypted = km.decrypt(encrypted.encryptedData, encrypted.iv, alias = "vaultguard_test_aes")
        assertArrayEquals(plaintext, decrypted)
    }
}

