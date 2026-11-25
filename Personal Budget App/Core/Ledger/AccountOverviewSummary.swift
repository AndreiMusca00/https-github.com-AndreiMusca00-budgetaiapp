import Foundation

struct AccountOverviewSummary: Identifiable {
    let id: UUID
    let name: String
    let emoji: String
    let currency: String
    let balance: Decimal
    let spent: Decimal

    static func rows(accounts: [BudgetAccount], entries: [LedgerEntry], month: Date, asOf: Date) -> [Self] {
        accounts.filter { !$0.isArchived }.sorted {
            if $0.isDefault != $1.isDefault { return $0.isDefault }
            if $0.createdAt != $1.createdAt { return $0.createdAt < $1.createdAt }
            return $0.id.uuidString < $1.id.uuidString
        }.map { account in
            Self(id: account.id, name: account.name, emoji: account.emoji, currency: account.currencyCode,
                 balance: LedgerMath.balance(account: account, entries: entries, through: asOf),
                 spent: LedgerMath.total(.expense, entries: entries.filter { $0.accountID == account.id },
                                         month: month, currency: account.currencyCode))
        }
    }

    static func totals(_ rows: [Self]) -> [String: Decimal] {
        rows.reduce(into: [:]) { result, row in result[row.currency, default: 0] += row.balance }
    }
}
