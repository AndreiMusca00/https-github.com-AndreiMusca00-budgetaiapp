import Foundation

struct PaymentCalendarItem: Identifiable {
    enum State: Equatable {
        case planned, dueSoon, unrecorded, recorded
        var title: String {
            switch self {
            case .planned: "Programată"
            case .dueSoon: "Scadentă curând"
            case .unrecorded: "De înregistrat"
            case .recorded: "Înregistrată"
            }
        }
    }
    let id: String
    let ruleID: UUID
    let dueDate: Date
    let merchant: String
    let categoryName: String
    let categorySystemKey: String?
    let emoji: String
    let money: MoneyAmount
    let currency: String
    let state: State
    let daysUntilDue: Int
    let canConfirm: Bool
    let timeZoneIdentifier: String

    /// Nearby unpaid occurrences use a relative mini-calendar; paid/history keep their date.
    var badgeCountdownDays: Int? {
        state != .recorded && (0...3).contains(daysUntilDue) ? daysUntilDue : nil
    }
}

/// Forecasts are value objects. Browsing another month never creates ledger entries or advances a rule.
enum PaymentCalendarProjection {
    static func items(rules: [RecurrenceRule], entries: [LedgerEntry], month: Date, currency: String,
                      asOf: Date, calendar selectionCalendar: Calendar = .current) -> [PaymentCalendarItem] {
        let selected = selectionCalendar.dateComponents([.year, .month], from: month)
        var result: [String: PaymentCalendarItem] = [:]
        for rule in rules where rule.kind == .expense && rule.currencyCode == currency {
            let calendar = rule.calendar
            guard let start = calendar.date(from: DateComponents(year: selected.year, month: selected.month, day: 1)),
                  let end = calendar.date(byAdding: .month, value: 1, to: start) else { continue }
            let today = calendar.startOfDay(for: asOf)
            if rule.isActive {
                var due = firstCandidate(rule: rule, in: start)
                while due < end {
                    if let last = rule.endDate, calendar.startOfDay(for: due) > calendar.startOfDay(for: last) { break }
                    if due >= start {
                        let key = RecurrenceSchedule.occurrenceKey(rule: rule, date: due)
                        let day = calendar.startOfDay(for: due)
                        let days = calendar.dateComponents([.day], from: today, to: day).day ?? 0
                        result[key] = PaymentCalendarItem(id: key, ruleID: rule.id, dueDate: due,
                            merchant: rule.merchant, categoryName: rule.categoryNameSnapshot,
                            categorySystemKey: rule.categorySystemKey, emoji: rule.categoryEmojiSnapshot,
                            money: rule.money, currency: currency,
                            state: days < 0 ? .unrecorded : days <= 2 ? .dueSoon : .planned, daysUntilDue: days,
                            canConfirm: day <= today && calendar.isDate(due, inSameDayAs: rule.nextDueDate),
                            timeZoneIdentifier: rule.timeZoneIdentifier)
                    }
                    let next = RecurrenceSchedule.next(after: due, rule: rule)
                    guard next > due else { break }
                    due = next
                }
            }
            // A confirmed occurrence remains visible after nextDueDate advances, including paused/end-dated plans.
            for entry in entries where entry.isConfirmed && entry.kind == .expense &&
                entry.currencyCode == currency && entry.recurrenceRuleID == rule.id {
                let due = originalDue(entry, rule: rule)
                guard due >= start && due < end else { continue }
                let key = entry.occurrenceKey ?? RecurrenceSchedule.occurrenceKey(rule: rule, date: due)
                result[key] = PaymentCalendarItem(id: key, ruleID: rule.id, dueDate: due,
                    merchant: entry.merchant, categoryName: entry.categoryNameSnapshot,
                    categorySystemKey: entry.categorySystemKey, emoji: entry.categoryEmojiSnapshot,
                    money: entry.money, currency: currency, state: .recorded,
                    daysUntilDue: calendar.dateComponents([.day], from: today, to: calendar.startOfDay(for: due)).day ?? 0,
                    canConfirm: false,
                    timeZoneIdentifier: rule.timeZoneIdentifier)
            }
        }
        return result.values.sorted {
            if ($0.state == .recorded) != ($1.state == .recorded) { return $0.state != .recorded }
            return $0.dueDate == $1.dueDate ? $0.id < $1.id : $0.dueDate < $1.dueDate
        }
    }

    private static func firstCandidate(rule: RecurrenceRule, in start: Date) -> Date {
        let due = rule.nextDueDate
        guard due < start else { return due }
        let calendar = rule.calendar
        let interval = max(1, rule.interval)
        let cycles: Int
        switch rule.frequency {
        case .weekly:
            let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: due), to: start).day ?? 0
            cycles = max(0, days / (7 * interval))
        case .monthly:
            let a = calendar.dateComponents([.year, .month], from: due)
            let b = calendar.dateComponents([.year, .month], from: start)
            let months = ((b.year ?? 0) - (a.year ?? 0)) * 12 + (b.month ?? 1) - (a.month ?? 1)
            cycles = max(0, months / interval)
        case .yearly:
            cycles = max(0, (calendar.component(.year, from: start) - calendar.component(.year, from: due)) / interval)
        }
        guard cycles > 0 else { return due }
        return RecurrenceSchedule.next(after: due, anchor: rule.anchorDate, frequency: rule.frequency,
            interval: cycles * interval, lastDay: rule.usesLastDay, calendar: calendar)
    }

    private static func originalDue(_ entry: LedgerEntry, rule: RecurrenceRule) -> Date {
        guard let key = entry.occurrenceKey, key.hasPrefix(rule.id.uuidString + ":"),
              let suffix = key.split(separator: ":", maxSplits: 1).last else { return entry.occurredAt }
        let parts = suffix.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3,
              let date = rule.calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12)) else {
            return entry.occurredAt
        }
        let verified = rule.calendar.dateComponents([.year, .month, .day], from: date)
        guard verified.year == parts[0], verified.month == parts[1], verified.day == parts[2] else { return entry.occurredAt }
        return date
    }
}
