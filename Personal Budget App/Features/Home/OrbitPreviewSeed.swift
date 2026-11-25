#if DEBUG
import Foundation
import SwiftData

/// Isolated simulator/UI-test data. Never called for the normal persistent store.
@MainActor
enum OrbitPreviewSeed {
    static func insert(in context: ModelContext) throws {
        guard let account = try context.fetch(FetchDescriptor<BudgetAccount>()).first else { return }
        let categories = try context.fetch(FetchDescriptor<ExpenseCategory>())
        let samples: [(String, Int64, String)] = [
            ("transport", 10000, "Benzină"), ("transport", 8000, "Parcare"),
            ("home", 72000, "Chirie"), ("groceries", 32000, "Cumpărături"),
            ("groceries", 22000, "Piață"), ("shopping", 36000, "Haine")
        ]
        let keys = ["transport", "home", "groceries", "shopping"]
        for (index, key) in keys.enumerated() {
            categories.first { $0.systemKey == key }?.id = UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index + 1))!
        }
        for (key, amount, merchant) in samples {
            let category = categories.first { $0.systemKey == key }!
            let entry = LedgerEntry()
            entry.amountMinorUnits = amount; entry.accountID = account.id
            entry.categoryID = category.id; entry.categorySystemKey = category.systemKey
            entry.categoryNameSnapshot = category.name; entry.categoryEmojiSnapshot = category.emoji
            entry.merchant = merchant
            context.insert(entry)
        }
        let income = LedgerEntry(); income.kindRawValue = "income"; income.amountMinorUnits = 600000; income.accountID = account.id
        income.merchant = "Salariu"; context.insert(income)
        let cash = BudgetAccount(name: "Numerar", emoji: "💵", currencyCode: "RON")
        context.insert(cash)
        let transfer = LedgerEntry(); transfer.kindRawValue = "transfer"; transfer.accountID = account.id
        transfer.destinationAccountID = cash.id; transfer.amountMinorUnits = 10000
        transfer.receivedMinorUnits = 10000; transfer.receivedCurrencyCode = "RON"; transfer.receivedFractionDigits = 2
        context.insert(transfer)
        let pending = LedgerEntry(); pending.accountID = account.id; pending.amountMinorUnits = 9900; pending.statusRawValue = "pending"
        let transport = categories.first { $0.systemKey == "transport" }!
        pending.categoryID = transport.id; pending.categorySystemKey = transport.systemKey
        pending.categoryNameSnapshot = transport.name; pending.categoryEmojiSnapshot = transport.emoji
        pending.merchant = "Transport de verificat"
        context.insert(pending)
        let euro = BudgetAccount(name: "Euro", emoji: "💶", currencyCode: "EUR"); context.insert(euro)
        let otherCurrency = LedgerEntry(); otherCurrency.accountID = euro.id; otherCurrency.currencyCode = "EUR"; otherCurrency.amountMinorUnits = 25000
        otherCurrency.categoryID = transport.id; otherCurrency.categorySystemKey = transport.systemKey
        otherCurrency.categoryNameSnapshot = transport.name; otherCurrency.categoryEmojiSnapshot = transport.emoji
        otherCurrency.merchant = "Transport EUR"
        context.insert(otherCurrency)
        let otherMonth = LedgerEntry(); otherMonth.accountID = account.id; otherMonth.amountMinorUnits = 5000
        otherMonth.occurredAt = Calendar.current.date(byAdding: .month, value: -1, to: .now)!
        otherMonth.categoryID = transport.id; otherMonth.categorySystemKey = transport.systemKey
        otherMonth.categoryNameSnapshot = transport.name; otherMonth.categoryEmojiSnapshot = transport.emoji
        otherMonth.merchant = "Transport luna trecută"
        context.insert(otherMonth)
        context.insert(MonthlyBudget(monthKey: LedgerMath.monthKey(.now), currencyCode: "RON", money: MoneyAmount(minorUnits: 400000, fractionDigits: 2)))
        try context.save()
    }
}
#endif
