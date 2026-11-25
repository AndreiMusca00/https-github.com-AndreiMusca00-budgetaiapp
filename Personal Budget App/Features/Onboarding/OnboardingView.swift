import SwiftUI

struct OnboardingView: View {
    @Environment(PreferencesStore.self) private var preferences
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var flow = OnboardingFlow()
    @State private var hasLoadedDefaults = false
    @State private var errorMessage: String?

    private var language: BudgetLanguage { flow.language ?? .english }
    private var copy: OnboardingCopy { OnboardingCopy(language: language) }
    private var animation: Animation {
        reduceMotion ? .easeInOut(duration: 0.15) : .spring(response: 0.48, dampingFraction: 0.88)
    }
    private var transition: AnyTransition {
        if reduceMotion { return .opacity }
        return .asymmetric(
            insertion: .offset(x: flow.isMovingForward ? 36 : -36, y: 8)
                .combined(with: .opacity).combined(with: .scale(scale: 0.98)),
            removal: .offset(x: flow.isMovingForward ? -28 : 28).combined(with: .opacity)
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            header.padding(.horizontal, 28).padding(.top, 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 36) {
                    OnboardingHeading(step: flow.step, copy: copy)
                        .id("\(flow.step.rawValue)-\(language.rawValue)")
                        .transition(.opacity)

                    switch flow.step {
                    case .language:
                        VStack(alignment: .leading, spacing: 16) {
                            LanguageDropdown(
                                options: BudgetLanguage.allCases,
                                displayLanguage: language,
                                selection: $flow.language
                            )
                            if let first = Locale.preferredLanguages.first,
                               BudgetLanguage.matching(first) == flow.language {
                                Text(copy.detectedLanguage).font(.footnote).foregroundStyle(.secondary)
                                    .padding(.horizontal, 4)
                            }
                            if BudgetLanguage.allCases.isEmpty {
                                Text(copy.unavailable).font(.footnote).foregroundStyle(.secondary)
                                Button(copy.retry) {
                                    flow.language = BudgetLanguage.preferred(deviceLanguages: Locale.preferredLanguages, available: BudgetLanguage.allCases)
                                }
                            }
                        }
                    case .currency:
                        OnboardingCurrencyStep(language: language, currencyCode: $flow.currencyCode)
                    }
                }
                .id(flow.step)
                .transition(transition)
                .frame(maxWidth: 480, alignment: .leading)
                .padding(.horizontal, 28).padding(.top, 64).padding(.bottom, 32)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)

            footer
        }
        .background(BudgetStyle.background)
        .animation(animation, value: flow.step)
        .animation(.easeInOut(duration: reduceMotion ? 0.15 : 0.25), value: flow.language)
        .sensoryFeedback(.selection, trigger: flow.step)
        .onAppear {
            guard !hasLoadedDefaults else { return }
            hasLoadedDefaults = true
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                flow.language = BudgetLanguage.preferred(deviceLanguages: Locale.preferredLanguages, available: BudgetLanguage.allCases)
                let suggestedCurrency = Locale.current.currency?.identifier
                flow.currencyCode = CurrencyOption.all.contains { $0.id == suggestedCurrency } ? suggestedCurrency : nil
            }
        }
    }

    private var header: some View {
        HStack(spacing: 20) {
            Button {
                withAnimation(animation) {
                    errorMessage = nil
                    flow.goBack()
                }
            } label: {
                Image(systemName: "arrow.left")
                    .font(.system(size: 16, weight: .medium)).foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
                    .background(BudgetStyle.card, in: Circle())
            }
            .buttonStyle(.plain)
            .opacity(flow.step.previous == nil ? 0 : 1)
            .disabled(flow.step.previous == nil)
            .accessibilityHidden(flow.step.previous == nil)
            .accessibilityLabel(copy.backTitle)
            .accessibilityIdentifier("onboarding.back")

            HStack(spacing: 6) {
                ForEach(OnboardingStep.allCases) { step in
                    Capsule()
                        .fill(step.rawValue <= flow.step.rawValue ? BudgetStyle.accent : BudgetStyle.accent.opacity(0.12))
                        .frame(height: 3)
                }
            }
            .frame(maxWidth: 120)
            .accessibilityLabel(language == .romanian
                ? "Pasul \(flow.step.number) din \(OnboardingStep.allCases.count)"
                : "Step \(flow.step.number) of \(OnboardingStep.allCases.count)")

            Spacer(minLength: 0)
            Text(String(format: "%02d / %02d", flow.step.number, OnboardingStep.allCases.count))
                .font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
                .contentTransition(.numericText()).accessibilityHidden(true)
        }
        .frame(maxWidth: 480).frame(maxWidth: .infinity)
    }

    private var footer: some View {
        VStack(spacing: 16) {
            if let errorMessage {
                Text(errorMessage).font(.footnote).foregroundStyle(.red)
            }
            Button(action: continueFlow) {
                HStack(spacing: 12) {
                    Text(flow.step.next == nil ? copy.finishTitle : copy.continueTitle)
                    Image(systemName: "arrow.right").font(.subheadline.weight(.semibold))
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!flow.canContinue(availableLanguages: BudgetLanguage.allCases))
            .opacity(flow.canContinue(availableLanguages: BudgetLanguage.allCases) ? 1 : 0.45)
            .accessibilityIdentifier("onboarding.continue")
            Text(copy.changeLater).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: 480)
        .padding(.horizontal, 28).padding(.top, 16).padding(.bottom, 20)
        .frame(maxWidth: .infinity)
    }

    private func continueFlow() {
        guard flow.canContinue(availableLanguages: BudgetLanguage.allCases) else { return }
        if flow.step.next != nil {
            withAnimation(animation) { flow.advance(availableLanguages: BudgetLanguage.allCases) }
        } else if let completed = flow.completedPreferences(availableLanguages: BudgetLanguage.allCases) {
            do {
                try preferences.save(completed)
            } catch {
                errorMessage = copy.saveError
            }
        }
    }
}
