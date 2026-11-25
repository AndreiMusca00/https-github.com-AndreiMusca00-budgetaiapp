import SwiftUI

extension AnyTransition {
    static func voiceExpansion(from sourceFrame: CGRect) -> AnyTransition {
        .asymmetric(
            insertion: .modifier(
                active: VoiceExpansionModifier(sourceFrame: sourceFrame, progress: 0),
                identity: VoiceExpansionModifier(sourceFrame: sourceFrame, progress: 1)
            ),
            removal: .opacity
        )
    }
}

private struct VoiceExpansionModifier: AnimatableModifier {
    let sourceFrame: CGRect
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { geometry in
                    let source = localSource(in: geometry)
                    let gel = VoiceGelGeometry(rect: CGRect(origin: .zero, size: geometry.size), source: source, progress: progress)
                    RadialGradient(
                        stops: [
                            .init(color: .white.opacity(0.10), location: 0),
                            .init(color: BudgetStyle.accent.opacity(0.32), location: 0.3),
                            .init(color: BudgetStyle.accent.opacity(0.08), location: 0.68),
                            .init(color: .clear, location: 1)
                        ],
                        center: UnitPoint(x: gel.center.x / max(geometry.size.width, 1),
                                          y: gel.center.y / max(geometry.size.height, 1)),
                        startRadius: 0,
                        endRadius: max(gel.radius, 36)
                    )
                    .blendMode(.screen)
                    .opacity(Double(1 - gel.progress))
                }
                .ignoresSafeArea().allowsHitTesting(false).accessibilityHidden(true)
            }
            .mask {
                GeometryReader { geometry in
                    let p = min(1, max(0, progress))
                    VoiceGelMask(sourceFrame: localSource(in: geometry), progress: p)
                        .blur(radius: 3.5 * pow(sin(CGFloat.pi * p), 1.15))
                }
                .ignoresSafeArea()
            }
    }

    private func localSource(in geometry: GeometryProxy) -> CGRect {
        let global = geometry.frame(in: .global)
        return sourceFrame.isEmpty
            ? CGRect(x: geometry.size.width - 96, y: geometry.size.height - 104, width: 72, height: 72)
            : sourceFrame.offsetBy(dx: -global.minX, dy: -global.minY)
    }
}

nonisolated private struct VoiceGelGeometry {
    let progress: CGFloat
    let center: CGPoint
    let radius: CGFloat
    let axis: CGFloat
    let elasticity: CGFloat

    init(rect: CGRect, source: CGRect, progress: CGFloat) {
        let p = min(1, max(0, progress))
        self.progress = p
        let start = CGPoint(x: source.midX, y: source.midY)
        let destination = CGPoint(x: rect.midX, y: rect.midY)
        let travel = min(1, p / 0.82)
        let easedTravel = travel * travel * (3 - 2 * travel)
        let envelope = pow(max(0, sin(CGFloat.pi * p)), 1.15)
        let angle = atan2(destination.y - start.y, destination.x - start.x)
        let initialRadius = max(source.width, source.height) / 2
        let finalRadius = hypot(rect.width, rect.height) / 2 + 28
        let radius = initialRadius + (finalRadius - initialRadius) * p
        // A small sideways recoil makes the swelling feel attached to the button rather than a wipe.
        let recoil = radius * 0.045 * envelope * sin(p * CGFloat.pi * 3)
        self.center = CGPoint(
            x: start.x + (destination.x - start.x) * easedTravel - sin(angle) * recoil,
            y: start.y + (destination.y - start.y) * easedTravel + cos(angle) * recoil
        )
        self.radius = radius
        self.axis = angle
        self.elasticity = envelope
    }
}

nonisolated private struct VoiceGelMask: Shape {
    let sourceFrame: CGRect
    let progress: CGFloat

    func path(in rect: CGRect) -> Path {
        let gel = VoiceGelGeometry(rect: rect, source: sourceFrame, progress: progress)
        if gel.progress <= 0 {
            return Path(ellipseIn: sourceFrame)
        }
        if gel.progress >= 0.999 {
            return Path(rect)
        }

        let count = 36
        let p = gel.progress
        let envelope = gel.elasticity
        let stretch = 1 + 0.26 * envelope
        let compression = 1 - 0.12 * envelope
        let squash = 0.12 * envelope * sin(p * CGFloat.pi * 3)
        let axisCos = cos(gel.axis)
        let axisSin = sin(gel.axis)
        var points: [CGPoint] = []
        points.reserveCapacity(count)

        for index in 0..<count {
            let theta = CGFloat(index) * CGFloat.pi * 2 / CGFloat(count)
            let relative = theta - gel.axis
            let back = atan2(sin(relative - CGFloat.pi), cos(relative - CGFloat.pi))
            let tail = exp(-pow(back / 0.48, 2))
            let shoulders = exp(-pow((back - 0.72) / 0.3, 2))
                + exp(-pow((back + 0.72) / 0.3, 2))
            // Travelling lobes, a narrow trailing neck, and squash/stretch all settle to zero.
            let ripple = 0.055 * sin(theta * 3 - p * CGFloat.pi * 3)
                + 0.025 * sin(theta * 5 + p * CGFloat.pi * 2)
            let swelling = 1 + envelope * (ripple + 0.18 * tail - 0.07 * shoulders)
                + squash * cos(relative * 2)
            let radial = gel.radius * swelling
            let along = cos(relative) * radial * stretch
            let across = sin(relative) * radial * compression
            points.append(CGPoint(
                x: gel.center.x + along * axisCos - across * axisSin,
                y: gel.center.y + along * axisSin + across * axisCos
            ))
        }

        // Closed cubic curves keep the contour soft; no segmented polygon edges or persistent border.
        var path = Path()
        path.move(to: points[0])
        for index in 0..<count {
            let previous = points[(index + count - 1) % count]
            let current = points[index]
            let next = points[(index + 1) % count]
            let after = points[(index + 2) % count]
            path.addCurve(
                to: next,
                control1: CGPoint(x: current.x + (next.x - previous.x) / 6,
                                  y: current.y + (next.y - previous.y) / 6),
                control2: CGPoint(x: next.x - (after.x - current.x) / 6,
                                  y: next.y - (after.y - current.y) / 6)
            )
        }
        path.closeSubpath()
        return path
    }
}
