package com.vaultguard.security.biometric

import android.view.WindowManager
import androidx.test.core.app.ActivityScenario
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.vaultguard.security.biometric.ui.BiometricSettingsActivity
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class BiometricSettingsActivityInstrumentedTest {
    @Test
    fun setsFlagSecure() {
        ActivityScenario.launch(BiometricSettingsActivity::class.java).use { scenario ->
            scenario.onActivity { activity ->
                val flags = activity.window.attributes.flags
                assertTrue((flags and WindowManager.LayoutParams.FLAG_SECURE) != 0)
            }
        }
    }
}

