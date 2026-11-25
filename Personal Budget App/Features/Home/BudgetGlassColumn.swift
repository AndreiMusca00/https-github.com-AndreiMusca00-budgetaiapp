import SwiftUI

struct BudgetGlassColumn: View {
    let status: MonthlyBudgetProgress.Status
    let height: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var visible = false
    private var pulses: Bool { status != .neutral && !reduceMotion && scenePhase == .active && visible }
    private var color: Color {
        switch status {
        case .neutral: .gray
        case .warning: .orange
        case .exceeded: .red
        }
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !pulses)) { timeline in
            let phase = pulses ? (sin(timeline.date.timeIntervalSinceReferenceDate * .pi) + 1) / 2 : 1
            let shape = RoundedRectangle(cornerRadius: 7, style: .continuous)
            shape.fill(color.opacity(status == .neutral ? 0.12 : 0.25))
                .frame(width: 64, height: height)
                .glassEffect(.regular.tint(color.opacity(status == .neutral ? 0.10 : 0.40)), in: shape)
                .opacity(pulses ? 0.62 + 0.38 * phase : 1)
        }.onAppear { visible = true }.onDisappear { visible = false }
            .accessibilityHidden(true)
    }
}
