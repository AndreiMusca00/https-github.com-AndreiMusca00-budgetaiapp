import SwiftUI
import SwiftData

struct BudgetPlanView: View {
    @State var month: Date
    @State var currency: String
    @Environment(PreferencesStore.self) private var preferences
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ExpenseCategory.sortOrder) private var categories: [ExpenseCategory]
    @Query private var budgets: [MonthlyBudget]
    @Query private var entries: [LedgerEntry]
    @Query private var accounts: [BudgetAccount]

    private var expenseCategories: [ExpenseCategory] { categories.filter { $0.kindRawValue == EntryKind.expense.rawValue } }
    private var monthBudgets: [MonthlyBudget] { budgets.filter { $0.monthKey == LedgerMath.monthKey(month) && $0.currencyCode == currency } }
    private var general: MonthlyBudget? { monthBudgets.first { $0.categoryID == nil } }
    private var allocated: Decimal { monthBudgets.filter { $0.categoryID != nil }.reduce(0) { $0 + $1.money.decimalValue } }
    private var currencies: [String] { Set(accounts.map(\.currencyCode) + budgets.map(\.currencyCode) + [currency]).sorted() }
    private func spent(categoryID: UUID? = nil) -> Decimal {
        LedgerMath.total(.expense, entries: entries.filter { categoryID == nil || $0.categoryID == categoryID }, month: month, currency: currency)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Button { moveMonth(-1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                        .accessibilityLabel(tr("Luna anterioară")).accessibilityIdentifier("budgets.previous")
                    Text(displayDate(month, monthOnly: true)).font(.subheadline.weight(.medium))
                        .contentTransition(.opacity).frame(maxWidth: .infinity)
                    Button { moveMonth(1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }
                        .accessibilityLabel(tr("Luna următoare")).accessibilityIdentifier("budgets.next")
                    Menu {
                        ForEach(currencies, id: \.self) { value in Button(value) { withAnimation(motion) { currency = value } } }
                    } label: { Text(currency).font(.caption.weight(.medium)).padding(.horizontal, 14).frame(height: 40).budgetGlass(in: Capsule()) }
                        .accessibilityIdentifier("budgets.currency")
                }.buttonStyle(.plain).foregroundStyle(.primary.opacity(0.75))

                NavigationLink {
                    MonthlyBudgetEditor(month: month, currency: currency)
                } label: {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text(tr("Buget general")).font(.system(size: 13, weight: .medium, design: .rounded))
                            Spacer()
                            Image(systemName: "slider.horizontal.3").font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(.secondary)
                        }
                        BudgetUsageView(spent: spent(), limit: general?.money.decimalValue, currency: currency)
                    }.padding(20).budgetGlass()
                }.buttonStyle(.plain).accessibilityIdentifier("budgets.general")

                VStack(alignment: .leading, spacing: 9) {
                    HStack {
                        Text(tr("Pe categorii")).font(.system(size: 18, weight: .medium, design: .rounded))
                        Spacer()
                        Text("\(orbitNumber(allocated, currency: currency)) \(currency)")
                            .font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(.secondary)
                            .contentTransition(.numericText()).accessibilityIdentifier("budgets.allocated")
                    }
                    if let general {
                        let difference = general.money.decimalValue - allocated
                        Text("\(orbitNumber(abs(difference), currency: currency)) \(currency) \(tr(difference < 0 ? "peste bugetul general" : "nealocați"))")
                            .font(.caption).foregroundStyle(difference < 0 ? Color.orange : .primary.opacity(0.45))
                            .contentTransition(.numericText()).accessibilityIdentifier("budgets.unallocated")
                    }
                }
                LazyVStack(spacing: 10) {
                    ForEach(expenseCategories) { category in
                        NavigationLink {
                            MonthlyBudgetEditor(month: month, currency: currency, categoryID: category.id)
                        } label: {
                            HStack(alignment: .top, spacing: 14) {
                                Text(category.emoji).font(.system(size: 25, weight: .medium, design: .rounded)).frame(width: 30).padding(.top, 2)
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        Text(category.systemKey == nil ? category.name : tr(category.name))
                                            .font(.system(size: 14, weight: .medium, design: .rounded)).lineLimit(2)
                                        Spacer(minLength: 8)
                                        Image(systemName: monthBudgets.contains { $0.categoryID == category.id } ? "slider.horizontal.3" : "plus")
                                            .font(.system(size: 11, weight: .medium, design: .rounded)).foregroundStyle(.secondary)
                                    }
                                    BudgetUsageView(spent: spent(categoryID: category.id),
                                        limit: monthBudgets.first { $0.categoryID == category.id }?.money.decimalValue,
                                        currency: currency, compact: true)
                                }
                            }.padding(18).budgetGlass()
                        }.buttonStyle(.plain).accessibilityIdentifier("budgets.category.\(category.name)")
                    }
                }
                if expenseCategories.isEmpty {
                    Text(tr("Adaugă o categorie din Setări pentru a-i stabili un buget.")).font(.footnote).foregroundStyle(.secondary)
                }
                Text(tr("Limitele sunt pentru luna selectată. Bugetul general rămâne limita totală; limitele categoriilor nu se adună la el."))
                    .font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(.primary.opacity(0.4)).lineSpacing(3)
            }.frame(maxWidth: 500).padding(24).frame(maxWidth: .infinity)
        }
        .background(BudgetStyle.background)
        .navigationTitle(tr("Bugete pe categorii")).navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button(tr("Gata")) { dismiss() }.accessibilityIdentifier("budgets.close") } }
        .animation(motion, value: LedgerMath.monthKey(month) + currency)
    }
    private var motion: Animation? { reduceMotion ? nil : .smooth(duration: 0.5) }
    private func moveMonth(_ offset: Int) {
        let start = Calendar.current.dateInterval(of: .month, for: month)?.start ?? month
        withAnimation(motion) { month = Calendar.current.date(byAdding: .month, value: offset, to: start) ?? start }
    }
}
