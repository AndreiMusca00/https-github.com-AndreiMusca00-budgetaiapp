import SwiftUI

struct DictationMeshBackground: View {
    let isListening: Bool
    var audioLevel: Float = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var startedAt = Date.now
    @State private var levelStart: Float = 0
    @State private var levelTarget: Float = 0
    @State private var levelChangedAt = Date.now

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion || scenePhase != .active)) { context in
            let time = reduceMotion ? 0 : context.date.timeIntervalSince(startedAt)
            let energy: Float = reduceMotion ? 0 : visualLevel(at: context.date)
            MeshGradient(
                width: 4, height: 4,
                points: points(at: time, energy: energy),
                colors: colors(energy: Double(energy)),
                background: .black, smoothsColors: true
            )
        }
        .overlay {
            LinearGradient(
                colors: [.black.opacity(0.18), .black.opacity(0.04), .black.opacity(0.4)],
                startPoint: .top, endPoint: .bottom
            )
        }
        .opacity(isListening ? 1 : 0.86)
        .background(.black)
        .animation(.easeInOut(duration: reduceMotion ? 0.15 : 1), value: isListening)
        .ignoresSafeArea()
        .accessibilityHidden(true)
        .onChange(of: audioLevel, initial: true) { _, value in
            let now = Date.now
            levelStart = visualLevel(at: now)
            levelTarget = value.isFinite ? min(1, max(0, value)) : 0
            levelChangedAt = now
        }
    }

    private func visualLevel(at date: Date) -> Float {
        let elapsed = max(0, date.timeIntervalSince(levelChangedAt))
        let fraction = Float(1 - exp(-elapsed / 0.12))
        return levelStart + (levelTarget - levelStart) * fraction
    }

    private func colors(energy: Double) -> [Color] {
        [
            .black, Color(red: 0.01, green: 0.10 + energy * 0.06, blue: 0.05),
            Color(red: 0.02, green: 0.28 + energy * 0.12, blue: 0.13), .black,
            Color(red: 0.02, green: 0.18 + energy * 0.08, blue: 0.08),
            Color(red: 0.003, green: 0.014, blue: 0.009), Color(red: 0.02, green: 0.06, blue: 0.03),
            Color(red: 0.04, green: 0.33 + energy * 0.18, blue: 0.18 + energy * 0.06),
            Color(red: 0.02, green: 0.32 + energy * 0.18, blue: 0.15),
            Color(red: 0.025, green: 0.20 + energy * 0.10, blue: 0.10),
            Color(red: 0.01, green: 0.07, blue: 0.04),
            Color(red: 0.18 + energy * 0.04, green: 0.60 + energy * 0.28, blue: 0.36 + energy * 0.10),
            .black, Color(red: 0.06, green: 0.40 + energy * 0.22, blue: 0.21),
            Color(red: 0.18, green: 0.72 + energy * 0.25, blue: 0.48),
            Color(red: 0.01, green: 0.16 + energy * 0.12, blue: 0.08)
        ]
    }

    private func points(at time: TimeInterval, energy: Float) -> [SIMD2<Float>] {
        let t = Float(time) * 0.28
        let ripple = Float(time) * 2.2
        let e = energy
        // Pinned corners and non-crossing rows/columns keep the mesh filled even at peak volume.
        return [
            [0, 0], [0.32 + 0.06 * sin(t) + 0.025 * e * sin(ripple), 0],
            [0.68 + 0.05 * cos(t * 0.8) + 0.025 * e * cos(ripple * 0.9), 0], [1, 0],
            [0, 0.30 + 0.055 * sin(t * 0.9) + 0.035 * e * cos(ripple * 1.1)],
            [0.32 + 0.05 * sin(t * 0.8) + 0.075 * e * sin(ripple + 0.3),
             0.30 + 0.05 * cos(t * 0.7) + 0.075 * e * cos(ripple * 1.1)],
            [0.68 + 0.05 * cos(t * 0.7) + 0.075 * e * cos(ripple + 0.9),
             0.30 + 0.05 * sin(t) + 0.075 * e * sin(ripple * 1.1 + 0.6)],
            [1, 0.31 + 0.055 * cos(t * 0.8) + 0.035 * e * sin(ripple)],
            [0, 0.68 + 0.055 * cos(t * 0.7) + 0.035 * e * sin(ripple * 0.9)],
            [0.32 + 0.05 * cos(t) + 0.075 * e * cos(ripple * 1.2 + 0.2),
             0.68 + 0.05 * sin(t * 0.8) + 0.075 * e * sin(ripple + 0.9)],
            [0.68 + 0.05 * sin(t * 0.7) + 0.075 * e * sin(ripple * 0.9 + 1),
             0.67 + 0.05 * cos(t) + 0.075 * e * cos(ripple + 0.4)],
            [1, 0.68 + 0.055 * sin(t * 0.9) + 0.035 * e * cos(ripple)],
            [0, 1], [0.32 + 0.05 * sin(t * 0.7) + 0.025 * e * cos(ripple), 1],
            [0.68 + 0.05 * cos(t * 0.8) + 0.025 * e * sin(ripple), 1], [1, 1]
        ]
    }
}
