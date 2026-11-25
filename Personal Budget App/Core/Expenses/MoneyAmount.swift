import Foundation

/// Exact currency amounts. The scale is stored with each expense, never inferred from a new preference.
struct MoneyAmount: Equatable {
    let minorUnits: Int64
    let fractionDigits: Int

    var decimalValue: Decimal {
        Decimal(minorUnits) / Self.scale(fractionDigits)
    }

    static func fractionDigits(for currencyCode: String) -> Int {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        return formatter.maximumFractionDigits
    }

    static func parse(_ text: String, currencyCode: String) -> MoneyAmount? {
        guard CurrencyOption.all.contains(where: { $0.id == currencyCode }) else { return nil }
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // A single comma or period is a decimal separator. Ambiguous grouping is rejected.
        guard value.range(of: #"^(?:[0-9]+(?:[.,][0-9]+)?|[.,][0-9]+)$"#, options: .regularExpression) != nil else { return nil }
        let normalized = value.replacingOccurrences(of: ",", with: ".")
        let digits = fractionDigits(for: currencyCode)
        let enteredDigits = normalized.split(separator: ".", omittingEmptySubsequences: false).dropFirst().first?.count ?? 0
        guard enteredDigits <= digits,
              let decimal = Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX")),
              decimal > 0 else { return nil }
        let minor = decimal * scale(digits)
        guard minor <= Decimal(Int64.max) else { return nil }
        return MoneyAmount(minorUnits: NSDecimalNumber(decimal: minor).int64Value, fractionDigits: digits)
    }

    func editableText(locale: Locale = .current) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = fractionDigits
        return formatter.string(from: NSDecimalNumber(decimal: decimalValue)) ?? "\(decimalValue)"
    }

    func formatted(currencyCode: String, locale: Locale) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.minimumFractionDigits = fractionDigits
        formatter.maximumFractionDigits = fractionDigits
        return formatter.string(from: NSDecimalNumber(decimal: decimalValue)) ?? "\(decimalValue) \(currencyCode)"
    }

    private static func scale(_ digits: Int) -> Decimal {
        (0..<max(0, digits)).reduce(Decimal(1)) { value, _ in value * 10 }
    }
}
