import Foundation
import Observation

struct TransactionDraft: Codable, Equatable {
    let text: String
    let currencyCode: String
    let speechLocaleIdentifier: String
    let updatedAt: Date
}

@MainActor
@Observable
final class TransactionDraftStore {
    static let storageKey = "personalBudget.transactionDraft.v1"

    private(set) var draft: TransactionDraft?
    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey) {
            draft = try? JSONDecoder().decode(TransactionDraft.self, from: data)
        }
    }

    func save(text: String, preferences: UserPreferences) throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let draft = TransactionDraft(
            text: trimmed,
            currencyCode: preferences.currencyCode,
            speechLocaleIdentifier: preferences.speechLocaleIdentifier,
            updatedAt: .now
        )
        defaults.set(try JSONEncoder().encode(draft), forKey: Self.storageKey)
        self.draft = draft
    }
}
