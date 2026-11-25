import Foundation

struct CurrencyOption: Identifiable, Equatable {
    let id: String

    var name: String {
        Locale(identifier: "ro").localizedString(forCurrencyCode: id) ?? id
    }

    static let all: [CurrencyOption] = {
        let preferred = ["RON", "EUR", "USD", "GBP", "CHF"]
        return Locale.commonISOCurrencyCodes.map { CurrencyOption(id: $0) }.sorted {
            let left = preferred.firstIndex(of: $0.id) ?? preferred.count
            let right = preferred.firstIndex(of: $1.id) ?? preferred.count
            if left != right { return left < right }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }()

    static func formatted(_ amount: Decimal, preferences: UserPreferences) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = preferences.locale
        formatter.currencyCode = preferences.currencyCode
        return formatter.string(from: NSDecimalNumber(decimal: amount))
            ?? "\(amount) \(preferences.currencyCode)"
    }
}
