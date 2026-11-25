import SwiftUI

struct LedgerEntryRow: View {
    let entry: LedgerEntry
    let accounts: [BudgetAccount]
    var categoryName: String?
    private var accountName: String { accounts.first { $0.id == entry.accountID }?.name ?? tr("Cont") }
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.merchant.isEmpty ? (entry.kind == .transfer ? tr("Transfer") : displayCategory) : entry.merchant)
                    .font(.system(size: 16, weight: .semibold, design: .rounded)).foregroundStyle(.primary).lineLimit(2)
                Text(entry.kind == .transfer ? "\(accountName) → \(accounts.first { $0.id == entry.destinationAccountID }?.name ?? tr("Cont"))" : displayCategory)
                    .font(.system(size: 13, weight: .medium, design: .rounded)).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 2)
            VStack(alignment: .trailing, spacing: 4) {
                Text(!entry.isConfirmed && entry.amountMinorUnits == 0 ? tr("Verifică suma") : "\(entry.kind == .income ? "+" : entry.kind == .expense ? "−" : "")\(shortMoney(entry.money.decimalValue, currency: entry.currencyCode))")
                    .font(.system(size: 16, weight: .semibold, design: .rounded)).foregroundStyle(entry.kind == .income ? BudgetStyle.accent : .primary)
                    .lineLimit(1).minimumScaleFactor(0.65).contentTransition(.numericText())
                if entry.kind == .transfer, entry.receivedCurrencyCode != entry.currencyCode, let received = entry.receivedMoney {
                    Text(shortMoney(received.decimalValue, currency: entry.receivedCurrencyCode ?? ""))
                        .font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(.secondary)
                }
            }
        }.padding(.vertical, 12).contentShape(Rectangle())
            .accessibilityElement(children: .combine).accessibilityIdentifier("ledger.row.\(entry.merchant)")
    }
    private var displayCategory: String {
        if let categoryName { return categoryName }
        return entry.categorySystemKey == nil ? entry.categoryNameSnapshot : tr(entry.categoryNameSnapshot)
    }
}

struct LedgerAddButton: View {
    @Environment(LedgerSession.self) private var session
    var body: some View {
        Button { session.sheet = .create(.expense) } label: {
            Image(systemName: "square.and.pencil").font(.system(size: 22, weight: .medium, design: .rounded)).foregroundStyle(BudgetStyle.accent)
                .frame(width: 48, height: 48).glassEffect(.regular.interactive(), in: Circle())
        }.buttonStyle(.plain)
            .accessibilityLabel(tr("Adaugă tranzacție")).accessibilityIdentifier("ledger.add")
    }
}

@MainActor
func displayDate(_ date: Date, monthOnly: Bool = false) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: AppCopy.shared.language.speechLocaleIdentifier)
    if monthOnly { formatter.dateFormat = "LLLL yyyy" }
    else { formatter.dateStyle = .medium; formatter.timeStyle = .none }
    return formatter.string(from: date)
}
