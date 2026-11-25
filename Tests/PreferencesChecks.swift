import Foundation

@main
@MainActor
struct PreferencesChecks {
    static func main() throws {
        let suite = "personalBudget.checks.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            fatalError("Could not create isolated UserDefaults suite")
        }
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = PreferencesStore(defaults: defaults)
        expect(store.preferences == nil, "A first launch must show onboarding")

        let romanian = UserPreferences(currencyCode: "RON", speechLocaleIdentifier: "ro-RO")
        try store.save(romanian)
        expect(store.preferences == romanian, "Saving must update the visible preferences")
        expect(defaults.data(forKey: PreferencesStore.storageKey) != nil, "Preferences must be stored in UserDefaults")

        let relaunched = PreferencesStore(defaults: defaults)
        expect(relaunched.preferences == romanian, "A new store must restore both choices and skip onboarding")

        let english = UserPreferences(currencyCode: "EUR", speechLocaleIdentifier: "en-GB")
        try relaunched.save(english)
        expect(PreferencesStore(defaults: defaults).preferences == english, "Settings must persist changes to both choices")

        do {
            try relaunched.save(UserPreferences(currencyCode: "INVALID", speechLocaleIdentifier: "ro-RO"))
            fatalError("An invalid currency must be rejected")
        } catch PreferencesStore.ValidationError.invalidPreferences { }
        expect(relaunched.preferences == english, "A rejected save must preserve the existing preferences")

        do {
            try relaunched.save(UserPreferences(currencyCode: "RON", speechLocaleIdentifier: ""))
            fatalError("An incomplete preference pair must be rejected")
        } catch PreferencesStore.ValidationError.invalidPreferences { }
        expect(PreferencesStore(defaults: defaults).preferences == english, "An incomplete save must not overwrite valid storage")

        defaults.set(Data("corrupted".utf8), forKey: PreferencesStore.storageKey)
        expect(PreferencesStore(defaults: defaults).preferences == nil, "Unreadable storage must return to onboarding without crashing")
        defaults.set(Data(#"{"currencyCode":"RON"}"#.utf8), forKey: PreferencesStore.storageKey)
        expect(PreferencesStore(defaults: defaults).preferences == nil, "A record without a language must not complete onboarding")
        defaults.set(try JSONEncoder().encode(UserPreferences(currencyCode: "INVALID", speechLocaleIdentifier: "ro-RO")), forKey: PreferencesStore.storageKey)
        expect(PreferencesStore(defaults: defaults).preferences == nil, "Decoded values must also be validated")

        let drafts = TransactionDraftStore(defaults: defaults)
        try drafts.save(text: "  85 de lei la Lidl ieri  ", preferences: romanian)
        expect(drafts.draft?.text == "85 de lei la Lidl ieri", "Drafts must trim whitespace")
        let restoredDraft = TransactionDraftStore(defaults: defaults).draft
        expect(restoredDraft == drafts.draft, "A draft must survive store recreation")
        expect(restoredDraft?.currencyCode == "RON", "Draft currency must retain its original context")
        expect(restoredDraft?.speechLocaleIdentifier == "ro-RO", "Draft language must retain its original context")
        try drafts.save(text: "  \n ", preferences: english)
        expect(drafts.draft == restoredDraft, "An empty save must not erase an existing draft")

        let formatted = CurrencyOption.formatted(1234.5, preferences: english)
        expect(formatted.contains("1,234.50"), "Home formatting must use the preferred locale")
        expect(formatted.contains("€") || formatted.contains("EUR"), "Home formatting must use the preferred currency")
        expect(Set(CurrencyOption.all.map(\.id)).count == CurrencyOption.all.count, "Currency choices must be unique")
        expect(!SpeechLanguage(id: "ro-RO").name.isEmpty, "Speech preferences need readable labels")

        let available = BudgetLanguage.allCases
        expect(available.count == 2, "This release offers only Romanian and English")
        expect(BudgetLanguage.preferred(deviceLanguages: ["ro-RO", "en-US"], available: available) == .romanian,
               "Romanian phone language must be selected first")
        expect(BudgetLanguage.preferred(deviceLanguages: ["en-US", "ro-RO"], available: available) == .english,
               "English must follow phone language, independently of the phone region")
        expect(BudgetLanguage.preferred(deviceLanguages: ["en_AU"], available: available) == .english,
               "Regional English variants must map to the single English choice")
        expect(BudgetLanguage.preferred(deviceLanguages: ["fr-FR", "ro-RO"], available: available) == .romanian,
               "The next supported preferred phone language must be respected")
        expect(BudgetLanguage.preferred(deviceLanguages: ["de-DE"], available: available) == .english,
               "An unsupported phone language must fall back predictably to English")
        expect(BudgetLanguage.preferred(deviceLanguages: ["en-US"], available: [.romanian]) == .romanian,
               "A language not reported by Apple must not be suggested")
        expect(BudgetLanguage.preferred(deviceLanguages: ["ro-RO"], available: []) == nil,
               "An empty Apple catalog must not create an unsupported choice")

        var flow = OnboardingFlow()
        flow.currencyCode = "EUR"
        flow.advance(availableLanguages: available)
        expect(flow.step == .language, "A missing language must block advancing")
        flow.language = .romanian
        expect(flow.completedPreferences(availableLanguages: available) == nil,
               "Language selection alone must never complete onboarding or save partial preferences")
        flow.advance(availableLanguages: available)
        expect(flow.step == .currency, "A supported language must allow the currency step")
        expect(flow.completedPreferences(availableLanguages: available)
               == UserPreferences(currencyCode: "EUR", speechLocaleIdentifier: "ro-RO", appLanguageCode: "ro"),
               "Completion must preserve the selected speech language and independent currency")
        flow.goBack()
        expect(flow.language == .romanian && flow.currencyCode == "EUR", "Going back must preserve both choices")
        flow.language = .english
        flow.advance(availableLanguages: available)
        expect(flow.completedPreferences(availableLanguages: available)?.speechLocaleIdentifier == "en-GB",
               "The United Kingdom flag must correspond to the actual British English locale")
        flow.currencyCode = "INVALID"
        expect(flow.completedPreferences(availableLanguages: available) == nil, "An invalid currency must block completion")
        flow.currencyCode = "RON"
        expect(flow.completedPreferences(availableLanguages: []) == nil, "Lost Apple support must block completion")

        var transcript = DictationTranscript()
        transcript.beginSession()
        transcript.updatePartial("85")
        transcript.updatePartial("85 de lei")
        transcript.updatePartial("  85 de lei la Lidl.  ")
        expect(transcript.text == "85 de lei la Lidl.", "Partial results must replace earlier hypotheses, not duplicate them")
        transcript.finishSession()
        expect(transcript.text == "85 de lei la Lidl.", "Stopping must retain the latest recognized words")
        transcript.beginSession()
        transcript.updatePartial("Și 20")
        transcript.updatePartial("Și 20 de lei cafeaua.")
        expect(transcript.text == "85 de lei la Lidl. Și 20 de lei cafeaua.", "A new recording must append once to previous text")
        transcript.finishSession()
        transcript.finishSession()
        expect(transcript.text == "85 de lei la Lidl. Și 20 de lei cafeaua.", "Repeated cleanup must not duplicate recognized text")
        transcript.beginSession()
        transcript.finishSession()
        expect(transcript.text == "85 de lei la Lidl. Și 20 de lei cafeaua.", "An empty recording must preserve previous text")
        transcript.clear()
        expect(transcript.text.isEmpty, "Clearing must remove both partial and committed text")

        expect(VoiceLevel.normalized(rms: 0) == 0, "Silence must not animate as speech")
        expect(VoiceLevel.normalized(rms: .nan) == 0, "Invalid samples must not poison mesh coordinates")
        expect(VoiceLevel.normalized(rms: .infinity) == 0, "Infinite samples must be rejected")
        expect(VoiceLevel.normalized(rms: -1) == 0, "Negative RMS values must be rejected")
        expect(VoiceLevel.normalized(rms: 0.001) == 0, "Very quiet input must stay below the visual noise floor")
        expect(VoiceLevel.normalized(rms: 0.1) > VoiceLevel.normalized(rms: 0.01), "Louder speech must produce stronger motion")
        expect(VoiceLevel.normalized(rms: 1) == 1, "Clipped input must stay within the mesh's safe range")
        let attack = VoiceLevel.smoothed(previous: 0, input: 1)
        let release = VoiceLevel.smoothed(previous: attack, input: 0)
        expect(attack > 0 && attack < 1, "Voice onset must be smoothed")
        expect(release > 0 && release < attack, "The glow must decay smoothly rather than snap off")
        expect(VoiceLevel.smoothed(previous: .nan, input: .infinity).isFinite, "Invalid envelope values must recover to a finite level")

        print("Passed: preferences, dictation transcript handling, voice sensitivity, noise floor and audio envelope smoothing.")
    }

    private static func expect(_ value: @autoclosure () -> Bool, _ message: String) {
        guard value() else { fatalError(message) }
    }
}
