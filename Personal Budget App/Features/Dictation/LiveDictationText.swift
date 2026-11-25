import SwiftUI

/// Reveals new speech hypotheses without replaying the already visible sentence.
struct LiveDictationText: View {
    let text: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealedCharacters = 0.0

    var body: some View {
        Text(text)
            .font(.system(.title2, design: .rounded, weight: .semibold))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .lineSpacing(5)
            .textRenderer(SpeechGlyphRenderer(
                revealedCharacters: reduceMotion ? Double(text.count) : revealedCharacters,
                characterCount: text.count
            ))
            .fixedSize(horizontal: false, vertical: true)
            .shadow(color: .black.opacity(0.45), radius: 14, y: 2)
            .accessibilityIdentifier("dictation.liveTranscript")
            .task {
                if !reduceMotion {
                    do { try await Task.sleep(for: .milliseconds(24)) } catch { return }
                }
                // A newer partial hypothesis may already have started its reveal.
                if revealedCharacters == 0 { reveal(from: 0, to: text.count) }
            }
            .onChange(of: text) { oldValue, newValue in
                reveal(from: oldValue.count, to: newValue.count)
            }
    }

    private func reveal(from oldCount: Int, to newCount: Int) {
        if reduceMotion || newCount <= oldCount {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { revealedCharacters = Double(newCount) }
        } else {
            let duration = min(0.45, max(0.16, Double(newCount - oldCount) * 0.022))
            withAnimation(.easeOut(duration: duration)) { revealedCharacters = Double(newCount) }
        }
    }
}

nonisolated private struct SpeechGlyphRenderer: TextRenderer {
    var revealedCharacters: Double
    let characterCount: Int

    var animatableData: Double {
        get { revealedCharacters }
        set { revealedCharacters = newValue }
    }

    var displayPadding: EdgeInsets { EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8) }

    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        guard revealedCharacters > 0 else { return }
        if revealedCharacters >= Double(characterCount) {
            for line in layout { context.draw(line) }
            return
        }
        let glyphCount = layout.reduce(0) { total, line in total + line.reduce(0) { $0 + $1.count } }
        let fraction = min(1, max(0, revealedCharacters / Double(max(characterCount, 1))))
        let edge = fraction * Double(glyphCount) + 2
        var index = 0
        for line in layout {
            for run in line {
                for slice in run {
                    let visibility = min(1, max(0, (edge - Double(index)) / 3))
                    index += 1
                    guard visibility > 0 else { continue }
                    LetterBounceRenderer.draw(slice, progress: visibility, in: context)
                }
            }
        }
    }
}
