package com.example.vaultguard.gdpr

import android.os.Bundle
import android.widget.Toast
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
import androidx.compose.ui.unit.dp

/**
 * 2.5.6 Simple retention policy UI.
 */
class RetentionSettingsActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        setContent {
            Surface(color = MaterialTheme.colorScheme.background) {
                val currentDays = remember { mutableStateOf(GdprPrefs.dataRetentionDays(this)) }
                val lastRun = remember { mutableStateOf<String?>(null) }
                RetentionSettingsScreen(
                    currentDays = currentDays.value,
                    onSet = { days ->
                        GdprPrefs.setDataRetentionDays(this, days)
                        currentDays.value = days
                    },
                    onRunNow = {
                        val deleted = runCatching { DataRetentionManager.applyRetentionIfNeeded(this) }.getOrDefault(0)
                        val msg = if (deleted <= 0) "Nothing to delete." else "Deleted $deleted old encrypted files."
                        lastRun.value = msg
                        Toast.makeText(this, msg, Toast.LENGTH_SHORT).show()
                    },
                    lastRunMessage = lastRun.value,
                    onClose = { finish() },
                )
            }
        }
    }
}

@Composable
private fun RetentionSettingsScreen(
    currentDays: Int,
    onSet: (Int) -> Unit,
    onRunNow: () -> Unit,
    lastRunMessage: String?,
    onClose: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text("Data retention", style = MaterialTheme.typography.headlineSmall)
        Text("Current: ${if (currentDays <= 0) "Forever" else "$currentDays days"}", style = MaterialTheme.typography.bodyMedium)
        Text(
            "Policy: old encrypted documents/metadata are auto-deleted by age. Consent history is trimmed to the same window.",
            style = MaterialTheme.typography.bodySmall,
        )

        Button(modifier = Modifier.fillMaxWidth().height(48.dp), onClick = { onSet(30) }) { Text("Keep 1 month") }
        Button(modifier = Modifier.fillMaxWidth().height(48.dp), onClick = { onSet(180) }) { Text("Keep 6 months") }
        Button(modifier = Modifier.fillMaxWidth().height(48.dp), onClick = { onSet(365) }) { Text("Keep 1 year") }
        Button(modifier = Modifier.fillMaxWidth().height(48.dp), onClick = { onSet(0) }) { Text("Keep forever") }

        Button(modifier = Modifier.fillMaxWidth().height(48.dp), onClick = onRunNow) { Text("Run retention now") }
        if (!lastRunMessage.isNullOrBlank()) {
            Text("Last run: $lastRunMessage", style = MaterialTheme.typography.bodySmall)
        }

        Spacer(modifier = Modifier.height(8.dp))
        OutlinedButton(modifier = Modifier.fillMaxWidth().height(48.dp), onClick = onClose) { Text("Close") }
    }
}

