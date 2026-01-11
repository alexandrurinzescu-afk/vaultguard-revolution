package com.vaultguard.security.biometric.ui

import android.os.Bundle
import android.view.WindowManager
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.fragment.app.FragmentActivity
import com.vaultguard.security.biometric.BiometricAuthManager
import com.vaultguard.security.keystore.utils.Constants

class BiometricSettingsActivity : FragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Prevent screenshots/screen recording of this security UI.
        @Suppress("DEPRECATION")
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)

        val auth = BiometricAuthManager(this)

        setContent {
            MaterialTheme {
                val last = remember { mutableStateOf("Idle") }
                val lastError = remember { mutableStateOf<String?>(null) }
                val lastCiphertext = remember { mutableStateOf<ByteArray?>(null) }
                val lastIv = remember { mutableStateOf<ByteArray?>(null) }
                val showDialog = remember { mutableStateOf(false) }

                if (showDialog.value) {
                    BiometricAuthDialog(
                        errorMessage = lastError.value,
                        onAuthenticate = {
                            showDialog.value = false
                            auth.authenticate(
                                activity = this@BiometricSettingsActivity,
                                reason = "Access VaultGuard security",
                            ) { result ->
                                last.value = result.toString()
                                lastError.value = when (result) {
                                    is BiometricAuthResult.Error -> result.message
                                    else -> null
                                }
                            }
                        },
                        onDismiss = { showDialog.value = false },
                    )
                }

                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(24.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Text("VaultGuard Biometric Settings", style = MaterialTheme.typography.headlineSmall)
                    Text("Session valid: ${auth.isSessionValid()}")
                    Text("Last result: ${last.value}")
                    if (!lastError.value.isNullOrBlank()) {
                        Text("Error: ${lastError.value}")
                    }
                    if (lastCiphertext.value != null && lastIv.value != null) {
                        Text("Blob: enc=${lastCiphertext.value?.size} bytes, iv=${lastIv.value?.size} bytes")
                    }

                    Button(onClick = { showDialog.value = true }) {
                        Text("Test Biometric Prompt")
                    }

                    Button(onClick = { auth.clearSession(); last.value = "Session cleared" }) {
                        Text("Clear Session")
                    }

                    Button(onClick = {
                        auth.generateKeyWithBiometricGate(
                            activity = this@BiometricSettingsActivity,
                            alias = Constants.DEFAULT_KEY_ALIAS,
                        ) { res ->
                            last.value = "GenerateKey: $res"
                            lastError.value = (res as? BiometricAuthResult.Error)?.message
                        }
                    }) { Text("Generate Key (gated)") }

                    Button(onClick = {
                        auth.deleteKeyWithBiometricGate(
                            activity = this@BiometricSettingsActivity,
                            alias = Constants.DEFAULT_KEY_ALIAS,
                        ) { res ->
                            last.value = "DeleteKey: $res"
                            lastError.value = (res as? BiometricAuthResult.Error)?.message
                            if (res is BiometricAuthResult.Success) {
                                lastCiphertext.value = null
                                lastIv.value = null
                            }
                        }
                    }) { Text("Delete Key (gated)") }

                    Button(onClick = {
                        val data = "biometric-test".toByteArray()
                        auth.encryptWithBiometricGate(
                            activity = this@BiometricSettingsActivity,
                            plaintext = data,
                            alias = Constants.DEFAULT_KEY_ALIAS,
                        ) { res, enc, iv ->
                            last.value = "Encrypt: $res (enc=${enc?.size}, iv=${iv?.size})"
                            lastError.value = (res as? BiometricAuthResult.Error)?.message
                            lastCiphertext.value = enc
                            lastIv.value = iv
                        }
                    }) {
                        Text("Test Encrypt (gated)")
                    }

                    Button(onClick = {
                        val enc = lastCiphertext.value
                        val iv = lastIv.value
                        if (enc == null || iv == null) {
                            last.value = "Decrypt: missing encrypted blob (run encrypt first)"
                            return@Button
                        }
                        auth.decryptWithBiometricGate(
                            activity = this@BiometricSettingsActivity,
                            encryptedData = enc,
                            iv = iv,
                            alias = Constants.DEFAULT_KEY_ALIAS,
                        ) { res, plain ->
                            last.value = "Decrypt: $res (plain=${plain?.size})"
                            lastError.value = (res as? BiometricAuthResult.Error)?.message
                        }
                    }) {
                        Text("Test Decrypt (gated)")
                    }
                }
            }
        }
    }
}

