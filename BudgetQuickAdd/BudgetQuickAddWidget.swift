import WidgetKit
import SwiftUI

private struct QuickAddEntry: TimelineEntry {
    let date: Date
}

private struct QuickAddProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickAddEntry { QuickAddEntry(date: .now) }
    func getSnapshot(in context: Context, completion: @escaping (QuickAddEntry) -> Void) {
        completion(QuickAddEntry(date: .now))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickAddEntry>) -> Void) {
        completion(Timeline(entries: [QuickAddEntry(date: .now)], policy: .never))
    }
}

private struct QuickAddWidgetView: View {
    @Environment(\.widgetFamily) private var family
    private let accent = Color(red: 0.42, green: 0.96, blue: 0.65)
    private let ink = Color(red: 0.015, green: 0.055, blue: 0.035)

    var body: some View {
        VStack(alignment: .leading, spacing: family == .systemSmall ? 10 : 16) {
            HStack(spacing: 7) {
                Image(systemName: "circle.hexagongrid.fill").foregroundStyle(accent)
                Text("Bugetul tău").foregroundStyle(.white.opacity(0.7))
            }
            .font(.caption.weight(.medium))
            if family == .systemMedium {
                Text("O cheltuială, într-o clipă.")
                    .font(.system(.headline, design: .rounded)).foregroundStyle(.white)
            }
            if family == .systemSmall {
                action("Cheltuială", symbol: "plus", route: "manual", highlighted: false)
                action("Venit", symbol: "arrow.down.left", route: "income", highlighted: true)
            } else {
                HStack(spacing: 12) {
                    action("Cheltuială", symbol: "plus", route: "manual", highlighted: false)
                    action("Venit", symbol: "arrow.down.left", route: "income", highlighted: true)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [Color(red: 0.035, green: 0.11, blue: 0.07), .black],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
        .widgetURL(URL(string: "personalbudget://add/manual"))
    }

    private func action(_ title: String, symbol: String, route: String, highlighted: Bool) -> some View {
        Link(destination: URL(string: "personalbudget://add/\(route)")!) {
            HStack(spacing: 8) {
                Image(systemName: symbol).font(.subheadline.weight(.semibold))
                Text(title).font(.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity, minHeight: 42)
            .foregroundStyle(highlighted ? ink : .white)
            .background {
                if highlighted {
                    RoundedRectangle(cornerRadius: 14).fill(
                        LinearGradient(colors: [accent, Color(red: 0.12, green: 0.64, blue: 0.36)],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                } else {
                    RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.09))
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .accessibilityLabel(title == "Venit" ? "Adaugă un venit" : "Adaugă o cheltuială")
    }
}

@main
struct BudgetQuickAddWidget: Widget {
    let kind = "BudgetQuickAdd"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickAddProvider()) { _ in
            QuickAddWidgetView()
        }
        .configurationDisplayName("Cheltuială rapidă")
        .description("Adaugă o cheltuială sau un venit.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
