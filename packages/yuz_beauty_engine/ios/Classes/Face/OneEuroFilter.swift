import Foundation

/// One Euro filter (Casiez et al., CHI 2012). Same defaults as the Android
/// engine (`OneEuroFilter.kt`), tuned for normalized 0...1 coordinates.
struct OneEuroFilter {
  private let minCutoffHz: Double
  private let beta: Double
  private let derivativeCutoffHz: Double

  private var previousValue = 0.0
  private var previousDerivative = 0.0
  private var previousTimestamp: TimeInterval = 0
  private var initialized = false

  init(minCutoffHz: Double = 1.2, beta: Double = 5.0, derivativeCutoffHz: Double = 1.0) {
    self.minCutoffHz = minCutoffHz
    self.beta = beta
    self.derivativeCutoffHz = derivativeCutoffHz
  }

  mutating func filter(_ value: Double, timestamp: TimeInterval) -> Double {
    guard initialized else {
      initialized = true
      previousValue = value
      previousDerivative = 0
      previousTimestamp = timestamp
      return value
    }
    let elapsed = timestamp - previousTimestamp
    guard elapsed > 0 else { return previousValue }

    let derivative = (value - previousValue) / elapsed
    let smoothedDerivative = Self.lowPass(
      derivative, previousDerivative, alpha: Self.alpha(elapsed, cutoff: derivativeCutoffHz))
    let cutoff = minCutoffHz + beta * abs(smoothedDerivative)
    let smoothed = Self.lowPass(value, previousValue, alpha: Self.alpha(elapsed, cutoff: cutoff))

    previousValue = smoothed
    previousDerivative = smoothedDerivative
    previousTimestamp = timestamp
    return smoothed
  }

  mutating func reset() {
    initialized = false
  }

  private static func alpha(_ elapsed: Double, cutoff: Double) -> Double {
    let tau = 1.0 / (2.0 * Double.pi * cutoff)
    return 1.0 / (1.0 + tau / elapsed)
  }

  private static func lowPass(_ value: Double, _ previous: Double, alpha: Double) -> Double {
    alpha * value + (1 - alpha) * previous
  }
}
