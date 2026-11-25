import SwiftUI

struct HomeCategoryChart: View {
    let rows: [CategorySpendingSummary]
    let currency: String
    let period: String
    @Binding var visibleCategory: String?
    let onSelect: (CategorySpendingSummary) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var motion: Animation? { reduceMotion ? nil : .smooth(duration: 0.45) }
    private var maximum: Decimal { rows.first?.spent ?? 0 }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(rows) { row in column(row).id(row.id) }
                }.scrollTargetLayout()
            }
            .scrollIndicators(.hidden).scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $visibleCategory, anchor: .leading)
            .accessibilityLabel(tr("Cheltuieli pe categorii"))
            .accessibilityIdentifier("home.categoryChart")
            .onChange(of: period) { _, _ in
                guard let first = rows.first else { return }
                withAnimation(motion) { proxy.scrollTo(first.id, anchor: .leading) }
            }
        }
        .animation(motion, value: rows.map(\.spent))
        .animation(motion, value: rows.map(\.limit))
        .animation(motion, value: rows.map(\.id))
    }

    private func column(_ row: CategorySpendingSummary) -> some View {
        let name = row.systemKey == nil ? row.name : tr(row.name)
        let usage = MonthlyBudgetProgress(spent: row.spent, limit: row.limit)
        let fraction = maximum > 0 ? min(1, max(0, NSDecimalNumber(decimal: row.spent / maximum).doubleValue)) : 0
        let height = 84 * fraction
        return Button { onSelect(row) } label: {
            VStack(spacing: 6) {
                VStack(spacing: 5) {
                    Text(shortMoney(row.spent, currency: currency))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .lineLimit(1).minimumScaleFactor(0.65).contentTransition(.numericText())
                    BudgetGlassColumn(status: usage.status, height: height)
                }.frame(height: 106, alignment: .bottom)
                Text(row.emoji).font(.system(size: 20))
            }.frame(width: 64).foregroundStyle(.primary).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(name), \(shortMoney(row.spent, currency: currency)), \(row.count) \(tr("tranzacții"))")
        .accessibilityValue(budgetDescription(row, usage: usage))
        .accessibilityHint(tr("Vezi tranzacțiile categoriei"))
        .accessibilityIdentifier("home.chart.category.\(row.id)")
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    private func budgetDescription(_ row: CategorySpendingSummary, usage: MonthlyBudgetProgress) -> String {
        guard let limit = row.limit, limit > 0 else { return tr("Fără limită stabilită") }
        let remaining = limit - row.spent
        let amount = shortMoney(abs(remaining), currency: currency)
        switch usage.status {
        case .exceeded: return "\(tr("Buget depășit")): \(amount)"
        case .warning: return "\(tr("Aproape de limită")), \(tr("Buget rămas")): \(amount)"
        case .neutral: return "\(tr("Buget rămas")): \(amount)"
        }
    }
}
