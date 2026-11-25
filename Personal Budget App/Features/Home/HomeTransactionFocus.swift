import SwiftUI

enum HomeFocus: Equatable, Identifiable {
    case transactions(HomeTransactionFocus)
    case account(UUID)
    var transaction: HomeTransactionFocus? {
        if case .transactions(let selection) = self { return selection }
        return nil
    }
    var accountID: UUID? {
        if case .account(let id) = self { return id }
        return nil
    }
    var id: String {
        switch self {
        case .transactions(let selection): "transactions." + selection.id
        case .account(let id): "account." + id.uuidString
        }
    }
}

struct HomeTransactionFocus: Equatable, Identifiable {
    let kind: EntryKind
    let categoryKey: String?
    let name: String
    let emoji: String
    let translatesName: Bool
    var id: String { categoryKey ?? kind.rawValue }

    static let expenses = Self(kind: .expense, categoryKey: nil, name: "Cheltuieli", emoji: "", translatesName: true)
    static let income = Self(kind: .income, categoryKey: nil, name: "Încasări", emoji: "", translatesName: true)
    init(kind: EntryKind, categoryKey: String?, name: String, emoji: String, translatesName: Bool) {
        self.kind = kind; self.categoryKey = categoryKey; self.name = name; self.emoji = emoji; self.translatesName = translatesName
    }
    init(_ category: CategorySpendingSummary) {
        self.init(kind: .expense, categoryKey: category.id, name: category.name, emoji: category.emoji, translatesName: category.systemKey != nil)
    }
}

struct HomeFocusSummary: View {
    let selection: HomeTransactionFocus
    let title: String
    let emoji: String
    let records: [EntryRecord]
    let currency: String
    let period: String
    let limit: Decimal?
    let canEditBudget: Bool
    let onBudget: () -> Void
    private var total: Decimal {
        records.reduce(0) { $0 + MoneyAmount(minorUnits: $1.amount, fractionDigits: $1.digits).decimalValue }
    }
    private var usage: MonthlyBudgetProgress { .init(spent: total, limit: limit) }
    private var statusColor: Color {
        switch usage.status { case .neutral: .secondary; case .warning: .orange; case .exceeded: .red }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                if selection.categoryKey != nil {
                    Text(emoji).font(.system(size: 30)).letterBounce(delay: 0.08).accessibilityHidden(true)
                }
                Text(title).font(.system(size: 20, weight: .semibold, design: .rounded)).letterBounce(delay: 0.12)
                    .accessibilityAddTraits(.isHeader).accessibilityIdentifier("home.focus.title")
                Spacer(minLength: 0)
            }
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        HomeEntryIcon(kind: selection.kind, size: 28)
                            .modifier(HomeCascadeReveal(delay: 0.14))
                        Text(shortMoney(total, currency: currency))
                            .font(.system(size: 40, weight: .semibold, design: .rounded)).tracking(-1)
                            .foregroundStyle(selection.kind == .income ? BudgetStyle.accent : .primary)
                            .lineLimit(1).minimumScaleFactor(0.5).contentTransition(.numericText()).letterBounce(delay: 0.18)
                            .accessibilityIdentifier("home.focus.total")
                    }
                    HStack(spacing: 6) {
                        Image(systemName: "list.bullet").font(.system(size: 11, weight: .medium, design: .rounded))
                            .accessibilityHidden(true)
                        Text("\(records.count) \(tr(records.count == 1 ? "tranzacție" : "tranzacții"))")
                            .contentTransition(.numericText()).letterBounce(delay: 0.24).accessibilityIdentifier("home.focus.count")
                    }.font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading)
                if selection.kind == .expense && (canEditBudget || limit != nil) {
                    budgetControl.modifier(HomeCascadeReveal(delay: 0.12))
                        .offset(y: -14)
                }
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private var budgetControl: some View {
        let chart = HomeBudgetChart(spent: total, limit: limit, currency: currency,
            period: period + selection.id, emptyTitle: "Setează bugetul", accessibilityPrefix: "home.focus.budget",
            statusTint: usage.status == .neutral ? nil : statusColor, showsRemaining: true)
        return Button(action: onBudget) { chart }
            .buttonStyle(.plain).disabled(!canEditBudget)
            .accessibilityLabel(limit.map { tr("Buget lunar") + ", " + shortMoney($0, currency: currency) } ?? tr("Setează bugetul"))
            .accessibilityValue(limit == nil ? "" : [chart.percentage, tr(usage.status == .exceeded ? "Buget depășit" : usage.status == .warning ? "Aproape de limită" : "Buget rămas")].filter { !$0.isEmpty }.joined(separator: ", "))
            .accessibilityIdentifier("home.focus.budget")
    }
}

struct HomeFocusTransactions: View {
    let records: [EntryRecord]
    let kind: EntryKind?
    let accountNames: [UUID: String]
    var focusedAccountID: UUID? = nil
    let onEdit: (UUID) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var groups: [Date: [EntryRecord]] {
        Dictionary(grouping: records, by: { Calendar.current.startOfDay(for: $0.occurredAt) })
    }
    private var emptyTitle: String {
        switch kind {
        case .income: "Fără încasări"
        case .expense: "Fără cheltuieli"
        case .transfer: "Fără transferuri"
        case nil: "Fără tranzacții"
        }
    }
    private var emptyDescription: String {
        switch kind {
        case .income: "Nu ai încasări în această lună."
        case .expense: "Nu ai cheltuieli în această lună."
        case .transfer: "Nu ai transferuri în această lună."
        case nil: "Nu ai tranzacții în această lună."
        }
    }

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            if records.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(tr(emptyTitle))
                        .font(.system(size: 17, weight: .semibold, design: .rounded)).letterBounce(delay: 0.2)
                    Text(tr(emptyDescription))
                        .font(.system(size: 14, weight: .medium, design: .rounded)).foregroundStyle(.secondary)
                }.padding(.vertical, 12).accessibilityIdentifier("home.focus.empty")
            }
            ForEach(groups.keys.sorted(by: >), id: \.self) { day in
                Text(dayLabel(day)).font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary).padding(.top, 8).padding(.bottom, 4)
                    .letterBounce(delay: 0.2).accessibilityAddTraits(.isHeader)
                ForEach(groups[day] ?? [], id: \.id) { record in
                    let index = records.firstIndex { $0.id == record.id } ?? 0
                    VStack(spacing: 0) {
                        Button { onEdit(record.id) } label: {
                            HomeFocusedEntryRow(record: record, accountNames: accountNames, focusedAccountID: focusedAccountID)
                        }.buttonStyle(.plain)
                        Divider().overlay(BudgetStyle.separator).accessibilityHidden(true)
                    }.modifier(HomeCascadeReveal(delay: 0.18 + Double(min(index, 5)) * 0.035))
                        .transition(reduceMotion ? .identity : .opacity.combined(with: .offset(y: 8)))
                }
            }
        }.animation(reduceMotion ? nil : .smooth(duration: 0.35), value: records.map(\.id))
    }
}

/// Keep value snapshots while animated rows disappear after edits or deletions.
private struct HomeFocusedEntryRow: View {
    let record: EntryRecord
    let accountNames: [UUID: String]
    let focusedAccountID: UUID?
    private var category: String { record.categorySystemKey == nil ? record.categoryName : tr(record.categoryName) }
    private var isTransfer: Bool { record.kind == EntryKind.transfer.rawValue }
    private var accountName: String { accountNames[record.accountID] ?? tr("Cont") }
    private var amount: AccountActivity.Amount? {
        if let focusedAccountID { return AccountActivity.amount(of: record, in: focusedAccountID) }
        return .init(money: MoneyAmount(minorUnits: record.amount, fractionDigits: record.digits),
                     currency: record.currency, isIncoming: record.kind == EntryKind.income.rawValue)
    }
    private var caption: String {
        if isTransfer { return accountName + " → " + (record.destinationID.flatMap { accountNames[$0] } ?? tr("Cont")) }
        return focusedAccountID == nil ? accountName : category
    }
    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            HomeEntryIcon(kind: EntryKind(rawValue: record.kind) ?? .expense, emoji: isTransfer ? nil : record.categoryEmoji)
            VStack(alignment: .leading, spacing: 4) {
                Text(record.merchant.isEmpty ? (isTransfer ? tr("Transfer") : category) : record.merchant)
                    .font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundStyle(.primary).lineLimit(2)
                    .letterBounce(delay: 0.22)
                Text(caption).font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 4)
            Text(amount.map { ($0.isIncoming ? "+" : "−") + shortMoney($0.money.decimalValue, currency: $0.currency) } ?? tr("Verifică suma"))
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(amount?.isIncoming == true ? BudgetStyle.accent : .primary)
                .lineLimit(1).minimumScaleFactor(0.65).contentTransition(.numericText())
        }.padding(.vertical, 14).frame(minHeight: 56).contentShape(Rectangle())
            .accessibilityElement(children: .combine).accessibilityIdentifier("ledger.row.\(record.merchant)")
    }
}

/// A quiet glass backing keeps the direction symbols and category emoji visually aligned.
private struct HomeEntryIcon: View {
    let kind: EntryKind
    var emoji: String?
    var size: CGFloat = 36

    var body: some View {
        Group {
            if let emoji {
                Text(emoji).font(.system(size: 21))
            } else {
                Image(systemName: kind.symbol).font(.system(size: size * 0.43, weight: .semibold, design: .rounded))
                    .foregroundStyle(kind == .income ? BudgetStyle.accent : .secondary)
            }
        }.frame(width: size, height: size)
            .glassEffect(.regular.tint(Color.primary.opacity(0.015)), in: RoundedRectangle(cornerRadius: size * 0.34, style: .continuous))
            .accessibilityHidden(true)
    }
}
