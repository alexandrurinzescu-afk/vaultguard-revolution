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
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.runtime.Composable
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.example.vaultguard.MainActivity
import com.example.vaultguard.R
import com.vaultguard.security.SecureStorage

/**
 * 2.5.4 Data deletion flow: one-click wipe all user data + keys.
 *
 * Confirmation UX:
 * - user must type DELETE
 * - then confirm via dialog
 */
class DataDeletionActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        setContent {
            Surface(color = MaterialTheme.colorScheme.background) {
                DataDeletionScreen(
                    onCancel = { finish() },
                    onDeleteConfirmed = {
                        val okStorage = runCatching { SecureStorage(this).wipeAllStoredData(deleteKeys = true) }.getOrDefault(false)
                        GdprPrefs.wipeConsentAndPolicyPrefs(this)

                        startActivity(
                            Intent(this, MainActivity::class.java)
                                .putExtra(EXTRA_DELETION_OK, okStorage)
                        )
                        finishAffinity()
                    }
                )
            }
        }
    }

    companion object {
        const val EXTRA_DELETION_OK = "deletion_ok"
    }
}

@Composable
private fun DataDeletionScreen(
    onCancel: () -> Unit,
    onDeleteConfirmed: () -> Unit,
) {
    val typed = remember { mutableStateOf("") }
    val showDialog = remember { mutableStateOf(false) }

    if (showDialog.value) {
        AlertDialog(
            onDismissRequest = { showDialog.value = false },
            title = { Text(stringResource(id = R.string.data_delete_dialog_title)) },
            text = { Text(stringResource(id = R.string.data_delete_dialog_body)) },
            confirmButton = {
                Button(onClick = {
                    showDialog.value = false
                    onDeleteConfirmed()
                }) { Text(stringResource(id = R.string.data_delete_dialog_confirm)) }
            },
            dismissButton = {
                OutlinedButton(onClick = { showDialog.value = false }) {
                    Text(stringResource(id = R.string.data_delete_dialog_cancel))
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
            text = stringResource(id = R.string.data_delete_title),
            style = MaterialTheme.typography.headlineSmall,
            fontWeight = FontWeight.SemiBold,
        )
        Spacer(modifier = Modifier.height(12.dp))
        Text(
            text = stringResource(id = R.string.data_delete_body),
            style = MaterialTheme.typography.bodyMedium,
        )
        Spacer(modifier = Modifier.height(16.dp))

        TextField(
            value = typed.value,
            onValueChange = { typed.value = it },
            modifier = Modifier.fillMaxWidth(),
            singleLine = true,
            placeholder = { Text(stringResource(id = R.string.data_delete_type_to_confirm)) },
        )

        Spacer(modifier = Modifier.height(16.dp))

        Button(
            onClick = { showDialog.value = true },
            enabled = typed.value.trim().equals("DELETE", ignoreCase = true),
            modifier = Modifier.fillMaxWidth().height(48.dp),
            contentPadding = PaddingValues(horizontal = 16.dp),
        ) {
            Text(text = stringResource(id = R.string.data_delete_confirm_button))
        }

        Spacer(modifier = Modifier.height(10.dp))

        OutlinedButton(
            onClick = onCancel,
            modifier = Modifier.fillMaxWidth().height(48.dp),
            contentPadding = PaddingValues(horizontal = 16.dp),
        ) {
            Text(text = stringResource(id = R.string.data_delete_cancel_button))
        }
    }
}

