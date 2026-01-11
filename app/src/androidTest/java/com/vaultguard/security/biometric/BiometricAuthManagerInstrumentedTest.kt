package com.vaultguard.security.biometric

import androidx.fragment.app.FragmentActivity
import androidx.test.core.app.ActivityScenario
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.vaultguard.security.biometric.ui.BiometricAuthResult
import com.vaultguard.security.biometric.ui.BiometricResultHandler
import com.vaultguard.security.biometric.ui.BiometricSettingsActivity
import com.vaultguard.security.keystore.models.EncryptionResult
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.atomic.AtomicReference

@RunWith(AndroidJUnit4::class)
class BiometricAuthManagerInstrumentedTest {

    private class FakePromptClient(
        private val calls: AtomicInteger,
        private val result: BiometricAuthResult = BiometricAuthResult.Success,
    ) : PromptClient {
        override fun authenticate(
            title: String,
            subtitle: String?,
            description: String?,
            requireConfirmation: Boolean,
            allowDeviceCredentialFallback: Boolean,
            handler: BiometricResultHandler,
        ) {
            calls.incrementAndGet()
            handler.onResult(result)
        }
    }

    private class FakeKeystoreOps : KeystoreOps {
        override fun generateKey(alias: String) {}
        override fun encrypt(data: ByteArray, alias: String): EncryptionResult {
            return EncryptionResult(encryptedData = byteArrayOf(1, 2, 3), iv = ByteArray(12) { 7 })
        }
        override fun decrypt(encryptedData: ByteArray, iv: ByteArray, alias: String): ByteArray {
            return byteArrayOf(9, 9)
        }
        override fun deleteKey(alias: String) {}
        override fun keyExists(alias: String): Boolean = true
    }

    @Test
    fun encrypt_prompts_when_session_invalid_then_sets_session() {
        val calls = AtomicInteger(0)
        val prompt = FakePromptClient(calls)
        val keystore = FakeKeystoreOps()

        ActivityScenario.launch(BiometricSettingsActivity::class.java).use { scenario ->
            scenario.onActivity { activity ->
                val mgr = BiometricAuthManager(
                    context = activity,
                    keystore = keystore,
                    promptFactory = { prompt },
                    sessionSeconds = 30,
                )
                mgr.clearSession()

                val latch = CountDownLatch(1)
                val resultRef = AtomicReference<BiometricAuthResult>()
                val encRef = AtomicReference<ByteArray?>()
                val ivRef = AtomicReference<ByteArray?>()

                mgr.encryptWithBiometricGate(
                    activity = activity as FragmentActivity,
                    plaintext = byteArrayOf(4, 5),
                    alias = "test",
                ) { res, enc, iv ->
                    resultRef.set(res)
                    encRef.set(enc)
                    ivRef.set(iv)
                    latch.countDown()
                }

                assertTrue(latch.await(2, TimeUnit.SECONDS))
                assertEquals(1, calls.get())
                assertEquals(BiometricAuthResult.Success, resultRef.get())
                assertNotNull(encRef.get())
                assertNotNull(ivRef.get())
                assertTrue(mgr.isSessionValid())
            }
        }
    }

    @Test
    fun encrypt_skips_prompt_when_session_valid() {
        val calls = AtomicInteger(0)
        val prompt = FakePromptClient(calls)
        val keystore = FakeKeystoreOps()

        ActivityScenario.launch(BiometricSettingsActivity::class.java).use { scenario ->
            scenario.onActivity { activity ->
                val mgr = BiometricAuthManager(
                    context = activity,
                    keystore = keystore,
                    promptFactory = { prompt },
                    sessionSeconds = 30,
                )
                mgr.clearSession()

                // First call sets session (prompt called once).
                val latch1 = CountDownLatch(1)
                mgr.encryptWithBiometricGate(activity, byteArrayOf(1), "test") { _, _, _ -> latch1.countDown() }
                assertTrue(latch1.await(2, TimeUnit.SECONDS))
                assertEquals(1, calls.get())
                assertTrue(mgr.isSessionValid())

                // Second call should NOT prompt again.
                val latch2 = CountDownLatch(1)
                mgr.encryptWithBiometricGate(activity, byteArrayOf(1), "test") { _, _, _ -> latch2.countDown() }
                assertTrue(latch2.await(2, TimeUnit.SECONDS))
                assertEquals(1, calls.get())
            }
        }
    }
}

