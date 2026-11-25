import Foundation

// Add future questions here; navigation and progress follow this ordered sequence.
enum OnboardingStep: Int, CaseIterable, Identifiable {
    case language
    case currency

    var id: Int { rawValue }
    var number: Int { rawValue + 1 }
    var next: OnboardingStep? { OnboardingStep(rawValue: rawValue + 1) }
    var previous: OnboardingStep? { OnboardingStep(rawValue: rawValue - 1) }
}

struct OnboardingFlow {
    private(set) var step: OnboardingStep = .language
    private(set) var isMovingForward = true
    var language: BudgetLanguage?
    var currencyCode: String?

    func canContinue(availableLanguages: [BudgetLanguage]) -> Bool {
        guard let language, availableLanguages.contains(language) else { return false }
        switch step {
        case .language: return true
        case .currency: return CurrencyOption.all.contains { $0.id == currencyCode }
        }
    }

    mutating func advance(availableLanguages: [BudgetLanguage]) {
        guard canContinue(availableLanguages: availableLanguages), let next = step.next else { return }
        isMovingForward = true
        step = next
    }

    mutating func goBack() {
        guard let previous = step.previous else { return }
        isMovingForward = false
        step = previous
    }

    func completedPreferences(availableLanguages: [BudgetLanguage]) -> UserPreferences? {
        guard step.next == nil, canContinue(availableLanguages: availableLanguages),
              let language, let currencyCode else { return nil }
        return UserPreferences(currencyCode: currencyCode, speechLocaleIdentifier: language.speechLocaleIdentifier, appLanguageCode: language.rawValue)
    }
}
