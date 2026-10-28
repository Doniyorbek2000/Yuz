package app.yuz.beauty_engine.face

import android.content.Context
import android.graphics.Bitmap
import android.util.Log
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.core.Delegate
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.facelandmarker.FaceLandmarker
import com.google.mediapipe.tasks.vision.facelandmarker.FaceLandmarkerResult

/**
 * Synchronous landmarker for photos (IMAGE mode) and video files (VIDEO
 * mode, timestamps must increase). GPU delegate first, CPU as fallback.
 */
class OfflineLandmarker private constructor(private val landmarker: FaceLandmarker, private val mode: RunningMode) {
    fun detect(bitmap: Bitmap, timestampMillis: Long = 0): List<DetectedFace> {
        val image = BitmapImageBuilder(bitmap).build()
        val result: FaceLandmarkerResult = runCatching {
            if (mode == RunningMode.VIDEO) landmarker.detectForVideo(image, timestampMillis) else landmarker.detect(image)
        }.onFailure { Log.w(TAG, "Face detection failed", it) }.getOrNull() ?: return emptyList()
        return result.faceLandmarks().mapNotNull { landmarks ->
            if (landmarks.size < FaceMaskGeometry.MESH_LANDMARK_COUNT) return@mapNotNull null
            DetectedFace(landmarks.map { NormalizedPoint(it.x(), it.y()) })
        }
    }

    fun close() = landmarker.close()

    companion object {
        private const val TAG = "YuzOfflineLandmarker"
        const val MAX_FACES = 4

        /** Returns null when the model is missing or no delegate works. */
        fun create(context: Context, mode: RunningMode, maxFaces: Int = MAX_FACES): OfflineLandmarker? {
            require(mode == RunningMode.IMAGE || mode == RunningMode.VIDEO) { "use FaceLandmarkDetector for live streams" }
            val modelAvailable = runCatching { context.assets.open(FaceModel.ASSET).close() }.isSuccess
            if (!modelAvailable) return null
            for (delegate in listOf(Delegate.GPU, Delegate.CPU)) {
                val created = runCatching {
                    FaceLandmarker.createFromOptions(
                        context,
                        FaceLandmarker.FaceLandmarkerOptions.builder()
                            .setBaseOptions(
                                BaseOptions.builder()
                                    .setModelAssetPath(FaceModel.ASSET)
                                    .setDelegate(delegate)
                                    .build(),
                            )
                            .setRunningMode(mode)
                            .setNumFaces(maxFaces.coerceIn(1, MAX_FACES))
                            .setMinFaceDetectionConfidence(0.5f)
                            .setMinFacePresenceConfidence(0.5f)
                            .setMinTrackingConfidence(0.5f)
                            .build(),
                    )
                }.onFailure { Log.w(TAG, "$mode landmarker unavailable on $delegate", it) }.getOrNull()
                if (created != null) return OfflineLandmarker(created, mode)
            }
            return null
        }
    }
}
