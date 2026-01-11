package com.vaultguard.security.biometric

import androidx.biometric.BiometricManager.Authenticators
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity
import com.vaultguard.security.biometric.ui.BiometricAuthResult
import com.vaultguard.security.biometric.ui.BiometricResultHandler
import com.vaultguard.security.biometric.utils.BiometricErrorMapper

interface PromptClient {
    fun authenticate(
        title: String,
        subtitle: String?,
        description: String?,
        requireConfirmation: Boolean,
        allowDeviceCredentialFallback: Boolean,
        handler: BiometricResultHandler,
    )
}

class BiometricPromptController(
    private val activity: FragmentActivity,
) : PromptClient {
    override fun authenticate(
        title: String,
        subtitle: String?,
        description: String?,
        requireConfirmation: Boolean,
        allowDeviceCredentialFallback: Boolean,
        handler: BiometricResultHandler,
    ) {
        val executor = ContextCompat.getMainExecutor(activity)
        val prompt = BiometricPrompt(
            activity,
            executor,
            object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
                    handler.onResult(BiometricAuthResult.Success)
                }

                override fun onAuthenticationFailed() {
                    handler.onResult(BiometricAuthResult.Failed)
                }

                override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                    val msg = BiometricErrorMapper.toUserMessage(errorCode, errString)
                    val mapped = when (errorCode) {
                        BiometricPrompt.ERROR_USER_CANCELED,
                        BiometricPrompt.ERROR_NEGATIVE_BUTTON,
                        BiometricPrompt.ERROR_CANCELED,
                        -> BiometricAuthResult.Cancelled
                        else -> BiometricAuthResult.Error(errorCode, msg)
                    }
                    handler.onResult(mapped)
                }
            },
        )

        val allowed = if (allowDeviceCredentialFallback) {
            Authenticators.BIOMETRIC_STRONG or Authenticators.DEVICE_CREDENTIAL
        } else {
            Authenticators.BIOMETRIC_STRONG
        }

        val info = BiometricPrompt.PromptInfo.Builder()
            .setTitle(title)
            .setAllowedAuthenticators(allowed)
            .setConfirmationRequired(requireConfirmation)
            .apply {
                if (!subtitle.isNullOrBlank()) setSubtitle(subtitle)
                if (!description.isNullOrBlank()) setDescription(description)
            }
            .build()

        prompt.authenticate(info)
    }
}

