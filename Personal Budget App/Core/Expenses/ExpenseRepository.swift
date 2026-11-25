import Foundation
import SwiftData

@MainActor
enum ExpenseRepository {
    enum ValidationError: LocalizedError {
        case invalidAmount, invalidCategoryName, duplicateCategory, invalidEmoji
        var errorDescription: String? {
            switch self {
            case .invalidAmount: "Verifică suma și moneda cheltuielii."
            case .invalidCategoryName: "Alege un nume între 1 și 40 de caractere."
            case .duplicateCategory: "Există deja o categorie cu acest nume."
            case .invalidEmoji: "Alege un singur emoji pentru categorie."
            }
        }
    }

    @discardableResult
    static func createPending(_ input: ExpenseInput, in context: ModelContext) throws -> Expense {
        try validate(input)
        let category = try findCategory(input.categoryID, in: context)
        let expense = Expense(input: input, category: category)
        context.insert(expense)
        do { try context.save() } catch { context.rollback(); throw error }
        return expense
    }

    static func confirm(_ expense: Expense, input: ExpenseInput, in context: ModelContext) throws {
        guard expense.status == .pending else { return } // Repeated taps cannot duplicate a payment.
        try validate(input)
        let category = try findCategory(input.categoryID, in: context)
        expense.apply(input: input, category: category)
        expense.statusRawValue = ExpenseStatus.confirmed.rawValue
        expense.confirmedAt = .now
        do { try context.save() } catch { context.rollback(); throw error }
    }

    static func discard(_ expense: Expense, in context: ModelContext) throws {
        guard expense.status == .pending else { return }
        context.delete(expense)
        do { try context.save() } catch { context.rollback(); throw error }
    }

    @discardableResult
    static func saveCategory(
        _ category: ExpenseCategory? = nil, name: String, emoji: String, kind: EntryKind = .expense, in context: ModelContext
    ) throws -> ExpenseCategory {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let emoji = emoji.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 40 else { throw ValidationError.invalidCategoryName }
        guard emoji.count == 1,
              emoji.unicodeScalars.contains(where: { $0.properties.isEmojiPresentation })
                || emoji.unicodeScalars.contains(where: { $0.properties.isEmoji })
                    && emoji.unicodeScalars.contains(where: { $0.value == 0xFE0F || $0.value == 0x20E3 }) else {
            throw ValidationError.invalidEmoji
        }
        let categories = try context.fetch(FetchDescriptor<ExpenseCategory>())
        let normalized = normalizedName(name)
        guard !categories.contains(where: { $0.id != category?.id && $0.kindRawValue == kind.rawValue && normalizedName($0.name) == normalized }) else {
            throw ValidationError.duplicateCategory
        }
        let result: ExpenseCategory
        if let category {
            category.name = name
            category.emoji = emoji
            result = category
        } else {
            result = ExpenseCategory(name: name, emoji: emoji, sortOrder: (categories.map(\.sortOrder).max() ?? -1) + 1)
            context.insert(result)
        }
        result.kindRawValue = kind.rawValue
        for entry in try LedgerRepository.entries(in: context) where entry.categoryID == result.id {
            entry.categoryNameSnapshot = name; entry.categoryEmojiSnapshot = emoji
            entry.categorySystemKey = result.systemKey
        }
        for rule in try context.fetch(FetchDescriptor<RecurrenceRule>()) where rule.categoryID == result.id {
            rule.categoryNameSnapshot = name; rule.categoryEmojiSnapshot = emoji
            rule.categorySystemKey = result.systemKey
        }
        do { try context.save() } catch { context.rollback(); throw error }
        return result
    }

    static func deleteCategory(_ category: ExpenseCategory, in context: ModelContext) throws {
        // Explicitly snapshot and unlink before deleting; never cascade into financial history.
        for expense in category.expenses ?? [] {
            expense.categoryNameSnapshot = category.name
            expense.categoryEmojiSnapshot = category.emoji
            expense.category = nil
        }
        for entry in try LedgerRepository.entries(in: context) where entry.categoryID == category.id {
            entry.categoryNameSnapshot = category.name
            entry.categoryEmojiSnapshot = category.emoji
            entry.categoryID = nil
        }
        for rule in try context.fetch(FetchDescriptor<RecurrenceRule>()) where rule.categoryID == category.id {
            rule.categoryNameSnapshot = category.name
            rule.categoryEmojiSnapshot = category.emoji
            rule.categoryID = nil
        }
        // Limits belong to this category; deleting them never touches the overall budget or history.
        for budget in try context.fetch(FetchDescriptor<MonthlyBudget>()) where budget.categoryID == category.id {
            context.delete(budget)
        }
        context.delete(category)
        do { try context.save() } catch { context.rollback(); throw error }
    }

    private static func validate(_ input: ExpenseInput) throws {
        guard input.money.minorUnits > 0,
              CurrencyOption.all.contains(where: { $0.id == input.currencyCode }),
              input.money.fractionDigits == MoneyAmount.fractionDigits(for: input.currencyCode) else {
            throw ValidationError.invalidAmount
        }
    }

    private static func findCategory(_ id: UUID?, in context: ModelContext) throws -> ExpenseCategory? {
        guard let id else { return nil }
        var query = FetchDescriptor<ExpenseCategory>(predicate: #Predicate { $0.id == id })
        query.fetchLimit = 1
        return try context.fetch(query).first
    }

    private static func normalizedName(_ name: String) -> String {
        name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "ro_RO"))
    }
}
