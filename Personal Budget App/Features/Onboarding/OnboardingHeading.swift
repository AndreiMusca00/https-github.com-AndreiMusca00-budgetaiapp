import SwiftUI

struct OnboardingHeading: View {
    let step: OnboardingStep
    let copy: OnboardingCopy
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = false

    private var lines: [String] {
        (step == .language ? copy.languageTitle : copy.currencyTitle).components(separatedBy: "\n")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(step == .language ? copy.languageLabel : copy.currencyLabel)
                .font(.system(size: 11, weight: .semibold)).tracking(2.5)
                .foregroundStyle(BudgetStyle.accent)
                .modifier(RevealText(isVisible: isVisible, delay: 0, reduceMotion: reduceMotion))

            VStack(alignment: .leading, spacing: 2) {
                ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                    Text(line)
                        .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                        .tracking(-0.8).fixedSize(horizontal: false, vertical: true)
                        .modifier(RevealText(isVisible: isVisible, delay: 0.07 + Double(index) * 0.09, reduceMotion: reduceMotion))
                }
            }
            .accessibilityElement(children: .combine)

            Text(step == .language ? copy.languageSubtitle : copy.currencySubtitle)
                .font(.subheadline).foregroundStyle(.secondary)
                .modifier(RevealText(isVisible: isVisible, delay: 0.25, reduceMotion: reduceMotion))
        }
        .task {
            // Let the first frame render before starting the staggered text reveal.
            do { try await Task.sleep(for: .milliseconds(40)) } catch { return }
            guard !Task.isCancelled else { return }
            isVisible = true
        }
    }
}

private struct RevealText: ViewModifier {
    let isVisible: Bool
    let delay: Double
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .blur(radius: isVisible || reduceMotion ? 0 : 9)
            .offset(y: isVisible || reduceMotion ? 0 : 18)
            .animation(
                reduceMotion ? .easeOut(duration: 0.15)
                    : .spring(response: 0.6, dampingFraction: 0.88).delay(delay),
                value: isVisible
            )
    }
}
