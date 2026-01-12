
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
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.example.vaultguard.gdpr.BiometricConsentActivity
import com.example.vaultguard.gdpr.DisclaimerActivity
import com.example.vaultguard.gdpr.GdprPrefs
import com.example.vaultguard.gdpr.PrivacyPolicyActivity
import com.vaultguard.document.DocumentScannerActivity
import com.vaultguard.security.biometric.ui.BiometricSettingsActivity

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

        setContent {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(Color.Black),
                contentAlignment = Alignment.Center
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(
                        text = "EU SUNT AICI!\nDACĂ VEZI ASTA, AM PRELUAT CONTROLUL.",
                        color = Color.Green,
                        textAlign = TextAlign.Center
                    )
                    Spacer(modifier = Modifier.height(16.dp))
                    Button(onClick = {
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
                        Text("Open Biometric UI (2.1.2)")
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
                        startActivity(Intent(this@MainActivity, DocumentScannerActivity::class.java))
                    }) {
                        Text("Open Document Scanner (2.1.6)")
                    }
                }
            }
        }
    }
}
