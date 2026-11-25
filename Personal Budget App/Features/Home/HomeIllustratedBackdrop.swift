import SwiftUI

enum HomeIllustrationSection: String, CaseIterable {
    case accounts, expenses, payments
}

struct HomeIllustrationAnchors: PreferenceKey {
    static let defaultValue: [HomeIllustrationSection: Anchor<CGRect>] = [:]
    static func reduce(value: inout [HomeIllustrationSection: Anchor<CGRect>],
                       nextValue: () -> [HomeIllustrationSection: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { _, latest in latest })
    }
}

extension View {
    func homeIllustrationAnchor(_ section: HomeIllustrationSection) -> some View {
        anchorPreference(key: HomeIllustrationAnchors.self, value: .bounds) { [section: $0] }
    }
}

/// Decorative art is positioned from the live content bounds, outside the scroll view's clip.
/// It follows the sections as they scroll, including under the fixed header and safe areas.
struct HomeIllustratedBackdrop: View {
    let anchors: [HomeIllustrationSection: Anchor<CGRect>]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = false
    private let ink = Color(red: 0.43, green: 0.49, blue: 0.42)

    var body: some View {
        GeometryReader { proxy in
            let width = min(proxy.size.width, 600)
            let center = proxy.size.width / 2
            ZStack(alignment: .topLeading) {
                if let anchor = anchors[.accounts] {
                    let rect = proxy[anchor]
                    let height = width * 0.51
                    artwork(.accounts)
                        .frame(width: width * 1.08, height: height)
                        .position(x: center, y: rect.minY - height * 0.31)
                }
                if let anchor = anchors[.expenses] {
                    let rect = proxy[anchor]
                    let side = min(width * 0.67, max(108, rect.height * 0.88))
                    artwork(.expenses)
                        .frame(width: side, height: side)
                        .position(x: center + width * 0.24, y: rect.minY + min(rect.height * 0.52, side * 0.59))
                    contour(width: width * 1.15, height: 36, reversed: false)
                        .position(x: center, y: rect.minY - 17)
                }
                if let anchor = anchors[.payments] {
                    let rect = proxy[anchor]
                    let height = width * 0.43
                    artwork(.payments)
                        .frame(width: width * 0.98, height: height)
                        .position(x: center - width * 0.20, y: rect.maxY + height * 0.34)
                    contour(width: width * 1.15, height: 44, reversed: true)
                        .position(x: center, y: rect.minY - 15)
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                // Merge opaque strokes first; apply translucency once so intersections stay uniform.
                .compositingGroup().opacity(0.25)
        }
        .allowsHitTesting(false).accessibilityHidden(true)
        .task(id: anchors.isEmpty) {
            guard !anchors.isEmpty, !revealed else { return }
            if !reduceMotion {
                do { try await Task.sleep(for: .milliseconds(32)) } catch { return }
            }
            revealed = true
        }
        .onChange(of: reduceMotion) { _, enabled in if enabled { revealed = true } }
    }

    private func artwork(_ section: HomeIllustrationSection) -> some View {
        HomeContourDrawing(section: section, revealed: revealed, ink: ink)
    }

    private func contour(width: CGFloat, height: CGFloat, reversed: Bool) -> some View {
        HomeSectionContour(reversed: reversed).trim(from: 0, to: revealed || reduceMotion ? 1 : 0)
            .stroke(ink, style: StrokeStyle(lineWidth: 2.3, lineCap: .round))
            .frame(width: width, height: height)
            .animation(reduceMotion ? nil : .easeInOut(duration: 1.8).delay(0.1), value: revealed)
    }
}

private struct HomeSectionContour: Shape {
    let reversed: Bool
    func path(in rect: CGRect) -> Path {
        let height = rect.height
        func y(_ fraction: CGFloat) -> CGFloat { rect.minY + height * (reversed ? 1 - fraction : fraction) }
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: y(0.35)))
        path.addCurve(to: CGPoint(x: rect.minX + rect.width * 0.49, y: y(0.65)),
                      control1: CGPoint(x: rect.minX + rect.width * 0.18, y: y(-0.25)),
                      control2: CGPoint(x: rect.minX + rect.width * 0.28, y: y(1.15)))
        path.addCurve(to: CGPoint(x: rect.maxX, y: y(0.45)),
                      control1: CGPoint(x: rect.minX + rect.width * 0.80, y: y(-0.20)),
                      control2: CGPoint(x: rect.minX + rect.width * 0.82, y: y(-0.35)))
        return path
    }
}
