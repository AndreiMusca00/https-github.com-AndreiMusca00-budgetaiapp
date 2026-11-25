import SwiftUI
import SwiftData

struct RecurrenceEditorView: View {
    var ruleID: UUID?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(LedgerSession.self) private var session
    @Query(sort: \BudgetAccount.createdAt) private var accounts: [BudgetAccount]
    @State private var draft = EntryDraft()
    @State private var frequency: RepeatFrequency = .monthly
    @State private var interval = 1
    @State private var lastDay = false
    @State private var hasEnd = false
    @State private var end = Calendar.current.date(byAdding: .year, value: 1, to: .now)!
    @State private var loaded = false
    @State private var missing = false
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                LedgerEntryFields(draft: $draft, accounts: accounts.filter { !$0.isArchived || $0.id == draft.accountID },
                                  allowsKindChange: true, allowsFuture: true)
                VStack(spacing: 16) {
                    Picker(tr("Frecvență"), selection: $frequency) {
                        ForEach(RepeatFrequency.allCases) { Text(tr($0.title)).tag($0) }
                    }.accessibilityIdentifier("rule.frequency")
                    Stepper("\(tr("Frecvență")) · \(interval) × \(tr(frequency.title))", value: $interval, in: 1...365)
                    if frequency == .monthly { Toggle(tr("Ultima zi a lunii"), isOn: $lastDay) }
                    Toggle(tr("Dată de încheiere"), isOn: $hasEnd)
                    if hasEnd { DatePicker(tr("Dată de încheiere"), selection: $end, in: draft.date..., displayedComponents: .date) }
                }
                .font(.subheadline).padding(18).budgetGlass()
                Text(tr("Programarea nu modifică soldul. Confirmă plata sau încasarea când are loc."))
                    .font(.footnote).foregroundStyle(.secondary)
            }.frame(maxWidth: 500).padding(24).frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively).background(BudgetStyle.background)
        .navigationTitle(tr(ruleID == nil ? "Recurență nouă" : "Editează recurența"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button(tr("Închide")) { dismiss() } } }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                if let error { Text(tr(error)).font(.footnote).foregroundStyle(.red) }
                Button(tr("Salvează"), action: save).buttonStyle(PrimaryButtonStyle())
                    .disabled(draft.input(accounts: accounts) == nil || missing)
                    .accessibilityIdentifier("rule.save")
            }.padding(24).background(.ultraThinMaterial)
        }
        .onAppear(perform: load)
    }
    private func load() {
        guard !loaded else { return }; loaded = true
        draft.accountID = accounts.first(where: { $0.isDefault && !$0.isArchived })?.id
            ?? accounts.first(where: { !$0.isArchived })?.id
        guard let ruleID else { return }
        do {
            guard let rule = try LedgerRepository.rule(ruleID, in: context) else { missing = true; return }
            draft.kind = rule.kind; draft.amount = rule.money.editableText(); draft.accountID = rule.accountID
            draft.categoryID = rule.categoryID; draft.merchant = rule.merchant; draft.note = rule.note
            draft.date = rule.nextDueDate; frequency = rule.frequency; interval = rule.interval
            lastDay = rule.usesLastDay; hasEnd = rule.endDate != nil; end = rule.endDate ?? end
        } catch { missing = true; self.error = "Nu am putut salva. Încearcă din nou." }
    }
    private func save() {
        guard let input = draft.input(accounts: accounts) else { return }
        do {
            let existing = try ruleID.flatMap { try LedgerRepository.rule($0, in: context) }
            if ruleID != nil && existing == nil { throw LedgerRepository.Failure.invalidRecurrence }
            try LedgerRepository.saveRule(existing, input: input, frequency: frequency, interval: interval,
                                           nextDue: draft.date, end: hasEnd ? end : nil,
                                           lastDay: frequency == .monthly && lastDay, in: context)
            session.show(LedgerChange(message: "Recurență salvată")); dismiss()
        } catch { self.error = (error as? LocalizedError)?.errorDescription ?? "Nu am putut salva. Încearcă din nou." }
    }
}
