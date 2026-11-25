import SwiftUI
import SwiftData

struct MonthlyBudgetEditor: View {
    let month: Date
    let currency: String
    var categoryID: UUID?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(LedgerSession.self) private var session
    @Query private var budgets: [MonthlyBudget]
    @Query private var categories: [ExpenseCategory]
    @Query private var entries: [LedgerEntry]
    @State private var amount = ""
    @State private var loaded = false
    @State private var error: String?
    @FocusState private var editing: Bool
    private var category: ExpenseCategory? { categories.first { $0.id == categoryID } }
    private var budget: MonthlyBudget? {
        budgets.first { $0.monthKey == LedgerMath.monthKey(month) && $0.currencyCode == currency && $0.categoryID == categoryID }
    }
    private var spent: Decimal {
        LedgerMath.total(.expense, entries: entries.filter { categoryID == nil || $0.categoryID == categoryID }, month: month, currency: currency)
    }
    private var parsed: MoneyAmount? { MoneyAmount.parse(amount, currencyCode: currency) }

    var body: some View {
        ScrollView {
            VStack(spacing: 26) {
                VStack(spacing: 12) {
                    if let category { Text(category.emoji).font(.system(size: 40, weight: .medium, design: .rounded)).frame(height: 50) }
                    Text(displayDate(month, monthOnly: true)).font(.system(size: 13, weight: .medium, design: .rounded)).foregroundStyle(.secondary)
                    if let category {
                        Text(category.systemKey == nil ? category.name : tr(category.name)).font(.system(size: 20, weight: .medium, design: .rounded)).multilineTextAlignment(.center)
                    }
                }.padding(.top, 20)
                VStack(spacing: 8) {
                    Text(tr("Limita lunară")).font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(.secondary)
                    TextField("0", text: $amount).font(.system(size: 54, weight: .medium, design: .rounded))
                        .keyboardType(.decimalPad).multilineTextAlignment(.center).minimumScaleFactor(0.5).focused($editing)
                        .accessibilityLabel(tr("Limita lunară")).accessibilityIdentifier("budget.amount")
                    Text(currency).font(.system(size: 12, weight: .medium, design: .rounded)).tracking(1.5).foregroundStyle(BudgetStyle.accent)
                }.padding(.vertical, 14)
                VStack(alignment: .leading, spacing: 12) {
                    Text(tr("Cheltuit în această lună")).font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(.secondary)
                    BudgetUsageView(spent: spent, limit: parsed?.decimalValue, currency: currency)
                }.padding(20).budgetGlass().accessibilityIdentifier("budget.preview")
                Text(tr(categoryID == nil ? "Bugetul este separat de soldul conturilor și de venituri." : "Limita categoriei face parte din bugetul general. Se aplică doar lunii și monedei selectate."))
                    .font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(.secondary).multilineTextAlignment(.center).lineSpacing(3)
                if categoryID != nil && category == nil {
                    Text(tr("Categoria nu mai este disponibilă. Alege din nou.")).font(.footnote).foregroundStyle(.orange)
                }
            }.frame(maxWidth: 500).padding(24).frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively).background(BudgetStyle.background)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                if let error { Text(tr(error)).font(.footnote).foregroundStyle(.red).transition(.opacity) }
                Button(tr("Salvează bugetul"), action: save).buttonStyle(PrimaryButtonStyle())
                    .disabled(parsed == nil || (categoryID != nil && category == nil))
                    .opacity(parsed == nil ? 0.45 : 1).accessibilityIdentifier("budget.save")
                if let budget {
                    Button(tr("Elimină bugetul"), role: .destructive) {
                        context.delete(budget)
                        do {
                            try LedgerRepository.commit(context)
                            session.show(LedgerChange(message: "Buget eliminat")); dismiss()
                        } catch { self.error = "Nu am putut salva. Încearcă din nou." }
                    }.font(.footnote).frame(minHeight: 44).accessibilityIdentifier("budget.remove")
                }
            }.frame(maxWidth: 500).padding(.horizontal, 24).padding(.vertical, 12)
                .frame(maxWidth: .infinity).background(.ultraThinMaterial)
        }
        .navigationTitle(tr(categoryID == nil ? "Buget lunar" : "Buget categorie")).navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button(tr("Închide")) { dismiss() }.accessibilityIdentifier("budget.close") }
            ToolbarItemGroup(placement: .keyboard) { Spacer(); Button(tr("Gata")) { editing = false } }
        }
        .onAppear { if !loaded { loaded = true; amount = budget?.money.editableText() ?? "" } }
        .animation(reduceMotion ? nil : .smooth(duration: 0.4), value: error)
    }
    private func save() {
        guard let money = parsed else { return }
        do {
            try LedgerRepository.saveBudget(month: month, currency: currency, money: money, categoryID: categoryID, in: context)
            session.show(LedgerChange(message: "Buget salvat")); dismiss()
        } catch { self.error = (error as? LocalizedError)?.errorDescription ?? "Nu am putut salva. Încearcă din nou." }
    }
}
