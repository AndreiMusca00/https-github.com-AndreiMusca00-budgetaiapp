import SwiftUI

enum BudgetStyle {
    static let accent = Color(red: 0.08, green: 0.35, blue: 0.17)
    static let ink = Color.white
    static let background = Color(red: 0.986, green: 0.981, blue: 0.971)
    static let card = Color.primary.opacity(0.025)
    static let separator = Color.primary.opacity(0.09)
    static let muted = Color.primary.opacity(0.44)
    static let buttonGradient = accent
    static let languageBadge = accent.opacity(0.07)
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(.headline, design: .rounded, weight: .semibold))
            .frame(maxWidth: .infinity, minHeight: 52)
            .foregroundStyle(.white)
            .background(BudgetStyle.accent, in: Capsule())
            .contentShape(Capsule())
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.84 : 1)
            .animation(reduceMotion ? nil : .smooth(duration: 0.2), value: configuration.isPressed)
    }
}

/// Quiet content surfaces; native Liquid Glass is reserved for navigation controls.
extension View {
    func budgetGlass<S: Shape>(in shape: S) -> some View {
        background(Color.primary.opacity(0.025), in: shape)
    }
    func budgetGlass() -> some View { budgetGlass(in: RoundedRectangle(cornerRadius: 20, style: .continuous)) }
}


struct NotesNavigationButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold, design: .rounded))
            .foregroundStyle(BudgetStyle.accent)
            .frame(maxWidth: .infinity, minHeight: 48)
            .contentShape(Capsule())
            .glassEffect(.regular.tint(BudgetStyle.accent.opacity(0.025)).interactive(), in: Capsule())
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(reduceMotion ? nil : .smooth(duration: 0.2), value: configuration.isPressed)
    }
}
