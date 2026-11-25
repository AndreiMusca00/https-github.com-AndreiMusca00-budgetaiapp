import SwiftUI

struct HomePaymentCalendar: View {
    let items: [PaymentCalendarItem]
    let currency: String
    let period: String
    let onManage: () -> Void
    let onEdit: (UUID) -> Void
    let onConfirm: (PaymentCalendarItem) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var motion: Animation? { reduceMotion ? nil : .smooth(duration: 0.45) }
    private var total: Decimal { items.reduce(0) { $0 + $1.money.decimalValue } }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 5) {
                    Label(tr("Calendarul plăților"), systemImage: "calendar")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .accessibilityAddTraits(.isHeader)
                    Text(shortMoney(total, currency: currency)).font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary).contentTransition(.numericText())
                        .accessibilityIdentifier("home.payments.total")
                }
                Spacer(minLength: 0)
                Button(action: onManage) {
                    Image(systemName: "slider.horizontal.3").font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.primary).frame(width: 36, height: 36)
                        .glassEffect(.regular.interactive(), in: Circle())
                }.buttonStyle(.plain).accessibilityLabel(tr("Gestionează"))
                    .accessibilityIdentifier("home.payments.manage")
            }
            if items.isEmpty {
                Text(tr("Nicio plată programată în luna aleasă."))
                    .font(.system(size: 13, weight: .medium, design: .rounded)).foregroundStyle(.secondary)
                    .padding(.vertical, 12).accessibilityIdentifier("home.payments.empty")
            } else {
                ScrollViewReader { scroll in
                    ScrollView(.horizontal) {
                        HStack(spacing: 10) {
                            ForEach(items) { item in
                                Button { onEdit(item.ruleID) } label: { HomePaymentTile(item: item) }
                                    .buttonStyle(.plain).id(item.id)
                                    .accessibilityIdentifier("home.payment.\(item.id)")
                                    .accessibilityValue(tr(item.state.title))
                                    .accessibilityHint("\(tr("Categorie")): \(item.categorySystemKey == nil ? item.categoryName : tr(item.categoryName)). \(tr("Editează recurența"))")
                                    .contextMenu {
                                        Button(tr("Editează recurența")) { onEdit(item.ruleID) }
                                        if item.canConfirm { Button(tr("Confirmă plata")) { onConfirm(item) } }
                                    }
                            }
                        }.scrollTargetLayout().padding(.vertical, 2)
                    }.scrollIndicators(.hidden).scrollClipDisabled().scrollTargetBehavior(.viewAligned)
                        .accessibilityIdentifier("home.payments.carousel")
                        .onChange(of: period) { _, _ in
                            guard let first = items.first else { return }
                            withAnimation(motion) { scroll.scrollTo(first.id, anchor: .leading) }
                        }
                }
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .contain).accessibilityIdentifier("home.payments.section")
            .animation(motion, value: items.map(\.id)).animation(motion, value: items.map(\.state))
            .animation(motion, value: total)
    }
}

private struct HomePaymentTile: View {
    let item: PaymentCalendarItem
    private var category: String { item.categorySystemKey == nil ? item.categoryName : tr(item.categoryName) }
    private var title: String {
        let description = item.merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        return description.isEmpty ? category : description
    }
    private var tone: Color {
        switch item.state {
        case .recorded: BudgetStyle.accent
        case .dueSoon: Color(red: 0.48, green: 0.33, blue: 0.03)
        default: .secondary
        }
    }
    private var fill: Color {
        switch item.state {
        case .recorded: BudgetStyle.accent.opacity(0.11)
        case .dueSoon: Color.yellow.opacity(0.20)
        default: Color.primary.opacity(0.025)
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 7) {
                Text(item.emoji).font(.system(size: 22)).accessibilityHidden(true)
                Text(title).font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary).lineLimit(2).fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("payment.title.\(item.id)")
            }.frame(maxWidth: .infinity, minHeight: 36, alignment: .topLeading)
            Text(shortMoney(item.money.decimalValue, currency: item.currency))
                .font(.system(size: 21, weight: .semibold, design: .rounded))
                .foregroundStyle(item.state == .recorded ? BudgetStyle.accent : .primary)
                .lineLimit(1).minimumScaleFactor(0.7).contentTransition(.numericText())
            Text(tr(item.state.title)).font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(tone).lineLimit(1).minimumScaleFactor(0.85)
        }.padding(.horizontal, 12).padding(.bottom, 12).padding(.top, 40)
            .frame(width: 156, alignment: .leading)
            .background {
                if item.state == .recorded || item.state == .dueSoon {
                    PaymentStateWatermark(recorded: item.state == .recorded)
                        .stroke(tone.opacity(item.state == .recorded ? 0.14 : 0.11),
                                style: StrokeStyle(lineWidth: item.state == .recorded ? 12 : 5, lineCap: .round, lineJoin: .round))
                        .mask { LinearGradient(colors: [.clear, .white, .white], startPoint: .leading, endPoint: .trailing) }
                        .allowsHitTesting(false).accessibilityHidden(true)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .glassEffect(.regular.tint(fill), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(alignment: .top) { PaymentDateNotch(item: item).offset(y: -0.4) }
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .accessibilityElement(children: .combine)
    }
}

/// The state symbol is an off-centre native contour, clipped to the glass card.
private struct PaymentStateWatermark: Shape {
    let recorded: Bool
    func path(in rect: CGRect) -> Path {
        var path = Path()
        if recorded {
            path.move(to: CGPoint(x: rect.width * 0.39, y: rect.height * 0.59))
            path.addLine(to: CGPoint(x: rect.width * 0.64, y: rect.height * 0.83))
            path.addLine(to: CGPoint(x: rect.width * 1.06, y: rect.height * 0.25))
        } else {
            let radius = min(rect.width, rect.height) * 0.36
            let center = CGPoint(x: rect.width * 0.96, y: rect.height * 0.62)
            path.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
            path.move(to: CGPoint(x: center.x, y: center.y - radius * 0.54))
            path.addLine(to: center)
            path.addLine(to: CGPoint(x: center.x + radius * 0.43, y: center.y + radius * 0.22))
        }
        return path
    }
}

private struct PaymentDateNotch: View {
    let item: PaymentCalendarItem
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var calendar: Calendar {
        var result = Calendar(identifier: .gregorian)
        result.timeZone = TimeZone(identifier: item.timeZoneIdentifier) ?? .current
        return result
    }
    private var dateLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: AppCopy.shared.language.speechLocaleIdentifier)
        formatter.timeZone = calendar.timeZone; formatter.dateStyle = .long
        return formatter.string(from: item.dueDate)
    }
    private var relativeLabel: String? {
        guard let days = item.badgeCountdownDays else { return nil }
        switch days {
        case 0: return tr("Azi")
        case 1: return tr("Mâine")
        default: return "\(days) \(tr("zile"))"
        }
    }
    private var title: String {
        if let relativeLabel { return relativeLabel }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: AppCopy.shared.language.speechLocaleIdentifier)
        formatter.timeZone = calendar.timeZone; formatter.dateFormat = "d MMM"
        return formatter.string(from: item.dueDate)
    }
    var body: some View {
        Text(title).font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(.primary).lineLimit(1).minimumScaleFactor(0.85)
            .contentTransition(.opacity)
            .padding(.horizontal, 13).padding(.bottom, 2)
            .frame(width: 106, height: 27)
            .glassEffect(.clear, in: PaymentNotchShape())
            .animation(reduceMotion ? nil : .smooth(duration: 0.25), value: title)
            .allowsHitTesting(false)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(relativeLabel.map { "\($0), \(dateLabel)" } ?? dateLabel)
            .accessibilityIdentifier("payment.date.\(item.id)")
    }
}

/// Concave shoulders meet the card's top edge; only the lower corners curve inward.
private struct PaymentNotchShape: Shape {
    func path(in rect: CGRect) -> Path {
        let width = rect.width
        let height = rect.height
        var path = Path()
        path.move(to: .zero)
        path.addLine(to: CGPoint(x: width, y: 0))
        path.addCurve(to: CGPoint(x: width - 9, y: 8),
                      control1: CGPoint(x: width - 6, y: 0), control2: CGPoint(x: width - 9, y: 2))
        path.addLine(to: CGPoint(x: width - 9, y: height - 11))
        path.addQuadCurve(to: CGPoint(x: width - 20, y: height), control: CGPoint(x: width - 9, y: height))
        path.addLine(to: CGPoint(x: 20, y: height))
        path.addQuadCurve(to: CGPoint(x: 9, y: height - 11), control: CGPoint(x: 9, y: height))
        path.addLine(to: CGPoint(x: 9, y: 8))
        path.addCurve(to: .zero, control1: CGPoint(x: 9, y: 2), control2: CGPoint(x: 6, y: 0))
        path.closeSubpath()
        return path
    }
}
