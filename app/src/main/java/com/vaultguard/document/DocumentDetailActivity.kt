package com.vaultguard.document

import android.os.Bundle
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
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
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp

/**
 * Minimal document detail screen (v2.1.6).
 * Shows decrypted metadata (not the decrypted image) and supports delete.
 */
class DocumentDetailActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val id = intent.getStringExtra(EXTRA_ID)
        if (id.isNullOrBlank()) {
            finish()
            return
        }
        val repository = DocumentRepository(this)

        setContent {
            MaterialTheme {
                Surface(modifier = Modifier.fillMaxSize(), color = Color.Black) {
                    DocumentDetailScreen(
                        repository = repository,
                        id = id,
                        onBack = { finish() },
                        onDeleted = {
                            Toast.makeText(this, "Deleted: $id", Toast.LENGTH_LONG).show()
                            finish()
                        },
                    )
                }
            }
        }
    }

    companion object {
        const val EXTRA_ID = "document_id"
    }
}

@Composable
private fun DocumentDetailScreen(
    repository: DocumentRepository,
    id: String,
    onBack: () -> Unit,
    onDeleted: () -> Unit,
) {
    var doc by remember { mutableStateOf<DocumentData?>(null) }

    LaunchedEffect(id) {
        doc = repository.getDocument(id)
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
            .padding(12.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Text("Document Detail", color = Color.White)
            Spacer(modifier = Modifier.weight(1f))
            OutlinedButton(onClick = onBack) { Text("Back", color = Color.White) }
        }

        val d = doc
        if (d == null) {
            Text("Loading...", color = Color.White)
            return
        }

        Text("ID: ${d.id}", color = Color.White)
        Text("Type: ${d.type.name}", color = Color.White)
        Text("Scanned: ${d.scanDate}", color = Color.White)
        if (d.expirationDate != null) Text("Expires: ${d.expirationDate}", color = Color.White)
        Text("Verified: ${d.isVerified}", color = Color.White)
        if (d.biometricBindingId != null) Text("Biometric binding: ${d.biometricBindingId}", color = Color.White)

        Text("Extracted fields", color = Color.White)
        LazyColumn(
            modifier = Modifier
                .fillMaxWidth()
                .weight(1f)
                .background(Color(0xFF111111))
                .padding(8.dp),
        ) {
            items(d.extractedText.entries.toList()) { (k, v) ->
                Text("$k: $v", color = Color.White)
            }
        }

        Button(
            onClick = {
                if (repository.delete(id)) onDeleted()
            }
        ) {
            Text("Delete (Encrypted)")
        }
    }
}

