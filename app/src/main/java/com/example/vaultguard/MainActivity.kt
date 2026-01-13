
package com.example.vaultguard

import android.os.Bundle
import android.content.Intent
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.material3.Button
import androidx.compose.material3.Text
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.lifecycleScope
import com.example.vaultguard.gdpr.BiometricConsentActivity
import com.example.vaultguard.gdpr.DataDeletionActivity
import com.example.vaultguard.gdpr.DataExportActivity
import com.example.vaultguard.gdpr.DataRetentionManager
import com.example.vaultguard.gdpr.DisclaimerActivity
import com.example.vaultguard.gdpr.GdprPrefs
import com.example.vaultguard.gdpr.PrivacyPolicyActivity
import com.example.vaultguard.gdpr.RetentionSettingsActivity
import com.example.vaultguard.tier.EntitlementsRepository
import com.example.vaultguard.tier.Feature
import com.example.vaultguard.tier.FeatureGate
import com.example.vaultguard.tier.TierPrefs
import com.example.vaultguard.tier.UserEntitlements
import com.example.vaultguard.tier.UserTier
import com.example.vaultguard.tier.ui.PaywallActivity
import com.vaultguard.document.DocumentScannerActivity
import com.vaultguard.security.biometric.ui.BiometricSettingsActivity
import kotlinx.coroutines.launch

// OPERAȚIUNEA "CANARUL DIN MINĂ"
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 2.5.1 "first-to-claim" gate: user must accept the legal disclaimer once before using the app.
        if (!GdprPrefs.isLegalDisclaimerAccepted(this)) {
            startActivity(Intent(this, DisclaimerActivity::class.java))
            finish()
            return
        }

        // 2.5.2 gate: privacy policy must be accepted before using the app.
        if (!GdprPrefs.isPrivacyPolicyAccepted(this)) {
            startActivity(Intent(this, PrivacyPolicyActivity::class.java))
            finish()
            return
        }

        // 2.5.6 best-effort retention pruning (no decryption; deletes encrypted files by age).
        runCatching { DataRetentionManager.applyRetentionIfNeeded(this) }

        setContent {
            val repo = remember { EntitlementsRepository() }

            // Load from local prefs immediately (fast), then refresh from backend (best-effort).
            val tierState = remember { mutableStateOf(TierPrefs.getUserTier(this)) }

            LaunchedEffect(Unit) {
                // Best-effort: if backend is down, keep local tier.
                lifecycleScope.launch {
                    repo.refreshEntitlements(this@MainActivity).onSuccess { tierState.value = it }
                }
            }

            val userTier = tierState.value
            val entitlements = UserEntitlements.fromTier(userTier)

            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(Color.Black),
                contentAlignment = Alignment.Center
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(
                        text = "VaultGuard Angel\nMode: $userTier",
                        color = Color.Green,
                        textAlign = TextAlign.Center
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        text = when (userTier) {
                            UserTier.LITE -> "Angel Lite: demo / onboarding. Upgrade to unlock real biometric enrollment."
                            UserTier.ANGEL -> "Angel: activated. Real biometric features are enabled."
                            UserTier.REVOLUTION -> "Revolution: premium entitlements enabled."
                        },
                        color = Color.White,
                        textAlign = TextAlign.Center
                    )
                    Spacer(modifier = Modifier.height(16.dp))

                    // Lite -> Angel upgrade CTA (scaffold).
                    if (userTier == UserTier.LITE) {
                        Button(onClick = {
                            // Show paywall (mock purchase), then refresh entitlements.
                            startActivity(Intent(this@MainActivity, PaywallActivity::class.java))
                        }) {
                            Text("Upgrade to Angel (paywall)")
                        }
                        Spacer(modifier = Modifier.height(12.dp))
                    }

                    Button(onClick = {
                        val canUseRealBiometrics = FeatureGate.isFeatureEnabled(entitlements, Feature.REAL_BIOMETRIC_AUTH)
                        if (!canUseRealBiometrics) {
                            // Premium feature gate: show paywall instead of running biometrics in Lite.
                            startActivity(Intent(this@MainActivity, PaywallActivity::class.java))
                            return@Button
                        }

                        if (!GdprPrefs.isBiometricConsentAccepted(this@MainActivity)) {
                            startActivity(
                                Intent(this@MainActivity, BiometricConsentActivity::class.java)
                                    .putExtra(BiometricConsentActivity.EXTRA_MODE, BiometricConsentActivity.MODE_GATE)
                                    .putExtra(BiometricConsentActivity.EXTRA_NEXT, BiometricConsentActivity.NEXT_BIOMETRIC_SETTINGS)
                            )
                        } else {
                            startActivity(Intent(this@MainActivity, BiometricSettingsActivity::class.java))
                        }
                    }) {
                        Text(if (userTier == UserTier.LITE) "Biometric demo / consent (Lite)" else "Open Biometric UI (Angel)")
                    }
                    Spacer(modifier = Modifier.height(12.dp))
                    Button(onClick = {
                        startActivity(
                            Intent(this@MainActivity, BiometricConsentActivity::class.java)
                                .putExtra(BiometricConsentActivity.EXTRA_MODE, BiometricConsentActivity.MODE_MANAGE)
                                .putExtra(BiometricConsentActivity.EXTRA_NEXT, BiometricConsentActivity.NEXT_MAIN)
                        )
                    }) {
                        Text("Manage Biometric Consent (2.5.3)")
                    }
                    Spacer(modifier = Modifier.height(12.dp))
                    Button(onClick = {
                        // Documents are available in all tiers, but Lite can be treated as demo-only later.
                        startActivity(Intent(this@MainActivity, DocumentScannerActivity::class.java))
                    }) {
                        Text("Open Document Scanner (2.1.6)")
                    }
                    Spacer(modifier = Modifier.height(12.dp))
                    Button(onClick = {
                        startActivity(Intent(this@MainActivity, DataDeletionActivity::class.java))
                    }) {
                        Text("Delete all data (2.5.4)")
                    }
                    Spacer(modifier = Modifier.height(12.dp))
                    Button(onClick = {
                        startActivity(Intent(this@MainActivity, DataExportActivity::class.java))
                    }) {
                        Text("Export my data (2.5.5)")
                    }
                    Spacer(modifier = Modifier.height(12.dp))
                    Button(onClick = {
                        startActivity(Intent(this@MainActivity, RetentionSettingsActivity::class.java))
                    }) {
                        Text("Data retention (2.5.6)")
                    }

                    if (userTier == UserTier.ANGEL) {
                        Spacer(modifier = Modifier.height(12.dp))
                        Button(onClick = {
                            // Placeholder: in real app this will be website upgrade + entitlement refresh.
                            lifecycleScope.launch {
                                repo.mockPurchaseRevolution(this@MainActivity).onSuccess { tierState.value = it }
                            }
                        }) {
                            Text("Upgrade to Revolution (mock)")
                        }
                    }
                }
            }
        }
    }
}
