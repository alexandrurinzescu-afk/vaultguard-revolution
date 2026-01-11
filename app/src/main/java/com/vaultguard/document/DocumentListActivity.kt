package com.vaultguard.document

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
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
 * Minimal document library UI (v2.1.6).
 * This is intentionally simple: list stored docs from SecureStorage-backed repository.
 */
class DocumentListActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val repository = DocumentRepository(this)

        setContent {
            MaterialTheme {
                Surface(modifier = Modifier.fillMaxSize(), color = Color.Black) {
                    DocumentListScreen(
                        repository = repository,
                        onBack = { finish() },
                        onOpenDetail = { id ->
                            startActivity(Intent(this, DocumentDetailActivity::class.java).putExtra(DocumentDetailActivity.EXTRA_ID, id))
                        },
                    )
                }
            }
        }
    }
}

@Composable
private fun DocumentListScreen(
    repository: DocumentRepository,
    onBack: () -> Unit,
    onOpenDetail: (String) -> Unit,
) {
    var docs by remember { mutableStateOf<List<DocumentData>>(emptyList()) }

    LaunchedEffect(Unit) {
        docs = repository.listDocuments()
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
            .padding(12.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text("Documents", color = Color.White)
            Spacer(modifier = Modifier.weight(1f))
            OutlinedButton(onClick = {
                docs = repository.listDocuments()
            }) { Text("Refresh", color = Color.White) }
            Spacer(modifier = Modifier.padding(4.dp))
            OutlinedButton(onClick = onBack) { Text("Back", color = Color.White) }
        }

        LazyColumn(modifier = Modifier.fillMaxSize()) {
            items(docs) { doc ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 10.dp)
                        .clickable { onOpenDetail(doc.id) },
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text(doc.type.name, color = Color.White)
                        Text(doc.id, color = Color(0xFFAAAAAA))
                    }
                    Text(doc.scanDate.toString(), color = Color(0xFF888888))
                }
            }
        }
    }
}

