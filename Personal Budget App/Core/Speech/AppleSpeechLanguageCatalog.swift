import Foundation
import Observation
import Speech

@MainActor
@Observable
final class AppleSpeechLanguageCatalog {
    private(set) var languages: [SpeechLanguage] = []

    init() {
        refresh()
    }

    func refresh() {
        // Query Apple's real catalog; do not infer dictation support from UI languages.
        let identifiers = Set(SFSpeechRecognizer.supportedLocales().map {
            $0.identifier.replacingOccurrences(of: "_", with: "-")
        })
        let preferred = ["ro-RO", "en-US", "en-GB"]
        languages = identifiers.map { SpeechLanguage(id: $0) }.sorted {
            let left = preferred.firstIndex(of: $0.id) ?? preferred.count
            let right = preferred.firstIndex(of: $1.id) ?? preferred.count
            if left != right { return left < right }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    func contains(_ identifier: String) -> Bool {
        languages.contains { $0.id == identifier }
    }

    var appLanguages: [BudgetLanguage] {
        BudgetLanguage.allCases.filter { contains($0.speechLocaleIdentifier) }
    }

    func suggestedAppLanguage() -> BudgetLanguage? {
        BudgetLanguage.preferred(deviceLanguages: Locale.preferredLanguages, available: appLanguages)
    }
}
