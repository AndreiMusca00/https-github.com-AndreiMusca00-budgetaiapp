import SwiftUI

struct HomeAccountFocusSummary: View {
    let account: AccountOverviewSummary
    let month: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 10) {
                Text(account.emoji.isEmpty ? "💳" : account.emoji).font(.system(size: 30))
                    .letterBounce(delay: 0.08).accessibilityHidden(true)
                Text(account.name).font(.system(size: 20, weight: .semibold, design: .rounded))
                    .lineLimit(2).letterBounce(delay: 0.12).accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("home.accountFocus.title")
                Spacer(minLength: 0)
                Text(account.currency).font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            HStack(alignment: .bottom, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(tr("Sold actual")).font(.system(size: 11, weight: .medium, design: .rounded)).foregroundStyle(.secondary)
                    Text(shortMoney(account.balance, currency: account.currency))
                        .font(.system(size: 34, weight: .semibold, design: .rounded)).tracking(-1)
                        .foregroundStyle(account.balance < 0 ? Color.red : BudgetStyle.accent)
                        .lineLimit(1).minimumScaleFactor(0.5).contentTransition(.numericText())
                        .letterBounce(delay: 0.18).accessibilityIdentifier("home.accountFocus.balance")
                }.frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .trailing, spacing: 6) {
                    Text(tr("Cheltuieli")).font(.system(size: 11, weight: .medium, design: .rounded)).foregroundStyle(.secondary)
                    Text(shortMoney(account.spent, currency: account.currency))
                        .font(.system(size: 21, weight: .semibold, design: .rounded))
                        .lineLimit(1).minimumScaleFactor(0.6).contentTransition(.numericText())
                        .accessibilityIdentifier("home.accountFocus.spent")
                    Text(monthLabel(month, year: false)).font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary).contentTransition(.opacity)
                }.frame(maxWidth: .infinity, alignment: .trailing)
                    .modifier(HomeCascadeReveal(delay: 0.18))
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
