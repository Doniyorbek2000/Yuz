package app.yuz.beauty_engine.face

import android.content.Context
import android.graphics.Bitmap
import android.os.SystemClock
import android.util.Log
import androidx.camera.core.ImageProxy
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.core.Delegate
import com.google.mediapipe.tasks.vision.core.ImageProcessingOptions
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.facelandmarker.FaceLandmarker
import com.google.mediapipe.tasks.vision.facelandmarker.FaceLandmarkerResult
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicLong

/**
 * MediaPipe Face Landmarker in LIVE_STREAM mode.
 *
 * Backpressure: at most one frame is in flight. Frames arriving while the
 * model is busy are dropped immediately (the ImageProxy is closed), so the
 * camera pipeline never queues up and latency stays bounded.
 *
 * Threading: [analyze] runs on the CameraX analysis executor; results arrive
 * on MediaPipe's callback thread and are forwarded to [onResult].
 */
class FaceLandmarkDetector private constructor(
    private val landmarker: FaceLandmarker,
    private val delegateName: String,
) {
    private val inFlight = AtomicBoolean(false)
    private val inFlightSinceMillis = AtomicLong(0)
    private var lastTimestampMillis = 0L
    private var reusableBitmap: Bitmap? = null

    @Volatile
    var mirrorHorizontally: Boolean = false

    @Volatile
    private var listener: ((List<DetectedFace>, Long, Long) -> Unit)? = null

    fun setListener(onResult: ((faces: List<DetectedFace>, frameTimestampNanos: Long, inferenceNanos: Long) -> Unit)?) {
        listener = onResult
    }

    /** @return true if the frame was submitted, false if it was dropped. */
    fun analyze(image: ImageProxy): Boolean {
        image.use { proxy ->
            val now = SystemClock.uptimeMillis()
            if (inFlight.get() && now - inFlightSinceMillis.get() < STALE_IN_FLIGHT_MILLIS) {
                return false
            }
            val bitmap = copyToBitmap(proxy)
            // MediaPipe requires strictly increasing timestamps.
            val timestamp = maxOf(now, lastTimestampMillis + 1)
            lastTimestampMillis = timestamp
            inFlight.set(true)
            inFlightSinceMillis.set(now)
            pendingSubmitNanos = System.nanoTime()
            val options = ImageProcessingOptions.builder()
                .setRotationDegrees(proxy.imageInfo.rotationDegrees)
                .build()
            return try {
                landmarker.detectAsync(BitmapImageBuilder(bitmap).build(), options, timestamp)
                true
            } catch (error: RuntimeException) {
                inFlight.set(false)
                Log.w(TAG, "detectAsync failed", error)
                false
            }
        }
    }

    @Volatile
    private var pendingSubmitNanos = 0L

    private fun copyToBitmap(proxy: ImageProxy): Bitmap {
        val plane = proxy.planes[0]
        val width = proxy.width
        val height = proxy.height
        // RGBA_8888 output: one plane. Fast path when rows are tightly packed.
        if (plane.pixelStride == 4 && plane.rowStride == width * 4) {
            val bitmap = reusableBitmap?.takeIf { it.width == width && it.height == height }
                ?: Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888).also { reusableBitmap = it }
            plane.buffer.rewind()
            bitmap.copyPixelsFromBuffer(plane.buffer)
            return bitmap
        }
        return proxy.toBitmap()
    }

    private fun handleResult(result: FaceLandmarkerResult) {
        val inferenceNanos = System.nanoTime() - pendingSubmitNanos
        inFlight.set(false)
        val mirror = mirrorHorizontally
        val faces = result.faceLandmarks().mapNotNull { landmarks ->
            if (landmarks.size < FaceMaskGeometry.MESH_LANDMARK_COUNT) return@mapNotNull null
            DetectedFace(
                landmarks.map { landmark ->
                    val x = landmark.x()
                    NormalizedPoint(if (mirror) 1f - x else x, landmark.y())
                },
            )
        }
        listener?.invoke(faces, System.nanoTime(), inferenceNanos)
    }

    private fun handleError(error: RuntimeException) {
        inFlight.set(false)
        Log.w(TAG, "Face landmarker error ($delegateName)", error)
    }

    fun close() {
        listener = null
        landmarker.close()
        reusableBitmap?.recycle()
        reusableBitmap = null
    }

    companion object {
        private const val TAG = "YuzFaceDetector"
        const val MODEL_ASSET = FaceModel.ASSET
        private const val STALE_IN_FLIGHT_MILLIS = 500L

        /**
         * Creates a detector, preferring the GPU delegate and falling back to
         * CPU. Returns null when the model asset is missing or both delegates
         * fail; the engine then runs colour-only skin detection.
         */
        fun create(context: Context, maxFaces: Int): FaceLandmarkDetector? {
            val modelAvailable = runCatching { context.assets.open(MODEL_ASSET).close() }.isSuccess
            if (!modelAvailable) {
                Log.w(TAG, "Model asset $MODEL_ASSET missing; run tools/fetch_models.sh")
                return null
            }
            for (delegate in listOf(Delegate.GPU, Delegate.CPU)) {
                val holder = arrayOfNulls<FaceLandmarkDetector>(1)
                val landmarker = runCatching {
                    val options = FaceLandmarker.FaceLandmarkerOptions.builder()
                        .setBaseOptions(
                            BaseOptions.builder()
                                .setModelAssetPath(MODEL_ASSET)
                                .setDelegate(delegate)
                                .build(),
                        )
                        .setRunningMode(RunningMode.LIVE_STREAM)
                        .setNumFaces(maxFaces.coerceIn(1, 4))
                        .setMinFaceDetectionConfidence(0.5f)
                        .setMinFacePresenceConfidence(0.5f)
                        .setMinTrackingConfidence(0.5f)
                        .setOutputFaceBlendshapes(false)
                        .setOutputFacialTransformationMatrixes(false)
                        .setResultListener { result, _ -> holder[0]?.handleResult(result) }
                        .setErrorListener { error -> holder[0]?.handleError(error) }
                        .build()
                    FaceLandmarker.createFromOptions(context, options)
                }.onFailure { Log.w(TAG, "Delegate $delegate unavailable", it) }.getOrNull() ?: continue
                return FaceLandmarkDetector(landmarker, delegate.name).also { holder[0] = it }
            }
            return null
        }
    }
}
