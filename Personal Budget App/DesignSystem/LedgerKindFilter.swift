import SwiftUI

/// One selection control for account activity and the full transaction history.
struct LedgerKindFilter: View {
    @Binding var selection: EntryKind?
    var accessibilityPrefix = "history.kind"
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var highlight

    var body: some View {
        HStack(spacing: 6) {
            ForEach(["all"] + EntryKind.allCases.map(\.rawValue), id: \.self) { value in
                let option = EntryKind(rawValue: value)
                let title = option == .expense ? "Cheltuieli" : option == .income ? "Încasări" : option == .transfer ? "Transferuri" : "Toate"
                Button {
                    guard selection != option else { return }
                    withAnimation(reduceMotion ? nil : .smooth(duration: 0.35)) { selection = option }
                } label: {
                    Text(tr(title)).font(.system(size: 12, weight: .semibold, design: .rounded))
                        .lineLimit(1).minimumScaleFactor(0.85).padding(.horizontal, 4)
                        .foregroundStyle(selection == option ? BudgetStyle.accent : .secondary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background {
                            if selection == option {
                                Capsule().fill(BudgetStyle.accent.opacity(0.025))
                                    .glassEffect(.regular, in: Capsule())
                                    .matchedGeometryEffect(id: "selection", in: highlight)
                            }
                        }.contentShape(Capsule())
                }.buttonStyle(.plain).accessibilityIdentifier(accessibilityPrefix + "." + value)
                    .accessibilityAddTraits(selection == option ? .isSelected : [])
            }
        }.accessibilityElement(children: .contain)
    }
}
