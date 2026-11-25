import Foundation
import SwiftData

// The prototype's original on-disk schema. Compile separately to test a genuine upgrade.
@Model final class Expense {
    var id: UUID = UUID()
    var amountMinorUnits: Int64 = 0
    var currencyCode: String = "RON"
    var currencyFractionDigits: Int = 2
    var occurredAt: Date = Date.now
    var merchant: String = ""
    var note: String = ""
    var sourceRawValue: String = "manual"
    var statusRawValue: String = "pending"
    var originalText: String?
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var confirmedAt: Date?
    var category: ExpenseCategory?
    var categoryNameSnapshot: String = "Necategorizat"
    var categoryEmojiSnapshot: String = "🧾"
    init() { }
}
@Model final class ExpenseCategory {
    var id: UUID = UUID()
    var name: String = ""
    var emoji: String = "🧾"
    var sortOrder: Int = 0
    var systemKey: String?
    var createdAt: Date = Date.now
    @Relationship(deleteRule: .nullify, inverse: \Expense.category) var expenses: [Expense]? = []
    init() { }
}
@Model final class BudgetMetadata {
    var key: String = "initial-categories-v1"
    var createdAt: Date = Date.now
    init() { }
}
@main @MainActor struct LegacyFixture {
    static func main() throws {
        let url = URL(fileURLWithPath: CommandLine.arguments[1])
        let schema = Schema([Expense.self, ExpenseCategory.self, BudgetMetadata.self])
        let container = try ModelContainer(for: schema, configurations: [
            ModelConfiguration("Budget", schema: schema, url: url, cloudKitDatabase: .none)
        ])
        let category = ExpenseCategory(); category.name = "Categorie veche"; category.emoji = "☕️"
        container.mainContext.insert(category)
        let first = Expense()
        first.merchant = "Istoric păstrat"; first.amountMinorUnits = 1250; first.statusRawValue = "confirmed"
        first.category = category; first.confirmedAt = .now
        container.mainContext.insert(first)
        let pending = Expense()
        pending.merchant = "Ciornă păstrată"; pending.currencyCode = "EUR"; pending.amountMinorUnits = 1000
        container.mainContext.insert(pending)
        container.mainContext.insert(BudgetMetadata())
        try container.mainContext.save()
    }
}
