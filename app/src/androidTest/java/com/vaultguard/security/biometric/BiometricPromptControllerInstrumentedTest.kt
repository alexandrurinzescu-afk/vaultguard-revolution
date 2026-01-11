package com.vaultguard.security.biometric

import androidx.test.core.app.ActivityScenario
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.vaultguard.security.biometric.ui.BiometricAuthResult
import com.vaultguard.security.biometric.ui.BiometricResultHandler
import com.vaultguard.security.biometric.ui.BiometricSettingsActivity
import org.junit.Assert.assertNotNull
import org.junit.Test
import org.junit.runner.RunWith
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference

@RunWith(AndroidJUnit4::class)
class BiometricPromptControllerInstrumentedTest {
    @Test
    fun controller_canBeConstructed() {
        ActivityScenario.launch(BiometricSettingsActivity::class.java).use { scenario ->
            scenario.onActivity { activity ->
                val controller = BiometricPromptController(activity)
                assertNotNull(controller)

                // We do not call authenticate() here because it requires real device biometrics/user interaction.
                // This test ensures the controller wiring compiles and can be instantiated on-device.
                val latch = CountDownLatch(1)
                val result = AtomicReference<BiometricAuthResult>()
                val handler = BiometricResultHandler { r -> result.set(r); latch.countDown() }
                // Simulate callback path by direct call (no prompt).
                handler.onResult(BiometricAuthResult.Cancelled)
                latch.await(1, TimeUnit.SECONDS)
            }
        }
    }
}

