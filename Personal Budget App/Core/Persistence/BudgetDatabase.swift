import Foundation
import Observation
import SwiftData

@Model
final class BudgetMetadata {
    var key: String = "initial-categories-v1"
    var createdAt: Date = Date.now
    init() { }
}

@MainActor
@Observable
final class BudgetDatabase {
    private(set) var container: ModelContainer?
    private(set) var failedToOpen = false

    static var schema: Schema {
        Schema([Expense.self, ExpenseCategory.self, BudgetMetadata.self, BudgetAccount.self, LedgerEntry.self, RecurrenceRule.self, MonthlyBudget.self])
    }

    @ObservationIgnored private let inMemory: Bool
    @ObservationIgnored private var preferredCurrency: String?

    init(inMemory: Bool = false, preferredCurrency: String? = nil) {
        self.inMemory = inMemory
        self.preferredCurrency = preferredCurrency
        open()
    }

    func open() {
        do {
            let configuration = ModelConfiguration("Budget", schema: Self.schema, isStoredInMemoryOnly: inMemory, cloudKitDatabase: .none)
            let container = try ModelContainer(for: Self.schema, configurations: [configuration])
            container.mainContext.autosaveEnabled = false
            try Self.seedCategories(in: container.mainContext)
            if let preferredCurrency {
                try LedgerBootstrap.run(in: container.mainContext, preferredCurrency: preferredCurrency)
            }
            self.container = container
            failedToOpen = false
        } catch {
            // Never silently replace a failed financial store with an empty in-memory database.
            container = nil
            failedToOpen = true
        }
    }

    func configure(currency: String) {
        preferredCurrency = currency
        guard let container else { return }
        do { try LedgerBootstrap.run(in: container.mainContext, preferredCurrency: currency) }
        catch { self.container = nil; failedToOpen = true }
    }

    static func seedCategories(in context: ModelContext) throws {
        let metadata = try context.fetch(FetchDescriptor<BudgetMetadata>())
        if !metadata.contains(where: { $0.key == "initial-categories-v1" }) {
            let existing = try context.fetch(FetchDescriptor<ExpenseCategory>())
            for (index, item) in ExpenseCategory.defaults.enumerated() {
                if !existing.contains(where: { $0.systemKey == item.key }) {
                    context.insert(ExpenseCategory(name: item.name, emoji: item.emoji, sortOrder: index, systemKey: item.key))
                }
            }
            context.insert(BudgetMetadata())
        }
        // An additive, one-time upgrade never re-creates previously deleted categories.
        if !metadata.contains(where: { $0.key == "subscription-categories-v1" }) {
            let existing = try context.fetch(FetchDescriptor<ExpenseCategory>())
            let start = (existing.map(\.sortOrder).max() ?? -1) + 1
            func normalized(_ name: String) -> String {
                name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "ro_RO"))
            }
            for (index, item) in ExpenseCategory.subscriptionDefaults.enumerated() {
                let present = existing.contains {
                    $0.kindRawValue == EntryKind.expense.rawValue &&
                    ($0.systemKey == item.key || normalized($0.name) == normalized(item.name))
                }
                if !present {
                    context.insert(ExpenseCategory(name: item.name, emoji: item.emoji, sortOrder: start + index, systemKey: item.key))
                }
            }
            let marker = BudgetMetadata(); marker.key = "subscription-categories-v1"; context.insert(marker)
        }
        try context.save()
    }
}
