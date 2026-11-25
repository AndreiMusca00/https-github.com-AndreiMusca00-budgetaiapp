import SwiftUI

struct SpendingOrbitCategory: Identifiable, Equatable {
    let id: String
    let name: String
    let emoji: String
    let amount: Decimal
    let transactionCount: Int
    let share: Double
    var budget: Decimal? = nil

    var palette: OrbitPalette {
        let hash = id.utf8.reduce(UInt64(5381)) { ($0 &* 33) &+ UInt64($1) }
        return OrbitPalette.values[Int(hash % UInt64(OrbitPalette.values.count))]
    }
}

struct OrbitPalette {
    let light: Color
    let dark: Color
    static let values: [OrbitPalette] = [
        .init(light: Color(red: 0.64, green: 0.99, blue: 0.79), dark: Color(red: 0.08, green: 0.42, blue: 0.32)),
        .init(light: Color(red: 0.31, green: 0.84, blue: 0.68), dark: Color(red: 0.025, green: 0.28, blue: 0.24)),
        .init(light: Color(red: 0.43, green: 0.93, blue: 0.56), dark: Color(red: 0.055, green: 0.34, blue: 0.20)),
        .init(light: Color(red: 0.42, green: 0.87, blue: 0.81), dark: Color(red: 0.035, green: 0.32, blue: 0.30)),
        .init(light: Color(red: 0.72, green: 0.94, blue: 0.62), dark: Color(red: 0.13, green: 0.39, blue: 0.26))
    ]
}

struct SpendingOrbitView: View {
    let categories: [SpendingOrbitCategory]
    let spent: Decimal
    let currency: String
    @Binding var selection: String?
    var spentTitle: String = "Cheltuit"
    let editBudget: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var focusedID: String?
    @State private var expansion = 0.0
    @State private var transitionID = UUID()
    @State private var previous: SpendingOrbitCategory?
    @State private var sweep = 1.0

    private var focused: SpendingOrbitCategory? { categories.first { $0.id == focusedID } }
    var body: some View {
        ZStack {
            OrbitSurface(categories: categories, currency: currency, focusedID: focusedID,
                previous: previous, expansion: expansion, sweep: sweep, onTap: handleTap)
                .padding(12)
            OrbitReadout(progress: expansion, isSelected: focused != nil,
                overview: overview,
                details: Group {
                    if let focused {
                        OrbitCategoryReadout(progress: sweep, hasPrevious: previous != nil,
                            current: categoryDetails(focused), previous: Group { if let previous { categoryDetails(previous) } })
                    }
                })
                .allowsHitTesting(false)

        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .contain)
        .animation(reduceMotion ? nil : .smooth(duration: 0.45), value: categories.map(\.amount))
        .animation(reduceMotion ? nil : .smooth(duration: 0.45), value: categories.map(\.budget))
        .onChange(of: categories.map(\.id)) { _, ids in
            if let focusedID, !ids.contains(focusedID) {
                transitionID = UUID(); self.focusedID = nil; previous = nil; selection = nil; expansion = 0
            }
        }
        .onChange(of: selection) { _, value in
            if value == nil && expansion > 0 { closeSelection() }
        }
    }

    private var overview: some View {
        VStack(spacing: 7) {
            Text(orbitNumber(spent, currency: currency))
                .font(.system(size: 47, weight: .medium)).tracking(-1.8)
                .minimumScaleFactor(0.45).lineLimit(1)
                .foregroundStyle(.white).contentTransition(.numericText())
                .accessibilityLabel(formattedMoney(spent, currency: currency))
                .accessibilityIdentifier("home.spent")
            Text(currency).font(.system(size: 11, weight: .medium)).tracking(1.5).foregroundStyle(.white.opacity(0.45))
            Text(tr(spentTitle))
                .font(.system(size: 12)).foregroundStyle(.white.opacity(0.6)).padding(.top, 6)
        }.frame(maxWidth: 190).padding(.horizontal, 10)
    }

    private func categoryDetails(_ category: SpendingOrbitCategory) -> some View {
        VStack(spacing: 9) {
            Text(category.name).font(.system(size: 14, weight: .medium)).lineLimit(2).multilineTextAlignment(.center)
                .contentTransition(.opacity)
                .accessibilityIdentifier("orbit.category.name")
            Text(orbitNumber(category.amount, currency: currency))
                .font(.system(size: 36, weight: .medium)).tracking(-1.2).lineLimit(1).minimumScaleFactor(0.5)
                .contentTransition(.numericText())
                .accessibilityLabel(formattedMoney(category.amount, currency: currency))
                .accessibilityIdentifier("orbit.category.amount")
            Text(currency).font(.system(size: 11, weight: .medium)).tracking(1.5).foregroundStyle(.white.opacity(0.50))
            if let limit = category.budget {
                Text("\(tr("Buget alocat")) · \(orbitNumber(limit, currency: currency))")
                    .font(.system(size: 11)).foregroundStyle(.white.opacity(0.55))
                    .contentTransition(.numericText()).accessibilityIdentifier("orbit.category.budget")
            }
            HStack(spacing: 7) {
                Text("\(category.transactionCount) \(tr(category.transactionCount == 1 ? "tranzacție" : "tranzacții"))")
                    .contentTransition(.numericText())
                    .accessibilityIdentifier("orbit.category.count")
                Text("·").foregroundStyle(.white.opacity(0.3))
                Text(category.share, format: .percent.precision(.fractionLength(0...1)))
                    .contentTransition(.numericText())
                    .accessibilityIdentifier("orbit.category.share")
            }.font(.system(size: 12)).foregroundStyle(.white.opacity(0.68)).padding(.top, 3)
        }.frame(maxWidth: 180).padding(.horizontal, 6)
    }

    private func handleTap(_ id: String?) {
        guard let id else {
            if focusedID != nil { closeSelection() }
            else { editBudget() }
            return
        }
        guard id != focusedID || selection != id else { return }
        let token = UUID(); transitionID = token
        if let focused {
            previous = focused
            sweep = reduceMotion ? 1 : 0
            withAnimation(reduceMotion ? nil : .smooth(duration: 0.72)) {
                focusedID = id; selection = id; expansion = 1
            }
            Task { @MainActor in
                await Task.yield()
                guard transitionID == token else { return }
                withAnimation(reduceMotion ? nil : .smooth(duration: 0.72), completionCriteria: .logicallyComplete) {
                    sweep = 1
                } completion: {
                    if transitionID == token { previous = nil }
                }
            }
        } else {
            previous = nil; sweep = 1; focusedID = id
            withAnimation(reduceMotion ? nil : .smooth(duration: 0.82)) {
                selection = id; expansion = 1
            }
        }
    }

    private func closeSelection() {
        let token = UUID(); transitionID = token
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.68), completionCriteria: .logicallyComplete) {
            selection = nil
            expansion = 0
        } completion: {
            if transitionID == token { focusedID = nil; previous = nil; sweep = 1 }
        }
    }

}

private struct OrbitReadout<Overview: View, Details: View>: View, Animatable {
    var progress: Double
    let isSelected: Bool
    let overview: Overview
    let details: Details
    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }
    var body: some View {
        Group {
            if isSelected && progress > 0.40 {
                details
                    .opacity(min(1, max(0, (progress - 0.40) / 0.50)))
                    .offset(x: -16 * (1 - min(1, max(0, (progress - 0.40) / 0.50))))
                    .transition(.identity)
            } else {
                overview
                    .opacity(min(1, max(0, 1 - progress / 0.25)))
                    .offset(x: 10 * min(1, max(0, progress / 0.25)))
                    .accessibilityHidden(isSelected)
                    .transition(.identity)
            }
        }
    }
}

/// Two phases prevent outgoing and incoming labels from being visible together.
private struct OrbitCategoryReadout<Current: View, Previous: View>: View, Animatable {
    var progress: Double
    let hasPrevious: Bool
    let current: Current
    let previous: Previous
    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }
    var body: some View {
        Group {
            if hasPrevious && progress < 0.40 {
                previous.opacity(max(0, 1 - progress / 0.34))
                    .offset(x: 10 * progress / 0.40).accessibilityHidden(true).transition(.identity)
            } else {
                let phase = hasPrevious ? min(1, max(0, (progress - 0.42) / 0.50)) : 1
                current.opacity(phase).offset(x: -16 * (1 - phase)).transition(.identity)
            }
        }
    }
}

private struct OrbitSurface: View, Animatable {
    let categories: [SpendingOrbitCategory]
    let currency: String
    let focusedID: String?
    let previous: SpendingOrbitCategory?
    var expansion: Double
    var sweep: Double
    let onTap: (String?) -> Void
    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(expansion, sweep) }
        set { expansion = newValue.first; sweep = newValue.second }
    }

    var body: some View {
        GeometryReader { proxy in
            let progress = min(1, max(0, expansion))
            let geometry = SpendingOrbitGeometry(shares: categories.map(\.share))
            let radius = min(proxy.size.width, proxy.size.height) / 2
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            ZStack {
                GlassEffectContainer(spacing: 6) {
                    ZStack {
                        OrbitLiquidMaterial(
                            ribbon: ribbonPath(geometry, center: center, radius: radius),
                            slices: geometry.segments.map { segment in
                                OrbitLiquidSlice(id: categories[segment.index].id,
                                    path: sectorPath(segment, geometry: geometry, center: center, radius: radius),
                                    palette: categories[segment.index].palette, angle: segment.middle)
                            }, expansion: 0
                        )
                        if let category = categories.first(where: { $0.id == focusedID }), progress > 0.0001 {
                            let hubRadius = radius * (1 - SpendingOrbitGeometry.restingDepth)
                            let hub = Path(ellipseIn: CGRect(x: center.x - hubRadius, y: center.y - hubRadius,
                                width: hubRadius * 2, height: hubRadius * 2))
                            let bounds = CGRect(origin: .zero, size: proxy.size)
                            let opening = progress > 0.9999 ? hub : hub.intersection(OrganicSlideFront(progress: progress).path(in: bounds))
                            if !opening.isEmpty {
                                if let previous { focusMaterial(previous, hub: opening) }
                                let incoming = sweep > 0.9999 ? opening : opening.intersection(OrganicSlideFront(progress: sweep).path(in: bounds))
                                if !incoming.isEmpty { focusMaterial(category, hub: incoming).allowsHitTesting(false) }
                            }
                        }
                    }
                }
                .contentShape(Circle())
                .onTapGesture { location in
                    let dx = location.x - center.x, dy = location.y - center.y
                    let distance = hypot(dx, dy)
                    let hubRadius = radius * (1 - SpendingOrbitGeometry.restingDepth)
                    if distance >= hubRadius, let segment = geometry.segment(at: atan2(dy, dx)) {
                        onTap(categories[segment.index].id)
                    } else if distance < hubRadius {
                        onTap(nil)
                    }
                }
                .accessibilityHidden(true)
                ForEach(geometry.segments, id: \.index) { segment in
                    let category = categories[segment.index]
                    let middleRadius = radius * (1 + segment.innerRadius) / 2
                    let iconSize = min(23, max(8, radius * (1 - segment.innerRadius) - 2))
                    Button { onTap(category.id) } label: {
                        Text(category.emoji).font(.system(size: iconSize)).frame(width: 44, height: 44)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .position(point(center, radius: middleRadius, angle: segment.middle))
                    .opacity(category.id == focusedID ? 1 : 1 - progress * 0.25)
                    .accessibilityAddTraits(category.id == focusedID ? .isSelected : [])
                    .accessibilityLabel("\(category.name), \(formattedMoney(category.amount, currency: currency))")
                    .accessibilityIdentifier("orbit.category.\(category.name)")
                }
                if focusedID != nil {
                    Button { onTap(nil) } label: { Circle().fill(.clear).contentShape(Circle()) }
                        .buttonStyle(.plain)
                        .frame(width: radius * (1 - SpendingOrbitGeometry.restingDepth) * 2,
                               height: radius * (1 - SpendingOrbitGeometry.restingDepth) * 2)
                        .position(center)
                        .accessibilityLabel(tr("Revino la buget"))
                        .accessibilityHint(tr("Atinge centrul pentru a reveni."))
                        .accessibilityIdentifier("orbit.collapse")
                }
            }
        }
    }

    private func focusMaterial(_ category: SpendingOrbitCategory, hub: Path) -> some View {
        OrbitLiquidMaterial(ribbon: hub,
            slices: [OrbitLiquidSlice(id: "focus-" + category.id, path: hub, palette: category.palette, angle: 0)], expansion: 1)
    }

    private func ribbonPath(_ geometry: SpendingOrbitGeometry, center: CGPoint, radius: CGFloat) -> Path {
        let bounds = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        guard !geometry.segments.isEmpty else { return Path(ellipseIn: bounds) }
        if geometry.segments.allSatisfy({ $0.innerRadius < 0.00001 }) { return Path(ellipseIn: bounds) }
        let start = geometry.segments[0].start
        var path = Path()
        path.move(to: point(center, radius: radius, angle: start))
        path.addArc(center: center, radius: radius, startAngle: .radians(start), endAngle: .radians(start + 2 * .pi), clockwise: false)
        path.closeSubpath()
        // Separate reverse-wound subpaths avoid a radial seam in the glass refraction.
        var hole = Path()
        hole.move(to: point(center, radius: radius * geometry.innerRadius(at: start), angle: start))
        for step in 1...480 {
            let angle = start - 2 * .pi * Double(step) / 480
            hole.addLine(to: point(center, radius: radius * geometry.innerRadius(at: angle), angle: angle))
        }
        hole.closeSubpath()
        path.addPath(hole)
        return path
    }

    private func sectorPath(_ segment: SpendingOrbitGeometry.Segment, geometry: SpendingOrbitGeometry, center: CGPoint, radius: CGFloat) -> Path {
        if geometry.segments.count == 1 && segment.span >= 2 * .pi - 0.00001 {
            return ribbonPath(geometry, center: center, radius: radius)
        }
        let overlap = 0.0015
        let start = segment.start - overlap, end = segment.start + segment.span + overlap
        let steps = max(4, Int(ceil((end - start) / (2 * .pi) * 480)))
        var path = Path()
        path.move(to: point(center, radius: radius, angle: start))
        path.addArc(center: center, radius: radius, startAngle: .radians(start), endAngle: .radians(end), clockwise: false)
        for step in 0...steps {
            let angle = end - (end - start) * Double(step) / Double(steps)
            path.addLine(to: point(center, radius: radius * geometry.innerRadius(at: angle), angle: angle))
        }
        path.closeSubpath()
        return path
    }

    private func point(_ center: CGPoint, radius: CGFloat, angle: Double) -> CGPoint {
        CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
    }
}

@MainActor
func orbitNumber(_ value: Decimal, currency: String) -> String {
    let formatter = NumberFormatter()
    formatter.locale = Locale(identifier: AppCopy.shared.language.speechLocaleIdentifier)
    formatter.numberStyle = .decimal
    formatter.minimumFractionDigits = 0
    formatter.maximumFractionDigits = MoneyAmount.fractionDigits(for: currency)
    return formatter.string(from: NSDecimalNumber(decimal: value)) ?? "0"
}
