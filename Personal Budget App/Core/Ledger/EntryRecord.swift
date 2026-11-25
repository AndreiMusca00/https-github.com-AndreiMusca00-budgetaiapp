import Foundation

/// Value snapshots make edits/deletions reversible without retaining deleted SwiftData objects.
struct EntryRecord: Codable {
    var id: UUID
    var kind: String
    var status: String
    var amount: Int64
    var digits: Int
    var currency: String
    var accountID: UUID
    var destinationID: UUID?
    var received: Int64?
    var receivedDigits: Int?
    var receivedCurrency: String?
    var categoryID: UUID?
    var categoryName: String
    var categoryEmoji: String
    var categorySystemKey: String?
    var merchant: String
    var note: String
    var occurredAt: Date
    var createdAt: Date
    var updatedAt: Date
    var source: String
    var originalText: String?
    var ruleID: UUID?
    var occurrenceKey: String?

    init(_ entry: LedgerEntry) {
        id = entry.id; kind = entry.kindRawValue; status = entry.statusRawValue
        amount = entry.amountMinorUnits; digits = entry.fractionDigits; currency = entry.currencyCode
        accountID = entry.accountID; destinationID = entry.destinationAccountID
        received = entry.receivedMinorUnits; receivedDigits = entry.receivedFractionDigits
        receivedCurrency = entry.receivedCurrencyCode
        categoryID = entry.categoryID; categoryName = entry.categoryNameSnapshot
        categoryEmoji = entry.categoryEmojiSnapshot; categorySystemKey = entry.categorySystemKey
        merchant = entry.merchant; note = entry.note; occurredAt = entry.occurredAt
        createdAt = entry.createdAt; updatedAt = entry.updatedAt
        source = entry.sourceRawValue; originalText = entry.originalText
        ruleID = entry.recurrenceRuleID; occurrenceKey = entry.occurrenceKey
    }

    func apply(to entry: LedgerEntry) {
        entry.id = id; entry.kindRawValue = kind; entry.statusRawValue = status
        entry.amountMinorUnits = amount; entry.fractionDigits = digits; entry.currencyCode = currency
        entry.accountID = accountID; entry.destinationAccountID = destinationID
        entry.receivedMinorUnits = received; entry.receivedFractionDigits = receivedDigits
        entry.receivedCurrencyCode = receivedCurrency
        entry.categoryID = categoryID; entry.categoryNameSnapshot = categoryName
        entry.categoryEmojiSnapshot = categoryEmoji; entry.categorySystemKey = categorySystemKey
        entry.merchant = merchant; entry.note = note; entry.occurredAt = occurredAt
        entry.createdAt = createdAt; entry.updatedAt = updatedAt
        entry.sourceRawValue = source; entry.originalText = originalText
        entry.recurrenceRuleID = ruleID; entry.occurrenceKey = occurrenceKey
    }
}

struct LedgerChange {
    var entryID: UUID?
    let message: String
    var undo: (@MainActor () throws -> Void)?
}
