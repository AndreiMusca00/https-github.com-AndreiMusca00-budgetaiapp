import Foundation

enum LedgerCategoryKey {
    static func of(_ entry: LedgerEntry) -> String {
        entry.categoryID?.uuidString ?? "snapshot:\(entry.categoryNameSnapshot):\(entry.categoryEmojiSnapshot)"
    }
}

struct CategorySpendingSummary: Identifiable {
    let id: String
    let categoryID: UUID?
    let name: String
    let emoji: String
    let systemKey: String?
    let spent: Decimal
    let limit: Decimal?
    let count: Int

    static func rows(entries: [LedgerEntry], categories: [ExpenseCategory], budgets: [MonthlyBudget], month: Date, currency: String) -> [Self] {
        guard let period = Calendar.current.dateInterval(of: .month, for: month) else { return [] }
        let expenses = entries.filter { $0.isConfirmed && $0.kind == .expense && $0.currencyCode == currency && $0.occurredAt >= period.start && $0.occurredAt < period.end }
        let groups = Dictionary(grouping: expenses, by: { LedgerCategoryKey.of($0) })
        let limits = budgets.filter { $0.monthKey == LedgerMath.monthKey(month) && $0.currencyCode == currency }
        var result = categories.filter { $0.kindRawValue == EntryKind.expense.rawValue }.map { category in
            let group = groups[category.id.uuidString] ?? []
            return Self(id: category.id.uuidString, categoryID: category.id, name: category.name, emoji: category.emoji,
                systemKey: category.systemKey, spent: group.reduce(0) { $0 + $1.money.decimalValue },
                limit: limits.first { $0.categoryID == category.id }?.money.decimalValue, count: group.count)
        }
        let known = Set(result.map(\.id))
        for (key, group) in groups where !known.contains(key) {
            guard let first = group.first else { continue }
            result.append(Self(id: key, categoryID: nil, name: first.categoryNameSnapshot, emoji: first.categoryEmojiSnapshot,
                systemKey: first.categorySystemKey, spent: group.reduce(0) { $0 + $1.money.decimalValue }, limit: nil, count: group.count))
        }
        return result.sorted { $0.spent == $1.spent ? $0.name.localizedStandardCompare($1.name) == .orderedAscending : $0.spent > $1.spent }
    }
}
