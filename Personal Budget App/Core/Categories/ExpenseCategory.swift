import Foundation
import SwiftData

@Model
final class ExpenseCategory {
    var id: UUID = UUID()
    var name: String = ""
    var emoji: String = "🧾"
    var sortOrder: Int = 0
    var systemKey: String?
    var kindRawValue: String = "expense"
    var createdAt: Date = Date.now
    @Relationship(deleteRule: .nullify, inverse: \Expense.category)
    var expenses: [Expense]? = []

    init(name: String, emoji: String, sortOrder: Int, systemKey: String? = nil) {
        self.name = name
        self.emoji = emoji
        self.sortOrder = sortOrder
        self.systemKey = systemKey
    }

    static let defaults: [(key: String, name: String, emoji: String)] = [
        ("groceries", "Alimente", "🛒"),
        ("dining", "Restaurante și cafenele", "☕️"),
        ("transport", "Transport", "🚗"),
        ("home", "Casă și facturi", "🏠"),
        ("health", "Sănătate", "💊"),
        ("shopping", "Cumpărături", "🛍️"),
        ("leisure", "Timp liber", "🎬"),
        ("subscriptions", "Abonamente", "📱"),
        ("other", "Altele", "✨")
    ] + subscriptionDefaults

    static let subscriptionDefaults: [(key: String, name: String, emoji: String)] = [
        ("subscriptions-streaming", "Streaming", "📺"),
        ("subscriptions-software", "Aplicații și cloud", "☁️"),
        ("subscriptions-phone", "Telefon și internet", "📶")
    ]
}
