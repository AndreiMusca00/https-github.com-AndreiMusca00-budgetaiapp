import SwiftUI
import SwiftData

struct RecurringListView: View {
    var isModal = false
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(LedgerSession.self) private var session
    @Query(sort: \RecurrenceRule.nextDueDate) private var rules: [RecurrenceRule]
    @Query private var accounts: [BudgetAccount]
    @State private var editor: RuleEditorRoute?
    @State private var occurrence: OccurrenceRoute?
    @State private var deleteID: UUID?
    @State private var asksDelete = false
    @State private var error: String?

    var body: some View {
        List {
            ForEach([true, false], id: \.self) { active in
                let group = rules.filter { $0.isActive == active }
                if !group.isEmpty {
                    Section(tr(active ? "Programate" : "În pauză")) {
                        ForEach(group) { rule in
                            VStack(alignment: .leading, spacing: 14) {
                                HStack(spacing: 12) {
                                    Text(rule.categoryEmojiSnapshot).font(.system(size: 26))
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(rule.merchant.isEmpty ? tr(rule.categoryNameSnapshot) : rule.merchant)
                                            .font(.subheadline.weight(.semibold))
                                        Text("\(displayDate(rule.nextDueDate)) · \(tr(rule.frequency.title))")
                                            .font(.caption).foregroundStyle(.secondary)
                                        Text(accounts.first { $0.id == rule.accountID }?.name ?? tr("Cont"))
                                            .font(.caption2).foregroundStyle(.secondary)
                                    }
                                    Spacer(minLength: 6)
                                    Text(formattedMoney(rule.money.decimalValue, currency: rule.currencyCode))
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(rule.kind == .income ? BudgetStyle.accent : .primary)
                                    Menu {
                                        Button(tr("Editează")) { editor = RuleEditorRoute(id: rule.id) }
                                        Button(tr(rule.isActive ? "Pauză" : "Reia")) { toggle(rule) }
                                        if rule.isActive { Button(tr("Omite scadența")) { skip(rule) } }
                                        Button(tr("Șterge"), role: .destructive) { deleteID = rule.id; asksDelete = true }
                                    } label: { Image(systemName: "ellipsis").frame(width: 32, height: 44) }
                                    .accessibilityIdentifier("rule.menu.\(rule.merchant)")
                                }
                                if rule.isActive {
                                    Button(tr(rule.kind == .income ? "Confirmă încasarea" : "Confirmă plata")) {
                                        occurrence = OccurrenceRoute(ruleID: rule.id, date: rule.nextDueDate)
                                    }
                                    .font(.subheadline.weight(.medium)).buttonStyle(.bordered).tint(BudgetStyle.accent)
                                    .accessibilityIdentifier("rule.confirm.\(rule.merchant)")
                                }
                            }.padding(.vertical, 10).listRowBackground(BudgetStyle.card)
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden).background(BudgetStyle.background)
        .overlay {
            if rules.isEmpty {
                ContentUnavailableView(tr("Fără recurențe"), systemImage: "repeat",
                                       description: Text(tr("Planifică salariul, chiria sau abonamentele.")))
            }
        }
        .navigationTitle(tr("Recurente")).navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isModal { ToolbarItem(placement: .cancellationAction) { Button(tr("Gata")) { dismiss() } } }
            ToolbarItem(placement: .primaryAction) {
                Button { editor = RuleEditorRoute() } label: { Image(systemName: "plus") }
                    .accessibilityLabel(tr("Recurență nouă")).accessibilityIdentifier("rules.add")
            }
        }
        .sheet(item: $editor) { route in NavigationStack { RecurrenceEditorView(ruleID: route.ruleID) } }
        .fullScreenCover(item: $occurrence) { route in
            NavigationStack { LedgerEntryEditor(ruleID: route.ruleID, dueDate: route.date) }
        }
        .safeAreaInset(edge: .top, spacing: 0) { if isModal { LedgerToast() } }
        .confirmationDialog(tr("Ștergi recurența?"), isPresented: $asksDelete, titleVisibility: .visible) {
            Button(tr("Șterge"), role: .destructive) { deleteRule() }
        } message: { Text(tr("Tranzacțiile deja înregistrate rămân în istoric.")) }
        .alert(tr("Nu am putut salva. Încearcă din nou."), isPresented: Binding(
            get: { error != nil }, set: { if !$0 { error = nil } }
        )) { Button("OK", role: .cancel) { } } message: { Text(tr(error ?? "")) }
    }
    private func toggle(_ rule: RecurrenceRule) {
        do { try LedgerRepository.toggleRule(rule, in: context) }
        catch { self.error = (error as? LocalizedError)?.errorDescription ?? "Nu am putut salva. Încearcă din nou." }
    }
    private func skip(_ rule: RecurrenceRule) {
        do { session.show(try LedgerRepository.skipOccurrence(rule, in: context)) }
        catch { self.error = "Nu am putut salva. Încearcă din nou." }
    }
    private func deleteRule() {
        do {
            if let deleteID, let rule = try LedgerRepository.rule(deleteID, in: context) {
                try LedgerRepository.deleteRule(rule, in: context)
                session.show(LedgerChange(message: "Recurență ștearsă"))
            }
        } catch { self.error = "Nu am putut salva. Încearcă din nou." }
    }
}

private struct RuleEditorRoute: Identifiable {
    let id = UUID()
    var ruleID: UUID?
    init(id: UUID? = nil) { ruleID = id }
}
private struct OccurrenceRoute: Identifiable {
    let id = UUID()
    let ruleID: UUID
    let date: Date
}
