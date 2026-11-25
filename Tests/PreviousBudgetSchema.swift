import Foundation
import SwiftData

// Snapshot of MonthlyBudget before category limits. This is built in a separate process.
@Model final class MonthlyBudget {
    var id: UUID = UUID()
    var monthKey: String = ""
    var currencyCode: String = "RON"
    var fractionDigits: Int = 2
    var limitMinorUnits: Int64 = 0
    var updatedAt: Date = Date.now
    init() { }
}
@Model final class BudgetMetadata {
    var key: String = "initial-categories-v1"
    var createdAt: Date = Date.now
    init() { }
}

@main @MainActor struct PreviousBudgetFixture {
    static func main() throws {
        let url = URL(fileURLWithPath: CommandLine.arguments[1])
        let schema = Schema([Expense.self, ExpenseCategory.self, BudgetMetadata.self, BudgetAccount.self, LedgerEntry.self, RecurrenceRule.self, MonthlyBudget.self])
        let container = try ModelContainer(for: schema, configurations: [
            ModelConfiguration("Budget", schema: schema, url: url, cloudKitDatabase: .none)
        ])
        let context = container.mainContext
        let account = BudgetAccount(name: "Cont existent", emoji: "💳", currencyCode: "RON", openingMinorUnits: 12345)
        let category = ExpenseCategory(name: "Transport existent", emoji: "🚗", sortOrder: 0)
        context.insert(account); context.insert(category)
        let entry = LedgerEntry(); entry.accountID = account.id; entry.categoryID = category.id
        entry.categoryNameSnapshot = category.name; entry.amountMinorUnits = 18025; entry.merchant = "Tranzacție existentă"
        context.insert(entry)
        let budget = MonthlyBudget(); budget.monthKey = "2026-11"; budget.limitMinorUnits = 550025
        context.insert(budget); context.insert(BudgetMetadata())
        try context.save()
    }
}
