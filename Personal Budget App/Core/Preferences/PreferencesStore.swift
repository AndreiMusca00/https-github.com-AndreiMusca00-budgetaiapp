import Foundation
import Observation

@MainActor
@Observable
final class PreferencesStore {
    static let storageKey = "personalBudget.preferences.v1"

    private(set) var preferences: UserPreferences?
    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey),
           let saved = try? JSONDecoder().decode(UserPreferences.self, from: data),
           saved.isValid {
            preferences = saved
        }
    }

    func save(_ preferences: UserPreferences) throws {
        guard preferences.isValid else { throw ValidationError.invalidPreferences }
        // Save both choices together. The existence of a valid record completes onboarding.
        let data = try JSONEncoder().encode(preferences)
        defaults.set(data, forKey: Self.storageKey)
        self.preferences = preferences
    }

    enum ValidationError: Error {
        case invalidPreferences
    }
}
