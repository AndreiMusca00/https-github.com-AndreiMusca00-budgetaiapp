import Foundation
import SwiftData

@MainActor
enum PendingEntryRepository {
    enum ReviewError: LocalizedError {
        case incomplete
        var errorDescription: String? { "Verifică detaliile tranzacției." }
    }

    /// Both actions re-fetch by ID and only operate on pending records, making repeated taps harmless.
    static func confirm(_ id: UUID, in context: ModelContext) throws -> LedgerChange? {
        guard let entry = try LedgerRepository.entry(id, in: context), !entry.isConfirmed else { return nil }
        guard entry.amountMinorUnits > 0,
              !entry.merchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ReviewError.incomplete }
        let account = try LedgerRepository.account(entry.accountID, in: context)
        guard !account.isArchived, account.currencyCode == entry.currencyCode,
              account.fractionDigits == entry.fractionDigits else { throw ReviewError.incomplete }
        if entry.kind == .transfer {
            guard let destinationID = entry.destinationAccountID else { throw ReviewError.incomplete }
            let destination = try LedgerRepository.account(destinationID, in: context)
            guard !destination.isArchived, entry.receivedCurrencyCode == destination.currencyCode,
                  entry.receivedFractionDigits == destination.fractionDigits else { throw ReviewError.incomplete }
        }
        let input = EntryInput(kind: entry.kind, money: entry.money, accountID: entry.accountID,
            destinationAccountID: entry.destinationAccountID, receivedMoney: entry.receivedMoney,
            categoryID: entry.categoryID, merchant: entry.merchant, note: entry.note, occurredAt: entry.occurredAt)
        return try LedgerRepository.saveEntry(id: id, input: input, in: context)
    }

    static func reject(_ id: UUID, in context: ModelContext) throws -> LedgerChange? {
        guard let entry = try LedgerRepository.entry(id, in: context), !entry.isConfirmed else { return nil }
        let removed = try LedgerRepository.deleteEntry(entry, in: context)
        return LedgerChange(message: "Propunere respinsă", undo: removed.undo)
    }

    /// Speech is retained as a proposal; an amount and category are supplied during review.
    static func voice(text: String, currency: String, in context: ModelContext) throws -> LedgerChange {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw LedgerRepository.Failure.invalidName }
        let accounts = try LedgerRepository.accounts(in: context).filter { !$0.isArchived && $0.currencyCode == currency }
        guard let account = accounts.first(where: \.isDefault) ?? accounts.first else {
            throw LedgerRepository.Failure.missingAccount
        }
        let entry = LedgerEntry()
        entry.statusRawValue = "pending"
        entry.sourceRawValue = "voice"
        entry.accountID = account.id
        entry.currencyCode = account.currencyCode
        entry.fractionDigits = account.fractionDigits
        entry.merchant = text
        entry.originalText = text
        context.insert(entry)
        try LedgerRepository.commit(context)
        let id = entry.id
        return LedgerChange(entryID: id, message: "Propunere salvată") {
            if let entry = try LedgerRepository.entry(id, in: context), !entry.isConfirmed {
                context.delete(entry)
                try LedgerRepository.commit(context)
            }
        }
    }
}

extension LedgerEntry {
    var isHomeExample: Bool { sourceRawValue.hasPrefix("demo.home.") }
    var reviewSource: String { isHomeExample ? String(sourceRawValue.dropFirst("demo.home.".count)) : sourceRawValue }
}
