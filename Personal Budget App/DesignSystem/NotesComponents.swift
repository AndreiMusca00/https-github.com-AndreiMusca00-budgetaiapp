import SwiftUI

@MainActor
func moneyNumber(_ amount: Decimal, currency: String) -> String {
    let formatter = NumberFormatter()
    formatter.locale = Locale(identifier: AppCopy.shared.language.speechLocaleIdentifier)
    formatter.numberStyle = .decimal
    formatter.minimumFractionDigits = 0
    formatter.maximumFractionDigits = MoneyAmount.fractionDigits(for: currency)
    return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "0"
}

@MainActor
func moneyUnit(_ currency: String) -> String { currency == "RON" && AppCopy.shared.language == .romanian ? "lei" : currency }

@MainActor
func shortMoney(_ amount: Decimal, currency: String) -> String { "\(moneyNumber(amount, currency: currency)) \(moneyUnit(currency))" }

@MainActor
func monthLabel(_ date: Date, year: Bool = true) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: AppCopy.shared.language.speechLocaleIdentifier)
    formatter.dateFormat = year ? "LLLL yyyy" : "LLLL"
    let text = formatter.string(from: date)
    return text.prefix(1).uppercased() + text.dropFirst()
}

@MainActor
func dayLabel(_ date: Date) -> String {
    if Calendar.current.isDateInToday(date) { return tr("Azi") }
    if Calendar.current.isDateInYesterday(date) { return tr("Ieri") }
    return displayDate(date)
}

struct NotesTitle: View {
    let title: String
    var body: some View {
        Text(tr(title)).font(.system(.largeTitle, design: .rounded, weight: .bold)).tracking(-0.5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

struct NotesMonthButton: View {
    @Binding var month: Date
    var includesYear = true
    @State private var showingPicker = false
    var body: some View {
        Button { showingPicker = true } label: {
            HStack(spacing: 7) {
                Text(monthLabel(month, year: includesYear)).contentTransition(.opacity)
                Image(systemName: "chevron.down").font(.system(size: 10, weight: .medium, design: .rounded))
            }.font(.system(size: 17, weight: .medium, design: .rounded)).foregroundStyle(.secondary).frame(minHeight: 44)
        }.buttonStyle(.plain).accessibilityIdentifier("period.month")
            .accessibilityValue(LedgerMath.monthKey(month))
            .sheet(isPresented: $showingPicker) { NotesMonthPicker(month: $month) }
    }
}

private struct NotesMonthPicker: View {
    @Binding var month: Date
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var year = Calendar.current.component(.year, from: .now)
    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                HStack {
                    Button { year -= 1 } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                        .disabled(year <= 1900).accessibilityLabel(tr("Anul anterior")).accessibilityIdentifier("period.previousYear")
                    Spacer()
                    Text(String(year)).font(.system(.title3, design: .rounded, weight: .semibold)).contentTransition(.numericText())
                        .accessibilityIdentifier("period.year")
                    Spacer()
                    Button { year += 1 } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }
                        .disabled(year >= 2200).accessibilityLabel(tr("Anul următor")).accessibilityIdentifier("period.nextYear")
                }.buttonStyle(.plain)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                    ForEach(1...12, id: \.self) { number in
                        let date = Calendar.current.date(from: DateComponents(year: year, month: number, day: 1)) ?? month
                        let selected = LedgerMath.monthKey(month) == LedgerMath.monthKey(date)
                        Button {
                            withAnimation(reduceMotion ? nil : .smooth(duration: 0.45)) { month = date }
                            dismiss()
                        } label: {
                            Text(monthLabel(date, year: false)).font(.system(size: 14, weight: selected ? .semibold : .medium, design: .rounded))
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background(selected ? BudgetStyle.accent.opacity(0.08) : .clear, in: Capsule())
                        }.buttonStyle(.plain).foregroundStyle(selected ? BudgetStyle.accent : .primary)
                            .accessibilityIdentifier("period.pick.\(number)")
                            .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
            }.padding(.horizontal, 24).padding(.bottom, 20)
                .background(BudgetStyle.background)
                .navigationTitle(tr("Alege luna")).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button(tr("Închide")) { dismiss() } } }
        }
        .presentationDetents([.height(390)])
        .onAppear { year = Calendar.current.component(.year, from: month) }
        .animation(reduceMotion ? nil : .smooth(duration: 0.35), value: year)
    }
}

struct NotesComposeFooter: View {
    var showsVoice = false
    @Environment(LedgerSession.self) private var session
    var body: some View {
        HStack {
            Spacer()
            VStack(spacing: 12) {
                if showsVoice {
                    Button { session.showsDictation = true } label: {
                        Image(systemName: "mic.fill").font(.system(size: 22, weight: .medium, design: .rounded))
                            .foregroundStyle(BudgetStyle.accent).frame(width: 48, height: 48)
                            .glassEffect(.regular.interactive(), in: Circle())
                    }.buttonStyle(.plain).accessibilityLabel(tr("Adaugă prin voce"))
                        .accessibilityIdentifier("ledger.voice")
                }
                LedgerAddButton()
            }
        }
            .padding(.horizontal, 26).padding(.top, 10).padding(.bottom, 16)
    }
}
