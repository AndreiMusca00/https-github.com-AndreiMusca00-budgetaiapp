import Foundation

/// Account activity includes both sides of transfers without treating them as income or spending.
enum AccountActivity {
    struct Amount {
        let money: MoneyAmount
        let currency: String
        let isIncoming: Bool
    }

    static func records(accountID: UUID, entries: [LedgerEntry], month: Date, kind: EntryKind? = nil) -> [EntryRecord] {
        guard let period = Calendar.current.dateInterval(of: .month, for: month) else { return [] }
        return entries.filter { entry in
            entry.isConfirmed && entry.occurredAt >= period.start && entry.occurredAt < period.end &&
            (entry.accountID == accountID || (entry.kind == .transfer && entry.destinationAccountID == accountID)) &&
            (kind == nil || entry.kind == kind)
        }.sorted {
            if $0.occurredAt != $1.occurredAt { return $0.occurredAt > $1.occurredAt }
            if $0.createdAt != $1.createdAt { return $0.createdAt > $1.createdAt }
            return $0.id.uuidString < $1.id.uuidString
        }.map { EntryRecord($0) }
    }

    static func amount(of record: EntryRecord, in accountID: UUID) -> Amount? {
        if record.kind == EntryKind.transfer.rawValue, record.destinationID == accountID {
            guard let received = record.received, let digits = record.receivedDigits,
                  let currency = record.receivedCurrency else { return nil }
            return Amount(money: MoneyAmount(minorUnits: received, fractionDigits: digits), currency: currency, isIncoming: true)
        }
        guard record.accountID == accountID else { return nil }
        return Amount(money: MoneyAmount(minorUnits: record.amount, fractionDigits: record.digits),
                      currency: record.currency, isIncoming: record.kind == EntryKind.income.rawValue)
    }
}
