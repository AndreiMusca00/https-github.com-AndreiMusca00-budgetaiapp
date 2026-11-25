import SwiftUI

struct BudgetUsageView: View {
    let spent: Decimal
    let limit: Decimal?
    let currency: String
    var compact = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var usage: MonthlyBudgetProgress { .init(spent: spent, limit: limit) }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 12) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(formattedMoney(spent, currency: currency))
                    .font(.system(size: compact ? 15 : 20, weight: .medium))
                    .contentTransition(.numericText())
                if let limit {
                    Text("\(tr("din")) \(orbitNumber(limit, currency: currency))")
                        .font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }
                Spacer(minLength: 4)
            }
            if let remaining = usage.remaining {
                GeometryReader { proxy in
                    let width = proxy.size.width.isFinite ? max(0, proxy.size.width) : 0
                    Capsule().fill(.primary.opacity(0.07))
                        .overlay(alignment: .leading) {
                            Capsule().fill(usage.isExceeded ? Color.orange : BudgetStyle.accent.opacity(0.8))
                                .frame(width: width * usage.fraction)
                        }
                }.frame(height: 3).accessibilityHidden(true)
                HStack(spacing: 4) {
                    Text(orbitNumber(abs(remaining), currency: currency))
                        .contentTransition(.numericText())
                    Text(tr(usage.isExceeded ? "peste buget" : "disponibili"))
                }
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(usage.isExceeded ? Color.orange : .primary.opacity(0.5))
            } else {
                Text(tr("Fără limită stabilită")).font(.system(size: 11, weight: .medium, design: .rounded)).foregroundStyle(.secondary)
            }
        }
        .animation(reduceMotion ? nil : .smooth(duration: 0.5), value: spent)
        .animation(reduceMotion ? nil : .smooth(duration: 0.5), value: limit)
    }
}
