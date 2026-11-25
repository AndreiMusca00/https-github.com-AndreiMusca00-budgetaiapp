import SwiftUI
import SwiftData

struct HomePendingCard: View {
    private let entry: EntryRecord
    init(entry: LedgerEntry) { self.entry = EntryRecord(entry) }
    private var kind: EntryKind { EntryKind(rawValue: entry.kind) ?? .expense }
    private var isExample: Bool { entry.source.hasPrefix("demo.home.") }
    private var reviewSource: String { isExample ? String(entry.source.dropFirst("demo.home.".count)) : entry.source }
    @Environment(LedgerSession.self) private var session
    @Environment(\.modelContext) private var context
    @State private var processing = false
    @State private var error: String?

    private var title: String { entry.merchant.isEmpty ? tr(entry.categoryName) : entry.merchant }
    private var amount: String {
        guard entry.amount > 0 else { return tr("Verifică suma") }
        return (kind == .income ? "+" : kind == .expense ? "−" : "")
            + shortMoney(MoneyAmount(minorUnits: entry.amount, fractionDigits: entry.digits).decimalValue, currency: entry.currency)
    }
    private var source: String {
        switch reviewSource { case "voice": "Voce"; case "wallet": "Wallet"; case "import": "Import"; default: "Tranzacție" }
    }
    private var symbol: String {
        switch reviewSource { case "voice": "mic"; case "wallet": "wallet.bifold"; default: "tray.and.arrow.down" }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Button { session.sheet = .edit(entry.id) } label: {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        Text(entry.categoryEmoji).font(.system(size: 23))
                        Text(title).font(.system(size: 15, weight: .semibold, design: .rounded)).lineLimit(1)
                        Spacer(minLength: 4)
                        Text(amount).font(.system(size: entry.amount > 0 ? 17 : 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(kind == .income ? BudgetStyle.accent : .primary)
                            .lineLimit(1).minimumScaleFactor(0.75)
                    }
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(spacing: 4) {
                                Image(systemName: symbol)
                                Text(tr(source)); Text("·"); Text(dayLabel(entry.occurredAt))
                            }.font(.system(size: 11, weight: .medium, design: .rounded)).foregroundStyle(.secondary).lineLimit(1)
                            if isExample {
                                Text(tr("Exemplu")).font(.system(size: 10, weight: .semibold, design: .rounded))
                                    .foregroundStyle(BudgetStyle.accent)
                            }
                        }
                        Spacer(minLength: 96)
                    }.frame(minHeight: 44, alignment: .leading)
                }.foregroundStyle(.primary).padding(14).frame(maxWidth: .infinity, minHeight: 114)
                    .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }.buttonStyle(.plain)
                .accessibilityLabel("\(title), \(amount), \(tr(source))" + (isExample ? ", " + tr("Exemplu") : ""))
                .accessibilityHint(tr("Corectează detaliile"))
                .accessibilityIdentifier("home.pending.\(entry.id)")

            HStack(spacing: 2) {
                Button(action: reject) {
                    Image(systemName: "xmark").font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary).frame(width: 30, height: 30)
                        .background(Color.primary.opacity(0.045), in: Circle())
                        .frame(width: 44, height: 44).contentShape(Rectangle())
                }.accessibilityLabel(tr("Respinge") + " " + title)
                    .accessibilityIdentifier("pending.reject.\(entry.id)")
                Button(action: confirm) {
                    Image(systemName: "checkmark").font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(BudgetStyle.accent).frame(width: 30, height: 30)
                        .background(BudgetStyle.accent.opacity(0.09), in: Circle())
                        .frame(width: 44, height: 44).contentShape(Rectangle())
                }.accessibilityLabel(tr("Confirmă") + " " + title)
                    .accessibilityIdentifier("pending.confirm.\(entry.id)")
            }.buttonStyle(.plain).disabled(processing).padding(.trailing, 10).padding(.bottom, 14)
        }
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .alert(tr("Nu am putut salva. Încearcă din nou."), isPresented: Binding(
            get: { error != nil }, set: { if !$0 { error = nil } }
        )) { Button("OK", role: .cancel) {} } message: { Text(tr(error ?? "")) }
    }

    private func confirm() {
        guard !processing else { return }
        processing = true
        defer { processing = false }
        do {
            if let change = try PendingEntryRepository.confirm(entry.id, in: context) { session.show(change) }
        } catch is PendingEntryRepository.ReviewError {
            session.sheet = .edit(entry.id)
        } catch is LedgerRepository.Failure {
            session.sheet = .edit(entry.id)
        } catch {
            self.error = "Nu am putut salva. Încearcă din nou."
        }
    }
    private func reject() {
        guard !processing else { return }
        processing = true
        defer { processing = false }
        do {
            if let change = try PendingEntryRepository.reject(entry.id, in: context) { session.show(change) }
        } catch {
            self.error = "Nu am putut salva. Încearcă din nou."
        }
    }
}
