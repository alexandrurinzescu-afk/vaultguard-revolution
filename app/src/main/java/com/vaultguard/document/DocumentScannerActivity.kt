package com.vaultguard.document

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Bundle
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.compose.setContent
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageCapture
import androidx.camera.core.ImageCaptureException
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Button
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
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
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import java.util.concurrent.Executors

/**
 * Document scanner UI (v2.1.6).
 *
 * - CameraX live preview + capture
 * - ML Kit Text Recognition via [DocumentScanner]
 * - Persist encrypted image + encrypted metadata via [DocumentRepository]
 */
class DocumentScannerActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        setContent {
            MaterialTheme {
                Surface(modifier = Modifier.fillMaxSize(), color = Color.Black) {
                    DocumentScannerScreen(
                        repository = DocumentRepository(this),
                        onOpenLibrary = {
                            startActivity(Intent(this, DocumentListActivity::class.java))
                        },
                    )
                }
            }
        }
    }
}

@Composable
private fun DocumentScannerScreen(
    repository: DocumentRepository,
    onOpenLibrary: () -> Unit,
) {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current

    var hasCamPermission by remember {
        mutableStateOf(
            ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED
        )
    }

    val permissionLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestPermission(),
        onResult = { granted -> hasCamPermission = granted },
    )

    var selectedType by remember { mutableStateOf(DocumentType.AUTO) }
    var typeMenuOpen by remember { mutableStateOf(false) }

    val cameraExecutor = remember { Executors.newSingleThreadExecutor() }
    var imageCapture by remember { mutableStateOf<ImageCapture?>(null) }
    var lastCaptureUri by remember { mutableStateOf<Uri?>(null) }

    var isProcessing by remember { mutableStateOf(false) }
    var rawText by remember { mutableStateOf("") }
    var extractedFields by remember { mutableStateOf<Map<String, String>>(emptyMap()) }
    var inferredType by remember { mutableStateOf<DocumentType?>(null) }
    var inferredConfidence by remember { mutableStateOf<Double?>(null) }
    var lastSavedId by remember { mutableStateOf<String?>(null) }

    LaunchedEffect(Unit) {
        if (!hasCamPermission) permissionLauncher.launch(Manifest.permission.CAMERA)
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
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box {
                OutlinedButton(onClick = { typeMenuOpen = true }) {
                    Text(text = "Type: ${selectedType.name}", color = Color.White)
                }
                DropdownMenu(expanded = typeMenuOpen, onDismissRequest = { typeMenuOpen = false }) {
                    DocumentType.entries.forEach { t ->
                        DropdownMenuItem(
                            text = { Text(t.name) },
                            onClick = {
                                selectedType = t
                                typeMenuOpen = false
                            }
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.weight(1f))

            OutlinedButton(onClick = onOpenLibrary) {
                Text("Documents", color = Color.White)
            }
        }

        Box(
            modifier = Modifier
                .fillMaxWidth()
                .weight(1f)
        ) {
            if (!hasCamPermission) {
                Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text("Camera permission is required", color = Color.White)
                        Spacer(modifier = Modifier.height(8.dp))
                        Button(onClick = { permissionLauncher.launch(Manifest.permission.CAMERA) }) {
                            Text("Grant permission")
                        }
                    }
                }
            } else {
                AndroidView(
                    factory = { ctx ->
                        PreviewView(ctx).apply {
                            scaleType = PreviewView.ScaleType.FILL_CENTER
                            implementationMode = PreviewView.ImplementationMode.COMPATIBLE
                        }
                    },
                    modifier = Modifier.fillMaxSize(),
                    update = { previewView ->
                        val cameraProviderFuture = ProcessCameraProvider.getInstance(previewView.context)
                        cameraProviderFuture.addListener({
                            val cameraProvider = cameraProviderFuture.get()
                            val preview = Preview.Builder().build().also { it.setSurfaceProvider(previewView.surfaceProvider) }
                            val capture = ImageCapture.Builder()
                                .setCaptureMode(ImageCapture.CAPTURE_MODE_MINIMIZE_LATENCY)
                                .build()
                            val selector = CameraSelector.DEFAULT_BACK_CAMERA

                            try {
                                cameraProvider.unbindAll()
                                cameraProvider.bindToLifecycle(lifecycleOwner, selector, preview, capture)
                                imageCapture = capture
                            } catch (e: Exception) {
                                Toast.makeText(previewView.context, "Camera start failed: ${e.message}", Toast.LENGTH_LONG).show()
                            }
                        }, ContextCompat.getMainExecutor(previewView.context))
                    }
                )
            }
        }

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Button(
                enabled = hasCamPermission && !isProcessing,
                onClick = {
                    val capture = imageCapture ?: return@Button
                    isProcessing = true
                    rawText = ""
                    extractedFields = emptyMap()
                    inferredType = null
                    inferredConfidence = null
                    lastSavedId = null

                    val outFile = File(context.cacheDir, "doc_capture_${System.currentTimeMillis()}.jpg")
                    val output = ImageCapture.OutputFileOptions.Builder(outFile).build()
                    capture.takePicture(
                        output,
                        cameraExecutor,
                        object : ImageCapture.OnImageSavedCallback {
                            override fun onError(exception: ImageCaptureException) {
                                isProcessing = false
                                CoroutineScope(Dispatchers.Main).launch {
                                    Toast.makeText(context, "Capture failed: ${exception.message}", Toast.LENGTH_LONG).show()
                                }
                            }

                            override fun onImageSaved(outputFileResults: ImageCapture.OutputFileResults) {
                                val uri = outputFileResults.savedUri ?: Uri.fromFile(outFile)
                                lastCaptureUri = uri

                                CoroutineScope(Dispatchers.Main).launch {
                                    runCatching {
                                        val scanner = DocumentScanner()
                                        val result = scanner.scan(context, uri, selectedType)
                                        rawText = result.enhancedText.ifBlank { result.rawText }
                                        extractedFields = result.extractedFields
                                        inferredType = result.inferredType
                                        inferredConfidence = result.classificationConfidence
                                    }.onFailure { e ->
                                        Toast.makeText(context, "OCR failed: ${e.message}", Toast.LENGTH_LONG).show()
                                    }
                                    isProcessing = false
                                }
                            }
                        }
                    )
                }
            ) {
                Text(if (isProcessing) "Processing..." else "Capture + OCR")
            }

            Button(
                enabled = !isProcessing && lastCaptureUri != null && extractedFields.isNotEmpty(),
                onClick = {
                    val uri = lastCaptureUri ?: return@Button
                    isProcessing = true
                    CoroutineScope(Dispatchers.Main).launch {
                        val saved = runCatching {
                            val bytes = withContext(Dispatchers.IO) {
                                context.contentResolver.openInputStream(uri)?.use { it.readBytes() }
                            } ?: throw IllegalStateException("Unable to read captured image bytes")

                            val effectiveType = if (selectedType == DocumentType.AUTO) {
                                inferredType ?: DocumentType.OTHER
                            } else {
                                selectedType
                            }

                            repository.saveScannedDocument(
                                type = effectiveType,
                                jpegBytes = bytes,
                                extractedText = extractedFields,
                                originalImageUri = uri.toString(),
                                expirationDate = null,
                                isVerified = false,
                                biometricBindingId = null,
                            )
                        }.getOrNull()

                        if (saved != null) {
                            lastSavedId = saved.id
                            Toast.makeText(context, "Saved securely: ${saved.id}", Toast.LENGTH_LONG).show()
                        } else {
                            Toast.makeText(context, "Save failed", Toast.LENGTH_LONG).show()
                        }
                        isProcessing = false
                    }
                }
            ) {
                Text("Save (Encrypted)")
            }
        }

        if (rawText.isNotBlank()) {
            if (inferredType != null && inferredConfidence != null) {
                Text(
                    "Auto-classified: ${inferredType!!.name} (conf ${(inferredConfidence!! * 100).toInt()}%)",
                    color = Color.White
                )
            }
            Text("Extracted fields", color = Color.White)
            LazyColumn(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(160.dp)
                    .background(Color(0xFF111111))
                    .padding(8.dp),
            ) {
                items(extractedFields.entries.toList()) { (k, v) ->
                    Text("$k: $v", color = Color.White)
                }
            }
        }

        if (lastSavedId != null) {
            Text("Last saved: $lastSavedId", color = Color.Green)
        }
    }
}

