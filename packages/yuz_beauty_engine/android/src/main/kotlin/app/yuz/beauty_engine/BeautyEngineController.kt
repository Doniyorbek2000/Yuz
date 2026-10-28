package app.yuz.beauty_engine

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.util.Size
import androidx.camera.core.Camera
import androidx.camera.core.CameraSelector
import androidx.camera.core.CameraState
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageCapture
import androidx.camera.core.ImageCaptureException
import androidx.camera.core.Preview
import androidx.camera.core.SurfaceRequest
import androidx.camera.core.resolutionselector.AspectRatioStrategy
import androidx.camera.core.resolutionselector.ResolutionSelector
import androidx.camera.core.resolutionselector.ResolutionStrategy
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.lifecycle.Observer
import app.yuz.beauty_engine.camera.CameraLifecycleOwner
import app.yuz.beauty_engine.face.FaceLandmarkDetector
import app.yuz.beauty_engine.face.FaceSelectionPolicy
import app.yuz.beauty_engine.face.FaceTracker
import app.yuz.beauty_engine.face.FaceTrackingSnapshot
import app.yuz.beauty_engine.generated.BeautyEngineEventsApi
import app.yuz.beauty_engine.generated.BeautyEngineFlutterError
import app.yuz.beauty_engine.generated.BeautyEngineHostApi
import app.yuz.beauty_engine.generated.BeautyParameters
import app.yuz.beauty_engine.generated.CameraCapabilities
import app.yuz.beauty_engine.generated.CameraLens
import app.yuz.beauty_engine.generated.CaptureAspectRatio
import app.yuz.beauty_engine.generated.EngineConfig
import app.yuz.beauty_engine.generated.EngineError
import app.yuz.beauty_engine.generated.EngineErrorCode
import app.yuz.beauty_engine.generated.FaceTrackingStatus
import app.yuz.beauty_engine.generated.FlashMode
import app.yuz.beauty_engine.generated.ImageProcessingRequest
import app.yuz.beauty_engine.generated.ImageProcessingResult
import app.yuz.beauty_engine.generated.MultiFacePolicy
import app.yuz.beauty_engine.generated.PerformanceSample
import app.yuz.beauty_engine.generated.PhotoCaptureResult
import app.yuz.beauty_engine.generated.PreviewDescriptor
import app.yuz.beauty_engine.generated.PreviewQuality
import app.yuz.beauty_engine.generated.VideoExportRequest
import app.yuz.beauty_engine.generated.VideoExportResult
import app.yuz.beauty_engine.generated.VideoMetadata
import app.yuz.beauty_engine.generated.VideoRecordingOptions
import app.yuz.beauty_engine.generated.VideoRecordingResult
import app.yuz.beauty_engine.gl.GlLutTexture
import app.yuz.beauty_engine.gl.ShaderLibrary
import app.yuz.beauty_engine.perf.PerformanceTracker
import app.yuz.beauty_engine.perf.ThermalMonitor
import app.yuz.beauty_engine.render.GlThread
import app.yuz.beauty_engine.render.PreviewPipeline
import app.yuz.beauty_engine.render.toSettings
import app.yuz.beauty_engine.still.JpegWriter
import app.yuz.beauty_engine.still.StillImageProcessor
import app.yuz.beauty_engine.video.RecordingException
import app.yuz.beauty_engine.video.RecordingResult
import app.yuz.beauty_engine.video.VideoRecorder
import app.yuz.beauty_engine.video.edit.ExportClip
import app.yuz.beauty_engine.video.edit.ExportRequest
import app.yuz.beauty_engine.video.edit.OverlayWindow
import app.yuz.beauty_engine.video.edit.VideoExporter
import app.yuz.beauty_engine.video.edit.VideoProbe
import io.flutter.view.TextureRegistry
import java.io.File
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executor
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicReference
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.guava.await
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeout

/**
 * Implements the Pigeon host API. Owns one camera session, one GL pipeline,
 * one face detector and one Flutter texture at a time. Every public method
 * is invoked on the Android main thread by the generated Pigeon glue.
 */
class BeautyEngineController(
    private val context: Context,
    private val textureRegistry: TextureRegistry,
    private val events: BeautyEngineEventsApi,
) : BeautyEngineHostApi {
    private val mainScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val mainHandler = Handler(Looper.getMainLooper())
    private val mainExecutor = Executor { command -> mainHandler.post(command) }

    private var session: Session? = null

    /** Current activity (null in the background); used for the brightness override. */
    var activity: android.app.Activity? = null
    private var stillProcessor: StillImageProcessor? = null
    private val videoExporter by lazy { VideoExporter(context) }
    private val exportMutex = Mutex()
    private val exportCancellations = ConcurrentHashMap<String, AtomicBoolean>()

    /** Everything that lives between initialize() and dispose(). */
    private inner class Session(val config: EngineConfig) {
        val lifecycleOwner = CameraLifecycleOwner()
        val performance = PerformanceTracker()
        val glThread = GlThread("YuzBeautyGL")
        val pipeline = PreviewPipeline(glThread, ShaderLibrary(context.assets), performance)
        val analysisExecutor: ExecutorService = Executors.newSingleThreadExecutor { runnable ->
            Thread(runnable, "YuzFaceAnalysis")
        }
        val surfaceProducer: TextureRegistry.SurfaceProducer = textureRegistry.createSurfaceProducer()
        val tracker = FaceTracker(
            maxFaces = config.maxFaces.toInt().coerceIn(1, 4),
            policy = when (config.multiFacePolicy) {
                MultiFacePolicy.PRIMARY_FACE -> FaceSelectionPolicy.PRIMARY_FACE
                MultiFacePolicy.ALL_FACES -> FaceSelectionPolicy.ALL_FACES
            },
        )
        val latestFaces = AtomicReference(FaceTrackingSnapshot.EMPTY)
        val thermal = ThermalMonitor(context, analysisExecutor) { level -> onThermalLevel(level) }

        var detector: FaceLandmarkDetector? = null
        var cameraProvider: ProcessCameraProvider? = null
        var camera: Camera? = null

        /** Full-sensor stills; null when the device cannot bind it next to preview + analysis. */
        var imageCapture: ImageCapture? = null

        /** Last LUT uploaded, re-applied to full-resolution stills. */
        @Volatile
        var lut: ByteArray? = null
        var lens: CameraLens = config.lens
        var flashMode: FlashMode = FlashMode.OFF
        var outputSize: Pair<Int, Int> = 0 to 0
        var firstSurface: CompletableDeferred<Pair<Int, Int>> = CompletableDeferred()
        var cameraStateObserver: Observer<CameraState>? = null
        var analysisFrameCounter = 0L
        var lastSentStatus: FaceTrackingStatus? = null
        var lastStatusSentAtMillis = 0L

        @Volatile
        var sceneLuma = 0.5f

        var recording = false

        /** A recording finished by pause(); handed out by the next stopRecording(). */
        var finishedRecording: Result<RecordingResult>? = null
    }

    private val performanceReporter = object : Runnable {
        override fun run() {
            val active = session ?: return
            val snapshot = active.performance.drain()
            val sample = PerformanceSample(
                renderedFps = snapshot.renderedFps,
                cameraFps = snapshot.cameraFps,
                averageGpuFrameMillis = snapshot.averageGpuFrameMillis,
                averageDetectorMillis = snapshot.averageDetectorMillis,
                droppedFrames = snapshot.droppedFrames,
                thermalLevel = active.thermal.level.toLong(),
            )
            mainScope.launch { runCatching { events.onPerformanceSample(sample) } }
            mainHandler.postDelayed(this, PERFORMANCE_INTERVAL_MILLIS)
        }
    }

    // region BeautyEngineHostApi

    override suspend fun initialize(config: EngineConfig): PreviewDescriptor {
        if (context.checkSelfPermission(Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
            throw engineError(EngineErrorCode.PERMISSION_DENIED, "Camera permission has not been granted")
        }
        session?.let { teardown(it) }
        val active = Session(config)
        session = active
        try {
            active.pipeline.start()
            active.surfaceProducer.setCallback(object : TextureRegistry.SurfaceProducer.Callback {
                override fun onSurfaceAvailable() {
                    active.pipeline.attachOutput(active.surfaceProducer.surface)
                }

                override fun onSurfaceCleanup() {
                    active.pipeline.detachOutput()
                }
            })

            if (config.enableFaceTracking) {
                active.detector = withContext(Dispatchers.IO) {
                    FaceLandmarkDetector.create(context, config.maxFaces.toInt())
                }
                active.detector?.setListener { faces, timestampNanos, inferenceNanos ->
                    active.performance.onDetectorRun(inferenceNanos)
                    val snapshot = active.tracker.update(faces, timestampNanos)
                    active.latestFaces.set(snapshot)
                    publishFaceStatus(active, snapshot)
                }
            }
            active.pipeline.faceProvider = { currentFaces(active) }
            active.thermal.start()

            active.cameraProvider = ProcessCameraProvider.getInstance(context).await()
            bindCamera(active, config.lens)
            active.lifecycleOwner.start()
            val (width, height) = withTimeout(SURFACE_TIMEOUT_MILLIS) { active.firstSurface.await() }
            mainHandler.removeCallbacks(performanceReporter)
            mainHandler.postDelayed(performanceReporter, PERFORMANCE_INTERVAL_MILLIS)
            return describe(active, width, height)
        } catch (error: Throwable) {
            teardown(active)
            session = null
            throw mapError(error)
        }
    }

    override suspend fun switchLens(lens: CameraLens): PreviewDescriptor {
        val active = requireSession()
        if (active.recording) throw engineError(EngineErrorCode.RECORDING_FAILED, "Cannot switch cameras while recording")
        active.tracker.reset()
        active.latestFaces.set(FaceTrackingSnapshot.EMPTY)
        active.firstSurface = CompletableDeferred()
        try {
            bindCamera(active, lens)
            val (width, height) = withTimeout(SURFACE_TIMEOUT_MILLIS) { active.firstSurface.await() }
            return describe(active, width, height)
        } catch (error: Throwable) {
            throw mapError(error)
        }
    }

    override fun getCapabilities(): CameraCapabilities {
        val active = requireSession()
        val provider = active.cameraProvider
        val info = active.camera?.cameraInfo
        val zoom = info?.zoomState?.value
        val exposure = info?.exposureState
        val step = exposure?.exposureCompensationStep?.toDouble() ?: 0.0
        return CameraCapabilities(
            hasFrontCamera = provider?.hasCamera(CameraSelector.DEFAULT_FRONT_CAMERA) == true,
            hasBackCamera = provider?.hasCamera(CameraSelector.DEFAULT_BACK_CAMERA) == true,
            hasFlash = info?.hasFlashUnit() == true,
            minZoomRatio = zoom?.minZoomRatio?.toDouble() ?: 1.0,
            maxZoomRatio = zoom?.maxZoomRatio?.toDouble() ?: 1.0,
            minExposureBias = (exposure?.exposureCompensationRange?.lower ?: 0) * step,
            maxExposureBias = (exposure?.exposureCompensationRange?.upper ?: 0) * step,
        )
    }

    override fun setBeautyParameters(parameters: BeautyParameters) {
        requireSession().pipeline.settings = parameters.toSettings()
    }

    override fun setColorLut(rgba512: ByteArray?) {
        if (rgba512 != null && rgba512.size != GlLutTexture.BYTES) {
            throw engineError(EngineErrorCode.UNKNOWN, "LUT must be ${GlLutTexture.BYTES} bytes, got ${rgba512.size}")
        }
        val active = requireSession()
        active.lut = rgba512
        active.pipeline.setLut(rgba512)
    }

    override fun setFlashMode(mode: FlashMode) {
        val active = requireSession()
        active.flashMode = mode
        active.camera?.cameraControl?.enableTorch(mode == FlashMode.TORCH)
        active.imageCapture?.flashMode = mode.toImageCaptureFlash()
    }

    override fun setScreenBrightness(brightness: Double) {
        val window = activity?.window ?: return
        val attributes = window.attributes
        attributes.screenBrightness = if (brightness < 0) {
            android.view.WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE
        } else {
            brightness.toFloat().coerceIn(0f, 1f)
        }
        window.attributes = attributes
    }

    private fun FlashMode.toImageCaptureFlash(): Int = when (this) {
        FlashMode.ON -> ImageCapture.FLASH_MODE_ON
        FlashMode.AUTO -> ImageCapture.FLASH_MODE_AUTO
        FlashMode.OFF, FlashMode.TORCH -> ImageCapture.FLASH_MODE_OFF
    }

    override fun setZoomRatio(ratio: Double) {
        val camera = requireSession().camera ?: return
        val zoom = camera.cameraInfo.zoomState.value
        val clamped = if (zoom == null) ratio.toFloat() else ratio.toFloat().coerceIn(zoom.minZoomRatio, zoom.maxZoomRatio)
        camera.cameraControl.setZoomRatio(clamped)
    }

    override fun setExposureBias(ev: Double) {
        val camera = requireSession().camera ?: return
        val state = camera.cameraInfo.exposureState
        if (!state.isExposureCompensationSupported) return
        val step = state.exposureCompensationStep.toDouble()
        if (step <= 0.0) return
        val index = Math.round(ev / step).toInt().coerceIn(
            state.exposureCompensationRange.lower,
            state.exposureCompensationRange.upper,
        )
        camera.cameraControl.setExposureCompensationIndex(index)
    }

    override suspend fun capturePhoto(outputFilePath: String): PhotoCaptureResult {
        val active = requireSession()
        val camera = active.camera ?: throw engineError(EngineErrorCode.CAMERA_UNAVAILABLE, "Camera is not bound")
        if (active.recording) throw engineError(EngineErrorCode.CAPTURE_FAILED, "Cannot take a photo while recording")
        active.imageCapture?.let { capture ->
            val result = runCatching { captureFullResolution(active, capture, File(outputFilePath)) }
            result.getOrNull()?.let { return it }
            Log.w(TAG, "Full-resolution capture failed; using the processed preview frame", result.exceptionOrNull())
        }
        val useTorch = camera.cameraInfo.hasFlashUnit() && when (active.flashMode) {
            FlashMode.ON -> true
            FlashMode.AUTO -> active.sceneLuma < AUTO_FLASH_LUMA_THRESHOLD
            FlashMode.OFF, FlashMode.TORCH -> false
        }
        try {
            if (useTorch) {
                camera.cameraControl.enableTorch(true).await()
                delay(TORCH_SETTLE_MILLIS)
            }
            val frame = active.pipeline.capture()
            withContext(Dispatchers.IO) {
                JpegWriter.write(frame.rgbaBottomUp, frame.width, frame.height, File(outputFilePath), JPEG_QUALITY)
            }
            return PhotoCaptureResult(outputFilePath, frame.width.toLong(), frame.height.toLong())
        } catch (error: BeautyEngineFlutterError) {
            throw error
        } catch (error: Throwable) {
            throw engineError(EngineErrorCode.CAPTURE_FAILED, error.message ?: "Capture failed")
        } finally {
            if (useTorch) camera.cameraControl.enableTorch(false)
        }
    }

    override suspend fun startRecording(options: VideoRecordingOptions) {
        val active = requireSession()
        if (active.recording) throw engineError(EngineErrorCode.RECORDING_FAILED, "Already recording")
        val (width, height) = active.pipeline.outputSize()
        if (width == 0 || height == 0) throw engineError(EngineErrorCode.CAMERA_UNAVAILABLE, "No camera frame rendered yet")
        val withAudio = options.recordAudio &&
            context.checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
        active.finishedRecording = null
        active.recording = true
        try {
            val recorder = withContext(Dispatchers.IO) {
                VideoRecorder.start(File(options.outputFilePath), width, height, options.videoBitrate.toInt(), withAudio)
            }
            try {
                active.pipeline.startRecording(recorder)
            } catch (error: Throwable) {
                withContext(Dispatchers.IO) { recorder.cancel() }
                throw error
            }
        } catch (error: Throwable) {
            active.recording = false
            throw recordingError(error)
        }
    }

    override suspend fun stopRecording(): VideoRecordingResult {
        val active = requireSession()
        val result = active.finishedRecording?.also { active.finishedRecording = null } ?: finishRecording(active)
            ?: throw engineError(EngineErrorCode.RECORDING_FAILED, "Not recording")
        val recording = result.getOrElse { throw recordingError(it) }
        return VideoRecordingResult(
            filePath = recording.file.path,
            durationMillis = recording.durationMillis,
            width = recording.width.toLong(),
            height = recording.height.toLong(),
            hasAudio = recording.hasAudio,
        )
    }

    /** Stops feeding frames and finishes the file; null when not recording. */
    private suspend fun finishRecording(active: Session): Result<RecordingResult>? {
        if (!active.recording) return null
        active.recording = false
        val recorder = runCatching { active.pipeline.stopRecording() }.getOrElse { return Result.failure(it) }
            ?: return null
        return withContext(Dispatchers.IO) { runCatching { recorder.stop() } }
    }

    private fun recordingError(error: Throwable): Throwable = when (error) {
        is BeautyEngineFlutterError -> error
        is RecordingException -> engineError(EngineErrorCode.RECORDING_FAILED, error.message ?: "Recording failed")
        else -> engineError(EngineErrorCode.RECORDING_FAILED, error.message ?: error.javaClass.simpleName)
    }

    override suspend fun probeVideo(path: String): VideoMetadata = withContext(Dispatchers.IO) {
        try {
            val probe = VideoProbe.probe(path)
            VideoMetadata(
                durationMillis = probe.durationUs / 1_000,
                width = probe.uprightWidth.toLong(),
                height = probe.uprightHeight.toLong(),
                rotationDegrees = probe.rotationDegrees.toLong(),
                hasAudio = probe.hasAudio,
            )
        } catch (error: java.io.IOException) {
            throw engineError(EngineErrorCode.CAPTURE_FAILED, error.message ?: "Video could not be read")
        }
    }

    override suspend fun videoThumbnails(path: String, count: Long, maxEdge: Long, outputDirectory: String): List<String> =
        withContext(Dispatchers.IO) {
            try {
                VideoProbe.thumbnails(path, count.toInt(), maxEdge.toInt().coerceIn(32, 1024), File(outputDirectory))
            } catch (error: java.io.IOException) {
                throw engineError(EngineErrorCode.CAPTURE_FAILED, error.message ?: "Video could not be read")
            } catch (error: IllegalArgumentException) {
                throw engineError(EngineErrorCode.UNKNOWN, error.message ?: "Invalid thumbnail request")
            }
        }

    override suspend fun exportVideo(request: VideoExportRequest): VideoExportResult {
        val lut = request.lutRgba
        if (lut != null && lut.size != GlLutTexture.BYTES) {
            throw engineError(EngineErrorCode.UNKNOWN, "LUT must be ${GlLutTexture.BYTES} bytes, got ${lut.size}")
        }
        val cancelled = AtomicBoolean(false)
        if (exportCancellations.putIfAbsent(request.jobId, cancelled) != null) {
            throw engineError(EngineErrorCode.RECORDING_FAILED, "Export ${request.jobId} is already running")
        }
        try {
            return exportMutex.withLock {
                var lastProgressAt = 0L
                val result = withContext(Dispatchers.IO) {
                    videoExporter.export(request.toExportRequest(), cancelled) { progress ->
                        val now = System.currentTimeMillis()
                        if (now - lastProgressAt >= PROGRESS_INTERVAL_MILLIS || progress >= 1.0) {
                            lastProgressAt = now
                            mainScope.launch { runCatching { events.onVideoExportProgress(request.jobId, progress) } }
                        }
                    }
                }
                VideoExportResult(
                    outputPath = result.file.path,
                    durationMillis = result.durationMillis,
                    width = result.width.toLong(),
                    height = result.height.toLong(),
                    hasAudio = result.hasAudio,
                )
            }
        } catch (error: java.util.concurrent.CancellationException) {
            if (cancelled.get()) throw engineError(EngineErrorCode.EXPORT_CANCELLED, "Export cancelled")
            throw error
        } catch (error: java.io.IOException) {
            throw engineError(EngineErrorCode.RECORDING_FAILED, error.message ?: "Video export failed")
        } catch (error: IllegalArgumentException) {
            throw engineError(EngineErrorCode.RECORDING_FAILED, error.message ?: "Invalid edit")
        } catch (error: IllegalStateException) {
            throw engineError(EngineErrorCode.RECORDING_FAILED, error.message ?: "Video codec error")
        } catch (error: OutOfMemoryError) {
            throw engineError(EngineErrorCode.RECORDING_FAILED, "Not enough memory to export this video")
        } catch (error: app.yuz.beauty_engine.gl.GlException) {
            throw engineError(EngineErrorCode.GPU_INITIALIZATION_FAILED, error.message ?: "GPU error")
        } finally {
            exportCancellations.remove(request.jobId)
        }
    }

    override fun cancelVideoExport(jobId: String) {
        exportCancellations[jobId]?.set(true)
    }

    private fun VideoExportRequest.toExportRequest() = ExportRequest(
        clips = clips.map { ExportClip(it.path, it.startMillis * 1_000, it.endMillis * 1_000, it.speed) },
        outputPath = outputPath,
        settings = parameters.toSettings(),
        lut = lutRgba,
        overlays = overlays.map { OverlayWindow(it.imagePath, it.startMillis * 1_000, it.endMillis * 1_000) },
        musicPath = musicPath,
        musicVolume = musicVolume.toFloat().coerceIn(0f, 1f),
        originalVolume = originalVolume.toFloat().coerceIn(0f, 1f),
        maxLongEdge = maxLongEdge.toInt(),
        applyBeauty = applyBeauty,
    )

    /**
     * Takes a sensor-resolution JPEG and runs it through the same beauty
     * pipeline (current look, LUT, faces) as the preview. Front-camera
     * stills are flipped via EXIF so they match the mirrored preview.
     */
    private suspend fun captureFullResolution(active: Session, capture: ImageCapture, output: File): PhotoCaptureResult {
        val temp = File(context.cacheDir, "yuz_capture_${System.nanoTime()}.jpg")
        try {
            val metadata = ImageCapture.Metadata().apply { isReversedHorizontal = active.lens == CameraLens.FRONT }
            val options = ImageCapture.OutputFileOptions.Builder(temp).setMetadata(metadata).build()
            suspendCancellableCoroutine { continuation ->
                capture.takePicture(options, mainExecutor, object : ImageCapture.OnImageSavedCallback {
                    override fun onImageSaved(outputFileResults: ImageCapture.OutputFileResults) {
                        continuation.resume(Unit)
                    }

                    override fun onError(exception: ImageCaptureException) {
                        continuation.resumeWithException(exception)
                    }
                })
            }
            val processor = stillProcessor ?: StillImageProcessor(context).also { stillProcessor = it }
            val processed = processor.process(
                inputPath = temp.path,
                outputPath = output.path,
                maxLongEdge = 0,
                settings = active.pipeline.settings,
                lut = active.lut,
                jpegQuality = JPEG_QUALITY,
                maxFaces = active.config.maxFaces.toInt(),
            )
            return PhotoCaptureResult(output.path, processed.width.toLong(), processed.height.toLong())
        } finally {
            temp.delete()
        }
    }

    override suspend fun processImage(request: ImageProcessingRequest): ImageProcessingResult {
        val lut = request.lutRgba
        if (lut != null && lut.size != GlLutTexture.BYTES) {
            throw engineError(EngineErrorCode.UNKNOWN, "LUT must be ${GlLutTexture.BYTES} bytes, got ${lut.size}")
        }
        val processor = stillProcessor ?: StillImageProcessor(context).also { stillProcessor = it }
        try {
            val output = processor.process(
                inputPath = request.inputPath,
                outputPath = request.outputPath,
                maxLongEdge = request.maxLongEdge.toInt().coerceAtLeast(0),
                settings = request.parameters.toSettings(),
                lut = lut,
                jpegQuality = request.jpegQuality.toInt(),
                maxFaces = request.maxFaces.toInt(),
            )
            return ImageProcessingResult(
                outputPath = request.outputPath,
                width = output.width.toLong(),
                height = output.height.toLong(),
                sourceWidth = output.sourceWidth.toLong(),
                sourceHeight = output.sourceHeight.toLong(),
                faceCount = output.faceCount.toLong(),
                faceTrackingAvailable = output.faceTrackingAvailable,
            )
        } catch (error: java.io.IOException) {
            throw engineError(EngineErrorCode.CAPTURE_FAILED, error.message ?: "Image could not be read or written")
        } catch (error: OutOfMemoryError) {
            throw engineError(EngineErrorCode.CAPTURE_FAILED, "Not enough memory for this image size")
        } catch (error: app.yuz.beauty_engine.gl.GlException) {
            throw engineError(EngineErrorCode.GPU_INITIALIZATION_FAILED, error.message ?: "GPU error")
        }
    }

    override suspend fun pause() {
        session?.let { active -> finishRecording(active)?.let { active.finishedRecording = it } }
        session?.lifecycleOwner?.stop()
        mainHandler.removeCallbacks(performanceReporter)
    }

    override suspend fun resume() {
        val active = session ?: return
        active.lifecycleOwner.start()
        mainHandler.removeCallbacks(performanceReporter)
        mainHandler.postDelayed(performanceReporter, PERFORMANCE_INTERVAL_MILLIS)
    }

    override suspend fun dispose() {
        val active = session ?: return
        session = null
        teardown(active)
    }

    // endregion

    /** Called when the plugin detaches from the engine. */
    fun shutdown() {
        val active = session
        session = null
        if (active != null) {
            // Detach is synchronous; run the suspend teardown without awaiting.
            CoroutineScope(Dispatchers.Main.immediate).launch { teardown(active) }
        }
        val processor = stillProcessor
        stillProcessor = null
        if (processor != null) CoroutineScope(Dispatchers.Default).launch { processor.close() }
        mainScope.cancel()
    }

    @SuppressLint("RestrictedApi")
    private fun bindCamera(active: Session, lens: CameraLens) {
        val provider = checkNotNull(active.cameraProvider)
        val selector = if (lens == CameraLens.FRONT) CameraSelector.DEFAULT_FRONT_CAMERA else CameraSelector.DEFAULT_BACK_CAMERA
        if (!provider.hasCamera(selector)) {
            throw engineError(EngineErrorCode.CAMERA_UNAVAILABLE, "No ${lens.name.lowercase()} camera on this device")
        }
        val mirror = lens == CameraLens.FRONT
        active.detector?.mirrorHorizontally = mirror

        val aspect = when (active.config.aspectRatio) {
            CaptureAspectRatio.RATIO4X3 -> AspectRatioStrategy.RATIO_4_3_FALLBACK_AUTO_STRATEGY
            CaptureAspectRatio.RATIO16X9 -> AspectRatioStrategy.RATIO_16_9_FALLBACK_AUTO_STRATEGY
        }
        val previewBound = when (active.config.quality) {
            PreviewQuality.LOW720 -> Size(1280, 720)
            PreviewQuality.HIGH1080 -> Size(1920, 1080)
        }
        val analysisBound = when (active.config.aspectRatio) {
            CaptureAspectRatio.RATIO4X3 -> Size(640, 480)
            CaptureAspectRatio.RATIO16X9 -> Size(640, 360)
        }

        val preview = Preview.Builder()
            .setResolutionSelector(
                ResolutionSelector.Builder()
                    .setAspectRatioStrategy(aspect)
                    .setResolutionStrategy(
                        ResolutionStrategy(previewBound, ResolutionStrategy.FALLBACK_RULE_CLOSEST_LOWER_THEN_HIGHER),
                    )
                    .build(),
            )
            .build()
        preview.setSurfaceProvider(mainExecutor) { request -> onSurfaceRequest(active, request, mirror) }

        val analysis = ImageAnalysis.Builder()
            .setResolutionSelector(
                ResolutionSelector.Builder()
                    .setAspectRatioStrategy(aspect)
                    .setResolutionStrategy(
                        ResolutionStrategy(analysisBound, ResolutionStrategy.FALLBACK_RULE_CLOSEST_HIGHER_THEN_LOWER),
                    )
                    .build(),
            )
            .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
            .setOutputImageFormat(ImageAnalysis.OUTPUT_IMAGE_FORMAT_RGBA_8888)
            .build()
        analysis.setAnalyzer(active.analysisExecutor) { image ->
            active.sceneLuma = estimateLuma(image.planes[0].buffer, image.planes[0].rowStride, image.width, image.height)
            val detector = active.detector
            val thermalLevel = active.thermal.level
            val counter = active.analysisFrameCounter++
            val skip = thermalLevel >= ThermalMonitor.CRITICAL_LEVEL ||
                (thermalLevel >= ThermalMonitor.REDUCED_DETECTION_LEVEL && counter % 2L == 1L)
            if (detector == null || skip) {
                image.close()
            } else {
                detector.analyze(image)
            }
        }

        active.camera?.cameraInfo?.cameraState?.let { state ->
            active.cameraStateObserver?.let { state.removeObserver(it) }
        }
        val capture = ImageCapture.Builder()
            .setCaptureMode(ImageCapture.CAPTURE_MODE_MINIMIZE_LATENCY)
            .setResolutionSelector(
                ResolutionSelector.Builder()
                    .setAspectRatioStrategy(aspect)
                    .setResolutionStrategy(ResolutionStrategy.HIGHEST_AVAILABLE_STRATEGY)
                    .build(),
            )
            .setFlashMode(active.flashMode.toImageCaptureFlash())
            .build()

        provider.unbindAll()
        // Some LIMITED devices cannot stream preview + analysis + still at
        // once; they keep the processed-preview capture path.
        val camera = try {
            provider.bindToLifecycle(active.lifecycleOwner, selector, preview, analysis, capture).also {
                active.imageCapture = capture
            }
        } catch (error: IllegalArgumentException) {
            Log.w(TAG, "ImageCapture not supported with preview + analysis; using preview-frame stills", error)
            active.imageCapture = null
            provider.unbindAll()
            provider.bindToLifecycle(active.lifecycleOwner, selector, preview, analysis)
        }
        active.camera = camera
        active.lens = lens
        if (active.flashMode == FlashMode.TORCH) camera.cameraControl.enableTorch(true)

        val observer = Observer<CameraState> { state -> onCameraState(state) }
        camera.cameraInfo.cameraState.observeForever(observer)
        active.cameraStateObserver = observer
    }

    /**
     * CameraX asks for a surface per binding. The buffer size is fixed here;
     * the rotation arrives via TransformationInfo, and only then is the
     * upright output size known, so [Session.firstSurface] completes there.
     */
    private fun onSurfaceRequest(active: Session, request: SurfaceRequest, mirror: Boolean) {
        mainScope.launch {
            try {
                val resolution = request.resolution
                val surface = active.pipeline.createCameraSurface(resolution.width, resolution.height)
                request.setTransformationInfoListener(mainExecutor) { info ->
                    mainScope.launch {
                        val size = active.pipeline.configure(
                            resolution.width,
                            resolution.height,
                            info.rotationDegrees,
                            mirror,
                        )
                        applyOutputSize(active, size)
                        if (!active.firstSurface.isCompleted) active.firstSurface.complete(size)
                    }
                }
                request.provideSurface(surface, mainExecutor) { surface.release() }
            } catch (error: Throwable) {
                request.willNotProvideSurface()
                if (!active.firstSurface.isCompleted) active.firstSurface.completeExceptionally(error)
            }
        }
    }

    private fun applyOutputSize(active: Session, size: Pair<Int, Int>) {
        if (active.outputSize == size) return
        active.outputSize = size
        active.surfaceProducer.setSize(size.first, size.second)
        active.pipeline.attachOutput(active.surfaceProducer.surface)
    }

    private fun currentFaces(active: Session) =
        if (active.detector == null || active.thermal.level >= ThermalMonitor.CRITICAL_LEVEL) {
            null
        } else {
            val snapshot = active.latestFaces.get()
            val ageNanos = System.nanoTime() - snapshot.timestampNanos
            if (ageNanos > FACE_STALE_NANOS) emptyList() else snapshot.beautifiedFaces
        }

    private fun publishFaceStatus(active: Session, snapshot: FaceTrackingSnapshot) {
        val now = System.currentTimeMillis()
        val status = FaceTrackingStatus(
            faceCount = snapshot.detectedFaceCount.toLong(),
            beautifiedFaceCount = snapshot.beautifiedFaces.size.toLong(),
            timestampMillis = now,
        )
        val previous = active.lastSentStatus
        val changed = previous == null ||
            previous.faceCount != status.faceCount ||
            previous.beautifiedFaceCount != status.beautifiedFaceCount
        if (!changed && now - active.lastStatusSentAtMillis < STATUS_HEARTBEAT_MILLIS) return
        active.lastSentStatus = status
        active.lastStatusSentAtMillis = now
        mainScope.launch { runCatching { events.onFaceTrackingStatus(status) } }
    }

    private fun onThermalLevel(level: Int) {
        if (level >= ThermalMonitor.CRITICAL_LEVEL) {
            emitError(EngineErrorCode.THERMAL_THROTTLING, "Device is overheating; face tracking paused")
        }
    }

    private fun onCameraState(state: CameraState) {
        val error = state.error ?: return
        val code = when (error.code) {
            CameraState.ERROR_CAMERA_IN_USE, CameraState.ERROR_MAX_CAMERAS_IN_USE -> EngineErrorCode.CAMERA_IN_USE
            CameraState.ERROR_CAMERA_DISABLED -> EngineErrorCode.CAMERA_UNAVAILABLE
            CameraState.ERROR_CAMERA_FATAL_ERROR, CameraState.ERROR_OTHER_RECOVERABLE_ERROR -> EngineErrorCode.CAMERA_DISCONNECTED
            else -> EngineErrorCode.UNKNOWN
        }
        emitError(code, "Camera state error ${error.code}")
    }

    private fun emitError(code: EngineErrorCode, message: String) {
        mainScope.launch { runCatching { events.onEngineError(EngineError(code, message)) } }
    }

    private suspend fun teardown(active: Session) {
        mainHandler.removeCallbacks(performanceReporter)
        runCatching {
            active.camera?.cameraInfo?.cameraState?.let { state ->
                active.cameraStateObserver?.let { state.removeObserver(it) }
            }
            active.cameraProvider?.unbindAll()
        }.onFailure { Log.w(TAG, "unbind failed", it) }
        active.lifecycleOwner.destroy()
        active.thermal.stop()
        active.detector?.close()
        active.detector = null
        runCatching { active.pipeline.release() }.onFailure { Log.w(TAG, "pipeline release failed", it) }
        active.glThread.quit()
        active.analysisExecutor.shutdown()
        active.surfaceProducer.setCallback(null)
        active.surfaceProducer.release()
    }

    private fun describe(active: Session, width: Int, height: Int) = PreviewDescriptor(
        textureId = active.surfaceProducer.id(),
        width = width.toLong(),
        height = height.toLong(),
        lens = active.lens,
        isMirrored = active.lens == CameraLens.FRONT,
        faceTrackingAvailable = active.detector != null,
    )

    private fun requireSession(): Session =
        session ?: throw engineError(EngineErrorCode.CAMERA_UNAVAILABLE, "Engine is not initialized")

    private fun mapError(error: Throwable): Throwable = when (error) {
        is BeautyEngineFlutterError -> error
        is kotlinx.coroutines.TimeoutCancellationException ->
            engineError(EngineErrorCode.CAMERA_UNAVAILABLE, "Camera did not deliver a surface in time")
        is app.yuz.beauty_engine.gl.GlException ->
            engineError(EngineErrorCode.GPU_INITIALIZATION_FAILED, error.message ?: "GPU init failed")
        else -> engineError(EngineErrorCode.UNKNOWN, error.message ?: error.javaClass.simpleName)
    }

    private fun estimateLuma(buffer: java.nio.ByteBuffer, rowStride: Int, width: Int, height: Int): Float {
        var sum = 0f
        var samples = 0
        val stepX = maxOf(1, width / 8)
        val stepY = maxOf(1, height / 8)
        var y = stepY / 2
        while (y < height) {
            var x = stepX / 2
            while (x < width) {
                val offset = y * rowStride + x * 4
                if (offset + 2 < buffer.limit()) {
                    val r = buffer.get(offset).toInt() and 0xFF
                    val g = buffer.get(offset + 1).toInt() and 0xFF
                    val b = buffer.get(offset + 2).toInt() and 0xFF
                    sum += (0.299f * r + 0.587f * g + 0.114f * b) / 255f
                    samples++
                }
                x += stepX
            }
            y += stepY
        }
        return if (samples == 0) 0.5f else sum / samples
    }

    private fun engineError(code: EngineErrorCode, message: String) =
        BeautyEngineFlutterError(code.name, message, null)

    private companion object {
        const val TAG = "YuzBeautyEngine"
        const val SURFACE_TIMEOUT_MILLIS = 5_000L
        const val PERFORMANCE_INTERVAL_MILLIS = 1_000L
        const val STATUS_HEARTBEAT_MILLIS = 1_000L
        const val FACE_STALE_NANOS = 300_000_000L
        const val TORCH_SETTLE_MILLIS = 400L
        const val AUTO_FLASH_LUMA_THRESHOLD = 0.18f
        const val JPEG_QUALITY = 95
        const val PROGRESS_INTERVAL_MILLIS = 100L
    }
}
