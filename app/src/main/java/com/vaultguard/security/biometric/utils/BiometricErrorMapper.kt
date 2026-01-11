package com.vaultguard.security.biometric.utils

import androidx.biometric.BiometricPrompt

object BiometricErrorMapper {
    fun toUserMessage(errorCode: Int, fallbackMessage: CharSequence?): String {
        val fallback = fallbackMessage?.toString()?.takeIf { it.isNotBlank() }
        return when (errorCode) {
            BiometricPrompt.ERROR_HW_UNAVAILABLE -> "Biometric hardware temporarily unavailable."
            BiometricPrompt.ERROR_HW_NOT_PRESENT -> "No biometric hardware available on this device."
            BiometricPrompt.ERROR_NO_BIOMETRICS -> "No biometrics enrolled. Please enroll biometrics in device settings."
            BiometricPrompt.ERROR_LOCKOUT -> "Too many attempts. Biometrics are temporarily locked."
            BiometricPrompt.ERROR_LOCKOUT_PERMANENT -> "Biometrics locked. Use device credentials to unlock."
            BiometricPrompt.ERROR_TIMEOUT -> "Authentication timed out. Please try again."
            BiometricPrompt.ERROR_USER_CANCELED,
            BiometricPrompt.ERROR_NEGATIVE_BUTTON,
            BiometricPrompt.ERROR_CANCELED,
            -> "Authentication cancelled."
            else -> fallback ?: "Authentication error ($errorCode)."
        }
    }
}

