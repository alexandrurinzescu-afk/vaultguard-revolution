package com.example.vaultguard.gdpr

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.example.vaultguard.MainActivity
import com.example.vaultguard.R
import com.vaultguard.security.biometric.ui.BiometricSettingsActivity

/**
 * 2.5.3 Explicit biometric consent gate.
 *
 * "First-to-claim" messaging is an app-level claim registry concept; it is NOT government identity verification.
 */
class BiometricConsentActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val next = intent.getStringExtra(EXTRA_NEXT) ?: NEXT_MAIN
        val mode = intent.getStringExtra(EXTRA_MODE) ?: MODE_GATE

        val isAccepted = GdprPrefs.isBiometricConsentAccepted(this)
        val acceptedInfo = if (isAccepted) {
            val ts = GdprPrefs.biometricConsentTimestampIso(this) ?: "unknown"
            val v = GdprPrefs.biometricConsentVersion(this)
            "Status: ACCEPTED (v=$v, at=$ts)"
        } else {
            null
        }

        // Gate mode fast path: if already accepted, continue to target.
        if (mode == MODE_GATE && isAccepted) {
            navigateNext(next)
            return
        }

        setContent {
            Surface(color = MaterialTheme.colorScheme.background) {
                BiometricConsentScreen(
                    accepted = isAccepted,
                    acceptedInfo = acceptedInfo,
                    onAccept = {
                        if (!GdprPrefs.isBiometricConsentAccepted(this)) {
                            GdprPrefs.setBiometricConsentAccepted(this, true)
                        }
                        navigateNext(next)
                    },
                    onDecline = {
                        finishAffinity()
                    },
                    onRevoke = {
                        GdprPrefs.setBiometricConsentAccepted(this, false)
                        startActivity(Intent(this, MainActivity::class.java))
                        finish()
                    },
                )
            }
        }
    }

    private fun navigateNext(next: String) {
        val target = when (next) {
            NEXT_BIOMETRIC_SETTINGS -> BiometricSettingsActivity::class.java
            else -> MainActivity::class.java
        }
        startActivity(Intent(this, target))
        finish()
    }

    companion object {
        const val EXTRA_NEXT = "next"
        const val EXTRA_MODE = "mode"

        const val NEXT_MAIN = "main"
        const val NEXT_BIOMETRIC_SETTINGS = "biometric_settings"

        const val MODE_GATE = "gate"
        const val MODE_MANAGE = "manage"
    }
}

@Composable
private fun BiometricConsentScreen(
    accepted: Boolean,
    acceptedInfo: String?,
    onAccept: () -> Unit,
    onDecline: () -> Unit,
    onRevoke: () -> Unit,
) {
    val showRevokeDialog = remember { mutableStateOf(false) }

    if (showRevokeDialog.value) {
        AlertDialog(
            onDismissRequest = { showRevokeDialog.value = false },
            title = { Text(stringResource(id = R.string.biometric_consent_revoke_title)) },
            text = { Text(stringResource(id = R.string.biometric_consent_revoke_body)) },
            confirmButton = {
                Button(onClick = {
                    showRevokeDialog.value = false
                    onRevoke()
                }) { Text(stringResource(id = R.string.biometric_consent_revoke_confirm)) }
            },
            dismissButton = {
                OutlinedButton(onClick = { showRevokeDialog.value = false }) {
                    Text(stringResource(id = R.string.biometric_consent_revoke_cancel))
                }
            }
        )
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(20.dp),
        verticalArrangement = Arrangement.Top,
    ) {
        Text(
            text = stringResource(id = R.string.biometric_consent_title),
            style = MaterialTheme.typography.headlineSmall,
            fontWeight = FontWeight.SemiBold,
        )
        Spacer(modifier = Modifier.height(12.dp))

        Text(
            modifier = Modifier
                .weight(1f, fill = true)
                .verticalScroll(rememberScrollState()),
            text = stringResource(id = R.string.biometric_consent_body),
            style = MaterialTheme.typography.bodyMedium,
        )

        if (accepted && !acceptedInfo.isNullOrBlank()) {
            Spacer(modifier = Modifier.height(10.dp))
            Text(text = acceptedInfo, style = MaterialTheme.typography.bodySmall)
        }

        Spacer(modifier = Modifier.height(16.dp))

        Button(
            onClick = onAccept,
            modifier = Modifier.fillMaxWidth().height(48.dp),
            contentPadding = PaddingValues(horizontal = 16.dp),
        ) {
            Text(text = stringResource(id = if (accepted) R.string.biometric_consent_continue else R.string.biometric_consent_accept))
        }
        Spacer(modifier = Modifier.height(10.dp))

        OutlinedButton(
            onClick = onDecline,
            modifier = Modifier.fillMaxWidth().height(48.dp),
            contentPadding = PaddingValues(horizontal = 16.dp),
        ) {
            Text(text = stringResource(id = R.string.biometric_consent_decline))
        }

        if (accepted) {
            Spacer(modifier = Modifier.height(10.dp))
            OutlinedButton(
                onClick = { showRevokeDialog.value = true },
                modifier = Modifier.fillMaxWidth().height(48.dp),
                contentPadding = PaddingValues(horizontal = 16.dp),
            ) {
                Text(text = stringResource(id = R.string.biometric_consent_revoke))
            }
        }
    }
}

