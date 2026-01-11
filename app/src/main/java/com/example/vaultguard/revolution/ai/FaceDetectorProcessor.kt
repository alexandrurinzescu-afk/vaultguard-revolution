package com.example.vaultguard.revolution.ai

import android.content.Context
import android.graphics.RectF
import android.util.Log
import androidx.camera.core.ImageProxy
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.face.Face
import com.google.mlkit.vision.face.FaceDetection
import com.google.mlkit.vision.face.FaceDetector
import com.google.mlkit.vision.face.FaceDetectorOptions
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext
import java.util.concurrent.atomic.AtomicBoolean

class FaceDetectorProcessor(context: Context) {

    private val TAG = "🧠 AI_REVOLUTION"

    private val _detectionState = MutableStateFlow(DetectionState.IDLE)
    val detectionState: StateFlow<DetectionState> = _detectionState.asStateFlow()

    private val _faceDetectionEvents = Channel<FaceDetectionEvent>(Channel.UNLIMITED)
    val faceDetectionEvents: Flow<FaceDetectionEvent> = _faceDetectionEvents.receiveAsFlow()

    private val _facePositions = MutableStateFlow<List<DetectedFace>>(emptyList())
    val facePositions: StateFlow<List<DetectedFace>> = _facePositions.asStateFlow()

    private val faceDetector: FaceDetector
    private var isInitialized = AtomicBoolean(false)

    companion object {
        private const val MIN_FACE_SIZE = 0.1f
        private const val PERFORMANCE_MODE = FaceDetectorOptions.PERFORMANCE_MODE_FAST
        // ACTIVĂM NOILE SIMȚURI!
        private const val LANDMARK_MODE = FaceDetectorOptions.LANDMARK_MODE_ALL
        private const val CLASSIFICATION_MODE = FaceDetectorOptions.CLASSIFICATION_MODE_ALL 
    }

    init {
        Log.i(TAG, "Initializing AI Revolution Face Detector...")
        val options = FaceDetectorOptions.Builder()
            .setPerformanceMode(PERFORMANCE_MODE)
            .setLandmarkMode(LANDMARK_MODE)
            .setClassificationMode(CLASSIFICATION_MODE)
            .setMinFaceSize(MIN_FACE_SIZE)
            .build()
        faceDetector = FaceDetection.getClient(options)
        isInitialized.set(true)
        _detectionState.value = DetectionState.READY
        Log.i(TAG, "✅ AI Brain online with advanced senses.")
    }

    suspend fun processFrame(imageProxy: ImageProxy) = withContext(Dispatchers.IO) {
        if (!isInitialized.get() || imageProxy.image == null) {
            imageProxy.close()
            return@withContext
        }

        try {
            _detectionState.value = DetectionState.PROCESSING
            val inputImage = InputImage.fromMediaImage(imageProxy.image!!, imageProxy.imageInfo.rotationDegrees)
            
            val faces = faceDetector.process(inputImage).await()

            if (faces.isEmpty()) {
                _facePositions.value = emptyList()
                _detectionState.value = DetectionState.READY
            } else {
                val detectedFacesList = faces.map { convertMlKitFaceToDetectedFace(it, imageProxy.width, imageProxy.height) }
                _facePositions.value = detectedFacesList
                _detectionState.value = DetectionState.FACE_DETECTED
                _faceDetectionEvents.send(FaceDetectionEvent.FacesDetected(faces.size))
            }
        } catch (e: Exception) {
            Log.e(TAG, "Face detection error: ${e.message}")
            _detectionState.value = DetectionState.ERROR
            _faceDetectionEvents.send(FaceDetectionEvent.ErrorEvent("Detection failed"))
        } finally {
            imageProxy.close()
        }
    }

    private fun convertMlKitFaceToDetectedFace(mlKitFace: Face, imageWidth: Int, imageHeight: Int): DetectedFace {
        val boundingBox = mlKitFace.boundingBox
        val normalizedBox = RectF(
            boundingBox.left.toFloat() / imageWidth,
            boundingBox.top.toFloat() / imageHeight,
            boundingBox.right.toFloat() / imageWidth,
            boundingBox.bottom.toFloat() / imageHeight
        )
        return DetectedFace(
            boundingBox = normalizedBox,
            leftEyeOpenProbability = mlKitFace.leftEyeOpenProbability,
            rightEyeOpenProbability = mlKitFace.rightEyeOpenProbability
        )
    }

    fun cleanup() {
        faceDetector.close()
        isInitialized.set(false)
        Log.i(TAG, "🧹 AI resources cleaned up.")
    }

    enum class DetectionState { IDLE, READY, PROCESSING, FACE_DETECTED, ERROR }

    // MEMORIA AI EXTINSĂ
    data class DetectedFace(
        val boundingBox: RectF,
        val leftEyeOpenProbability: Float?,
        val rightEyeOpenProbability: Float?
    )

    sealed class FaceDetectionEvent {
        data class FacesDetected(val count: Int) : FaceDetectionEvent()
        data class ErrorEvent(val message: String) : FaceDetectionEvent()
    }
}