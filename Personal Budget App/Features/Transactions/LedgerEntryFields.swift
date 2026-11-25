import SwiftUI
import SwiftData

struct EntryDraft {
    var kind: EntryKind = .expense
    var amount = ""
    var accountID: UUID?
    var destinationID: UUID?
    var receivedAmount = ""
    var categoryID: UUID?
    var merchant = ""
    var note = ""
    var date = Date.now
    var repeatFrequency: RepeatFrequency?

    func input(accounts: [BudgetAccount], requiresDescription: Bool = false) -> EntryInput? {
        guard !requiresDescription || !merchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        guard let account = accounts.first(where: { $0.id == accountID }),
              let money = MoneyAmount.parse(amount, currencyCode: account.currencyCode) else { return nil }
        var received: MoneyAmount?
        if kind == .transfer {
            guard let destination = accounts.first(where: { $0.id == destinationID }), destination.id != account.id else { return nil }
            received = destination.currencyCode == account.currencyCode ? money : MoneyAmount.parse(receivedAmount, currencyCode: destination.currencyCode)
            guard received != nil else { return nil }
        }
        return EntryInput(kind: kind, money: money, accountID: account.id, destinationAccountID: destinationID,
                          receivedMoney: received, categoryID: categoryID, merchant: merchant, note: note, occurredAt: date)
    }
}

struct LedgerEntryFields: View {
    @Binding var draft: EntryDraft
    let accounts: [BudgetAccount]
    var allowsKindChange = true
    var allowsFuture = false
    var autofocusAmount = false
    var allowsRecurrence = false
    @Query(sort: \ExpenseCategory.sortOrder) private var categories: [ExpenseCategory]
    @State private var inputPicker: EntryPicker?
    @State private var hasFocusedAmount = false
    @FocusState private var focus: EntryField?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var kindSelection
    private enum EntryField: Hashable { case amount, description, received }
    private enum EntryPicker { case category, source, destination, date, frequency }
    private var account: BudgetAccount? { accounts.first { $0.id == draft.accountID } }
    private var destination: BudgetAccount? { accounts.first { $0.id == draft.destinationID } }
    private var category: ExpenseCategory? { categories.first { $0.id == draft.categoryID } }
    private var motion: Animation? { reduceMotion ? nil : .smooth(duration: 0.3) }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if allowsKindChange { kindPicker }
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(tr("Suma")).font(.system(size: 11, weight: .medium, design: .rounded)).foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        TextField("0", text: $draft.amount)
                            .keyboardType(.decimalPad).focused($focus, equals: .amount)
                            .font(.system(size: 30, weight: .semibold, design: .rounded))
                            .minimumScaleFactor(0.65).accessibilityLabel(tr("Suma")).accessibilityIdentifier("entry.amount")
                        Text(account.map { moneyUnit($0.currencyCode) } ?? "—")
                            .font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(.secondary)
                    }
                }.frame(width: 118)
                Rectangle().fill(BudgetStyle.separator).frame(width: 1, height: 42).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text(tr("Descriere")).font(.system(size: 11, weight: .medium, design: .rounded)).foregroundStyle(.secondary)
                    TextField(tr("Descriere"), text: $draft.merchant)
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .focused($focus, equals: .description).textInputAutocapitalization(.sentences).autocorrectionDisabled()
                        .submitLabel(.done).onSubmit(dismissKeyboard)
                        .accessibilityLabel(tr("Descriere")).accessibilityIdentifier("entry.merchant")
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.padding(.vertical, 8)
            EntryChipLayout(spacing: 8) {
                if draft.kind == .transfer {
                    accountChip(destination: false)
                    accountChip(destination: true)
                } else {
                    Button { openPicker(.category) } label: {
                        CompactEntryChip(title: category.map { $0.systemKey == nil ? $0.name : tr($0.name) } ?? tr("Categorie"),
                                         emoji: category?.emoji, symbol: category == nil ? "square.grid.2x2" : nil)
                    }.accessibilityLabel("\(tr("Categorie")): \(category.map { $0.systemKey == nil ? $0.name : tr($0.name) } ?? tr("Necategorizat"))")
                        .accessibilityIdentifier("entry.category")
                    accountChip(destination: false)
                }
                Button { openPicker(.date) } label: {
                    CompactEntryChip(title: dateTitle, symbol: "calendar")
                }.accessibilityLabel("\(tr("Data")): \(dateTitle), \(displayDate(draft.date))")
                    .accessibilityIdentifier("entry.date")
            }.buttonStyle(.plain)
            if draft.kind == .transfer, let source = account, let destination, source.currencyCode != destination.currencyCode {
                HStack(spacing: 12) {
                    Text("\(tr("Suma primită")) · \(destination.currencyCode)")
                        .font(.system(size: 13, weight: .medium, design: .rounded)).foregroundStyle(.secondary)
                    Spacer(minLength: 4)
                    TextField("0", text: $draft.receivedAmount)
                        .keyboardType(.decimalPad).focused($focus, equals: .received).multilineTextAlignment(.trailing)
                        .font(.system(size: 21, weight: .semibold, design: .rounded))
                        .frame(maxWidth: 120).accessibilityLabel(tr("Suma primită")).accessibilityIdentifier("entry.received")
                }.frame(minHeight: 44)
            }
            if allowsRecurrence && draft.kind != .transfer { recurrenceControl }
        }
        .animation(motion, value: draft.kind)
        .onChange(of: draft.accountID) { _, id in if id == draft.destinationID { draft.destinationID = nil } }
        .onChange(of: focus) { _, field in if field != nil { inputPicker = nil } }
        .background {
            EntryInputPicker(selection: inputSelection, onSelect: selectInputOption, onDateChange: { draft.date = $0 }, onDismiss: { inputPicker = nil })
                .frame(width: 0, height: 0).allowsHitTesting(false).accessibilityHidden(true)
        }
        .task {
            guard autofocusAmount && !hasFocusedAmount else { return }
            hasFocusedAmount = true
            do { try await Task.sleep(for: .milliseconds(350)) } catch { return }
            guard !Task.isCancelled, inputPicker == nil else { return }
            focus = .amount
        }
    }

    private var kindPicker: some View {
        HStack(spacing: 4) {
            ForEach(EntryKind.allCases.filter { !allowsFuture || $0 != .transfer }) { kind in
                Button {
                    guard draft.kind != kind else { return }
                    if inputPicker != nil { dismissKeyboard() }
                    withAnimation(motion) { draft.kind = kind; draft.categoryID = nil; if kind == .transfer { draft.repeatFrequency = nil } }
                } label: {
                    Text(tr(kind.title)).font(.system(size: 14, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity, minHeight: 42)
                        .foregroundStyle(draft.kind == kind ? BudgetStyle.accent : .secondary)
                        .background {
                            if draft.kind == kind {
                                Capsule().fill(BudgetStyle.accent.opacity(0.025)).glassEffect(.regular, in: Capsule())
                                    .matchedGeometryEffect(id: "entry.kind.selection", in: kindSelection)
                            }
                        }
                }.buttonStyle(.plain).accessibilityIdentifier("entry.kind.\(kind.rawValue)")
                    .accessibilityAddTraits(draft.kind == kind ? .isSelected : [])
            }
        }.accessibilityElement(children: .contain).accessibilityIdentifier("entry.kind")
    }

    private func accountChip(destination isDestination: Bool) -> some View {
        let selected = isDestination ? destination : account
        let label = tr(isDestination ? "În cont" : draft.kind == .transfer ? "Din cont" : "Cont")
        return Button { openPicker(isDestination ? .destination : .source) } label: {
            CompactEntryChip(title: selected?.name ?? label, emoji: draft.kind == .transfer ? nil : selected?.emoji,
                symbol: draft.kind == .transfer ? isDestination ? "arrow.down.left" : "arrow.up.right" : selected == nil ? "wallet.bifold" : nil)
        }.accessibilityLabel("\(label): \(selected?.name ?? tr("Alege contul"))")
            .accessibilityIdentifier(isDestination ? "entry.destination" : "entry.account")
    }

    private func openPicker(_ picker: EntryPicker) {
        focus = nil
        if picker == .destination && draft.destinationID == nil {
            draft.destinationID = accounts.first { $0.id != draft.accountID }?.id
        }
        inputPicker = picker
    }

    private var inputSelection: EntryInputSelection? {
        guard let inputPicker else { return nil }
        switch inputPicker {
        case .category:
            let options = [EntryInputOption(id: nil, title: tr("Necategorizat"), emoji: "🧾")]
                + categories.filter { $0.kindRawValue == draft.kind.rawValue }.map {
                    EntryInputOption(id: $0.id.uuidString, title: $0.systemKey == nil ? $0.name : tr($0.name), emoji: $0.emoji)
                }
            return EntryInputSelection(id: "category.\(draft.kind.rawValue)", title: tr("Categorie"),
                                       options: options, selectedID: draft.categoryID?.uuidString)
        case .source, .destination:
            let isDestination = inputPicker == .destination
            let options = accounts.filter { !isDestination || $0.id != draft.accountID }.map {
                EntryInputOption(id: $0.id.uuidString, title: $0.name, emoji: $0.emoji, detail: $0.name.localizedCaseInsensitiveContains($0.currencyCode) ? nil : $0.currencyCode)
            }
            return EntryInputSelection(id: isDestination ? "destination" : "source",
                title: tr(isDestination ? "În cont" : draft.kind == .transfer ? "Din cont" : "Cont"),
                options: options, selectedID: (isDestination ? draft.destinationID : draft.accountID)?.uuidString,
                emptyMessage: tr("Adaugă un alt cont din Setări."))
        case .date:
            return EntryInputSelection(id: "date", title: tr("Data"), date: draft.date,
                maximumDate: allowsFuture ? nil : .now,
                localeIdentifier: AppCopy.shared.language.speechLocaleIdentifier)
        case .frequency:
            let options = RepeatFrequency.allCases.map {
                EntryInputOption(id: $0.rawValue, title: tr($0.title), emoji: "")
            }
            return EntryInputSelection(id: "frequency", title: tr("Frecvență"), options: options,
                                       selectedID: draft.repeatFrequency?.rawValue)
        }
    }

    private func selectInputOption(_ id: String?) {
        switch inputPicker {
        case .category: draft.categoryID = id.flatMap(UUID.init(uuidString:))
        case .source: draft.accountID = id.flatMap(UUID.init(uuidString:))
        case .destination: draft.destinationID = id.flatMap(UUID.init(uuidString:))
        case .frequency: draft.repeatFrequency = id.flatMap(RepeatFrequency.init(rawValue:))
        case .date, nil: break
        }
    }

    private var recurrenceControl: some View {
        HStack(spacing: 12) {
            Text(tr("Recurentă")).font(.system(size: 14, weight: .medium, design: .rounded))
            if let frequency = draft.repeatFrequency {
                Button { openPicker(.frequency) } label: {
                    CompactEntryChip(title: tr(frequency.title), symbol: "repeat")
                }.buttonStyle(.plain).accessibilityLabel("\(tr("Frecvență")): \(tr(frequency.title))")
                    .accessibilityIdentifier("entry.frequency")
            }
            Spacer(minLength: 8)
            Toggle(tr("Recurentă"), isOn: Binding(get: { draft.repeatFrequency != nil }, set: { enabled in
                draft.repeatFrequency = enabled ? .monthly : nil
                if !enabled && inputPicker == .frequency { dismissKeyboard() }
            }))
            .labelsHidden().tint(BudgetStyle.accent).accessibilityIdentifier("entry.recurring")
        }.frame(minHeight: 44).animation(motion, value: draft.repeatFrequency)
    }

    private var dateTitle: String {
        if Calendar.current.isDateInToday(draft.date) { return tr("Azi") }
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: AppCopy.shared.language.speechLocaleIdentifier)
        formatter.dateFormat = "d MMM"
        return formatter.string(from: draft.date)
    }

    private func dismissKeyboard() {
        inputPicker = nil
        focus = nil
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

private struct CompactEntryChip: View {
    let title: String
    var emoji: String?
    var symbol: String?
    var body: some View {
        HStack(spacing: 4) {
            if let emoji { Text(emoji).font(.system(size: 15)).fixedSize() }
            if let symbol { Image(systemName: symbol).font(.system(size: 11, weight: .medium)).fixedSize() }
            Text(title).font(.system(size: 12, weight: .semibold, design: .rounded))
                .fixedSize(horizontal: false, vertical: true).layoutPriority(1)
            Image(systemName: "chevron.down").font(.system(size: 7, weight: .semibold))
                .foregroundStyle(.secondary).fixedSize().accessibilityHidden(true)
        }.foregroundStyle(.primary).padding(.horizontal, 8).padding(.vertical, 8).frame(minHeight: 36)
            .glassEffect(.regular.interactive(), in: Capsule())
    }
}


private struct EntryChipLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrangement(width: proposal.width ?? .infinity, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let layout = arrangement(width: bounds.width, subviews: subviews)
        for (subview, frame) in zip(subviews, layout.frames) {
            subview.place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                          anchor: .topLeading, proposal: ProposedViewSize(frame.size))
        }
    }

    private func arrangement(width: CGFloat, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        let available = max(0, width)
        let sizes = subviews.map { subview in
            let ideal = subview.sizeThatFits(.unspecified)
            return subview.sizeThatFits(ProposedViewSize(width: min(ideal.width, available), height: nil))
        }
        // Keep account and date together when a long category needs its own row.
        let separateFirst = sizes.count == 3 && sizes.reduce(0) { $0 + $1.width } + spacing * 2 > available
            && sizes[1].width + spacing + sizes[2].width <= available
        var frames: [CGRect] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var usedWidth: CGFloat = 0
        for (index, size) in sizes.enumerated() {
            if x > 0 && (x + size.width > available || (separateFirst && index == 1)) {
                x = 0; y += rowHeight + spacing; rowHeight = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            usedWidth = max(usedWidth, x + size.width)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return (CGSize(width: available.isFinite ? available : usedWidth, height: y + rowHeight), frames)
    }
}
