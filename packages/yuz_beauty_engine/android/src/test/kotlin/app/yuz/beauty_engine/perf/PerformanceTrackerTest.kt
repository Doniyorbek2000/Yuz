package app.yuz.beauty_engine.perf

import kotlin.test.Test
import kotlin.test.assertEquals

class PerformanceTrackerTest {
    @Test
    fun computesRatesFromMeasuredCounts() {
        var now = 0L
        val tracker = PerformanceTracker { now }
        repeat(30) { tracker.onCameraFrame() }
        repeat(28) { tracker.onFrameRendered(4_000_000L) }
        repeat(2) { tracker.onFrameDropped() }
        repeat(10) { tracker.onDetectorRun(12_000_000L) }
        now = 1_000_000_000L

        val snapshot = tracker.drain()
        assertEquals(28.0, snapshot.renderedFps, 1e-9)
        assertEquals(30.0, snapshot.cameraFps, 1e-9)
        assertEquals(4.0, snapshot.averageGpuFrameMillis, 1e-9)
        assertEquals(12.0, snapshot.averageDetectorMillis, 1e-9)
        assertEquals(2L, snapshot.droppedFrames)
    }

    @Test
    fun drainResetsTheWindow() {
        var now = 0L
        val tracker = PerformanceTracker { now }
        tracker.onFrameRendered(1L)
        now = 500_000_000L
        tracker.drain()
        now = 1_500_000_000L
        val snapshot = tracker.drain()
        assertEquals(0.0, snapshot.renderedFps, 1e-9)
        assertEquals(0.0, snapshot.averageGpuFrameMillis, 1e-9)
    }
}
