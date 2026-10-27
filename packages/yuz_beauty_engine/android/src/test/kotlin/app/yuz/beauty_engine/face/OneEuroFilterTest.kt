package app.yuz.beauty_engine.face

import kotlin.math.abs
import kotlin.math.sin
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class OneEuroFilterTest {
    private val frameNanos = 33_333_333L

    @Test
    fun firstSampleIsReturnedUnchanged() {
        val filter = OneEuroFilter()
        assertEquals(0.42, filter.filter(0.42, 0L))
    }

    @Test
    fun reducesJitterOfStaticSignal() {
        val filter = OneEuroFilter()
        var rawEnergy = 0.0
        var filteredEnergy = 0.0
        for (frame in 0 until 120) {
            val jitter = if (frame % 2 == 0) 0.004 else -0.004
            val output = filter.filter(0.5 + jitter, frame * frameNanos)
            if (frame > 10) {
                rawEnergy += jitter * jitter
                filteredEnergy += (output - 0.5) * (output - 0.5)
            }
        }
        assertTrue(filteredEnergy < rawEnergy * 0.25, "filtered $filteredEnergy vs raw $rawEnergy")
    }

    @Test
    fun followsFastMotionWithLowLag() {
        val filter = OneEuroFilter()
        var lastOutput = 0.0
        var lastInput = 0.0
        for (frame in 0 until 60) {
            lastInput = 0.2 + 0.6 * sin(frame / 6.0)
            lastOutput = filter.filter(lastInput, frame * frameNanos)
        }
        assertTrue(abs(lastOutput - lastInput) < 0.08, "lag ${abs(lastOutput - lastInput)}")
    }

    @Test
    fun nonIncreasingTimestampKeepsPreviousValue() {
        val filter = OneEuroFilter()
        filter.filter(0.1, 1_000L)
        assertEquals(0.1, filter.filter(0.9, 1_000L))
    }

    @Test
    fun resetForgetsHistory() {
        val filter = OneEuroFilter()
        filter.filter(0.1, 0L)
        filter.filter(0.1, frameNanos)
        filter.reset()
        assertEquals(0.8, filter.filter(0.8, 2 * frameNanos))
    }
}
