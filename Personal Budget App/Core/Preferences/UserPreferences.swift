import Foundation

struct UserPreferences: Codable, Equatable {
    let currencyCode: String
    let speechLocaleIdentifier: String
    var appLanguageCode: String?

    var appLanguage: BudgetLanguage {
        appLanguageCode.flatMap(BudgetLanguage.init(rawValue:)) ?? BudgetLanguage.matching(speechLocaleIdentifier) ?? .english
    }
    var locale: Locale { Locale(identifier: appLanguage.speechLocaleIdentifier) }

    var isValid: Bool {
        (appLanguageCode == nil || appLanguageCode.flatMap(BudgetLanguage.init(rawValue:)) != nil)
            && CurrencyOption.all.contains { $0.id == currencyCode }
            && speechLocaleIdentifier.range(
                of: "^[a-z]{2,3}(-[A-Za-z0-9]{2,8})*$",
                options: .regularExpression
            ) != nil
    }
}
