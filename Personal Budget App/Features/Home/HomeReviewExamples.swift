#if DEBUG
import Foundation
import SwiftData

@MainActor
enum HomeReviewExamples {
    private static let marker = "personalBudget.homeReviewExamples.v1"

    static func prepare(currency: String, in context: ModelContext) throws {
        let args = ProcessInfo.processInfo.arguments
        let isolatedTest = args.contains("-budget-review-tests")
        guard isolatedTest || (args.contains("-budget-home-review-examples") && !UserDefaults.standard.bool(forKey: marker)) else { return }
        guard !(try LedgerRepository.entries(in: context)).contains(where: \.isHomeExample) else { return }
        let accounts = try LedgerRepository.accounts(in: context).filter { !$0.isArchived && $0.currencyCode == currency }
        guard let account = accounts.first(where: \.isDefault) ?? accounts.first else { throw LedgerRepository.Failure.missingAccount }
        let categories = try context.fetch(FetchDescriptor<ExpenseCategory>())
        let examples: [(String, String, String, EntryKind, String)] = [
            ("Cafea", "18", "dining", .expense, "voice"),
            ("Cumpărături", "125", "groceries", .expense, "wallet"),
            ("Bonus", "750", "other-income", .income, "import")
        ]
        for (index, sample) in examples.enumerated() {
            let entry = LedgerEntry()
            entry.kindRawValue = sample.3.rawValue
            entry.statusRawValue = "pending"
            entry.sourceRawValue = "demo.home." + sample.4
            entry.accountID = account.id
            entry.currencyCode = currency
            let money = MoneyAmount.parse(sample.1, currencyCode: currency)!
            entry.amountMinorUnits = money.minorUnits; entry.fractionDigits = money.fractionDigits
            entry.merchant = tr(sample.0)
            entry.originalText = tr("Exemplu de test") + " · " + entry.merchant
            entry.createdAt = Date.now.addingTimeInterval(TimeInterval(-index))
            if let category = categories.first(where: { $0.systemKey == sample.2 && $0.kindRawValue == sample.3.rawValue }) {
                entry.categoryID = category.id; entry.categorySystemKey = category.systemKey
                entry.categoryNameSnapshot = category.name; entry.categoryEmojiSnapshot = category.emoji
            }
            context.insert(entry)
        }
        try LedgerRepository.commit(context)
        if !isolatedTest { UserDefaults.standard.set(true, forKey: marker) }
    }

    static func remove(in context: ModelContext) throws -> LedgerChange {
        let entries = try LedgerRepository.entries(in: context).filter(\.isHomeExample)
        let records = entries.map(EntryRecord.init)
        for entry in entries { context.delete(entry) }
        try LedgerRepository.commit(context)
        return LedgerChange(message: "Exemple șterse") {
            for record in records where try LedgerRepository.entry(record.id, in: context) == nil {
                let entry = LedgerEntry(); record.apply(to: entry); context.insert(entry)
            }
            try LedgerRepository.commit(context)
        }
    }
}
#endif
