import SwiftUI
import SwiftData

struct LedgerEntryEditor: View {
    var entryID: UUID?
    var initialKind: EntryKind = .expense
    var ruleID: UUID?
    var dueDate: Date?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(PreferencesStore.self) private var preferences
    @Environment(LedgerSession.self) private var session
    @Query(sort: \BudgetAccount.createdAt) private var allAccounts: [BudgetAccount]
    @State private var draft = EntryDraft()
    @State private var loaded = false
    @State private var wasPending = false
    @State private var isRecurringEntry = false
    @State private var originalText: String?
    @State private var missing = false
    @State private var saving = false
    @State private var error: String?
    @State private var asksDelete = false
    @State private var showsAccountEditor = false
    @State private var originalAccountID: UUID?
    @State private var originalDestinationID: UUID?
    private var accounts: [BudgetAccount] {
        allAccounts.filter { !$0.isArchived || $0.id == originalAccountID || $0.id == originalDestinationID }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                if missing {
                    ContentUnavailableView(tr("Tranzacția nu mai este disponibilă."), systemImage: "doc.questionmark")
                } else if accounts.isEmpty {
                    ContentUnavailableView(tr("Fără conturi"), systemImage: "wallet.bifold",
                                           description: Text(tr("Adaugă primul cont pentru a înregistra tranzacții.")))
                    Button(tr("Cont nou")) { showsAccountEditor = true }.buttonStyle(PrimaryButtonStyle())
                } else {
                    if let originalText, !originalText.isEmpty {
                        VStack(alignment: .leading, spacing: 7) {
                            Text(tr("Textul original")).font(.caption).foregroundStyle(.secondary)
                            Text(originalText).font(.body).textSelection(.enabled)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                    LedgerEntryFields(draft: $draft, accounts: accounts, allowsKindChange: (entryID == nil && ruleID == nil) || wasPending,
                                      autofocusAmount: entryID == nil && ruleID == nil,
                                      allowsRecurrence: entryID == nil && ruleID == nil)
                    if ruleID != nil {
                        Text(tr("Programarea nu modifică soldul. Confirmă plata sau încasarea când are loc."))
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    if isRecurringEntry {
                        Text(tr("Modificarea afectează doar această tranzacție."))
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                if let error { Text(tr(error)).font(.footnote).foregroundStyle(.red).accessibilityIdentifier("entry.error") }
                if entryID != nil && !missing {
                    Button(tr("Șterge"), role: .destructive) { asksDelete = true }
                        .font(.system(size: 13, weight: .medium, design: .rounded)).frame(minHeight: 36)
                        .accessibilityIdentifier("entry.delete")
                }
            }.frame(maxWidth: 500).padding(.horizontal, 28).padding(.top, 14).padding(.bottom, 24).frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively).background(BudgetStyle.background.ignoresSafeArea())
        .navigationTitle(tr(ruleID != nil ? (draft.kind == .income ? "Confirmă încasarea" : "Confirmă plata") :
                                entryID == nil ? "" : wasPending ? "De verificat" : "Editează tranzacția"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button { dismiss() } label: { Image(systemName: "xmark").font(.system(size: 14, weight: .medium)) }
                    .accessibilityLabel(tr("Închide")).accessibilityIdentifier("entry.close")
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(action: save) {
                    Image(systemName: "checkmark").font(.system(size: 15, weight: .semibold))
                }
                .buttonStyle(.glassProminent).tint(BudgetStyle.accent)
                .disabled(draft.input(accounts: accounts, requiresDescription: true) == nil || saving || missing)
                .accessibilityLabel(tr(ruleID == nil ? wasPending ? "Confirmă" : "Salvează" : "Înregistrează"))
                .accessibilityIdentifier("entry.save")
            }
        }
        .confirmationDialog(tr("Ștergi tranzacția?"), isPresented: $asksDelete, titleVisibility: .visible) {
            Button(tr("Șterge"), role: .destructive, action: delete)
        } message: { Text(tr("Poți anula ștergerea din banner.")) }
        .sheet(isPresented: $showsAccountEditor) { NavigationStack { AccountEditorView() } }
        .onAppear(perform: load)
        .onChange(of: allAccounts.count) { _, _ in
            if draft.accountID == nil { chooseAccount() }
        }
    }

    private func chooseAccount() {
        draft.accountID = accounts.first(where: { $0.isDefault && !$0.isArchived })?.id
            ?? accounts.first(where: { $0.currencyCode == preferences.preferences?.currencyCode && !$0.isArchived })?.id
            ?? accounts.first(where: { !$0.isArchived })?.id
    }
    private func load() {
        guard !loaded else { return }
        loaded = true; draft.kind = initialKind
        do {
            if let entryID {
                guard let entry = try LedgerRepository.entry(entryID, in: context) else { missing = true; return }
                wasPending = !entry.isConfirmed; originalText = entry.originalText; isRecurringEntry = entry.recurrenceRuleID != nil
                draft.kind = entry.kind; draft.amount = !entry.isConfirmed && entry.amountMinorUnits == 0 ? "" : entry.money.editableText()
                draft.accountID = entry.accountID; draft.destinationID = entry.destinationAccountID
                draft.receivedAmount = entry.receivedMoney?.editableText() ?? ""
                draft.categoryID = entry.categoryID; draft.merchant = entry.merchant
                draft.note = entry.note; draft.date = entry.occurredAt
                originalAccountID = entry.accountID; originalDestinationID = entry.destinationAccountID
            } else if let ruleID {
                guard let rule = try LedgerRepository.rule(ruleID, in: context) else { missing = true; return }
                draft.kind = rule.kind; draft.amount = rule.money.editableText(); draft.accountID = rule.accountID
                draft.categoryID = rule.categoryID; draft.merchant = rule.merchant; draft.note = rule.note
                draft.date = .now
            } else { chooseAccount() }
        } catch { self.error = "Nu am putut salva. Încearcă din nou."; missing = true }
    }
    private func save() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        guard !saving, let input = draft.input(accounts: accounts, requiresDescription: true) else { return }
        saving = true
        do {
            let change: LedgerChange
            if let ruleID, let dueDate, let rule = try LedgerRepository.rule(ruleID, in: context) {
                change = try LedgerRepository.confirmOccurrence(rule: rule, dueDate: dueDate, input: input, in: context)
            } else if ruleID != nil { throw LedgerRepository.Failure.alreadyHandled }
            else {
                change = try LedgerRepository.saveEntry(id: entryID, input: input,
                                                         repeatFrequency: draft.repeatFrequency, in: context)
            }
            session.show(change); dismiss()
        } catch { self.error = (error as? LocalizedError)?.errorDescription ?? "Nu am putut salva. Încearcă din nou."; saving = false }
    }
    private func delete() {
        guard !saving, let entryID else { return }
        do {
            if let entry = try LedgerRepository.entry(entryID, in: context) {
                session.show(try LedgerRepository.deleteEntry(entry, in: context))
            }
            dismiss()
        } catch { self.error = "Nu am putut salva. Încearcă din nou." }
    }
}
