import Foundation
import SwiftData

enum EntryKind: String, Codable, CaseIterable, Identifiable {
    case expense, income, transfer
    var id: String { rawValue }
    var title: String {
        switch self { case .expense: "Cheltuială"; case .income: "Venit"; case .transfer: "Transfer" }
    }
    var symbol: String {
        switch self { case .expense: "arrow.up.right"; case .income: "arrow.down.left"; case .transfer: "arrow.left.arrow.right" }
    }
}

@Model
final class BudgetAccount {
    var id: UUID = UUID()
    var name: String = ""
    var emoji: String = "🏦"
    var currencyCode: String = "RON"
    var fractionDigits: Int = 2
    var openingMinorUnits: Int64 = 0
    var isArchived: Bool = false
    var isDefault: Bool = false
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    init(name: String, emoji: String, currencyCode: String, openingMinorUnits: Int64 = 0) {
        self.name = name
        self.emoji = emoji
        self.currencyCode = currencyCode
        fractionDigits = MoneyAmount.fractionDigits(for: currencyCode)
        self.openingMinorUnits = openingMinorUnits
    }
}

@Model
final class LedgerEntry {
    var id: UUID = UUID()
    var kindRawValue: String = "expense"
    var statusRawValue: String = "confirmed"
    var amountMinorUnits: Int64 = 0
    var fractionDigits: Int = 2
    var currencyCode: String = "RON"
    var accountID: UUID = UUID()
    var destinationAccountID: UUID?
    var receivedMinorUnits: Int64?
    var receivedFractionDigits: Int?
    var receivedCurrencyCode: String?
    var categoryID: UUID?
    var categoryNameSnapshot: String = "Necategorizat"
    var categoryEmojiSnapshot: String = "🧾"
    var categorySystemKey: String?
    var merchant: String = ""
    var note: String = ""
    var occurredAt: Date = Date.now
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var sourceRawValue: String = "manual"
    var originalText: String?
    var recurrenceRuleID: UUID?
    var occurrenceKey: String?

    init() { }
    var kind: EntryKind { EntryKind(rawValue: kindRawValue) ?? .expense }
    var money: MoneyAmount { MoneyAmount(minorUnits: amountMinorUnits, fractionDigits: fractionDigits) }
    var receivedMoney: MoneyAmount? {
        guard let receivedMinorUnits, let receivedFractionDigits else { return nil }
        return MoneyAmount(minorUnits: receivedMinorUnits, fractionDigits: receivedFractionDigits)
    }
    var isConfirmed: Bool { statusRawValue == "confirmed" }
}

@Model
final class MonthlyBudget {
    var id: UUID = UUID()
    // nil identifies the existing overall budget. Additive migration preserves it.
    var categoryID: UUID? = nil
    var monthKey: String = ""
    var currencyCode: String = "RON"
    var fractionDigits: Int = 2
    var limitMinorUnits: Int64 = 0
    var updatedAt: Date = Date.now
    init(monthKey: String, currencyCode: String, money: MoneyAmount, categoryID: UUID? = nil) {
        self.categoryID = categoryID
        self.monthKey = monthKey
        self.currencyCode = currencyCode
        fractionDigits = money.fractionDigits
        limitMinorUnits = money.minorUnits
    }
    var money: MoneyAmount { MoneyAmount(minorUnits: limitMinorUnits, fractionDigits: fractionDigits) }
}

struct EntryInput {
    var kind: EntryKind
    var money: MoneyAmount
    var accountID: UUID
    var destinationAccountID: UUID?
    var receivedMoney: MoneyAmount?
    var categoryID: UUID?
    var merchant: String = ""
    var note: String = ""
    var occurredAt: Date = Date.now
}
