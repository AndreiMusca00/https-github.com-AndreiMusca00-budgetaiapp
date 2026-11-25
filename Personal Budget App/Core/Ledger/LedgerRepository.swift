import Foundation
import SwiftData

@MainActor
enum LedgerRepository {
    enum Failure: LocalizedError {
        case invalidAmount, missingAccount, archivedAccount, sameAccount, missingCategory
        case futureDate, invalidName, currencyLocked, accountInUse, duplicateAccount
        case invalidRecurrence, alreadyHandled
        var errorDescription: String? {
            switch self {
            case .invalidAmount: "Verifică suma și moneda."
            case .missingAccount: "Alege un cont disponibil."
            case .archivedAccount: "Contul este arhivat. Reactivează-l sau alege alt cont."
            case .sameAccount: "Alege două conturi diferite pentru transfer."
            case .missingCategory: "Categoria nu mai este disponibilă. Alege din nou."
            case .futureDate: "Pentru o dată viitoare, adaugă o recurență."
            case .invalidName: "Introdu un nume între 1 și 40 de caractere."
            case .currencyLocked: "Moneda unui cont cu tranzacții sau recurențe nu poate fi schimbată."
            case .accountInUse: "Contul are tranzacții sau recurențe. Îl poți arhiva."
            case .duplicateAccount: "Există deja un cont cu acest nume."
            case .invalidRecurrence: "Verifică frecvența și datele recurenței."
            case .alreadyHandled: "Această scadență a fost deja înregistrată."
            }
        }
    }

    static func entries(in context: ModelContext) throws -> [LedgerEntry] {
        try context.fetch(FetchDescriptor<LedgerEntry>(sortBy: [SortDescriptor(\.occurredAt, order: .reverse)]))
    }
    static func accounts(in context: ModelContext) throws -> [BudgetAccount] {
        try context.fetch(FetchDescriptor<BudgetAccount>(sortBy: [SortDescriptor(\.createdAt)]))
    }
    static func account(_ id: UUID, in context: ModelContext) throws -> BudgetAccount {
        guard let account = try accounts(in: context).first(where: { $0.id == id }) else { throw Failure.missingAccount }
        return account
    }
    static func entry(_ id: UUID, in context: ModelContext) throws -> LedgerEntry? {
        var query = FetchDescriptor<LedgerEntry>(predicate: #Predicate { $0.id == id })
        query.fetchLimit = 1
        return try context.fetch(query).first
    }
    static func rule(_ id: UUID, in context: ModelContext) throws -> RecurrenceRule? {
        var query = FetchDescriptor<RecurrenceRule>(predicate: #Predicate { $0.id == id })
        query.fetchLimit = 1
        return try context.fetch(query).first
    }

    @discardableResult
    static func saveEntry(id: UUID? = nil, input: EntryInput, repeatFrequency: RepeatFrequency? = nil,
                          in context: ModelContext) throws -> LedgerChange {
        let existing = try id.flatMap { try entry($0, in: context) }
        if id != nil && existing == nil { throw Failure.missingAccount }
        let (source, destination, category) = try validate(input, existing: existing, in: context)
        let before = existing.map(EntryRecord.init)
        let result = existing ?? LedgerEntry()
        if existing == nil { context.insert(result) }
        apply(input, source: source, destination: destination, category: category, to: result)
        if let before, before.categoryID == nil, input.categoryID == nil,
           before.kind == input.kind.rawValue, input.kind != .transfer {
            result.categoryNameSnapshot = before.categoryName
            result.categoryEmojiSnapshot = before.categoryEmoji
            result.categorySystemKey = before.categorySystemKey
        }
        var newRuleID: UUID?
        if existing == nil, let repeatFrequency, input.kind != .transfer {
            let rule = RecurrenceRule()
            apply(input, source: source, category: category, to: rule)
            rule.frequencyRawValue = repeatFrequency.rawValue
            rule.anchorDate = RecurrenceSchedule.day(input.occurredAt, calendar: rule.calendar)
            rule.nextDueDate = RecurrenceSchedule.next(after: rule.anchorDate, rule: rule)
            context.insert(rule)
            result.recurrenceRuleID = rule.id
            result.occurrenceKey = RecurrenceSchedule.occurrenceKey(rule: rule, date: rule.anchorDate)
            newRuleID = rule.id
        }
        try commit(context)
        let entryID = result.id
        return LedgerChange(entryID: entryID, message: existing == nil ? "Tranzacție salvată" : "Tranzacție modificată") {
            if let before {
                guard let target = try entry(entryID, in: context) else { throw Failure.missingAccount }
                before.apply(to: target)
            } else if let target = try entry(entryID, in: context) {
                context.delete(target)
                if let newRuleID, let rule = try rule(newRuleID, in: context) { context.delete(rule) }
            }
            try commit(context)
        }
    }

    static func deleteEntry(_ entry: LedgerEntry, in context: ModelContext) throws -> LedgerChange {
        let record = EntryRecord(entry)
        context.delete(entry)
        try commit(context)
        return LedgerChange(message: "Tranzacție ștearsă") {
            _ = try account(record.accountID, in: context)
            if let id = record.destinationID { _ = try account(id, in: context) }
            guard try self.entry(record.id, in: context) == nil else { return }
            let restored = LedgerEntry()
            record.apply(to: restored)
            context.insert(restored)
            try commit(context)
        }
    }

    @discardableResult
    static func saveAccount(_ existing: BudgetAccount? = nil, name: String, emoji: String, currency: String,
                            opening: MoneyAmount, isDefault: Bool, in context: ModelContext) throws -> BudgetAccount {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 40 else { throw Failure.invalidName }
        guard CurrencyOption.all.contains(where: { $0.id == currency }),
              opening.fractionDigits == MoneyAmount.fractionDigits(for: currency) else { throw Failure.invalidAmount }
        let all = try accounts(in: context)
        guard !all.contains(where: { $0.id != existing?.id && $0.name.compare(name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame })
        else { throw Failure.duplicateAccount }
        if let existing, existing.currencyCode != currency, try accountIsUsed(existing.id, in: context) {
            throw Failure.currencyLocked
        }
        let result = existing ?? BudgetAccount(name: name, emoji: emoji, currencyCode: currency)
        if existing == nil { context.insert(result) }
        result.name = name; result.emoji = emoji; result.currencyCode = currency
        result.openingMinorUnits = opening.minorUnits; result.fractionDigits = opening.fractionDigits
        result.updatedAt = .now
        result.isDefault = isDefault || all.isEmpty
        if isDefault || all.isEmpty {
            for account in all { account.isDefault = false }
            result.isDefault = true
        }
        try commit(context)
        return result
    }

    static func accountIsUsed(_ id: UUID, in context: ModelContext) throws -> Bool {
        try entries(in: context).contains(where: { $0.accountID == id || $0.destinationAccountID == id })
            || context.fetch(FetchDescriptor<RecurrenceRule>()).contains(where: { $0.accountID == id })
    }
    static func archiveAccount(_ account: BudgetAccount, in context: ModelContext) throws {
        account.isArchived.toggle()
        account.updatedAt = .now
        try commit(context)
    }
    static func deleteAccount(_ account: BudgetAccount, in context: ModelContext) throws {
        guard try !accountIsUsed(account.id, in: context) else { throw Failure.accountInUse }
        context.delete(account)
        try commit(context)
    }

    static func saveBudget(month: Date, currency: String, money: MoneyAmount, categoryID: UUID? = nil, in context: ModelContext) throws {
        guard money.minorUnits > 0, money.fractionDigits == MoneyAmount.fractionDigits(for: currency),
              CurrencyOption.all.contains(where: { $0.id == currency }) else { throw Failure.invalidAmount }
        if let categoryID {
            guard try context.fetch(FetchDescriptor<ExpenseCategory>()).contains(where: {
                $0.id == categoryID && $0.kindRawValue == EntryKind.expense.rawValue
            }) else { throw Failure.missingCategory }
        }
        let key = LedgerMath.monthKey(month)
        let all = try context.fetch(FetchDescriptor<MonthlyBudget>())
        if let budget = all.first(where: { $0.monthKey == key && $0.currencyCode == currency && $0.categoryID == categoryID }) {
            budget.limitMinorUnits = money.minorUnits; budget.updatedAt = .now
        } else {
            context.insert(MonthlyBudget(monthKey: key, currencyCode: currency, money: money, categoryID: categoryID))
        }
        try commit(context)
    }

    static func saveRule(_ existing: RecurrenceRule? = nil, input: EntryInput, frequency: RepeatFrequency,
                         interval: Int, nextDue: Date, end: Date?, lastDay: Bool, in context: ModelContext) throws {
        guard input.kind != .transfer, (1...365).contains(interval),
              end.map({ Calendar.current.startOfDay(for: $0) >= Calendar.current.startOfDay(for: nextDue) }) ?? true else {
            throw Failure.invalidRecurrence
        }
        let (account, _, category) = try validate(input, allowFuture: true, in: context)
        let calendar = existing?.calendar ?? Calendar.current
        var normalizedDue = RecurrenceSchedule.day(nextDue, calendar: calendar)
        if lastDay && frequency == .monthly,
           let month = calendar.dateInterval(of: .month, for: normalizedDue),
           let last = calendar.date(byAdding: .day, value: -1, to: month.end) {
            normalizedDue = RecurrenceSchedule.day(last, calendar: calendar)
        }
        if let end, calendar.startOfDay(for: normalizedDue) > calendar.startOfDay(for: end) {
            throw Failure.invalidRecurrence
        }
        let rule = existing ?? RecurrenceRule()
        if existing == nil { context.insert(rule) }
        let changesAnchor = existing == nil || rule.frequency != frequency || rule.interval != interval
            || rule.usesLastDay != lastDay || !rule.calendar.isDate(rule.nextDueDate, inSameDayAs: normalizedDue)
        apply(input, source: account, category: category, to: rule)
        rule.frequencyRawValue = frequency.rawValue; rule.interval = interval; rule.usesLastDay = lastDay
        rule.nextDueDate = normalizedDue
        if changesAnchor { rule.anchorDate = rule.nextDueDate }
        rule.endDate = end
        rule.updatedAt = .now
        try commit(context)
    }

    static func confirmOccurrence(rule: RecurrenceRule, dueDate: Date, input: EntryInput,
                                  in context: ModelContext) throws -> LedgerChange {
        let key = RecurrenceSchedule.occurrenceKey(rule: rule, date: dueDate)
        guard rule.isActive, rule.calendar.isDate(dueDate, inSameDayAs: rule.nextDueDate),
              try !entries(in: context).contains(where: { $0.occurrenceKey == key }) else { throw Failure.alreadyHandled }
        let (account, _, category) = try validate(input, in: context)
        guard input.kind == rule.kind else { throw Failure.invalidRecurrence }
        let result = LedgerEntry()
        apply(input, source: account, destination: nil, category: category, to: result)
        result.recurrenceRuleID = rule.id; result.occurrenceKey = key
        context.insert(result)
        let oldDue = rule.nextDueDate
        let oldActive = rule.isActive
        RecurrenceSchedule.advance(rule)
        let nextDue = rule.nextDueDate
        let ruleID = rule.id
        let entryID = result.id
        try commit(context)
        return LedgerChange(entryID: entryID, message: "Scadență înregistrată") {
            if let entry = try entry(entryID, in: context) { context.delete(entry) }
            if let rule = try self.rule(ruleID, in: context),
               rule.nextDueDate == nextDue {
                rule.nextDueDate = oldDue; rule.isActive = oldActive
            }
            try commit(context)
        }
    }

    static func skipOccurrence(_ rule: RecurrenceRule, in context: ModelContext) throws -> LedgerChange {
        let old = rule.nextDueDate
        let oldActive = rule.isActive
        let id = rule.id
        RecurrenceSchedule.advance(rule)
        let next = rule.nextDueDate
        try commit(context)
        return LedgerChange(message: "Scadență omisă") {
            if let rule = try self.rule(id, in: context), rule.nextDueDate == next {
                rule.nextDueDate = old; rule.isActive = oldActive
            }
            try commit(context)
        }
    }
    static func toggleRule(_ rule: RecurrenceRule, in context: ModelContext) throws {
        rule.isActive.toggle()
        if rule.isActive, let end = rule.endDate,
           rule.calendar.startOfDay(for: rule.nextDueDate) > rule.calendar.startOfDay(for: end) {
            rule.isActive = false
            throw Failure.invalidRecurrence
        }
        try commit(context)
    }
    static func deleteRule(_ rule: RecurrenceRule, in context: ModelContext) throws {
        context.delete(rule)
        try commit(context)
    }

    static func commit(_ context: ModelContext) throws {
        do { try context.save() } catch { context.rollback(); throw error }
    }

    private static func validate(_ input: EntryInput, existing: LedgerEntry? = nil, allowFuture: Bool = false,
                                 in context: ModelContext) throws -> (BudgetAccount, BudgetAccount?, ExpenseCategory?) {
        let source = try account(input.accountID, in: context)
        guard !source.isArchived || existing?.accountID == source.id else { throw Failure.archivedAccount }
        guard input.money.minorUnits > 0, input.money.fractionDigits == source.fractionDigits else { throw Failure.invalidAmount }
        if !allowFuture {
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: .now))!
            guard input.occurredAt < tomorrow else { throw Failure.futureDate }
        }
        var destination: BudgetAccount?
        if input.kind == .transfer {
            guard let destinationID = input.destinationAccountID else { throw Failure.missingAccount }
            guard destinationID != source.id else { throw Failure.sameAccount }
            let target = try account(destinationID, in: context)
            guard !target.isArchived || existing?.destinationAccountID == target.id else { throw Failure.archivedAccount }
            guard let received = input.receivedMoney, received.minorUnits > 0,
                  received.fractionDigits == target.fractionDigits else { throw Failure.invalidAmount }
            if target.currencyCode == source.currencyCode, received != input.money { throw Failure.invalidAmount }
            destination = target
        }
        var category: ExpenseCategory?
        if input.kind != .transfer, let id = input.categoryID {
            category = try context.fetch(FetchDescriptor<ExpenseCategory>()).first { $0.id == id }
            guard let category, category.kindRawValue == input.kind.rawValue else { throw Failure.missingCategory }
        }
        return (source, destination, category)
    }

    private static func apply(_ input: EntryInput, source: BudgetAccount, destination: BudgetAccount?,
                              category: ExpenseCategory?, to entry: LedgerEntry) {
        entry.kindRawValue = input.kind.rawValue; entry.statusRawValue = "confirmed"
        entry.accountID = source.id; entry.currencyCode = source.currencyCode
        entry.amountMinorUnits = input.money.minorUnits; entry.fractionDigits = source.fractionDigits
        entry.destinationAccountID = destination?.id
        entry.receivedMinorUnits = destination == nil ? nil : input.receivedMoney?.minorUnits
        entry.receivedFractionDigits = destination?.fractionDigits; entry.receivedCurrencyCode = destination?.currencyCode
        entry.categoryID = category?.id; entry.categoryNameSnapshot = category?.name ?? "Necategorizat"
        entry.categoryEmojiSnapshot = category?.emoji ?? (input.kind == .transfer ? "↔️" : "🧾")
        entry.categorySystemKey = category?.systemKey
        entry.merchant = String(input.merchant.trimmingCharacters(in: .whitespacesAndNewlines).prefix(200))
        entry.note = String(input.note.trimmingCharacters(in: .whitespacesAndNewlines).prefix(2000))
        entry.occurredAt = input.occurredAt; entry.updatedAt = .now
    }
    private static func apply(_ input: EntryInput, source: BudgetAccount, category: ExpenseCategory?, to rule: RecurrenceRule) {
        rule.kindRawValue = input.kind.rawValue; rule.accountID = source.id
        rule.amountMinorUnits = input.money.minorUnits; rule.fractionDigits = source.fractionDigits
        rule.currencyCode = source.currencyCode; rule.categoryID = category?.id
        rule.categoryNameSnapshot = category?.name ?? "Necategorizat"; rule.categoryEmojiSnapshot = category?.emoji ?? "🧾"
        rule.categorySystemKey = category?.systemKey
        rule.merchant = String(input.merchant.trimmingCharacters(in: .whitespacesAndNewlines).prefix(200))
        rule.note = String(input.note.trimmingCharacters(in: .whitespacesAndNewlines).prefix(2000))
    }
}
