import SwiftUI

/// A single native Text layout retains kerning, wrapping, diacritics and accessibility.
nonisolated struct LetterBounceRenderer: TextRenderer {
    var time: Double
    var delay: Double = 0
    static let duration = 0.68
    static let glyphDuration = 0.42
    var animatableData: Double {
        get { time }
        set { time = newValue }
    }
    var displayPadding: EdgeInsets { EdgeInsets(top: 8, leading: 4, bottom: 16, trailing: 4) }

    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        guard time > delay else { return }
        if time >= delay + Self.duration {
            for line in layout { context.draw(line) }
            return
        }
        let count = layout.reduce(0) { result, line in result + line.reduce(0) { $0 + $1.count } }
        let interval = min(0.022, (Self.duration - Self.glyphDuration) / Double(max(count - 1, 1)))
        var index = 0
        for line in layout {
            for run in line {
                for glyph in run {
                    let progress = (time - delay - Double(index) * interval) / Self.glyphDuration
                    Self.draw(glyph, progress: progress, in: context)
                    index += 1
                }
            }
        }
    }

    static func draw(_ glyph: Text.Layout.RunSlice, progress: Double, in context: GraphicsContext) {
        guard progress > 0 else { return }
        var drawing = context
        if progress < 1 {
            let bounds = glyph.typographicBounds.rect
            let spring = Spring(duration: 0.4, bounce: 0.28)
            let displacement = spring.value(fromValue: 1.0, toValue: 0.0, initialVelocity: 0.0,
                                            time: progress * glyphDuration)
            let scale = 1 - 0.18 * displacement
            drawing.opacity *= min(1, progress * 3)
            drawing.translateBy(x: bounds.midX, y: bounds.midY + bounds.height * 0.35 * displacement)
            drawing.scaleBy(x: scale, y: scale)
            drawing.translateBy(x: -bounds.midX, y: -bounds.midY)
            if progress < 0.5 { drawing.addFilter(.blur(radius: (1 - progress * 2) * 1.8)) }
        }
        drawing.draw(glyph, options: .disablesSubpixelQuantization)
    }
}

private struct LetterBounceAppearance: ViewModifier {
    let delay: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var time = 0.0
    func body(content: Content) -> some View {
        content.textRenderer(LetterBounceRenderer(
            time: reduceMotion ? LetterBounceRenderer.duration + delay : time, delay: delay
        ))
        .task {
            guard time == 0, !reduceMotion else { return }
            // Commit the initial glyph state before animating the renderer.
            do { try await Task.sleep(for: .milliseconds(24)) } catch { return }
            let end = LetterBounceRenderer.duration + delay
            withAnimation(.linear(duration: end)) { time = end }
        }
    }
}

extension View {
    func letterBounce(delay: Double = 0) -> some View { modifier(LetterBounceAppearance(delay: delay)) }
}
