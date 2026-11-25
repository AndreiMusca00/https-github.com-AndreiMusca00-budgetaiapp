import Foundation
import SwiftData

enum ExpenseSource: String, Codable {
    case manual, voice, wallet
}

enum ExpenseStatus: String, Codable {
    case pending, confirmed
}

@Model
final class Expense {
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
    // Preserve the historical label when its category is deleted.
    var categoryNameSnapshot: String = "Necategorizat"
    var categoryEmojiSnapshot: String = "🧾"

    init(input: ExpenseInput, category: ExpenseCategory?) {
        apply(input: input, category: category)
    }

    var money: MoneyAmount {
        MoneyAmount(minorUnits: amountMinorUnits, fractionDigits: currencyFractionDigits)
    }
    var source: ExpenseSource { ExpenseSource(rawValue: sourceRawValue) ?? .manual }
    var status: ExpenseStatus { ExpenseStatus(rawValue: statusRawValue) ?? .pending }
    var categoryName: String { category?.name ?? categoryNameSnapshot }
    var categoryEmoji: String { category?.emoji ?? categoryEmojiSnapshot }
    var title: String { merchant.isEmpty ? categoryName : merchant }

    func apply(input: ExpenseInput, category: ExpenseCategory?) {
        amountMinorUnits = input.money.minorUnits
        currencyFractionDigits = input.money.fractionDigits
        currencyCode = input.currencyCode
        occurredAt = input.occurredAt
        merchant = input.merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        note = input.note.trimmingCharacters(in: .whitespacesAndNewlines)
        sourceRawValue = input.source.rawValue
        originalText = input.originalText
        self.category = category
        categoryNameSnapshot = category?.name ?? "Necategorizat"
        categoryEmojiSnapshot = category?.emoji ?? "🧾"
        updatedAt = .now
    }
}

struct ExpenseInput {
    let money: MoneyAmount
    let currencyCode: String
    let occurredAt: Date
    let categoryID: UUID?
    var merchant: String = ""
    var note: String = ""
    var source: ExpenseSource = .manual
    var originalText: String?
}
