package com.vaultguard.security.biometric.ui

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
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.vaultguard.security.biometric.BiometricAccessLogger
import java.io.File

/**
 * 2.5.7 Biometric Usage Transparency screen.
 *
 * Shows the local-only biometric access log (no network).
 */
class BiometricTransparencyActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            Surface(color = MaterialTheme.colorScheme.background) {
                BiometricTransparencyScreen(
                    loadLines = { readLogLines() },
                    onClear = {
                        BiometricAccessLogger.clear(this)
                    },
                    onClose = { finish() },
                )
            }
        }
    }

    private fun readLogLines(): List<String> {
        // File is stored via Context.openFileOutput; it lives under filesDir.
        val f = File(filesDir, "biometric_access_log.txt")
        if (!f.exists() || !f.isFile) return emptyList()
        return runCatching {
            // Show most recent lines first.
            f.readLines().takeLast(300).asReversed()
        }.getOrDefault(emptyList())
    }
}

@Composable
private fun BiometricTransparencyScreen(
    loadLines: () -> List<String>,
    onClear: () -> Unit,
    onClose: () -> Unit,
) {
    val lines = remember { mutableStateOf<List<String>>(emptyList()) }

    LaunchedEffect(Unit) {
        lines.value = loadLines()
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text("Biometric Usage Transparency", style = MaterialTheme.typography.headlineSmall)
        Text("Local-only log of biometric prompt attempts.", style = MaterialTheme.typography.bodySmall)

        Button(
            modifier = Modifier.fillMaxWidth().height(48.dp),
            onClick = {
                onClear()
                lines.value = loadLines()
            },
        ) { Text("Clear log") }

        Spacer(modifier = Modifier.height(4.dp))

        if (lines.value.isEmpty()) {
            Text("No biometric access events recorded yet.", style = MaterialTheme.typography.bodyMedium)
        } else {
            LazyColumn(modifier = Modifier.fillMaxWidth().weight(1f, fill = true)) {
                items(lines.value) { line ->
                    Text(text = line, style = MaterialTheme.typography.bodySmall)
                    Spacer(modifier = Modifier.height(8.dp))
                }
            }
        }

        OutlinedButton(
            modifier = Modifier.fillMaxWidth().height(48.dp),
            onClick = onClose,
        ) { Text("Close") }
    }
}

