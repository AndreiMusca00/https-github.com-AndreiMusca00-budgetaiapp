import SwiftUI

struct HomeAccountsOverview: View {
    let rows: [AccountOverviewSummary]
    let currency: String
    let income: Decimal
    let month: Date
    let onIncome: () -> Void
    let onAccounts: () -> Void
    let onAccount: (UUID) -> Void
    private var totals: [String: Decimal] { AccountOverviewSummary.totals(rows) }
    private var otherBalances: String {
        totals.keys.filter { $0 != currency }.sorted().map { shortMoney(totals[$0] ?? 0, currency: $0) }.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 16) {
                Button(action: onAccounts) {
                    VStack(alignment: .leading, spacing: 7) {
                        Label(tr("Conturi"), systemImage: "wallet.bifold")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary).letterBounce(delay: 0.04)
                        Text(shortMoney(totals[currency] ?? 0, currency: currency))
                            .font(.system(size: 34, weight: .semibold, design: .rounded)).tracking(-1)
                            .foregroundStyle((totals[currency] ?? 0) < 0 ? Color.red : BudgetStyle.accent)
                            .lineLimit(1).minimumScaleFactor(0.5).contentTransition(.numericText())
                            .accessibilityIdentifier("home.accounts.total")
                        if !otherBalances.isEmpty {
                            Text(otherBalances).font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary).lineLimit(2)
                                .accessibilityIdentifier("home.accounts.otherCurrencies")
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityIdentifier("home.accounts.manage")
                Button(action: onIncome) {
                    VStack(alignment: .leading, spacing: 7) {
                        Label(tr("Încasări"), systemImage: "arrow.down.left")
                            .font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(.secondary)
                        Text("+" + shortMoney(income, currency: currency))
                            .font(.system(size: 19, weight: .semibold, design: .rounded)).foregroundStyle(BudgetStyle.accent)
                            .lineLimit(1).minimumScaleFactor(0.65).contentTransition(.numericText())
                            .accessibilityLabel(formattedMoney(income, currency: currency)).accessibilityIdentifier("home.received")
                        Text(monthLabel(month, year: false)).font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary).lineLimit(1)
                    }.frame(width: 112, alignment: .leading).contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityIdentifier("home.income")
                    .accessibilityLabel("\(tr("Încasări")), \(formattedMoney(income, currency: currency)), \(monthLabel(month))")
            }
            if !rows.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 10) {
                        ForEach(rows) { row in
                            Button { onAccount(row.id) } label: {
                                HomeAccountTile(row: row, month: month)
                            }.buttonStyle(.plain).accessibilityIdentifier("home.account.\(row.id)")
                        }
                    }.scrollTargetLayout().padding(.vertical, 4)
                }.scrollIndicators(.hidden).scrollClipDisabled().scrollTargetBehavior(.viewAligned)
                    .accessibilityIdentifier("home.accounts.carousel")
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .contain).accessibilityIdentifier("home.accounts.overview")
    }
}

private struct HomeAccountTile: View {
    let row: AccountOverviewSummary
    let month: Date
    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .center, spacing: 7) {
                Text(row.emoji.isEmpty ? "💳" : row.emoji).font(.system(size: 21))
                Text(row.name).font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary).lineLimit(2).minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }.frame(height: 34, alignment: .leading)
            Text(shortMoney(row.balance, currency: row.currency))
                .font(.system(size: 24, weight: .semibold, design: .rounded)).tracking(-0.5)
                .foregroundStyle(row.balance < 0 ? Color.red : BudgetStyle.accent)
                .lineLimit(1).minimumScaleFactor(0.6).contentTransition(.numericText())
                .accessibilityIdentifier("home.account.balance.\(row.id)")
        }.padding(14).frame(width: 160, alignment: .leading)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .accessibilityElement(children: .combine)
            .accessibilityValue("\(tr("Cheltuit")) · \(monthLabel(month, year: false)): \(shortMoney(row.spent, currency: row.currency))")
    }
}
