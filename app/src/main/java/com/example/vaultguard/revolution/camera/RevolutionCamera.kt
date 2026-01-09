package com.example.vaultguard.revolution.camera

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.RectF
import android.util.Log
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Button
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import com.example.vaultguard.revolution.ai.FaceDetectorProcessor
import java.util.concurrent.Executors

// OCHIUL INTELIGENT AL REVOLUȚIEI (CU OGLINDĂ HOLOGRAFICĂ)

@Composable
fun RevolutionCameraPreview(
    modifier: Modifier = Modifier,
    onCameraReady: () -> Unit = {},
    analyzer: ((ImageProxy) -> Unit)? = null,
    detectedFaces: List<FaceDetectorProcessor.DetectedFace> = emptyList() // CANAL DE DATE PENTRU AI
) {
    val context = LocalContext.current
    var hasCamPermission by remember { mutableStateOf(ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) }
    val permissionLauncher = rememberLauncherForActivityResult(contract = ActivityResultContracts.RequestPermission()) { isGranted ->
        hasCamPermission = isGranted
    }

    LaunchedEffect(key1 = true) {
        if (!hasCamPermission) {
            permissionLauncher.launch(Manifest.permission.CAMERA)
        }
    }

    Box(modifier = modifier, contentAlignment = Alignment.Center) {
        if (hasCamPermission) {
            CameraView(onCameraReady, analyzer, detectedFaces)
        } else {
            PermissionDeniedUI { permissionLauncher.launch(Manifest.permission.CAMERA) }
        }
    }
}

@Composable
private fun CameraView(
    onCameraReady: () -> Unit, 
    analyzer: ((ImageProxy) -> Unit)?, 
    detectedFaces: List<FaceDetectorProcessor.DetectedFace>
) {
    val lifecycleOwner = LocalLifecycleOwner.current
    val context = LocalContext.current
    
    AndroidView(
        factory = { ctx ->
            val previewView = PreviewView(ctx)
            startCamera(context, lifecycleOwner, previewView, onCameraReady, analyzer)
            previewView
        },
        modifier = Modifier.fillMaxSize()
    )
    
    // AFIȘAJUL HOLOGRAFIC
    FaceBoundingBoxOverlay(faces = detectedFaces)
    IrisTargetingOverlay()
}

@Composable
private fun FaceBoundingBoxOverlay(faces: List<FaceDetectorProcessor.DetectedFace>) {
    Canvas(modifier = Modifier.fillMaxSize()) { 
        val viewWidth = size.width
        val viewHeight = size.height

        faces.forEach { face ->
            val box = face.boundingBox
            drawRect(
                color = Color.Yellow,
                topLeft = Offset(box.left * viewWidth, box.top * viewHeight),
                size = Size(box.width() * viewWidth, box.height() * viewHeight),
                style = Stroke(width = 2.dp.toPx())
            )
        }
    }
}

@Composable
private fun PermissionDeniedUI(onRequestPermission: () -> Unit) {
    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center, modifier = Modifier.fillMaxSize()) {
        Text("Revoluția are nevoie de ochi!")
        Spacer(modifier = Modifier.height(8.dp))
        Button(onClick = onRequestPermission) { Text("Acordă permisiunea") }
    }
}

private fun startCamera(
    context: Context, 
    lifecycleOwner: LifecycleOwner, 
    previewView: PreviewView, 
    onCameraReady: () -> Unit,
    analyzerCallback: ((ImageProxy) -> Unit)?
) {
    val cameraProviderFuture = ProcessCameraProvider.getInstance(context)
    val cameraExecutor = Executors.newSingleThreadExecutor()

    cameraProviderFuture.addListener({
        val cameraProvider = cameraProviderFuture.get()
        val preview = Preview.Builder().build().also { it.setSurfaceProvider(previewView.surfaceProvider) }
        val cameraSelector = CameraSelector.DEFAULT_FRONT_CAMERA

        val imageAnalyzer = analyzerCallback?.let {
            ImageAnalysis.Builder()
                .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                .build()
                .apply { setAnalyzer(cameraExecutor, it) }
        }

        try {
            cameraProvider.unbindAll()
            if (imageAnalyzer != null) {
                cameraProvider.bindToLifecycle(lifecycleOwner, cameraSelector, preview, imageAnalyzer)
            } else {
                cameraProvider.bindToLifecycle(lifecycleOwner, cameraSelector, preview)
            }
            onCameraReady()
        } catch(e: Exception) {
            Log.e("REVOLUTION_CAMERA", "Use case binding failed", e)
        }
    }, ContextCompat.getMainExecutor(context))
}

@Composable
private fun IrisTargetingOverlay() {
    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Box(modifier = Modifier.size(220.dp).border(width = 2.dp, color = Color.Green.copy(alpha = 0.6f), shape = CircleShape))
    }
}
