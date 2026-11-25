import Foundation
import SwiftData

@main
@MainActor
struct ExpenseChecks {
    static func main() throws {
        expect(MoneyAmount.parse("85,50", currencyCode: "RON")?.minorUnits == 8550, "Comma decimals must remain exact")
        expect(MoneyAmount.parse("85.50", currencyCode: "RON")?.minorUnits == 8550, "Period decimals must remain exact")
        expect(MoneyAmount.parse("0.01", currencyCode: "RON")?.minorUnits == 1, "One minor unit cannot be rounded away")
        expect(MoneyAmount.parse("0", currencyCode: "RON") == nil, "Zero is not an expense")
        expect(MoneyAmount.parse("-5", currencyCode: "RON") == nil, "Negative manual amounts must be rejected")
        expect(MoneyAmount.parse("1,234.56", currencyCode: "RON") == nil, "Ambiguous grouping must not be guessed")
        expect(MoneyAmount.parse("5abc", currencyCode: "RON") == nil, "Partial number parsing is unsafe")
        expect(MoneyAmount.parse("1.001", currencyCode: "RON") == nil, "Excess precision must not be silently rounded")
        expect(MoneyAmount.parse("1", currencyCode: "INVALID") == nil, "Unsupported currencies must be rejected")
        expect(MoneyAmount.parse("999999999999999999999", currencyCode: "RON") == nil, "Overflow must be rejected")
        expect(MoneyAmount.fractionDigits(for: "JPY") == 0, "JPY must not be treated as a two-decimal currency")
        expect(MoneyAmount.parse("50", currencyCode: "JPY")?.minorUnits == 50, "JPY amounts are whole units")
        expect(MoneyAmount.parse("50.1", currencyCode: "JPY") == nil, "JPY cannot have fractional units")
        expect(MoneyAmount.fractionDigits(for: "KWD") == 3, "Three-decimal currencies must be supported")
        expect(MoneyAmount.parse("1.234", currencyCode: "KWD")?.minorUnits == 1234, "KWD precision must remain exact")

        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("budget-model-checks-\(UUID())")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("checks.store")
        let expenseID = try exerciseStore(at: url)
        try verifyRelaunch(at: url, expenseID: expenseID)

        var transcript = DictationTranscript()
        transcript.beginSession()
        transcript.updatePartial("Prima cheltuială")
        transcript.finishSession()
        transcript.beginSession()
        transcript.updatePartial("Text greșit")
        transcript.discardCurrentSession()
        expect(transcript.text == "Prima cheltuială", "X must discard only the current session")
        transcript.beginSession()
        transcript.updatePartial("Finalizat devreme")
        transcript.finishSession()
        transcript.discardCurrentSession()
        expect(transcript.text == "Prima cheltuială", "X must also discard an already finalized current session")
        transcript.beginSession()
        transcript.discardCurrentSession()
        expect(transcript.text == "Prima cheltuială", "Cancelling before speech begins must preserve prior text")
        transcript.clear()
        transcript.discardCurrentSession()
        expect(transcript.text.isEmpty, "Clear must also reset the cancellation checkpoint")

        expect(ExpenseEntryRoute(url: URL(string: "personalbudget://add/manual")!) == .manual, "Manual widget URL must route correctly")
        expect(ExpenseEntryRoute(url: URL(string: "personalbudget://add/income")!) == .income, "Voice widget URL must route correctly")
        expect(ExpenseEntryRoute(url: URL(string: "https://add/manual")!) == nil, "Unrelated URLs must not open expense entry")
        expect(ExpenseEntryRoute(url: URL(string: "personalbudget://add/unknown")!) == nil, "Unknown actions must be ignored")
        print("Passed: exact money, pending/confirmed persistence, idempotent validation, category deletion, seeding, routing and voice cancellation.")
    }

    static func makeContainer(at url: URL) throws -> ModelContainer {
        let configuration = ModelConfiguration("Checks", schema: BudgetDatabase.schema, url: url, cloudKitDatabase: .none)
        return try ModelContainer(for: BudgetDatabase.schema, configurations: [configuration])
    }

    static func exerciseStore(at url: URL) throws -> UUID {
        let container = try makeContainer(at: url)
        let context = container.mainContext
        context.autosaveEnabled = false
        try BudgetDatabase.seedCategories(in: context)
        try BudgetDatabase.seedCategories(in: context)
        let categories = try context.fetch(FetchDescriptor<ExpenseCategory>())
        expect(categories.count == ExpenseCategory.defaults.count, "Default categories must be seeded once")

        let custom = try ExpenseRepository.saveCategory(name: "Cafeaua mea", emoji: "☕️", in: context)
        do {
            try ExpenseRepository.saveCategory(name: "  CAFEAUA MEA  ", emoji: "☕️", in: context)
            fatalError("Duplicate names must be rejected")
        } catch ExpenseRepository.ValidationError.duplicateCategory { }
        do {
            try ExpenseRepository.saveCategory(name: "Fără simbol", emoji: "abc", in: context)
            fatalError("Non-emoji text must be rejected")
        } catch ExpenseRepository.ValidationError.invalidEmoji { }

        let keycap = try ExpenseRepository.saveCategory(name: "Numere", emoji: "1️⃣", in: context)
        try ExpenseRepository.deleteCategory(keycap, in: context)

        let input = ExpenseInput(money: MoneyAmount.parse("85,50", currencyCode: "RON")!,
                                 currencyCode: "RON", occurredAt: Date.now, categoryID: custom.id, merchant: "  Lidl  ")
        let pending = try ExpenseRepository.createPending(input, in: context)
        expect(pending.status == .pending && pending.confirmedAt == nil, "Manual entry must always await review")
        expect(pending.category?.id == custom.id, "The category relationship must be persisted")
        expect(pending.merchant == "Lidl", "Merchant labels must be trimmed")
        try expect(try confirmedTotal(in: context) == 0, "Pending expenses must not enter totals")

        try ExpenseRepository.confirm(pending, input: input, in: context)
        try ExpenseRepository.confirm(pending, input: input, in: context)
        try expect(try context.fetchCount(FetchDescriptor<Expense>()) == 1, "Repeated validation must not create duplicates")
        try expect(try confirmedTotal(in: context) == Decimal(string: "85.50"), "Only the confirmed amount enters totals")
        expect(pending.confirmedAt != nil, "Confirmation must retain its own timestamp")

        try ExpenseRepository.deleteCategory(custom, in: context)
        expect(pending.category == nil, "Deleting a category must nullify the relationship")
        expect(pending.categoryName == "Cafeaua mea" && pending.categoryEmoji == "☕️", "History must retain its category label")
        try expect(try context.fetchCount(FetchDescriptor<Expense>()) == 1, "Deleting a category must preserve financial history")

        let rejected = try ExpenseRepository.createPending(input, in: context)
        try ExpenseRepository.discard(rejected, in: context)
        try expect(try context.fetchCount(FetchDescriptor<Expense>()) == 1, "Discard must remove only the pending proposal")
        try ExpenseRepository.discard(pending, in: context)
        try expect(try context.fetchCount(FetchDescriptor<Expense>()) == 1, "A confirmed expense cannot be discarded as pending")

        // A pending proposal must survive process recreation too.
        try ExpenseRepository.createPending(ExpenseInput(
            money: MoneyAmount.parse("12", currencyCode: "EUR")!, currencyCode: "EUR",
            occurredAt: .now, categoryID: nil, merchant: "De verificat"
        ), in: context)
        for category in try context.fetch(FetchDescriptor<ExpenseCategory>()) {
            try ExpenseRepository.deleteCategory(category, in: context)
        }
        try BudgetDatabase.seedCategories(in: context)
        try expect(try context.fetchCount(FetchDescriptor<ExpenseCategory>()) == 0, "Deleted defaults must not return on reseeding")
        return pending.id
    }

    static func verifyRelaunch(at url: URL, expenseID: UUID) throws {
        let container = try makeContainer(at: url)
        let context = container.mainContext
        try BudgetDatabase.seedCategories(in: context)
        let expenses = try context.fetch(FetchDescriptor<Expense>())
        expect(expenses.count == 2, "Both pending and confirmed expenses must survive reopening")
        let confirmed = expenses.first { $0.id == expenseID }
        expect(confirmed?.status == .confirmed && confirmed?.amountMinorUnits == 8550, "Validated money must survive reopening exactly")
        expect(confirmed?.currencyCode == "RON", "Currency belongs to the expense, independently of preferences")
        expect(confirmed?.categoryName == "Cafeaua mea", "Deleted category snapshots must survive reopening")
        expect(expenses.filter { $0.status == .pending }.count == 1, "Unreviewed proposals must survive reopening")
        try expect(try context.fetchCount(FetchDescriptor<ExpenseCategory>()) == 0, "Deleting every category must be permanent")
    }

    static func confirmedTotal(in context: ModelContext) throws -> Decimal {
        try context.fetch(FetchDescriptor<Expense>(predicate: #Predicate { $0.statusRawValue == "confirmed" }))
            .reduce(Decimal(0)) { $0 + $1.money.decimalValue }
    }

    static func expect(_ value: @autoclosure () throws -> Bool, _ message: String) rethrows {
        guard try value() else { fatalError(message) }
    }
}
