import SwiftUI
import SwiftData

struct AccountEditorView: View {
    var accountID: UUID?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(PreferencesStore.self) private var preferences
    @Environment(LedgerSession.self) private var session
    @State private var name = ""
    @State private var emoji = "🏦"
    @State private var currency = "RON"
    @State private var opening = ""
    @State private var isDefault = false
    @State private var isArchived = false
    @State private var currencyLocked = false
    @State private var loaded = false
    @State private var error: String?
    @State private var showsCurrency = false
    @State private var asksDelete = false
    private let emojis = ["🏦", "💵", "🐷", "💳", "💼", "🌍"]

    var body: some View {
        Form {
            Section {
                HStack {
                    ForEach(emojis, id: \.self) { option in
                        Button { emoji = option } label: {
                            Text(option).font(.system(size: 26)).frame(maxWidth: .infinity, minHeight: 44)
                                .background(emoji == option ? BudgetStyle.accent.opacity(0.15) : .clear,
                                            in: RoundedRectangle(cornerRadius: 12))
                        }.buttonStyle(.plain)
                    }
                }
                TextField(tr("Numele contului"), text: $name).accessibilityIdentifier("account.name")
                Button { showsCurrency = true } label: {
                    HStack { Text(tr("Moneda")); Spacer(); Text(currency).foregroundStyle(.secondary) }
                }.disabled(currencyLocked).accessibilityIdentifier("account.currency")
                TextField(tr("Sold inițial"), text: $opening).keyboardType(.numbersAndPunctuation)
                    .accessibilityIdentifier("account.opening")
                Toggle(tr("Cont implicit"), isOn: $isDefault).accessibilityIdentifier("account.default")
            } footer: {
                Text(tr("Soldul inițial reprezintă banii de la începutul evidenței, înainte de tranzacțiile introduse aici."))
            }
            .listRowBackground(BudgetStyle.card)
            if accountID != nil {
                Section {
                    Button(tr(isArchived ? "Reactivează" : "Arhivează"), action: archive)
                        .accessibilityIdentifier("account.archive")
                    if !currencyLocked {
                        Button(tr("Șterge"), role: .destructive) { asksDelete = true }
                            .accessibilityIdentifier("account.delete")
                    }
                } footer: { Text(tr("Arhivarea păstrează istoricul și soldul.")) }
                .listRowBackground(BudgetStyle.card)
            }
        }
        .scrollContentBackground(.hidden).background(BudgetStyle.background)
        .navigationTitle(tr(accountID == nil ? "Cont nou" : "Editează contul"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button(tr("Închide")) { dismiss() } } }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                if let error { Text(tr(error)).font(.footnote).foregroundStyle(.red) }
                Button(tr("Salvează contul"), action: save).buttonStyle(PrimaryButtonStyle())
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              MoneyAmount.parseBalance(opening, currencyCode: currency) == nil)
                    .accessibilityIdentifier("account.save")
            }.padding(24).background(.ultraThinMaterial)
        }
        .sheet(isPresented: $showsCurrency) {
            PreferencePicker(title: tr("Alege moneda"),
                             options: CurrencyOption.all.map { PreferenceOption(id: $0.id, title: $0.name, subtitle: $0.id) },
                             selectedID: Binding(get: { currency }, set: { currency = $0 ?? currency }),
                             searchPrompt: tr("Caută"), closeTitle: tr("Închide"))
        }
        .confirmationDialog(tr("Ștergi contul?"), isPresented: $asksDelete, titleVisibility: .visible) {
            Button(tr("Șterge"), role: .destructive, action: delete)
        }
        .onAppear(perform: load)
    }
    private func load() {
        guard !loaded else { return }; loaded = true
        currency = preferences.preferences?.currencyCode ?? "RON"
        guard let accountID else { return }
        do {
            let account = try LedgerRepository.account(accountID, in: context)
            name = account.name; emoji = account.emoji; currency = account.currencyCode
            opening = MoneyAmount(minorUnits: account.openingMinorUnits, fractionDigits: account.fractionDigits).editableText()
            isDefault = account.isDefault; isArchived = account.isArchived
            currencyLocked = try LedgerRepository.accountIsUsed(accountID, in: context)
        } catch { self.error = "Alege un cont disponibil." }
    }
    private func save() {
        guard let money = MoneyAmount.parseBalance(opening, currencyCode: currency) else { return }
        do {
            let existing = try accountID.map { try LedgerRepository.account($0, in: context) }
            try LedgerRepository.saveAccount(existing, name: name, emoji: emoji, currency: currency,
                                              opening: money, isDefault: isDefault, in: context)
            session.show(LedgerChange(message: "Cont salvat")); dismiss()
        } catch { self.error = (error as? LocalizedError)?.errorDescription ?? "Nu am putut salva. Încearcă din nou." }
    }
    private func archive() {
        guard let accountID else { return }
        do {
            let account = try LedgerRepository.account(accountID, in: context)
            try LedgerRepository.archiveAccount(account, in: context)
            session.show(LedgerChange(message: account.isArchived ? "Cont arhivat" : "Cont reactivat")); dismiss()
        } catch { self.error = "Nu am putut salva. Încearcă din nou." }
    }
    private func delete() {
        guard let accountID else { return }
        do {
            try LedgerRepository.deleteAccount(LedgerRepository.account(accountID, in: context), in: context)
            session.show(LedgerChange(message: "Cont șters")); dismiss()
        } catch { self.error = (error as? LocalizedError)?.errorDescription ?? "Nu am putut salva. Încearcă din nou." }
    }
}
