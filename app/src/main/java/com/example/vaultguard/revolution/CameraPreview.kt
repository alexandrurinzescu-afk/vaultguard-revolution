package com.example.vaultguard.revolution

import android.Manifest
import android.content.pm.PackageManager
import android.util.Log
import androidx.camera.core.CameraSelector
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner

@Composable
fun CameraPreviewComponent(
    modifier: Modifier = Modifier,
    onCameraStarted: () -> Unit = {},
    onCameraError: (String) -> Unit = {}
) {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current
    
    val hasCameraPermission = remember {
        ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.CAMERA
        ) == PackageManager.PERMISSION_GRANTED
    }
    
    Box(
        modifier = modifier,
        contentAlignment = Alignment.Center
    ) {
        if (hasCameraPermission) {
            AndroidView(
                factory = { ctx ->
                    PreviewView(ctx).apply {
                        scaleType = PreviewView.ScaleType.FILL_CENTER
                        implementationMode = PreviewView.ImplementationMode.COMPATIBLE
                    }
                },
                modifier = Modifier.fillMaxSize(),
                update = { previewView ->
                    startCamera(previewView, lifecycleOwner, onCameraStarted, onCameraError)
                }
            )
            
            IrisTargetingOverlay()
            
        } else {
            Text("Camera permission required")
        }
    }
}

@Composable
fun IrisTargetingOverlay() {
    Box(
        modifier = Modifier.fillMaxSize(),
        contentAlignment = Alignment.Center
    ) {
        Box(
            modifier = Modifier
                .size(200.dp)
                .border(
                    width = 3.dp,
                    color = androidx.compose.ui.graphics.Color.Green,
                    shape = CircleShape
                )
        )
        
        Canvas(modifier = Modifier.fillMaxSize()) {
            val centerX = size.width / 2
            val centerY = size.height / 2
            
            drawLine(
                color = androidx.compose.ui.graphics.Color.Red.copy(alpha = 0.5f),
                start = Offset(centerX - 150, centerY),
                end = Offset(centerX + 150, centerY),
                strokeWidth = 2f
            )
            
            drawLine(
                color = androidx.compose.ui.graphics.Color.Red.copy(alpha = 0.5f),
                start = Offset(centerX, centerY - 150),
                end = Offset(centerX, centerY + 150),
                strokeWidth = 2f
            )
        }
    }
}

private fun startCamera(
    previewView: PreviewView,
    lifecycleOwner: LifecycleOwner,
    onStarted: () -> Unit,
    onError: (String) -> Unit
) {
    val cameraProviderFuture = ProcessCameraProvider.getInstance(previewView.context)
    
    cameraProviderFuture.addListener({
        try {
            val cameraProvider: ProcessCameraProvider = cameraProviderFuture.get()
            
            val preview = Preview.Builder().build().also {
                it.setSurfaceProvider(previewView.surfaceProvider)
            }
            
            val cameraSelector = CameraSelector.DEFAULT_FRONT_CAMERA
            
            cameraProvider.unbindAll()
            cameraProvider.bindToLifecycle(
                lifecycleOwner,
                cameraSelector,
                preview
            )
            
            Log.i("CAMERA_PREVIEW", "✅ Camera started successfully")
            onStarted()
            
        } catch (e: Exception) {
            Log.e("CAMERA_PREVIEW", "❌ Camera start failed: ${e.message}")
            onError(e.message ?: "Unknown error")
        }
    }, ContextCompat.getMainExecutor(previewView.context))
}
