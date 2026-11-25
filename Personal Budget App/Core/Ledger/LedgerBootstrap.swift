import Foundation
import SwiftData

@MainActor
enum LedgerBootstrap {
    static func run(in context: ModelContext, preferredCurrency: String) throws {
        let markers = try context.fetch(FetchDescriptor<BudgetMetadata>())
        if !markers.contains(where: { $0.key == "income-categories-v1" }) {
            for (index, item) in [("salary", "Salariu", "💼"), ("freelance", "Freelance", "💻"), ("other-income", "Alte venituri", "💰")].enumerated() {
                let category = ExpenseCategory(name: item.1, emoji: item.2, sortOrder: index, systemKey: item.0)
                category.kindRawValue = "income"
                context.insert(category)
            }
            let marker = BudgetMetadata(); marker.key = "income-categories-v1"; context.insert(marker)
        }
        if !markers.contains(where: { $0.key == "ledger-migration-v1" }) {
            let old = try context.fetch(FetchDescriptor<Expense>())
            var accounts = try LedgerRepository.accounts(in: context)
            let codes = Set(old.map(\.currencyCode) + [preferredCurrency])
            for code in codes.sorted() where !accounts.contains(where: { $0.currencyCode == code }) {
                let account = BudgetAccount(name: "Personal · \(code)", emoji: "🏦", currencyCode: code)
                account.isDefault = code == preferredCurrency
                context.insert(account); accounts.append(account)
            }
            let existingIDs = Set(try LedgerRepository.entries(in: context).map(\.id))
            for expense in old where !existingIDs.contains(expense.id) {
                guard let account = accounts.first(where: { $0.currencyCode == expense.currencyCode }) else { continue }
                let entry = LedgerEntry()
                entry.id = expense.id; entry.accountID = account.id
                entry.amountMinorUnits = expense.amountMinorUnits; entry.fractionDigits = expense.currencyFractionDigits
                entry.currencyCode = expense.currencyCode; entry.statusRawValue = expense.statusRawValue
                entry.categoryID = expense.category?.id; entry.categoryNameSnapshot = expense.categoryName
                entry.categoryEmojiSnapshot = expense.categoryEmoji; entry.categorySystemKey = expense.category?.systemKey
                entry.merchant = expense.merchant; entry.note = expense.note; entry.occurredAt = expense.occurredAt
                entry.createdAt = expense.createdAt; entry.updatedAt = expense.updatedAt
                entry.sourceRawValue = expense.sourceRawValue; entry.originalText = expense.originalText
                context.insert(entry)
            }
            let marker = BudgetMetadata(); marker.key = "ledger-migration-v1"; context.insert(marker)
        }
        try LedgerRepository.commit(context)
    }
}
