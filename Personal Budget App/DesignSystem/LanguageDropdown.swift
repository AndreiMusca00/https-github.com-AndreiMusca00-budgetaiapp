import SwiftUI

struct LanguageDropdown: View {
    let options: [BudgetLanguage]
    let displayLanguage: BudgetLanguage
    @Binding var selection: BudgetLanguage?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isExpanded: Bool

    init(options: [BudgetLanguage], displayLanguage: BudgetLanguage, selection: Binding<BudgetLanguage?>, initiallyExpanded: Bool = false) {
        self.options = options
        self.displayLanguage = displayLanguage
        self._selection = selection
        self._isExpanded = State(initialValue: initiallyExpanded)
    }

    private var animation: Animation {
        reduceMotion ? .easeInOut(duration: 0.15) : .spring(response: 0.38, dampingFraction: 0.85)
    }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(animation) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 16) {
                    if let selection {
                        Text(selection.flag).font(.system(size: 32)).accessibilityHidden(true)
                        Text(selection.countryName(in: displayLanguage))
                            .font(.body.weight(.semibold)).contentTransition(.opacity)
                    } else {
                        Image(systemName: "globe").font(.title2)
                        Text(OnboardingCopy(language: displayLanguage).chooseLanguage)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .frame(width: 32, height: 32)
                        .background(.primary.opacity(0.04), in: Circle())
                }
                .foregroundStyle(.primary)
                .padding(.horizontal, 20).padding(.vertical, 18)
                .frame(minHeight: 76).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(OnboardingCopy(language: displayLanguage).languageLabel)
            .accessibilityValue(selection?.accessibilityName ?? "")
            .accessibilityIdentifier("onboarding.languageDropdown")

            if isExpanded {
                VStack(spacing: 6) {
                    Divider().padding(.horizontal, 12).padding(.bottom, 4)
                    ForEach(options) { option in
                        Button {
                            withAnimation(animation) { selection = option; isExpanded = false }
                        } label: {
                            HStack(spacing: 16) {
                                Text(option.flag).font(.system(size: 28)).accessibilityHidden(true)
                                Text(option.countryName(in: displayLanguage))
                                    .font(.body.weight(selection == option ? .semibold : .regular))
                                Spacer(minLength: 8)
                                if selection == option {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(BudgetStyle.accent)
                                }
                            }
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 16).padding(.vertical, 16)
                            .frame(minHeight: 56)
                            .background(selection == option ? BudgetStyle.accent.opacity(0.08) : .clear,
                                        in: RoundedRectangle(cornerRadius: 15))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(option.accessibilityName)
                        .accessibilityAddTraits(selection == option ? .isSelected : [])
                        .accessibilityIdentifier("onboarding.language.\(option.rawValue)")
                    }
                }
                .padding(10)
                .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
            }
        }
        .background(BudgetStyle.card, in: RoundedRectangle(cornerRadius: 24))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay { RoundedRectangle(cornerRadius: 24).strokeBorder(BudgetStyle.accent.opacity(0.16), lineWidth: 1) }
        .shadow(color: BudgetStyle.accent.opacity(isExpanded ? 0.07 : 0.025), radius: 24, y: 8)
        .sensoryFeedback(.selection, trigger: selection)
    }
}
