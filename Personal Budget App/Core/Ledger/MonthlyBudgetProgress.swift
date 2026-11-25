import Foundation

/// Category limits are optional monthly caps, within the separate overall cap.
struct MonthlyBudgetProgress {
    enum Status: String { case neutral, warning, exceeded }
    let spent: Decimal
    let limit: Decimal?

    var remaining: Decimal? { limit.map { $0 - spent } }
    var status: Status {
        guard let limit, limit > 0 else { return .neutral }
        if spent > limit { return .exceeded }
        // Exact Decimal comparison: warn at 80%, including the threshold itself.
        return spent * 5 >= limit * 4 ? .warning : .neutral
    }
    var isExceeded: Bool { (remaining ?? 0) < 0 }
    var fraction: Double {
        guard let limit, limit > 0 else { return 0 }
        return min(1, max(0, NSDecimalNumber(decimal: spent / limit).doubleValue))
    }
}
