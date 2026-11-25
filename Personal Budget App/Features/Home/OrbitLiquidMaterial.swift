import SwiftUI

struct OrbitLiquidSlice: Identifiable {
    let id: String
    let path: Path
    let palette: OrbitPalette
    let angle: Double
}

/// A single glass envelope keeps the category surfaces joined while they morph.
struct OrbitLiquidMaterial: View {
    let ribbon: Path
    let slices: [OrbitLiquidSlice]
    let expansion: Double
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var isVisible = false
    @State private var motionStart = Date.now

    private var freezeDecoration: Bool {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if !arguments.contains("-budget-live-effects") && (arguments.contains("-budget-ui-tests") || arguments.contains("-budget-orbit-tests")) { return true }
        #endif
        return reduceMotion || !isVisible || scenePhase != .active
    }

    var body: some View {
        GeometryReader { proxy in
            TimelineView(.animation(minimumInterval: ProcessInfo.processInfo.isLowPowerModeEnabled ? 1.0 / 12 : 1.0 / 24, paused: freezeDecoration)) { timeline in
                let phase = freezeDecoration ? 0 : timeline.date.timeIntervalSince(motionStart) * 0.14
                ZStack {
                    meshSurface(phase: phase)
                        .compositingGroup().opacity(0.5)
                        .blur(radius: 0.65)
                        .mask(ribbon)
                    if !reduceTransparency && !slices.isEmpty {
                        Color.clear
                            .glassEffect(.clear.tint(.white.opacity(0.025)).interactive(), in: ribbon)
                        reflection(size: proxy.size, phase: phase)
                            .opacity(0.5)
                            .mask(ribbon).allowsHitTesting(false)
                    }
                    Circle()
                        .fill(RadialGradient(stops: [
                            .init(color: .black.opacity(0.18 + expansion * 0.50), location: 0),
                            .init(color: .black.opacity(0.06 + expansion * 0.25), location: 0.52),
                            .init(color: .clear, location: 0.90)
                        ], center: .center, startRadius: 0, endRadius: proxy.size.width / 2))
                        .mask(ribbon).allowsHitTesting(false)
                }
            }
        }
        .onAppear { motionStart = .now; isVisible = true }
        .onDisappear { isVisible = false }
    }

    private func meshSurface(phase: Double) -> some View {
        ZStack {
            OrbitMeshField(palette: slices.isEmpty ? .init(light: Color(red: 0.035, green: 0.10, blue: 0.07), dark: Color(red: 0.008, green: 0.025, blue: 0.018)) : OrbitPalette.values[0], phase: phase, subdued: slices.isEmpty)
            ForEach(slices) { slice in
                OrbitMeshField(palette: slice.palette, phase: phase + slice.angle * 0.7)
                    .rotationEffect(.radians(slice.angle))
                    .mask(slice.path)
            }
        }
    }

    private func reflection(size: CGSize, phase: Double) -> some View {
        ZStack {
            Ellipse()
                .fill(LinearGradient(stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .white.opacity(0.03), location: 0.25),
                    .init(color: .white.opacity(0.19), location: 0.50),
                    .init(color: .white.opacity(0.025), location: 0.75),
                    .init(color: .clear, location: 1)
                ], startPoint: .top, endPoint: .bottom))
                .frame(width: size.width * 1.45, height: size.height * 0.22)
                .rotationEffect(.degrees(-35 + sin(phase * 0.45) * 8))
                .offset(x: size.width * sin(phase * 0.65) * 0.12, y: -size.height * 0.19)
                .blur(radius: size.width * 0.016)
            ribbon.stroke(LinearGradient(stops: [
                .init(color: .white.opacity(0.50), location: 0),
                .init(color: .white.opacity(0.08), location: 0.25),
                .init(color: .clear, location: 0.55),
                .init(color: .white.opacity(0.18), location: 0.85),
                .init(color: .white.opacity(0.38), location: 1)
            ], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.7)
        }
        .frame(width: size.width, height: size.height)
        .blendMode(.screen)
    }
}

private struct OrbitMeshField: View {
    let palette: OrbitPalette
    let phase: Double
    var subdued = false

    var body: some View {
        MeshGradient(width: 4, height: 4, points: points, colors: colors, smoothsColors: true)
    }

    private var colors: [Color] {
        let light = palette.light
        let dark = palette.dark
        let pearl = subdued ? light : Color(red: 0.86, green: 1, blue: 0.93)
        return [
            dark, light, pearl, dark,
            light, dark, light, dark,
            dark, pearl, dark, light,
            light, dark, light, dark
        ]
    }

    private var points: [SIMD2<Float>] {
        let t = phase
        return [
            p(0, 0), p(0.33 + 0.04 * sin(t), 0), p(0.67 + 0.04 * cos(t + 0.4), 0), p(1, 0),
            p(0, 0.33 + 0.04 * cos(t)),
            p(0.33 + 0.09 * sin(t + 0.7), 0.33 + 0.08 * cos(t * 0.9)),
            p(0.67 + 0.08 * cos(t + 1.2), 0.33 + 0.09 * sin(t * 0.8 + 2.1)),
            p(1, 0.33 + 0.04 * sin(t)),
            p(0, 0.67 + 0.04 * sin(t)),
            p(0.33 + 0.09 * cos(t * 0.7 + 1), 0.67 + 0.08 * sin(t * 0.8)),
            p(0.67 + 0.09 * sin(t * 0.7 + 2), 0.67 + 0.08 * cos(t * 0.9)),
            p(1, 0.67 + 0.04 * cos(t)),
            p(0, 1), p(0.33 + 0.04 * cos(t + 2), 1), p(0.67 + 0.04 * sin(t + 0.5), 1), p(1, 1)
        ]
    }

    private func p(_ x: Double, _ y: Double) -> SIMD2<Float> { SIMD2(Float(x), Float(y)) }
}
