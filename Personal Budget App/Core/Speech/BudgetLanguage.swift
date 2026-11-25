import Foundation

/// The product's supported languages, independently of Apple's larger speech catalog.
enum BudgetLanguage: String, CaseIterable, Identifiable {
    case romanian = "ro"
    case english = "en"

    var id: String { rawValue }
    var speechLocaleIdentifier: String { self == .romanian ? "ro-RO" : "en-GB" }
    var flag: String { self == .romanian ? "🇷🇴" : "🇬🇧" }

    func countryName(in displayLanguage: BudgetLanguage) -> String {
        switch (self, displayLanguage) {
        case (.romanian, .romanian): "România"
        case (.romanian, .english): "Romania"
        case (.english, .romanian): "Regatul Unit"
        case (.english, .english): "United Kingdom"
        }
    }

    var accessibilityName: String {
        self == .romanian ? "Română, România" : "English, United Kingdom"
    }

    static func matching(_ localeIdentifier: String) -> BudgetLanguage? {
        let code = localeIdentifier.replacingOccurrences(of: "_", with: "-")
            .split(separator: "-").first.map(String.init)?.lowercased()
        return code.flatMap(Self.init(rawValue:))
    }

    static func preferred(deviceLanguages: [String], available: [BudgetLanguage]) -> BudgetLanguage? {
        for identifier in deviceLanguages {
            if let language = matching(identifier), available.contains(language) { return language }
        }
        return available.contains(.english) ? .english : available.first
    }
}
