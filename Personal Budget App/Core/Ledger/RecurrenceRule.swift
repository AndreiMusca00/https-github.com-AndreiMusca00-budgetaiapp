import Foundation
import SwiftData

enum RepeatFrequency: String, Codable, CaseIterable, Identifiable {
    case weekly, monthly, yearly
    var id: String { rawValue }
    var title: String {
        switch self { case .weekly: "Săptămânal"; case .monthly: "Lunar"; case .yearly: "Anual" }
    }
}

@Model
final class RecurrenceRule {
    var id: UUID = UUID()
    var kindRawValue: String = "expense"
    var amountMinorUnits: Int64 = 0
    var fractionDigits: Int = 2
    var currencyCode: String = "RON"
    var accountID: UUID = UUID()
    var categoryID: UUID?
    var categoryNameSnapshot: String = "Necategorizat"
    var categoryEmojiSnapshot: String = "🧾"
    var categorySystemKey: String?
    var merchant: String = ""
    var note: String = ""
    var frequencyRawValue: String = "monthly"
    var interval: Int = 1
    var anchorDate: Date = Date.now
    var nextDueDate: Date = Date.now
    var endDate: Date?
    var usesLastDay: Bool = false
    var timeZoneIdentifier: String = TimeZone.current.identifier
    var isActive: Bool = true
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    init() { }
    var kind: EntryKind { EntryKind(rawValue: kindRawValue) ?? .expense }
    var frequency: RepeatFrequency { RepeatFrequency(rawValue: frequencyRawValue) ?? .monthly }
    var money: MoneyAmount { MoneyAmount(minorUnits: amountMinorUnits, fractionDigits: fractionDigits) }
    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneIdentifier) ?? .current
        return calendar
    }
}

enum RecurrenceSchedule {
    static func day(_ date: Date, calendar: Calendar) -> Date {
        calendar.date(bySettingHour: 12, minute: 0, second: 0, of: date) ?? date
    }

    static func next(after date: Date, rule: RecurrenceRule) -> Date {
        next(after: date, anchor: rule.anchorDate, frequency: rule.frequency,
             interval: rule.interval, lastDay: rule.usesLastDay, calendar: rule.calendar)
    }

    static func next(after date: Date, anchor: Date, frequency: RepeatFrequency, interval: Int,
                     lastDay: Bool, calendar: Calendar) -> Date {
        let interval = max(1, interval)
        if frequency == .weekly {
            return calendar.date(byAdding: .day, value: interval * 7, to: day(date, calendar: calendar))!
        }
        let components = calendar.dateComponents([.year, .month], from: date)
        let start = calendar.date(from: DateComponents(year: components.year, month: components.month, day: 1, hour: 12))!
        let target = calendar.date(byAdding: frequency == .monthly ? .month : .year, value: interval, to: start)!
        var result = calendar.dateComponents([.year, .month], from: target)
        let days = calendar.range(of: .day, in: .month, for: target)!.count
        result.day = lastDay ? days : min(calendar.component(.day, from: anchor), days)
        result.hour = 12
        return calendar.date(from: result)!
    }

    static func occurrenceKey(rule: RecurrenceRule, date: Date) -> String {
        let components = rule.calendar.dateComponents([.year, .month, .day], from: date)
        return "\(rule.id.uuidString):\(components.year!)-\(components.month!)-\(components.day!)"
    }

    static func advance(_ rule: RecurrenceRule) {
        rule.nextDueDate = next(after: rule.nextDueDate, rule: rule)
        if let endDate = rule.endDate,
           rule.calendar.startOfDay(for: rule.nextDueDate) > rule.calendar.startOfDay(for: endDate) {
            rule.isActive = false
        }
        rule.updatedAt = .now
    }
}
