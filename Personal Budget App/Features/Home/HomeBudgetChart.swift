import SwiftUI

struct HomeBudgetChart: View {
    let spent: Decimal
    let limit: Decimal?
    let currency: String
    let period: String
    var emptyTitle = "Buget"
    var accessibilityPrefix = "home.budget"
    var statusTint: Color?
    var showsRemaining = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var displayedFraction = 0.0
    @State private var revealed = false
    @State private var visible = false
    @State private var pulseStart = Date.now
    private var usage: MonthlyBudgetProgress { MonthlyBudgetProgress(spent: spent, limit: limit) }
    private var tint: Color { statusTint ?? (usage.isExceeded ? .orange : BudgetStyle.accent) }
    private var pulseTint: Color { statusTint ?? (usage.isExceeded ? .orange : .green) }
    private var pulses: Bool { revealed && visible && !reduceMotion && scenePhase == .active && usage.fraction > 0 }
    var percentage: String {
        guard let limit, limit > 0 else { return "" }
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: AppCopy.shared.language.speechLocaleIdentifier)
        formatter.numberStyle = .percent; formatter.maximumFractionDigits = 0
        return formatter.string(from: NSDecimalNumber(decimal: spent / limit)) ?? "0%"
    }
    private var caption: String {
        guard let limit else { return tr(emptyTitle) }
        guard showsRemaining else { return shortMoney(limit, currency: currency) }
        let remaining = limit - spent
        return shortMoney(abs(remaining), currency: currency) + " " + tr(remaining < 0 ? "peste buget" : "rămași")
    }

    var body: some View {
        VStack(spacing: 8) {
            if limit != nil {
                ZStack {
                    Circle().fill(.clear)
                        .glassEffect(.regular.tint(tint.opacity(0.035)), in: Circle())
                    Circle().strokeBorder(tint.opacity(0.08), lineWidth: 8).padding(4)
                    let arc = BudgetRingArc(fraction: displayedFraction, thickness: 8)
                    arc.fill(tint.opacity(0.8))
                        .glassEffect(.regular.tint(tint.opacity(0.65)), in: arc)
                    TimelineView(.animation(minimumInterval: 1 / 30, paused: !pulses)) { timeline in
                        let cycle = max(0, timeline.date.timeIntervalSince(pulseStart)).truncatingRemainder(dividingBy: 3.2) / 3.2
                        let head = displayedFraction * cycle
                        let tail = max(0, head - min(0.15, displayedFraction * 0.45))
                        Circle().trim(from: tail, to: max(tail, head))
                            .stroke(pulseTint.opacity(0.90), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .rotationEffect(.degrees(-90)).padding(8)
                            .shadow(color: pulseTint.opacity(0.45), radius: 3)
                            .opacity(pulses ? sin(cycle * .pi) * 0.85 : 0)
                    }.allowsHitTesting(false).accessibilityHidden(true)
                    Text(percentage)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(tint).lineLimit(1).minimumScaleFactor(0.6)
                        .padding(17).contentTransition(.numericText())
                        .accessibilityIdentifier(accessibilityPrefix + ".percent")
                }.frame(width: 86, height: 86)
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier(accessibilityPrefix + ".ring")
            } else {
                ZStack(alignment: .bottomTrailing) {
                    Image(systemName: "chart.pie")
                        .font(.system(size: 29, weight: .medium, design: .rounded))
                        .symbolRenderingMode(.hierarchical).foregroundStyle(BudgetStyle.accent)
                        .frame(width: 38, height: 38)
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold, design: .rounded)).foregroundStyle(.white)
                        .frame(width: 18, height: 18).background(BudgetStyle.accent, in: Circle())
                        .overlay { Circle().strokeBorder(.white.opacity(0.85), lineWidth: 1.5) }
                        .offset(x: 3, y: 2)
                }.frame(width: 86, height: 86)
                    .glassEffect(.regular.tint(BudgetStyle.accent.opacity(0.025)), in: Circle())
                    .accessibilityHidden(true)
            }
            Text(caption)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(showsRemaining && limit != nil ? tint : .secondary).lineLimit(1).minimumScaleFactor(0.65)
                .contentTransition(.numericText())
                .accessibilityIdentifier(accessibilityPrefix + ".caption")
        }.frame(width: 94)
            .onAppear { visible = true }.onDisappear { visible = false }
            .onScrollVisibilityChange(threshold: 0.05) { visible = $0 }
            .task(id: period) {
                revealed = false
                guard !reduceMotion else { displayedFraction = usage.fraction; revealed = true; return }
                displayedFraction = 0
                do { try await Task.sleep(for: .milliseconds(24)) } catch { return }
                withAnimation(.smooth(duration: 1.1)) { displayedFraction = usage.fraction }
                do { try await Task.sleep(for: .milliseconds(1120)) } catch { return }
                pulseStart = .now; revealed = true
            }
            .onChange(of: usage.fraction) { _, fraction in
                withAnimation(reduceMotion ? nil : .smooth(duration: 0.55)) { displayedFraction = fraction }
            }
            .onChange(of: reduceMotion) { _, enabled in
                if enabled { displayedFraction = usage.fraction; revealed = true }
            }
    }
}

/// A stroked arc is also the native glass shape; it can animate without rotating the percentage.
private struct BudgetRingArc: Shape {
    var fraction: Double
    let thickness: CGFloat
    var animatableData: Double {
        get { fraction }
        set { fraction = newValue }
    }
    func path(in rect: CGRect) -> Path {
        let progress = min(1, max(0, fraction))
        guard progress > 0 else { return Path() }
        var path = Path()
        let radius = max(0, min(rect.width, rect.height) / 2 - thickness / 2 - 4)
        path.addArc(center: CGPoint(x: rect.midX, y: rect.midY), radius: radius,
                    startAngle: .degrees(-90), endAngle: .degrees(-90 + 360 * progress), clockwise: false)
        return path.strokedPath(StrokeStyle(lineWidth: thickness, lineCap: .round))
    }
}
