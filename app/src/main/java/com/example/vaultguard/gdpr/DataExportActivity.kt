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
import androidx.compose.ui.unit.dp
import androidx.core.content.FileProvider
import androidx.lifecycle.lifecycleScope
import com.example.vaultguard.R
import com.vaultguard.document.DocumentRepository
import com.vaultguard.security.SecureStorage
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.FileInputStream
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream

/**
 * 2.5.5 GDPR data portability: export user-controlled data package.
 *
 * - Includes: document metadata, consent history, encrypted backup (no plaintext).
 * - Excludes: biometric templates.
 */
class DataExportActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        setContent {
            Surface(color = MaterialTheme.colorScheme.background) {
                val status = remember { mutableStateOf<ExportStatus>(ExportStatus.Idle) }
                val exportFile = remember { mutableStateOf<File?>(null) }

                DataExportScreen(
                    status = status.value,
                    onGenerate = {
                        status.value = ExportStatus.Generating
                        lifecycleScope.launch {
                            val res = withContext(Dispatchers.IO) { generateExportZip() }
                            if (res != null && res.exists()) {
                                exportFile.value = res
                                status.value = ExportStatus.Ready
                            } else {
                                status.value = ExportStatus.Error
                            }
                        }
                    },
                    onShare = {
                        val f = exportFile.value ?: return@DataExportScreen
                        shareFile(f)
                    },
                    onClose = { finish() },
                )
            }
        }
    }

    private fun shareFile(file: File) {
        val uri = FileProvider.getUriForFile(this, "${packageName}.fileprovider", file)
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "application/zip"
            putExtra(Intent.EXTRA_STREAM, uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        startActivity(Intent.createChooser(intent, getString(R.string.data_export_share)))
    }

    private fun generateExportZip(): File? {
        val out = File(cacheDir, "vaultguard_export_${System.currentTimeMillis()}.zip")
        if (out.exists()) out.delete()

        val repo = DocumentRepository(this)
        val docs = repo.listDocuments()

        val prefs = JSONObject().apply {
            put("legal_disclaimer_accepted", GdprPrefs.isLegalDisclaimerAccepted(this@DataExportActivity))
            put("privacy_policy_accepted", GdprPrefs.isPrivacyPolicyAccepted(this@DataExportActivity))
            put("biometric_consent_accepted", GdprPrefs.isBiometricConsentAccepted(this@DataExportActivity))
            put("biometric_consent_version", GdprPrefs.biometricConsentVersion(this@DataExportActivity))
            put("biometric_consent_timestamp_iso", GdprPrefs.biometricConsentTimestampIso(this@DataExportActivity))
        }

        val docsJson = JSONArray().apply {
            for (d in docs) {
                put(
                    JSONObject().apply {
                        put("id", d.id)
                        put("type", d.type.name)
                        put("scanDate", d.scanDate.toString())
                        put("expirationDate", d.expirationDate?.toString())
                        put("isVerified", d.isVerified)
                        put("biometricBindingId", d.biometricBindingId)
                        put("extractedText", JSONObject(d.extractedText))
                    }
                )
            }
        }

        val exportInfo = JSONObject().apply {
            put("generatedAtEpochMillis", System.currentTimeMillis())
            put("app", "VaultGuard Revolution")
            put("notes", "This export includes metadata + encrypted backups. No biometric templates are included.")
            put("preferencesSnapshot", prefs)
            put("documents", docsJson)
        }

        val consentLogText = runCatching {
            openFileInput("consent_log.txt").bufferedReader().use { it.readText() }
        }.getOrDefault("")

        val encryptedBackup = runCatching { SecureStorage(this).exportEncryptedBackup() }.getOrNull()

        return runCatching {
            ZipOutputStream(out.outputStream().buffered()).use { zos ->
                // 1) metadata
                zos.putNextEntry(ZipEntry("export_info.json"))
                zos.write(exportInfo.toString(2).toByteArray(Charsets.UTF_8))
                zos.closeEntry()

                // 2) consent history
                zos.putNextEntry(ZipEntry("consent_history.txt"))
                zos.write(consentLogText.toByteArray(Charsets.UTF_8))
                zos.closeEntry()

                // 3) encrypted backup zip (no plaintext)
                if (encryptedBackup != null && encryptedBackup.exists()) {
                    zos.putNextEntry(ZipEntry("encrypted_backup.zip"))
                    FileInputStream(encryptedBackup).use { it.copyTo(zos) }
                    zos.closeEntry()
                }
            }
            out
        }.getOrNull()
    }
}

private sealed class ExportStatus {
    data object Idle : ExportStatus()
    data object Generating : ExportStatus()
    data object Ready : ExportStatus()
    data object Error : ExportStatus()
}

@Composable
private fun DataExportScreen(
    status: ExportStatus,
    onGenerate: () -> Unit,
    onShare: () -> Unit,
    onClose: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(20.dp),
        verticalArrangement = Arrangement.Top,
    ) {
        Text(text = stringResource(id = R.string.data_export_title), style = MaterialTheme.typography.headlineSmall)
        Spacer(modifier = Modifier.height(12.dp))
        Text(text = stringResource(id = R.string.data_export_body), style = MaterialTheme.typography.bodyMedium)

        Spacer(modifier = Modifier.height(16.dp))

        when (status) {
            ExportStatus.Idle -> {
                Button(
                    onClick = onGenerate,
                    modifier = Modifier.fillMaxWidth().height(48.dp),
                    contentPadding = PaddingValues(horizontal = 16.dp),
                ) { Text(stringResource(id = R.string.data_export_generate)) }
            }

            ExportStatus.Generating -> {
                Text(text = stringResource(id = R.string.data_export_generating))
            }

            ExportStatus.Ready -> {
                Text(text = stringResource(id = R.string.data_export_done))
                Spacer(modifier = Modifier.height(10.dp))
                Button(
                    onClick = onShare,
                    modifier = Modifier.fillMaxWidth().height(48.dp),
                    contentPadding = PaddingValues(horizontal = 16.dp),
                ) { Text(stringResource(id = R.string.data_export_share)) }
            }

            ExportStatus.Error -> {
                Text(text = stringResource(id = R.string.data_export_error))
            }
        }

        Spacer(modifier = Modifier.height(12.dp))
        OutlinedButton(
            onClick = onClose,
            modifier = Modifier.fillMaxWidth().height(48.dp),
            contentPadding = PaddingValues(horizontal = 16.dp),
        ) { Text("Close") }
    }
}

