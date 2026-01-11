package com.vaultguard.security.biometric.utils

import androidx.biometric.BiometricPrompt
import org.junit.Assert.assertTrue
import org.junit.Test

class BiometricErrorMapperTest {
    @Test
    fun mapsCancelToCancelledMessage() {
        val msg = BiometricErrorMapper.toUserMessage(BiometricPrompt.ERROR_USER_CANCELED, "cancel")
        assertTrue(msg.contains("cancel", ignoreCase = true) || msg.contains("cancelled", ignoreCase = true))
    }

    @Test
    fun mapsNoBiometrics() {
        val msg = BiometricErrorMapper.toUserMessage(BiometricPrompt.ERROR_NO_BIOMETRICS, null)
        assertTrue(msg.contains("enroll", ignoreCase = true))
    }
}

