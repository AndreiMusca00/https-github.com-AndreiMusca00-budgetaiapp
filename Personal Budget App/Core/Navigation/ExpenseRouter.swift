import Foundation
import Observation

enum ExpenseEntryRoute: String {
    case manual, income, transfer
    var url: URL { URL(string: "personalbudget://add/\(rawValue)")! }
    init?(url: URL) {
        guard url.scheme?.lowercased() == "personalbudget", url.host?.lowercased() == "add",
              let route = Self(rawValue: url.lastPathComponent.lowercased()) else { return nil }
        self = route
    }
}
@MainActor @Observable
final class ExpenseRouter {
    struct Request: Identifiable { let id = UUID(); let route: ExpenseEntryRoute }
    var request: Request?
    func open(_ url: URL) {
        guard let route = ExpenseEntryRoute(url: url) else { return }
        request = Request(route: route)
    }
}
