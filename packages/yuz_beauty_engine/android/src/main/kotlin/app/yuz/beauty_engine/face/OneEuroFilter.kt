package app.yuz.beauty_engine.face

import kotlin.math.PI
import kotlin.math.abs

/**
 * One Euro filter (Casiez et al., CHI 2012): an adaptive low-pass filter that
 * removes landmark jitter when the face is still and keeps latency low when
 * it moves fast.
 *
 * Defaults are tuned for normalized (0..1) image coordinates, where head
 * motion reaches ~3 units/s: beta = 5 raises the cutoff to ~16 Hz during
 * fast motion while still jitter stays at the 1.2 Hz floor (verified in
 * OneEuroFilterTest; beta = 1 lags visibly).
 */
class OneEuroFilter(
    private val minCutoffHz: Double = 1.2,
    private val beta: Double = 5.0,
    private val derivativeCutoffHz: Double = 1.0,
) {
    private var previousValue = 0.0
    private var previousDerivative = 0.0
    private var previousTimestampNanos = 0L
    private var initialized = false

    fun filter(value: Double, timestampNanos: Long): Double {
        if (!initialized) {
            initialized = true
            previousValue = value
            previousDerivative = 0.0
            previousTimestampNanos = timestampNanos
            return value
        }
        val elapsedSeconds = (timestampNanos - previousTimestampNanos) / 1_000_000_000.0
        if (elapsedSeconds <= 0.0) return previousValue

        val derivative = (value - previousValue) / elapsedSeconds
        val smoothedDerivative = lowPass(derivative, previousDerivative, alpha(elapsedSeconds, derivativeCutoffHz))
        val cutoff = minCutoffHz + beta * abs(smoothedDerivative)
        val smoothedValue = lowPass(value, previousValue, alpha(elapsedSeconds, cutoff))

        previousValue = smoothedValue
        previousDerivative = smoothedDerivative
        previousTimestampNanos = timestampNanos
        return smoothedValue
    }

    fun reset() {
        initialized = false
    }

    private fun alpha(elapsedSeconds: Double, cutoffHz: Double): Double {
        val tau = 1.0 / (2.0 * PI * cutoffHz)
        return 1.0 / (1.0 + tau / elapsedSeconds)
    }

    private fun lowPass(value: Double, previous: Double, alpha: Double): Double =
        alpha * value + (1.0 - alpha) * previous
}
