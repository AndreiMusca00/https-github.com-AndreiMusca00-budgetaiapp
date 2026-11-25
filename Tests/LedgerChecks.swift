import Foundation
import SwiftData

@main @MainActor struct LedgerChecks {
    static func main() throws {
        check(MoneyAmount.parseBalance("-12,50", currencyCode: "RON")?.minorUnits == -1250, "Negative opening balances must be exact")
        check(MoneyAmount.parseBalance("0,0", currencyCode: "RON")?.minorUnits == 0, "Zero opening balances must accept valid precision")
        check(MoneyAmount.parse("1,234", currencyCode: "RON") == nil, "Excess precision cannot be rounded")
        check(MoneyAmount.parse("100", currencyCode: "JPY")?.minorUnits == 100, "Zero-decimal currencies must be exact")
        let fresh = BudgetDatabase(inMemory: true)
        check(try LedgerRepository.accounts(in: fresh.container!.mainContext).isEmpty,
              "Fresh installation must wait for onboarding before choosing an account currency")
        fresh.configure(currency: "EUR")
        check(try LedgerRepository.accounts(in: fresh.container!.mainContext).first?.currencyCode == "EUR",
              "The first account must follow the onboarding currency")
        fresh.configure(currency: "USD")
        check(try LedgerRepository.accounts(in: fresh.container!.mainContext).count == 1,
              "Changing preferences later must not create extra accounts")
        let container = try ModelContainer(for: BudgetDatabase.schema, configurations: [
            ModelConfiguration(schema: BudgetDatabase.schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        ])
        let context = container.mainContext
        context.autosaveEnabled = false
        try BudgetDatabase.seedCategories(in: context)
        try LedgerBootstrap.run(in: context, preferredCurrency: "RON")
        let bank = try LedgerRepository.accounts(in: context)[0]
        try LedgerRepository.saveAccount(bank, name: "Banca", emoji: "🏦", currency: "RON",
                                         opening: money("1000"), isDefault: true, in: context)
        let cash = try LedgerRepository.saveAccount(name: "Numerar", emoji: "💵", currency: "RON",
                                                    opening: money("100"), isDefault: false, in: context)
        let euro = try LedgerRepository.saveAccount(name: "Euro", emoji: "💳", currency: "EUR",
                                                    opening: MoneyAmount(minorUnits: 0, fractionDigits: 2), isDefault: false, in: context)
        let salaryCategory = try context.fetch(FetchDescriptor<ExpenseCategory>()).first { $0.systemKey == "salary" }!
        let income = EntryInput(kind: .income, money: money("7000"), accountID: bank.id,
                                categoryID: salaryCategory.id, merchant: "Salariu")
        _ = try LedgerRepository.saveEntry(input: income, in: context)
        check(try balance(bank, context) == 8000, "Income must increase the account balance")
        check(try total(.income, context) == 7000, "Only income is counted as income")

        let category = try ExpenseRepository.saveCategory(name: "Cafea", emoji: "☕️", in: context)
        var expense = EntryInput(kind: .expense, money: money("85.50"), accountID: bank.id,
                                 categoryID: category.id, merchant: "Lidl")
        var saved = try LedgerRepository.saveEntry(input: expense, in: context)
        check(try total(.expense, context) == Decimal(string: "85.50"), "Manual save must immediately enter totals")
        try saved.undo?()
        check(try total(.expense, context) == 0, "Undo save must remove the expense")
        saved = try LedgerRepository.saveEntry(input: expense, in: context)
        let expenseID = saved.entryID!
        expense.money = money("95.50")
        let edited = try LedgerRepository.saveEntry(id: expenseID, input: expense, in: context)
        check(try total(.expense, context) == Decimal(string: "95.50"), "Edit must update totals")
        try edited.undo?()
        check(try total(.expense, context) == Decimal(string: "85.50"), "Undo edit must restore the exact prior amount")
        let entry = try LedgerRepository.entry(expenseID, in: context)!
        let createdAt = entry.createdAt
        let deleted = try LedgerRepository.deleteEntry(entry, in: context)
        check(try total(.expense, context) == 0, "Delete must remove the amount from totals")
        try deleted.undo?()
        check(try LedgerRepository.entry(expenseID, in: context)?.createdAt == createdAt, "Undo delete must restore identity and creation date")

        let transfer = EntryInput(kind: .transfer, money: money("300"), accountID: bank.id,
                                  destinationAccountID: cash.id, receivedMoney: money("300"), merchant: "Retragere")
        let before = try balance(bank, context)
        let moved = try LedgerRepository.saveEntry(input: transfer, in: context)
        check(try balance(bank, context) == before - 300, "Transfer must debit the source")
        check(try balance(cash, context) == 400, "Transfer must credit the destination")
        check(try total(.expense, context) == Decimal(string: "85.50"), "Transfers must not inflate spending")
        check(try total(.income, context) == 7000, "Transfers must not inflate income")
        try moved.undo?()
        check(try balance(cash, context) == 100, "Undo transfer must restore both accounts atomically")
        let foreign = EntryInput(kind: .transfer, money: money("100"), accountID: bank.id,
                                 destinationAccountID: euro.id, receivedMoney: money("20"))
        _ = try LedgerRepository.saveEntry(input: foreign, in: context)
        check(try balance(euro, context) == 20, "Cross-currency transfers must use the entered destination amount")
        var invalid = foreign; invalid.destinationAccountID = bank.id
        try reject(.sameAccount) { _ = try LedgerRepository.saveEntry(input: invalid, in: context) }
        var wrongCategory = expense; wrongCategory.categoryID = salaryCategory.id
        try reject(.missingCategory) { _ = try LedgerRepository.saveEntry(input: wrongCategory, in: context) }

        try ExpenseRepository.saveCategory(category, name: "Cafea redenumită", emoji: "🍵", in: context)
        check(try LedgerRepository.entry(expenseID, in: context)?.categoryNameSnapshot == "Cafea redenumită", "Category renames must update linked history")
        try ExpenseRepository.deleteCategory(category, in: context)
        var afterCategoryDeletion = expense
        afterCategoryDeletion.money = money("85.50")
        afterCategoryDeletion.categoryID = nil
        afterCategoryDeletion.note = "Notiță nouă"
        _ = try LedgerRepository.saveEntry(id: expenseID, input: afterCategoryDeletion, in: context)
        let unlinked = try LedgerRepository.entry(expenseID, in: context)!
        check(unlinked.categoryID == nil && unlinked.categoryNameSnapshot == "Cafea redenumită", "Category deletion must preserve history labels")

        try LedgerRepository.saveBudget(month: .now, currency: "RON", money: money("5000"), in: context)
        try LedgerRepository.saveBudget(month: .now, currency: "RON", money: money("5500"), in: context)
        check(try context.fetchCount(FetchDescriptor<MonthlyBudget>()) == 1, "A monthly budget must upsert rather than duplicate")
        check(try context.fetch(FetchDescriptor<MonthlyBudget>())[0].limitMinorUnits == 550000, "Budget edits must remain exact")
        let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: .now)!
        try LedgerRepository.saveBudget(month: nextMonth, currency: "RON", money: money("4000"), in: context)
        check(try context.fetchCount(FetchDescriptor<MonthlyBudget>()) == 2, "Each month keeps its own budget")

        try categoryBudgetChecks(context: context, account: bank)
        categorySpendingChecks()
        accountOverviewChecks()
        try paymentCalendarChecks()
        try subscriptionCategoryUpgradeChecks()
        try recurrenceChecks(context: context, account: bank)
        try pendingSpeechChecks()
        try pendingActionChecks()
        try LedgerRepository.archiveAccount(bank, in: context)
        try reject(.archivedAccount) { _ = try LedgerRepository.saveEntry(input: expense, in: context) }
        try reject(.accountInUse) { try LedgerRepository.deleteAccount(bank, in: context) }
        try reject(.currencyLocked) {
            try LedgerRepository.saveAccount(bank, name: "Banca", emoji: "🏦", currency: "EUR",
                                             opening: money("1"), isDefault: true, in: context)
        }
        check(bank.currencyCode == "RON", "Rejected currency changes must preserve the original account")
        try LedgerRepository.archiveAccount(bank, in: context)
        try migrationChecks(at: URL(fileURLWithPath: CommandLine.arguments[1]))
        try previousBudgetMigration(at: URL(fileURLWithPath: CommandLine.arguments[2]))
        print("Passed: original and previous-budget migrations, category limits, direct-save/Undo, account balances, edits/deletion, transfers, recurring schedules and monthly budgets.")
    }

    static func pendingSpeechChecks() throws {
        let db = BudgetDatabase(inMemory: true, preferredCurrency: "RON")
        let context = db.container!.mainContext
        let account = try LedgerRepository.accounts(in: context)[0]
        let proposal = try PendingEntryRepository.voice(text: "  Am cheltuit 35 de lei pe cafea.  ", currency: "RON", in: context)
        let entry = try LedgerRepository.entry(proposal.entryID!, in: context)!
        check(!entry.isConfirmed && entry.sourceRawValue == "voice", "Speech must remain an unconfirmed proposal")
        check(entry.amountMinorUnits == 0, "Speech cannot invent an amount before interpretation/review")
        check(entry.originalText == "Am cheltuit 35 de lei pe cafea.", "The full original transcript must be retained")
        check(try total(.expense, context) == 0 && balance(account, context) == 0, "Pending speech cannot affect totals or balances")
        let confirmation = try LedgerRepository.saveEntry(id: entry.id, input: EntryInput(kind: .expense,
            money: money("35"), accountID: account.id, merchant: "Cafea"), in: context)
        check(entry.isConfirmed && entry.sourceRawValue == "voice" && entry.originalText != nil, "Review must preserve speech provenance")
        check(try total(.expense, context) == 35, "Only confirmed speech enters spending")
        try confirmation.undo?()
        check(!entry.isConfirmed && entry.amountMinorUnits == 0, "Undo review must restore the incomplete proposal")
        try proposal.undo?()
        check(try LedgerRepository.entry(proposal.entryID!, in: context) == nil, "Undo capture must remove the proposal")
    }

    static func pendingActionChecks() throws {
        let db = BudgetDatabase(inMemory: true, preferredCurrency: "RON")
        let context = db.container!.mainContext
        let account = try LedgerRepository.accounts(in: context)[0]
        let proposal = try PendingEntryRepository.voice(text: "Cafea", currency: "RON", in: context)
        let entry = try LedgerRepository.entry(proposal.entryID!, in: context)!
        do {
            _ = try PendingEntryRepository.confirm(entry.id, in: context)
            fatalError("A missing amount cannot be quick-confirmed")
        } catch is PendingEntryRepository.ReviewError {}
        entry.amountMinorUnits = 1800
        entry.currencyCode = "EUR"
        do {
            _ = try PendingEntryRepository.confirm(entry.id, in: context)
            fatalError("A mismatched currency cannot be reinterpreted as account currency")
        } catch is PendingEntryRepository.ReviewError {}
        check(!entry.isConfirmed && entry.currencyCode == "EUR", "Failed confirmation cannot mutate the proposal")
        entry.currencyCode = "RON"
        let confirmation = try PendingEntryRepository.confirm(entry.id, in: context)!
        check(try total(.expense, context) == 18 && balance(account, context) == -18, "Quick confirm must update totals once")
        check(try PendingEntryRepository.confirm(entry.id, in: context) == nil, "Repeating confirmation must be harmless")
        check(try PendingEntryRepository.reject(entry.id, in: context) == nil, "A stale reject cannot delete a confirmed entry")
        try confirmation.undo?()
        check(!entry.isConfirmed && entry.amountMinorUnits == 1800, "Undo confirm must restore the complete pending proposal")
        let id = entry.id
        let rejected = try PendingEntryRepository.reject(id, in: context)!
        check(try LedgerRepository.entry(id, in: context) == nil, "Reject must remove only the pending entry")
        check(try PendingEntryRepository.reject(id, in: context) == nil, "Repeating reject must be harmless")
        check(try total(.expense, context) == 0 && balance(account, context) == 0, "Reject cannot affect balances")
        try rejected.undo?()
        let restored = try LedgerRepository.entry(id, in: context)!
        check(!restored.isConfirmed && restored.amountMinorUnits == 1800 && restored.originalText == "Cafea", "Undo reject must restore identity, amount and provenance")
        let euro = try LedgerRepository.saveAccount(name: "Euro test", emoji: "💶", currency: "EUR",
            opening: MoneyAmount(minorUnits: 0, fractionDigits: 2), isDefault: false, in: context)
        let transfer = LedgerEntry(); transfer.statusRawValue = "pending"; transfer.kindRawValue = "transfer"
        transfer.merchant = "Schimb"; transfer.accountID = account.id; transfer.amountMinorUnits = 10000
        transfer.destinationAccountID = euro.id; transfer.receivedMinorUnits = 2000
        transfer.receivedFractionDigits = 2; transfer.receivedCurrencyCode = "USD"
        context.insert(transfer); try LedgerRepository.commit(context)
        do {
            _ = try PendingEntryRepository.confirm(transfer.id, in: context)
            fatalError("A received currency mismatch cannot be quick-confirmed")
        } catch is PendingEntryRepository.ReviewError {}
        transfer.receivedCurrencyCode = "EUR"
        let move = try PendingEntryRepository.confirm(transfer.id, in: context)!
        check(try balance(account, context) == -100 && balance(euro, context) == 20, "Confirmed transfers must respect both currencies")
        try move.undo?()
        check(try balance(account, context) == 0 && balance(euro, context) == 0, "Undo transfer confirmation must restore balances")
    }

    static func accountOverviewChecks() {
        let month = Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 18, hour: 12))!
        let previous = Calendar.current.date(byAdding: .month, value: -1, to: month)!
        let bank = BudgetAccount(name: "Banca", emoji: "🏦", currencyCode: "RON", openingMinorUnits: 100000)
        bank.isDefault = true
        let cash = BudgetAccount(name: "Numerar", emoji: "💵", currencyCode: "RON", openingMinorUnits: 5000)
        let euro = BudgetAccount(name: "Euro", emoji: "💶", currencyCode: "EUR", openingMinorUnits: 1000)
        let archived = BudgetAccount(name: "Arhivat", emoji: "🗄️", currencyCode: "RON", openingMinorUnits: 999999)
        archived.isArchived = true
        func entry(_ kind: EntryKind, _ amount: Int64, _ account: BudgetAccount, date: Date? = nil) -> LedgerEntry {
            let item = LedgerEntry(); item.kindRawValue = kind.rawValue; item.amountMinorUnits = amount
            item.accountID = account.id; item.currencyCode = account.currencyCode; item.occurredAt = date ?? month
            return item
        }
        let transfer = entry(.transfer, 10000, bank)
        transfer.destinationAccountID = cash.id; transfer.receivedMinorUnits = 10000
        transfer.receivedFractionDigits = 2; transfer.receivedCurrencyCode = "RON"
        let foreign = entry(.transfer, 5000, bank)
        foreign.destinationAccountID = euro.id; foreign.receivedMinorUnits = 1000
        foreign.receivedFractionDigits = 2; foreign.receivedCurrencyCode = "EUR"
        let pending = entry(.expense, 999900, bank); pending.statusRawValue = "pending"
        let entries = [entry(.income, 20000, bank), entry(.expense, 8000, bank), entry(.expense, 2000, bank, date: previous),
                       entry(.expense, 1000, cash), entry(.expense, 200, euro), transfer, foreign, pending]
        let accounts = [cash, euro, archived, bank]
        let rows = AccountOverviewSummary.rows(accounts: accounts, entries: entries, month: month, asOf: month)
        check(rows.count == 3 && rows.first?.id == bank.id, "Home must present active accounts with the default account first")
        check(rows.first { $0.id == bank.id }?.balance == 950 && rows.first { $0.id == bank.id }?.spent == 80,
              "Account balance includes opening balance, confirmed income, all past spending and outgoing transfers; monthly spending excludes transfers and drafts")
        check(rows.first { $0.id == cash.id }?.balance == 140 && rows.first { $0.id == cash.id }?.spent == 10,
              "Incoming transfers increase available money without becoming spending")
        check(rows.first { $0.id == euro.id }?.balance == 18 && rows.first { $0.id == euro.id }?.spent == 2,
              "Cross-currency balances use the received amount in the destination currency")
        let totals = AccountOverviewSummary.totals(rows)
        check(totals["RON"] == 1090 && totals["EUR"] == 18 && totals.count == 2,
              "Balances in different currencies must remain separate totals")
        let history = AccountOverviewSummary.rows(accounts: accounts, entries: entries, month: previous, asOf: month)
        check(history.first { $0.id == bank.id }?.spent == 20 && history.first { $0.id == bank.id }?.balance == 950,
              "Changing the selected month changes monthly spending while available balance remains current")
        let bankActivity = AccountActivity.records(accountID: bank.id, entries: entries, month: month)
        check(bankActivity.count == 4 && !bankActivity.contains { $0.id == pending.id },
              "Account activity includes only confirmed entries in the selected month")
        check(AccountActivity.records(accountID: bank.id, entries: entries, month: month, kind: .expense).count == 1 &&
              AccountActivity.records(accountID: bank.id, entries: entries, month: month, kind: .income).count == 1 &&
              AccountActivity.records(accountID: bank.id, entries: entries, month: month, kind: .transfer).count == 2,
              "Account filters keep transfers separate from actual income and spending")
        let euroTransfers = AccountActivity.records(accountID: euro.id, entries: entries, month: month, kind: .transfer)
        check(euroTransfers.count == 1 && euroTransfers.first?.id == foreign.id,
              "Destination account activity must include incoming transfers even when the source currency differs")
        let received = AccountActivity.amount(of: EntryRecord(foreign), in: euro.id)
        let sent = AccountActivity.amount(of: EntryRecord(foreign), in: bank.id)
        check(received?.money.decimalValue == 10 && received?.currency == "EUR" && received?.isIncoming == true,
              "Incoming transfer rows display the exact received amount and currency")
        check(sent?.money.decimalValue == 50 && sent?.currency == "RON" && sent?.isIncoming == false,
              "Outgoing transfer rows display the source amount with a debit direction")
        check(AccountActivity.amount(of: EntryRecord(foreign), in: cash.id) == nil,
              "Unrelated accounts must not claim a transfer amount")
        check(AccountActivity.records(accountID: bank.id, entries: entries, month: previous).count == 1,
              "Account activity changes month without carrying current-month transactions into history")
        let boundary = Calendar.current.dateInterval(of: .month, for: month)!
        let start = entry(.expense, 100, bank, date: boundary.start)
        let end = entry(.expense, 200, bank, date: boundary.end)
        check(AccountActivity.records(accountID: bank.id, entries: [start, end], month: month).map(\.id) == [start.id],
              "Account activity includes the month start and excludes next-month midnight")
    }

    static func categorySpendingChecks() {
        let a = ExpenseCategory(name: "Transport test", emoji: "🚗", sortOrder: 0)
        let b = ExpenseCategory(name: "Fără cheltuieli test", emoji: "🪴", sortOrder: 1)
        let now = Date.now
        let previous = Calendar.current.date(byAdding: .month, value: -1, to: now)!
        func entry(_ amount: Int64, categoryID: UUID? = nil, currency: String = "RON", kind: EntryKind = .expense, date: Date? = nil) -> LedgerEntry {
            let entry = LedgerEntry(); entry.amountMinorUnits = amount; entry.categoryID = categoryID
            entry.currencyCode = currency; entry.kindRawValue = kind.rawValue; entry.occurredAt = date ?? now
            return entry
        }
        let actual = entry(850, categoryID: a.id)
        let pending = entry(9999, categoryID: a.id); pending.statusRawValue = "pending"
        let historical = entry(300); historical.categoryNameSnapshot = a.name; historical.categoryEmojiSnapshot = a.emoji
        let uncategorized = entry(200)
        let entries = [actual, pending, historical, uncategorized, entry(100000, categoryID: a.id, kind: .income),
                       entry(10000, kind: .transfer), entry(1000, categoryID: a.id, currency: "EUR"), entry(1500, categoryID: a.id, date: previous)]
        let limits = [MonthlyBudget(monthKey: LedgerMath.monthKey(now), currencyCode: "RON", money: money("5000")),
                      MonthlyBudget(monthKey: LedgerMath.monthKey(now), currencyCode: "RON", money: money("20"), categoryID: a.id),
                      MonthlyBudget(monthKey: LedgerMath.monthKey(now), currencyCode: "RON", money: money("100"), categoryID: b.id),
                      MonthlyBudget(monthKey: LedgerMath.monthKey(previous), currencyCode: "RON", money: money("999"), categoryID: a.id)]
        let rows = CategorySpendingSummary.rows(entries: entries, categories: [a,b], budgets: limits, month: now, currency: "RON")
        check(rows.count == 4, "Category summaries must keep deleted and uncategorized history separate from current categories")
        check(rows.reduce(0) { $0 + $1.spent } == Decimal(string: "13.50"), "Category spending must match the confirmed month/currency expense total exactly")
        let transport = rows.first { $0.id == a.id.uuidString }!
        check(transport.spent == Decimal(string: "8.50") && transport.limit == 20 && transport.count == 1, "Category summaries exclude drafts, income, transfers, other currencies and other months")
        check(rows.first { $0.id == b.id.uuidString }?.limit == 100, "Zero-spend categories retain their allocated budget")
        check(rows.first { $0.id == LedgerCategoryKey.of(historical) }?.spent == 3, "A new category with the same name must not absorb deleted-category history")
        let period = Calendar.current.dateInterval(of: .month, for: now)!
        let first = entry(100, categoryID: a.id, date: period.start)
        let last = entry(200, categoryID: a.id, date: period.end.addingTimeInterval(-1))
        let next = entry(400, categoryID: a.id, date: period.end)
        let nextIncome = entry(800, categoryID: a.id, kind: .income, date: period.end)
        let boundaryEntries = [first, last, next, nextIncome]
        let boundaryRows = CategorySpendingSummary.rows(entries: boundaryEntries, categories: [a,b], budgets: [], month: now, currency: "RON")
        check(boundaryRows.first { $0.id == a.id.uuidString }?.spent == 3,
              "The category chart must include the month start and exclude the next month start")
        check(LedgerMath.total(.expense, entries: boundaryEntries, month: now, currency: "RON") == 3 &&
              LedgerMath.total(.income, entries: boundaryEntries, month: now, currency: "RON") == 0,
              "Monthly cards must not count next-month midnight transactions in the previous month")
        check(LedgerMath.total(.expense, entries: boundaryEntries, month: period.end, currency: "RON") == 4,
              "A transaction at the next month start belongs to that next month exactly once")
        let oldRows = CategorySpendingSummary.rows(entries: entries, categories: [a,b], budgets: limits, month: previous, currency: "RON")
        check(oldRows.first { $0.id == a.id.uuidString }?.spent == 15 && oldRows.first { $0.id == a.id.uuidString }?.limit == 999, "Category drill-down keeps period-specific budgets and spending")
    }

    static func categoryBudgetChecks(context: ModelContext, account: BudgetAccount) throws {
        let category = try ExpenseRepository.saveCategory(name: "Limită test", emoji: "🪴", in: context)
        let otherCategory = try ExpenseRepository.saveCategory(name: "A doua limită", emoji: "🎟️", in: context)
        let thisMonth = LedgerMath.monthKey(.now)
        let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: .now)!
        try LedgerRepository.saveBudget(month: .now, currency: "RON", money: money("150"), categoryID: category.id, in: context)
        try LedgerRepository.saveBudget(month: .now, currency: "RON", money: money("200.25"), categoryID: category.id, in: context)
        try LedgerRepository.saveBudget(month: .now, currency: "RON", money: money("100"), categoryID: otherCategory.id, in: context)
        try LedgerRepository.saveBudget(month: .now, currency: "EUR", money: money("50"), categoryID: category.id, in: context)
        try LedgerRepository.saveBudget(month: nextMonth, currency: "RON", money: money("300"), categoryID: category.id, in: context)
        let all = try context.fetch(FetchDescriptor<MonthlyBudget>())
        let matches = all.filter { $0.categoryID == category.id && $0.currencyCode == "RON" && $0.monthKey == thisMonth }
        check(matches.count == 1 && matches[0].limitMinorUnits == 20025, "Category limits must upsert with exact precision")
        check(all.first { $0.categoryID == nil && $0.monthKey == thisMonth }?.limitMinorUnits == 550000, "Category edits must preserve the overall budget")
        check(all.filter { $0.categoryID == category.id }.count == 3, "Month and currency keep independent category limits")
        let salary = try context.fetch(FetchDescriptor<ExpenseCategory>()).first { $0.systemKey == "salary" }!
        try reject(.missingCategory) { try LedgerRepository.saveBudget(month: .now, currency: "RON", money: money("10"), categoryID: salary.id, in: context) }
        try reject(.missingCategory) { try LedgerRepository.saveBudget(month: .now, currency: "RON", money: money("10"), categoryID: UUID(), in: context) }
        try reject(.invalidAmount) { try LedgerRepository.saveBudget(month: .now, currency: "RON", money: MoneyAmount(minorUnits: 0, fractionDigits: 2), categoryID: category.id, in: context) }
        let unbounded = MonthlyBudgetProgress(spent: 25, limit: nil)
        check(unbounded.remaining == nil && unbounded.fraction == 0, "An unset limit must not imply zero available money")
        let exceeded = MonthlyBudgetProgress(spent: Decimal(string: "250.50")!, limit: Decimal(string: "200.25")!)
        check(exceeded.isExceeded && exceeded.remaining == Decimal(string: "-50.25") && exceeded.fraction == 1, "Overspending remains exact and caps the visual rail")
        let empty = MonthlyBudgetProgress(spent: 0, limit: 100)
        check(empty.remaining == 100 && empty.fraction == 0, "Categories without transactions must support budgets")
        check(unbounded.status == .neutral && MonthlyBudgetProgress(spent: 20, limit: 0).status == .neutral,
              "Missing or invalid caps must not generate spending alerts")
        check(MonthlyBudgetProgress(spent: Decimal(string: "79.99")!, limit: 100).status == .neutral,
              "Spending below eighty percent must remain neutral")
        check(MonthlyBudgetProgress(spent: 80, limit: 100).status == .warning,
              "The exact eighty percent boundary must show a warning")
        check(MonthlyBudgetProgress(spent: 100, limit: 100).status == .warning,
              "An exhausted cap is a warning until it is actually exceeded")
        check(MonthlyBudgetProgress(spent: Decimal(string: "100.01")!, limit: 100).status == .exceeded,
              "One minor unit above the budget must be overspending")
        check(MonthlyBudgetProgress(spent: Decimal(string: "160.20")!, limit: Decimal(string: "200.25")!).status == .warning &&
              MonthlyBudgetProgress(spent: Decimal(string: "160.19")!, limit: Decimal(string: "200.25")!).status == .neutral,
              "The warning threshold must remain exact for fractional category budgets")

        try ExpenseRepository.deleteCategory(category, in: context)
        let remaining = try context.fetch(FetchDescriptor<MonthlyBudget>())
        check(!remaining.contains { $0.categoryID == category.id }, "Deleting a category must remove only its limits")
        check(remaining.filter { $0.categoryID == nil }.count == 2 && remaining.contains { $0.categoryID == otherCategory.id }, "Deleting a category preserves the overall and other category limits")
    }

    static func subscriptionCategoryUpgradeChecks() throws {
        let db = BudgetDatabase(inMemory: true, preferredCurrency: "RON")
        let context = db.container!.mainContext
        let keys = Set(ExpenseCategory.subscriptionDefaults.map(\.key))
        let initial = try context.fetch(FetchDescriptor<ExpenseCategory>())
        check(initial.filter { $0.kindRawValue == "expense" }.count == 12, "Fresh installs must have exactly three extra subscription categories")
        check(initial.filter { keys.contains($0.systemKey ?? "") }.count == 3, "Fresh seeding must not duplicate additive categories")
        let streaming = initial.first { $0.systemKey == "subscriptions-streaming" }!
        try ExpenseRepository.deleteCategory(streaming, in: context)
        try BudgetDatabase.seedCategories(in: context)
        check(try context.fetch(FetchDescriptor<ExpenseCategory>()).allSatisfy { $0.systemKey != "subscriptions-streaming" },
              "Restarting must respect the deletion of a newly added category")

        let old = try ModelContainer(for: BudgetDatabase.schema, configurations: [
            ModelConfiguration(schema: BudgetDatabase.schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        ])
        let previous = old.mainContext; previous.autosaveEnabled = false
        previous.insert(BudgetMetadata())
        let custom = ExpenseCategory(name: "streaming", emoji: "🎞️", sortOrder: 37)
        let customID = custom.id; previous.insert(custom); try previous.save()
        try BudgetDatabase.seedCategories(in: previous)
        try BudgetDatabase.seedCategories(in: previous)
        let upgraded = try previous.fetch(FetchDescriptor<ExpenseCategory>())
        check(upgraded.count == 3, "Existing stores add only missing categories and must not duplicate a custom equivalent")
        check(upgraded.first { $0.id == customID }?.systemKey == nil, "The custom category retains its identity and custom semantics")
        check(upgraded.allSatisfy { $0.kindRawValue == "expense" }, "New subscription categories must be expenses")
        check(upgraded.allSatisfy { $0.systemKey != "groceries" }, "An upgrade must not resurrect older categories the user removed")
        check(try LedgerRepository.entries(in: previous).isEmpty, "Adding categories must not create financial transactions")

        let samples = BudgetDatabase(inMemory: true, preferredCurrency: "RON")
        let sampleContext = samples.container!.mainContext
        try PaymentCalendarExamples.prepare(currency: "RON", asOf: .now, in: sampleContext)
        let all = try sampleContext.fetch(FetchDescriptor<ExpenseCategory>())
        let generic = all.first { $0.systemKey == "subscriptions" }!
        let transport = all.first { $0.systemKey == "transport" }!
        let netflix = try LedgerRepository.rule(PaymentCalendarExamples.ids[1], in: sampleContext)!
        func assign(_ category: ExpenseCategory) {
            netflix.categoryID = category.id; netflix.categoryNameSnapshot = category.name
            netflix.categoryEmojiSnapshot = category.emoji; netflix.categorySystemKey = category.systemKey
        }
        assign(generic); netflix.merchant = "Netflix personalizat"; try sampleContext.save()
        try PaymentCalendarExamples.refreshCategoryAssignments(in: sampleContext)
        check(netflix.categoryID == generic.id, "Customized sample rules must not be reclassified")
        netflix.merchant = "Netflix"; try sampleContext.save()
        try PaymentCalendarExamples.refreshCategoryAssignments(in: sampleContext)
        check(netflix.categorySystemKey == "subscriptions-streaming", "Original subscription samples should use their specific category")
        assign(transport); try sampleContext.save()
        try PaymentCalendarExamples.refreshCategoryAssignments(in: sampleContext)
        check(netflix.categoryID == transport.id, "A user's category override must be preserved")
    }

    static func paymentCalendarChecks() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Bucharest")!
        func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
            calendar.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
        }
        let now = date(2026, 11, 19)
        func plan(_ due: Date, frequency: RepeatFrequency = .monthly, interval: Int = 1) -> RecurrenceRule {
            let rule = RecurrenceRule(); rule.anchorDate = due; rule.nextDueDate = due
            rule.frequencyRawValue = frequency.rawValue; rule.interval = interval
            rule.amountMinorUnits = 4900; rule.timeZoneIdentifier = calendar.timeZone.identifier
            return rule
        }
        func items(_ rules: [RecurrenceRule], _ month: Date, entries: [LedgerEntry] = []) -> [PaymentCalendarItem] {
            PaymentCalendarProjection.items(rules: rules, entries: entries, month: month,
                currency: "RON", asOf: now, calendar: calendar)
        }
        let monthly = plan(date(2026, 11, 20))
        check(items([monthly], date(2026, 12, 1)).first?.dueDate == date(2026, 12, 20),
              "December must show recurring plans even when November has not been confirmed")
        check(monthly.nextDueDate == date(2026, 11, 20), "Forecasting cannot advance or book a schedule")
        check(items([monthly], date(2026, 10, 1)).isEmpty, "A plan must not project before its start")
        let short = plan(date(2025, 1, 31))
        check(items([short], date(2025, 2, 1)).first?.dueDate == date(2025, 2, 28), "Forecast clamps February")
        check(items([short], date(2025, 3, 1)).first?.dueDate == date(2025, 3, 31), "Forecast preserves the original day after February")
        let last = plan(date(2026, 4, 30)); last.usesLastDay = true
        check(items([last], date(2026, 5, 1)).first?.dueDate == date(2026, 5, 31), "Last-day forecast follows month length")
        let leap = plan(date(2024, 2, 29), frequency: .yearly)
        check(items([leap], date(2028, 2, 1)).first?.dueDate == date(2028, 2, 29), "Leap-day yearly forecast must recover Feb 29")
        let alternate = plan(date(2026, 11, 22), interval: 2)
        check(items([alternate], date(2026, 12, 1)).isEmpty && items([alternate], date(2027, 1, 1)).count == 1,
              "Intervals must not turn into monthly charges")
        let weekly = plan(date(2026, 11, 2), frequency: .weekly)
        check(items([weekly], date(2026, 12, 1)).map { calendar.component(.day, from: $0.dueDate) } == [7, 14, 21, 28],
              "Weekly plans must retain weekday and all occurrences")
        monthly.endDate = date(2026, 12, 20)
        check(items([monthly], date(2026, 12, 1)).count == 1 && items([monthly], date(2027, 1, 1)).isEmpty,
              "End date is inclusive and stops future projections")
        monthly.isActive = false
        check(items([monthly], date(2026, 12, 1)).isEmpty, "Paused plans must not project future charges")
        monthly.isActive = true
        monthly.kindRawValue = "income"
        check(items([monthly], date(2026, 12, 1)).isEmpty, "Payment calendar excludes recurring income")
        monthly.kindRawValue = "expense"; monthly.currencyCode = "EUR"
        check(items([monthly], date(2026, 12, 1)).isEmpty, "Currencies cannot be mixed in payment totals")
        let us = plan(date(2026, 11, 20)); us.timeZoneIdentifier = "America/New_York"
        let firstMidnight = calendar.date(from: DateComponents(year: 2026, month: 12, day: 1))!
        let usDate = items([us], firstMidnight).first!.dueDate
        check(us.calendar.component(.month, from: usDate) == 12, "Selecting December must not shift to November in a western timezone")
        let recorded = plan(date(2026, 11, 10))
        let payment = LedgerEntry(); payment.recurrenceRuleID = recorded.id
        payment.occurrenceKey = RecurrenceSchedule.occurrenceKey(rule: recorded, date: recorded.nextDueDate)
        payment.amountMinorUnits = 5100; payment.occurredAt = date(2026, 11, 12)
        RecurrenceSchedule.advance(recorded)
        let paid = items([recorded], date(2026, 11, 1), entries: [payment])
        check(paid.count == 1 && paid[0].state == .recorded && paid[0].money.minorUnits == 5100,
              "Recorded payments remain visible at the original due date with the actual amount after advancing")
        check(paid[0].dueDate == date(2026, 11, 10), "Recorded occurrence uses due date, even when payment date differs")
        recorded.isActive = false
        check(items([recorded], date(2026, 11, 1), entries: [payment]).count == 1, "Pausing preserves recorded payment history")
        payment.statusRawValue = "pending"
        check(items([recorded], date(2026, 11, 1), entries: [payment]).isEmpty, "Pending transactions cannot appear as recorded payments")
        let overdue = plan(date(2026, 11, 18))
        check(items([overdue], now).first?.state == .unrecorded && items([overdue], now).first?.canConfirm == true,
              "Past current due dates must be labelled unrecorded and allow confirmation")
        check(items([overdue], date(2026, 12, 1)).first?.canConfirm == false, "Future forecasts cannot be confirmed prematurely")

        for days in 0...3 {
            let candidate = plan(date(2026, 11, 19 + days))
            let item = items([candidate], now).first!
            check(item.daysUntilDue == days && item.state == (days <= 2 ? .dueSoon : .planned),
                  "Warning must include today and exactly two calendar days, but exclude the third day")
        }
        let later = plan(date(2026, 11, 25))
        payment.statusRawValue = "confirmed"
        let grouped = items([recorded, later], now, entries: [payment])
        check(grouped.map(\.ruleID) == [later.id, recorded.id], "Recorded payments must sort after all upcoming payments, even when their due date is earlier")
        check(items([recorded, later], date(2026, 12, 1), entries: [payment]).allSatisfy { $0.state != .recorded },
              "November recorded status must never carry into December")
        let newYork = plan(date(2026, 11, 21)); newYork.timeZoneIdentifier = "America/New_York"
        let lateFriday = newYork.calendar.date(from: DateComponents(year: 2026, month: 11, day: 19, hour: 23, minute: 59))!
        let localWarning = PaymentCalendarProjection.items(rules: [newYork], entries: [], month: now,
            currency: "RON", asOf: lateFriday, calendar: calendar).first!
        check(localWarning.state == .dueSoon && localWarning.daysUntilDue == 2, "Warning uses calendar days in the rule timezone rather than rounded hours")

        for days in 0...4 {
            let candidate = plan(date(2026, 11, 19 + days))
            let item = items([candidate], now).first!
            check(item.badgeCountdownDays == (days <= 3 ? days : nil), "Mini-calendar must show relative days through day three, then return to the date")
        }
        let recordedBadge = items([recorded], now, entries: [payment]).first!
        check(recordedBadge.badgeCountdownDays == nil, "Recorded occurrences retain their original calendar date rather than a countdown")
        check(items([overdue], now).first!.badgeCountdownDays == nil, "Past dates must never be presented as an upcoming countdown")

        let db = BudgetDatabase(inMemory: true, preferredCurrency: "RON")
        let context = db.container!.mainContext
        try PaymentCalendarExamples.prepare(currency: "RON", asOf: now, in: context)
        try PaymentCalendarExamples.prepare(currency: "RON", asOf: now, in: context)
        let examples = try context.fetch(FetchDescriptor<RecurrenceRule>())
        check(examples.count == 4 && items(examples, date(2026, 12, 1)).count == 4, "Four samples must seed once and project into December")
        check(try LedgerRepository.entries(in: context).isEmpty, "Demo schedules cannot insert expenses or change account balances")
        let custom = plan(date(2026, 11, 21)); context.insert(custom); try context.save()
        let removed = try PaymentCalendarExamples.remove(in: context)
        check(try context.fetchCount(FetchDescriptor<RecurrenceRule>()) == 1, "Removing examples must preserve personal rules")
        try PaymentCalendarExamples.prepare(currency: "RON", asOf: now, in: context)
        check(try context.fetchCount(FetchDescriptor<RecurrenceRule>()) == 1, "Removed samples must not reappear on subsequent launches")
        try removed.undo?()
        check(try context.fetchCount(FetchDescriptor<RecurrenceRule>()) == 5, "Undo sample cleanup must restore all schedules")
    }

    static func recurrenceChecks(context: ModelContext, account: BudgetAccount) throws {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(identifier: "Europe/Bucharest")!
        func date(_ y: Int, _ m: Int, _ d: Int) -> Date { calendar.date(from: DateComponents(year: y, month: m, day: d, hour: 12))! }
        let jan = date(2025, 1, 31)
        let feb = RecurrenceSchedule.next(after: jan, anchor: jan, frequency: .monthly, interval: 1, lastDay: false, calendar: calendar)
        let march = RecurrenceSchedule.next(after: feb, anchor: jan, frequency: .monthly, interval: 1, lastDay: false, calendar: calendar)
        check(calendar.component(.day, from: feb) == 28, "Monthly rules must handle short months")
        check(calendar.component(.day, from: march) == 31, "February must not shift a 31st-day rule permanently")
        let april = date(2025, 4, 30)
        let may = RecurrenceSchedule.next(after: april, anchor: april, frequency: .monthly, interval: 1, lastDay: true, calendar: calendar)
        check(calendar.component(.day, from: may) == 31, "Last-day rules must remain last-day rules")
        let leap = date(2024, 2, 29)
        let ordinary = RecurrenceSchedule.next(after: leap, anchor: leap, frequency: .yearly, interval: 1, lastDay: false, calendar: calendar)
        check(calendar.component(.day, from: ordinary) == 28, "Yearly leap-day rules must clamp safely")
        let input = EntryInput(kind: .expense, money: money("49"), accountID: account.id, merchant: "Abonament")
        try LedgerRepository.saveRule(input: input, frequency: .monthly, interval: 1, nextDue: jan,
                                      end: nil, lastDay: false, in: context)
        let rule = try context.fetch(FetchDescriptor<RecurrenceRule>()).first!
        let due = rule.nextDueDate
        let before = try total(.expense, context)
        check(before == Decimal(string: "85.50"), "Creating a recurring rule must not book an actual expense")
        let confirmation = try LedgerRepository.confirmOccurrence(rule: rule, dueDate: due, input: input, in: context)
        check(try total(.expense, context) == before + 49, "Confirmed occurrences must become real expenses")
        try reject(.alreadyHandled) { _ = try LedgerRepository.confirmOccurrence(rule: rule, dueDate: due, input: input, in: context) }
        try confirmation.undo?()
        check(rule.nextDueDate == due && rule.isActive, "Undo confirmation must restore the original due date")
        check(try total(.expense, context) == before, "Undo confirmation must remove its transaction")
        let skipped = try LedgerRepository.skipOccurrence(rule, in: context)
        check(rule.nextDueDate > due, "Skipping must advance the schedule")
        try skipped.undo?()
        check(rule.nextDueDate == due, "Undo skip must restore the schedule")
        try LedgerRepository.toggleRule(rule, in: context)
        check(!rule.isActive, "Pause must stop upcoming occurrences")
        try LedgerRepository.toggleRule(rule, in: context)
        check(rule.isActive, "Resume must reactivate the rule")
        let repeated = try LedgerRepository.saveEntry(input: input, repeatFrequency: .monthly, in: context)
        check(try LedgerRepository.entry(repeated.entryID!, in: context)?.recurrenceRuleID != nil, "Repeated manual entries must link to their future rule")
        let count = try context.fetchCount(FetchDescriptor<RecurrenceRule>())
        try repeated.undo?()
        check(try context.fetchCount(FetchDescriptor<RecurrenceRule>()) == count - 1, "Undo initial repeating entry must remove its new rule too")
    }

    static func migrationChecks(at url: URL) throws {
        func open() throws -> ModelContainer {
            try ModelContainer(for: BudgetDatabase.schema, configurations: [
                ModelConfiguration("Budget", schema: BudgetDatabase.schema, url: url, cloudKitDatabase: .none)
            ])
        }
        let first = try open()
        first.mainContext.autosaveEnabled = false
        try BudgetDatabase.seedCategories(in: first.mainContext)
        try LedgerBootstrap.run(in: first.mainContext, preferredCurrency: "RON")
        try LedgerBootstrap.run(in: first.mainContext, preferredCurrency: "RON")
        let entries = try LedgerRepository.entries(in: first.mainContext)
        check(entries.count == 2, "Legacy expenses must migrate exactly once")
        check(entries.first { $0.merchant == "Istoric păstrat" }?.amountMinorUnits == 1250, "Migration must retain exact amounts")
        check(entries.filter(\.isConfirmed).count == 1, "Migration must preserve pending status")
        check(try LedgerRepository.accounts(in: first.mainContext).count == 2, "Legacy currencies must receive separate accounts")
        let migratedCategories = try first.mainContext.fetch(FetchDescriptor<ExpenseCategory>()).filter { $0.kindRawValue == "expense" }
        let subscriptionKeys = Set(ExpenseCategory.subscriptionDefaults.map(\.key))
        check(migratedCategories.filter { !subscriptionKeys.contains($0.systemKey ?? "") }.count == 1,
              "Migration must not resurrect previously deleted default categories")
        check(migratedCategories.filter { subscriptionKeys.contains($0.systemKey ?? "") }.count == 3,
              "Existing financial stores must receive the three newly introduced subscription categories once")
        let firstAccount = try LedgerRepository.accounts(in: first.mainContext).first { $0.currencyCode == "RON" }!
        let input = EntryInput(kind: .income, money: money("7000"), accountID: firstAccount.id, merchant: "Venit persistent")
        _ = try LedgerRepository.saveEntry(input: input, in: first.mainContext)
        try LedgerRepository.saveBudget(month: .now, currency: "RON", money: money("5000"), in: first.mainContext)
        try LedgerRepository.saveRule(input: input, frequency: .monthly, interval: 1, nextDue: .now,
                                      end: nil, lastDay: true, in: first.mainContext)
        let category = try first.mainContext.fetch(FetchDescriptor<ExpenseCategory>()).first { $0.kindRawValue == "expense" }!
        try LedgerRepository.saveBudget(month: .now, currency: "RON", money: money("125.50"), categoryID: category.id, in: first.mainContext)
        let second = try open()
        let persistedBudgets = try second.mainContext.fetch(FetchDescriptor<MonthlyBudget>())
        check(persistedBudgets.count == 2, "Overall and category budgets must survive reopening")
        check(persistedBudgets.first { $0.categoryID == nil }?.limitMinorUnits == 500000, "Reopening must preserve the overall budget identity")
        check(persistedBudgets.first { $0.categoryID == category.id }?.limitMinorUnits == 12550, "Reopening must preserve the category link and exact limit")
        let restoredRule = try second.mainContext.fetch(FetchDescriptor<RecurrenceRule>()).first!
        check(restoredRule.amountMinorUnits == 700000 && restoredRule.kind == .income, "Income recurrence templates must survive reopening")
        check(restoredRule.calendar.component(.day, from: restoredRule.nextDueDate) == restoredRule.calendar.range(of: .day, in: .month, for: restoredRule.nextDueDate)!.count,
              "Last-day selection must normalize the first due date too")
        check(try LedgerRepository.entries(in: second.mainContext).count == 3, "Migrated data must survive reopening the store")
        check(try LedgerRepository.accounts(in: second.mainContext).allSatisfy { $0.openingMinorUnits == 0 }, "Migration must not double-count opening balances")
    }
    static func previousBudgetMigration(at url: URL) throws {
        func open() throws -> ModelContainer {
            try ModelContainer(for: BudgetDatabase.schema, configurations: [
                ModelConfiguration("Budget", schema: BudgetDatabase.schema, url: url, cloudKitDatabase: .none)
            ])
        }
        let first = try open()
        first.mainContext.autosaveEnabled = false
        let context = first.mainContext
        let budget = try context.fetch(FetchDescriptor<MonthlyBudget>()).first!
        check(budget.categoryID == nil && budget.limitMinorUnits == 550025, "Existing monthly budgets must migrate as overall limits without changing their amount")
        let category = try context.fetch(FetchDescriptor<ExpenseCategory>()).first!
        let month = Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 15))!
        try LedgerRepository.saveBudget(month: month, currency: "RON", money: money("250.75"), categoryID: category.id, in: context)
        let second = try open()
        let limits = try second.mainContext.fetch(FetchDescriptor<MonthlyBudget>())
        check(limits.count == 2 && limits.first { $0.categoryID == nil }?.limitMinorUnits == 550025, "Adding category limits to an upgraded store must preserve its overall budget")
        check(limits.first { $0.categoryID == category.id }?.limitMinorUnits == 25075, "New category budgets must persist in upgraded stores")
        let entry = try LedgerRepository.entries(in: second.mainContext).first!
        check(entry.amountMinorUnits == 18025 && entry.categoryID == category.id, "Migration must preserve transactions and category links")
        check(try LedgerRepository.accounts(in: second.mainContext).first?.openingMinorUnits == 12345, "Migration must preserve opening balances")
    }

    static func money(_ value: String) -> MoneyAmount { MoneyAmount.parse(value, currencyCode: "RON")! }
    static func balance(_ account: BudgetAccount, _ context: ModelContext) throws -> Decimal {
        LedgerMath.balance(account: account, entries: try LedgerRepository.entries(in: context))
    }
    static func total(_ kind: EntryKind, _ context: ModelContext) throws -> Decimal {
        LedgerMath.total(kind, entries: try LedgerRepository.entries(in: context), month: .now, currency: "RON")
    }
    static func reject(_ failure: LedgerRepository.Failure, action: () throws -> Void) throws {
        do { try action(); fatalError("Expected rejection: \(failure)") }
        catch let actual as LedgerRepository.Failure { check(actual == failure, "Wrong validation failure") }
    }
    static func check(_ value: Bool, _ message: String) { if !value { fatalError(message) } }
}
