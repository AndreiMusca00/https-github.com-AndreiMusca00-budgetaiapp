import Foundation

enum LedgerMath {
    static func monthKey(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", c.year!, c.month!)
    }

    static func balance(account: BudgetAccount, entries: [LedgerEntry], through date: Date = .now) -> Decimal {
        let end = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: date))!
        var result = MoneyAmount(minorUnits: account.openingMinorUnits, fractionDigits: account.fractionDigits).decimalValue
        for entry in entries where entry.isConfirmed && entry.occurredAt < end {
            if entry.accountID == account.id {
                result += entry.kind == .income ? entry.money.decimalValue : -entry.money.decimalValue
            }
            if entry.kind == .transfer, entry.destinationAccountID == account.id, let received = entry.receivedMoney {
                result += received.decimalValue
            }
        }
        return result
    }

    static func total(_ kind: EntryKind, entries: [LedgerEntry], month: Date, currency: String) -> Decimal {
        guard let period = Calendar.current.dateInterval(of: .month, for: month) else { return 0 }
        return entries.filter {
            $0.isConfirmed && $0.kind == kind && $0.currencyCode == currency && $0.occurredAt >= period.start && $0.occurredAt < period.end
        }.reduce(Decimal(0)) { $0 + $1.money.decimalValue }
    }
}

extension MoneyAmount {
    static func parseBalance(_ text: String, currencyCode: String) -> MoneyAmount? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let digits = fractionDigits(for: currencyCode)
        let fractional = value.split(whereSeparator: { $0 == "." || $0 == "," }).dropFirst().first?.count ?? 0
        if value.isEmpty || value.range(of: #"^-?(?:0+(?:[.,]0+)?|[.,]0+)$"#, options: .regularExpression) != nil && fractional <= digits {
            return MoneyAmount(minorUnits: 0, fractionDigits: digits)
        }
        let negative = value.hasPrefix("-")
        let unsigned = negative ? String(value.dropFirst()) : value
        guard let amount = parse(unsigned, currencyCode: currencyCode) else { return nil }
        return MoneyAmount(minorUnits: negative ? -amount.minorUnits : amount.minorUnits, fractionDigits: amount.fractionDigits)
    }
}
