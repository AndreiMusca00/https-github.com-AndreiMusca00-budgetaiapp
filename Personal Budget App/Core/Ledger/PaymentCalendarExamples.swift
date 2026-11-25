import Foundation
import SwiftData

@MainActor
enum PaymentCalendarExamples {
    private static let marker = "payment-calendar-examples-v1"
    static let ids = (1...4).map { UUID(uuidString: String(format: "730F01B7-5C2A-44A5-9C1B-%012d", $0))! }
    static func contains(_ id: UUID) -> Bool { ids.contains(id) }

    static func prepare(currency: String, asOf: Date, in context: ModelContext) throws {
        guard !(try context.fetch(FetchDescriptor<BudgetMetadata>())).contains(where: { $0.key == marker }) else { return }
        let accounts = try LedgerRepository.accounts(in: context).filter { !$0.isArchived && $0.currencyCode == currency }
        guard let account = accounts.first(where: \.isDefault) ?? accounts.first else { throw LedgerRepository.Failure.missingAccount }
        let categories = try context.fetch(FetchDescriptor<ExpenseCategory>()).filter { $0.kindRawValue == EntryKind.expense.rawValue }
        let existing = Set(try context.fetch(FetchDescriptor<RecurrenceRule>()).map(\.id))
        let samples: [(String, String, Int, String, String)] = [
            ("Chirie", "1200", 25, "home", "🏠"),
            ("Netflix", "49", 22, "subscriptions-streaming", "📺"),
            ("iCloud", "15", 20, "subscriptions-software", "☁️"),
            ("Spotify", "26", 27, "subscriptions-streaming", "📺")
        ]
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: asOf)
        for (index, sample) in samples.enumerated() where !existing.contains(ids[index]) {
            guard let money = MoneyAmount.parse(sample.1, currencyCode: currency),
                  let due = calendar.date(from: DateComponents(year: components.year, month: components.month, day: sample.2, hour: 12)) else { continue }
            let category = categories.first { $0.systemKey == sample.3 } ?? categories.first
            let rule = RecurrenceRule(); rule.id = ids[index]
            rule.kindRawValue = EntryKind.expense.rawValue; rule.accountID = account.id
            rule.amountMinorUnits = money.minorUnits; rule.fractionDigits = money.fractionDigits; rule.currencyCode = currency
            rule.categoryID = category?.id; rule.categoryNameSnapshot = category?.name ?? "Recurente"
            rule.categoryEmojiSnapshot = category?.emoji ?? sample.4; rule.categorySystemKey = category?.systemKey
            rule.merchant = sample.0; rule.note = "Exemplu de test"
            rule.frequencyRawValue = RepeatFrequency.monthly.rawValue; rule.interval = 1
            rule.anchorDate = due; rule.nextDueDate = due; rule.timeZoneIdentifier = calendar.timeZone.identifier
            context.insert(rule)
        }
        let saved = BudgetMetadata(); saved.key = marker; context.insert(saved)
        try LedgerRepository.commit(context)
    }

    #if DEBUG
    /// Isolated simulator fixture; never enabled by the on-device example flag.
    static func prepareStatusPreview(asOf: Date, in context: ModelContext) throws {
        let calendar = Calendar.current
        let today = RecurrenceSchedule.day(asOf, calendar: calendar)
        let parts = calendar.dateComponents([.year, .month, .day], from: today)
        let lastDay = calendar.range(of: .day, in: .month, for: today)!.count
        for (index, day) in [(2, parts.day!), (1, min(parts.day! + 2, lastDay)), (0, min(parts.day! + 3, lastDay)), (3, parts.day!)] {
            guard let rule = try LedgerRepository.rule(ids[index], in: context) else { continue }
            let due = calendar.date(from: DateComponents(year: parts.year, month: parts.month, day: day, hour: 12))!
            rule.nextDueDate = due; rule.anchorDate = due
            if index == 3 {
                _ = try LedgerRepository.confirmOccurrence(rule: rule, dueDate: due,
                    input: EntryInput(kind: .expense, money: rule.money, accountID: rule.accountID,
                        categoryID: rule.categoryID, merchant: rule.merchant, occurredAt: asOf), in: context)
            }
        }
        try LedgerRepository.commit(context)
    }
    #endif

    /// Only built-in samples with their original general category are reclassified.
    static func refreshCategoryAssignments(in context: ModelContext) throws {
        let categories = try context.fetch(FetchDescriptor<ExpenseCategory>())
        var changed = false
        for (index, name, key) in [(1, "Netflix", "subscriptions-streaming"), (2, "iCloud", "subscriptions-software"), (3, "Spotify", "subscriptions-streaming")] {
            guard let rule = try LedgerRepository.rule(ids[index], in: context), rule.merchant == name,
                  rule.categorySystemKey == "subscriptions", rule.categoryID != nil,
                  let category = categories.first(where: { $0.systemKey == key && $0.kindRawValue == "expense" }) else { continue }
            rule.categoryID = category.id; rule.categoryNameSnapshot = category.name
            rule.categoryEmojiSnapshot = category.emoji; rule.categorySystemKey = category.systemKey
            rule.updatedAt = .now; changed = true
        }
        if changed { try LedgerRepository.commit(context) }
    }

    static func remove(in context: ModelContext) throws -> LedgerChange {
        let rules = try context.fetch(FetchDescriptor<RecurrenceRule>()).filter { contains($0.id) }
        let entries = try LedgerRepository.entries(in: context).filter { $0.recurrenceRuleID.map { contains($0) } ?? false }
        let ruleRecords = rules.map { ExampleRuleRecord($0) }
        let entryRecords = entries.map { EntryRecord($0) }
        for entry in entries { context.delete(entry) }
        for rule in rules { context.delete(rule) }
        try LedgerRepository.commit(context)
        return LedgerChange(message: "Exemple șterse") {
            for record in ruleRecords where try LedgerRepository.rule(record.id, in: context) == nil {
                let rule = RecurrenceRule(); record.apply(to: rule); context.insert(rule)
            }
            for record in entryRecords where try LedgerRepository.entry(record.id, in: context) == nil {
                let entry = LedgerEntry(); record.apply(to: entry); context.insert(entry)
            }
            try LedgerRepository.commit(context)
        }
    }
}

private struct ExampleRuleRecord {
    let id: UUID, accountID: UUID, categoryID: UUID?
    let kind: String, currency: String, categoryName: String, emoji: String, categoryKey: String?
    let amount: Int64, digits: Int
    let merchant: String, note: String, frequency: String, interval: Int
    let anchor: Date, due: Date, end: Date?, lastDay: Bool, zone: String, active: Bool, created: Date, updated: Date
    init(_ rule: RecurrenceRule) {
        id = rule.id; accountID = rule.accountID; categoryID = rule.categoryID
        kind = rule.kindRawValue; currency = rule.currencyCode; categoryName = rule.categoryNameSnapshot
        emoji = rule.categoryEmojiSnapshot; categoryKey = rule.categorySystemKey
        amount = rule.amountMinorUnits; digits = rule.fractionDigits
        merchant = rule.merchant; note = rule.note; frequency = rule.frequencyRawValue; interval = rule.interval
        anchor = rule.anchorDate; due = rule.nextDueDate; end = rule.endDate; lastDay = rule.usesLastDay
        zone = rule.timeZoneIdentifier; active = rule.isActive; created = rule.createdAt; updated = rule.updatedAt
    }
    func apply(to rule: RecurrenceRule) {
        rule.id = id; rule.accountID = accountID; rule.categoryID = categoryID
        rule.kindRawValue = kind; rule.currencyCode = currency; rule.categoryNameSnapshot = categoryName
        rule.categoryEmojiSnapshot = emoji; rule.categorySystemKey = categoryKey
        rule.amountMinorUnits = amount; rule.fractionDigits = digits
        rule.merchant = merchant; rule.note = note; rule.frequencyRawValue = frequency; rule.interval = interval
        rule.anchorDate = anchor; rule.nextDueDate = due; rule.endDate = end; rule.usesLastDay = lastDay
        rule.timeZoneIdentifier = zone; rule.isActive = active; rule.createdAt = created; rule.updatedAt = updated
    }
}
