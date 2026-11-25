import SwiftUI
import SwiftData

struct CategorySpendingView: View {
    @Environment(LedgerSession.self) private var session
    @Environment(PreferencesStore.self) private var preferences
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var entries: [LedgerEntry]
    @Query(sort: \ExpenseCategory.sortOrder) private var categories: [ExpenseCategory]
    @Query private var budgets: [MonthlyBudget]
    @Query private var accounts: [BudgetAccount]
    @State private var showsManager = false
    @State private var showsUnused = false
    private var code: String { session.currency ?? preferences.preferences?.currencyCode ?? "RON" }
    private var rows: [CategorySpendingSummary] { CategorySpendingSummary.rows(entries: entries, categories: categories, budgets: budgets, month: session.month, currency: code) }
    private var active: [CategorySpendingSummary] { rows.filter { $0.spent > 0 || $0.limit != nil } }
    private var unused: [CategorySpendingSummary] { rows.filter { $0.spent == 0 && $0.limit == nil } }
    private var motion: Animation? { reduceMotion ? nil : .smooth(duration: 0.4) }
    var body: some View {
        @Bindable var session = session
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                NotesTitle(title: "Categorii")
                NotesMonthButton(month: $session.month).padding(.top, 1)
                Text(tr("Cheltuit / Buget")).font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing).padding(.top, 16).padding(.bottom, 8)
                if rows.isEmpty {
                    ContentUnavailableView(tr("Fără categorii"), systemImage: "square.grid.2x2")
                    Button(tr("Categorie nouă")) { showsManager = true }.buttonStyle(.plain).foregroundStyle(BudgetStyle.accent)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(active.isEmpty ? rows : active) { row in categoryRow(row) }
                        if !active.isEmpty && !unused.isEmpty {
                            DisclosureGroup(tr("Fără cheltuieli"), isExpanded: $showsUnused) {
                                ForEach(unused) { row in categoryRow(row) }
                            }.font(.system(size: 14, weight: .medium, design: .rounded)).foregroundStyle(.secondary).padding(.top, 24)
                        }
                    }
                }
                Button(tr("Editează bugetele")) { session.sheet = .budgets(session.month, code) }
                    .font(.system(size: 16, weight: .semibold, design: .rounded)).buttonStyle(.plain).foregroundStyle(BudgetStyle.accent)
                    .frame(minHeight: 44).padding(.top, 30).accessibilityIdentifier("categories.budgets")
            }.frame(maxWidth: 520).padding(.horizontal, 28).padding(.top, 8).padding(.bottom, 30).frame(maxWidth: .infinity)
        }
        .background(BudgetStyle.background).navigationTitle("").navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar).toolbarRole(.editor)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(tr("Gestionează categoriile")) { showsManager = true }.accessibilityIdentifier("categories.manage")
                    Picker(tr("Moneda"), selection: Binding(get: { code }, set: { session.currency = $0 })) {
                        ForEach(Set(accounts.map(\.currencyCode) + [code]).sorted(), id: \.self) { Text($0).tag($0) }
                    }
                } label: { Image(systemName: "ellipsis").font(.system(size: 17, weight: .medium, design: .rounded)).foregroundStyle(.primary) }.accessibilityIdentifier("categories.menu")
            }
        }
        .sheet(isPresented: $showsManager) { CategoryManagerView() }
        .animation(motion, value: rows.map(\.spent)).animation(motion, value: rows.map(\.limit))
        .animation(motion, value: showsUnused)
    }
    private func categoryRow(_ row: CategorySpendingSummary) -> some View {
        NavigationLink {
            TransactionHistoryView(fixedCategoryKey: row.id, fixedCategoryTitle: row.systemKey == nil ? row.name : tr(row.name))
        } label: {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    Text(row.emoji).font(.system(size: 20, weight: .medium, design: .rounded)).frame(width: 25)
                    Text(row.systemKey == nil ? row.name : tr(row.name)).font(.system(size: 16, weight: .semibold, design: .rounded)).lineLimit(2)
                    Spacer(minLength: 6)
                    HStack(spacing: 3) {
                        Text(moneyNumber(row.spent, currency: code)).contentTransition(.numericText())
                        if let limit = row.limit {
                            Text("/ \(moneyNumber(limit, currency: code))").contentTransition(.numericText())
                        }
                        Text(moneyUnit(code))
                    }.font(.system(size: 14, weight: .medium, design: .rounded)).lineLimit(1).minimumScaleFactor(0.7)
                    Image(systemName: "chevron.right").font(.system(size: 10, weight: .medium, design: .rounded)).foregroundStyle(.tertiary)
                }
                if let limit = row.limit {
                    let usage = MonthlyBudgetProgress(spent: row.spent, limit: limit)
                    GeometryReader { proxy in
                        Capsule().fill(BudgetStyle.separator)
                            .overlay(alignment: .leading) {
                                Capsule().fill(usage.isExceeded ? Color.orange : BudgetStyle.accent)
                                    .frame(width: proxy.size.width * usage.fraction)
                            }
                    }.frame(height: 2).padding(.leading, 35).padding(.trailing, 18).accessibilityHidden(true)
                }
            }.padding(.vertical, 17).foregroundStyle(.primary).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityIdentifier("spending.category.\(row.name)")
            .accessibilityHint(tr("Vezi tranzacțiile categoriei"))
            .accessibilityValue(row.limit.map { limit in shortMoney(abs(limit - row.spent), currency: code) + " " + tr(row.spent > limit ? "peste buget" : "disponibili") } ?? tr("Fără limită stabilită"))
    }
}
