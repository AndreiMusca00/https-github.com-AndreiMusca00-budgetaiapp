import SwiftUI

struct PreferencesEditor: View {
    enum Focus { case all, language }
    var focus: Focus = .all
    @Environment(PreferencesStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(LedgerSession.self) private var session
    @State private var currency: String?
    @State private var language: BudgetLanguage?
    @State private var showsCurrency = false
    @State private var loaded = false
    @State private var error: String?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Text(tr("Moneda principală")).font(.headline)
                Button { showsCurrency = true } label: {
                    HStack { Text(currency ?? "RON"); Spacer(); Image(systemName: "chevron.down") }
                        .padding(20).budgetGlass()
                }.buttonStyle(.plain).accessibilityIdentifier("preferences.currency")
                Text(tr("Limba aplicației")).font(.headline)
                LanguageDropdown(options: BudgetLanguage.allCases, displayLanguage: language ?? .english,
                                 selection: $language)
                Text(tr("Monedele tranzacțiilor existente rămân neschimbate."))
                    .font(.footnote).foregroundStyle(.secondary)
                if let error { Text(tr(error)).font(.footnote).foregroundStyle(.red) }
            }.frame(maxWidth: 500).padding(24).frame(maxWidth: .infinity)
        }
        .background(BudgetStyle.background).navigationTitle(tr("Preferințe")).navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button(tr("Salvează preferințele"), action: save).buttonStyle(PrimaryButtonStyle())
                .disabled(currency == nil || language == nil).padding(24).background(.ultraThinMaterial)
                .accessibilityIdentifier("preferences.save")
        }
        .sheet(isPresented: $showsCurrency) {
            PreferencePicker(title: tr("Moneda principală"),
                             options: CurrencyOption.all.map { PreferenceOption(id: $0.id, title: $0.name, subtitle: $0.id) },
                             selectedID: $currency, searchPrompt: tr("Caută"), closeTitle: tr("Închide"))
        }
        .onAppear {
            guard !loaded else { return }; loaded = true
            currency = store.preferences?.currencyCode ?? "RON"
            language = store.preferences?.appLanguage ?? .english
        }
    }
    private func save() {
        guard let currency, let language else { return }
        do {
            try store.save(UserPreferences(currencyCode: currency, speechLocaleIdentifier: language.speechLocaleIdentifier,
                                           appLanguageCode: language.rawValue))
            AppCopy.shared.language = language
            session.show(LedgerChange(message: "Preferințe salvate")); dismiss()
        } catch { self.error = "Nu am putut salva. Încearcă din nou." }
    }
}
