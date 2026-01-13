package com.example.vaultguard.tier.ui

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.lifecycleScope
import com.example.vaultguard.tier.EntitlementsRepository
import com.example.vaultguard.tier.UserTier
import kotlinx.coroutines.launch

/**
 * Sprint 0.1.2: Paywall screen (mock purchase).
 *
 * Real flow later:
 * - Apple/Google IAP (RevenueCat)
 * - after purchase success -> trigger identity verification -> backend activates ANGEL entitlement
 */
class PaywallActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val repo = EntitlementsRepository()

        setContent {
            Surface(color = MaterialTheme.colorScheme.background) {
                val status = remember { mutableStateOf<String?>(null) }
                val busy = remember { mutableStateOf(false) }

                PaywallScreen(
                    status = status.value,
                    busy = busy.value,
                    onMockPurchase = {
                        busy.value = true
                        status.value = "Purchasing (mock)..."
                        lifecycleScope.launch {
                            val res = repo.mockPurchaseAngel(this@PaywallActivity)
                            busy.value = false
                            status.value = res.fold(
                                onSuccess = { "Activated: $it" },
                                onFailure = { e ->
                                    // BLOCKER_FOR_HUMAN: backend not reachable (start backend/uvicorn, emulator networking, etc.)
                                    "Error: ${e.message ?: e.javaClass.simpleName}"
                                }
                            )
                            if (res.getOrNull() == UserTier.ANGEL) finish()
                        }
                    },
                    onClose = { finish() },
                )
            }
        }
    }
}

@Composable
private fun PaywallScreen(
    status: String?,
    busy: Boolean,
    onMockPurchase: () -> Unit,
    onClose: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text("VaultGuard Angel", style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.SemiBold)
        Text("Three tiers in one app:", style = MaterialTheme.typography.bodyMedium)
        Text("- Angel Lite: demo/onboarding (free)", style = MaterialTheme.typography.bodySmall)
        Text("- Angel: activated after purchase + identity verification", style = MaterialTheme.typography.bodySmall)
        Text("- Revolution: premium via website upgrade", style = MaterialTheme.typography.bodySmall)

        Spacer(modifier = Modifier.height(8.dp))
        Text("You are in LITE mode. This feature requires ANGEL activation.", style = MaterialTheme.typography.bodyMedium)

        if (!status.isNullOrBlank()) {
            Text("Status: $status", style = MaterialTheme.typography.bodySmall)
        }

        Button(
            modifier = Modifier.fillMaxWidth().height(48.dp),
            onClick = onMockPurchase,
            enabled = !busy,
        ) { Text("Mock purchase → Activate Angel") }

        OutlinedButton(
            modifier = Modifier.fillMaxWidth().height(48.dp),
            onClick = onClose,
        ) { Text("Not now") }
    }
}

