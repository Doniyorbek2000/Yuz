package app.yuz.beauty_engine.perf

import java.util.concurrent.atomic.AtomicLong

/**
 * Lock-free counters written from the GL, camera and detector threads and
 * drained once per second into a [Snapshot]. Values are measured, never
 * estimated: FPS is rendered frames per wall-clock second.
 */
class PerformanceTracker(private val clockNanos: () -> Long = System::nanoTime) {
    data class Snapshot(
        val renderedFps: Double,
        val cameraFps: Double,
        val averageGpuFrameMillis: Double,
        val averageDetectorMillis: Double,
        val droppedFrames: Long,
    )

    private val renderedFrames = AtomicLong()
    private val cameraFrames = AtomicLong()
    private val droppedFrames = AtomicLong()
    private val gpuNanosTotal = AtomicLong()
    private val detectorNanosTotal = AtomicLong()
    private val detectorRuns = AtomicLong()
    private var windowStartNanos = clockNanos()

    fun onCameraFrame() {
        cameraFrames.incrementAndGet()
    }

    fun onFrameRendered(gpuNanos: Long) {
        renderedFrames.incrementAndGet()
        gpuNanosTotal.addAndGet(gpuNanos)
    }

    fun onFrameDropped() {
        droppedFrames.incrementAndGet()
    }

    fun onDetectorRun(nanos: Long) {
        detectorRuns.incrementAndGet()
        detectorNanosTotal.addAndGet(nanos)
    }

    /** Returns the stats of the elapsed window and starts a new one. */
    @Synchronized
    fun drain(): Snapshot {
        val now = clockNanos()
        val seconds = ((now - windowStartNanos).coerceAtLeast(1L)) / 1_000_000_000.0
        windowStartNanos = now
        val rendered = renderedFrames.getAndSet(0)
        val camera = cameraFrames.getAndSet(0)
        val gpu = gpuNanosTotal.getAndSet(0)
        val detector = detectorNanosTotal.getAndSet(0)
        val runs = detectorRuns.getAndSet(0)
        return Snapshot(
            renderedFps = rendered / seconds,
            cameraFps = camera / seconds,
            averageGpuFrameMillis = if (rendered == 0L) 0.0 else gpu / rendered / 1_000_000.0,
            averageDetectorMillis = if (runs == 0L) 0.0 else detector / runs / 1_000_000.0,
            droppedFrames = droppedFrames.getAndSet(0),
        )
    }
}
