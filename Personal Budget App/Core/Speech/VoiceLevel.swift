import Foundation

nonisolated enum VoiceLevel {
    static func normalized(rms: Float) -> Float {
        guard rms.isFinite, rms > 0 else { return 0 }
        let decibels = 20 * log10(max(rms, 0.0000001))
        return min(1, max(0, (decibels + 55) / 40))
    }

    static func smoothed(previous: Float, input: Float) -> Float {
        let previous = previous.isFinite ? min(1, max(0, previous)) : 0
        let input = input.isFinite ? min(1, max(0, input)) : 0
        let coefficient: Float = input > previous ? 0.6 : 0.16
        return previous + coefficient * (input - previous)
    }
}
