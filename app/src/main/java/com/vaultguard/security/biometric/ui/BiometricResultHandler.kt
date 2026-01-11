package com.vaultguard.security.biometric.ui

sealed class BiometricAuthResult {
    data object Success : BiometricAuthResult()
    data class Error(val code: Int, val message: String) : BiometricAuthResult()
    data object Failed : BiometricAuthResult()
    data object Cancelled : BiometricAuthResult()
}

fun interface BiometricResultHandler {
    fun onResult(result: BiometricAuthResult)
}

