import SwiftUI
import SwiftData

struct TransactionHistoryView: View {
    var pendingOnly = false
    var fixedCategoryKey: String?
    var fixedCategoryTitle: String?
    private let initialKind: EntryKind?
    @Environment(LedgerSession.self) private var session
    @Environment(PreferencesStore.self) private var preferences
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \LedgerEntry.occurredAt, order: .reverse) private var entries: [LedgerEntry]
    @Query(sort: \BudgetAccount.createdAt) private var accounts: [BudgetAccount]
    @Query private var categories: [ExpenseCategory]
    @State private var search = ""
    @State private var showsSearch = false
    @FocusState private var searchFocused: Bool
    @State private var allMonths = false
    @State private var allCurrencies = false
    @State private var kind: EntryKind?
    @State private var accountID: UUID?
    @State private var categoryKey: String?
    @State private var error: String?
    @State private var pendingEditor: UUID?
    init(pendingOnly: Bool = false, fixedCategoryKey: String? = nil, fixedCategoryTitle: String? = nil, initialKind: EntryKind? = nil, initialAccountID: UUID? = nil) {
        self.pendingOnly = pendingOnly; self.fixedCategoryKey = fixedCategoryKey; self.fixedCategoryTitle = fixedCategoryTitle
        self.initialKind = initialKind; _kind = State(initialValue: initialKind)
        _accountID = State(initialValue: initialAccountID)
        _allCurrencies = State(initialValue: initialAccountID != nil)
    }

    private var code: String { session.currency ?? preferences.preferences?.currencyCode ?? "RON" }
    private var motion: Animation? { reduceMotion ? nil : .smooth(duration: 0.4) }
    private var filtered: [LedgerEntry] {
        entries.filter { entry in
            guard entry.isConfirmed != pendingOnly else { return false }
            if !pendingOnly {
                if !allMonths && LedgerMath.monthKey(entry.occurredAt) != LedgerMath.monthKey(session.month) { return false }
                if !allCurrencies && entry.currencyCode != code { return false }
            }
            if let fixedCategoryKey, (entry.kind != .expense || LedgerCategoryKey.of(entry) != fixedCategoryKey) { return false }
            if let kind, entry.kind != kind { return false }
            if let accountID, entry.accountID != accountID && entry.destinationAccountID != accountID { return false }
            if let categoryKey, LedgerCategoryKey.of(entry) != categoryKey { return false }
            let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
            return query.isEmpty || "\(entry.merchant) \(entry.note) \(entry.categoryNameSnapshot) \(entry.categorySystemKey == nil ? entry.categoryNameSnapshot : tr(entry.categoryNameSnapshot))".localizedStandardContains(query)
        }
    }
    private var days: [Date] { Set(filtered.map { Calendar.current.startOfDay(for: $0.occurredAt) }).sorted(by: >) }
    private var categoryOptions: [(id: String, name: String)] {
        var names: [String: String] = [:]
        for entry in entries where entry.kind != .transfer {
            names[LedgerCategoryKey.of(entry)] = entry.categorySystemKey == nil ? entry.categoryNameSnapshot : tr(entry.categoryNameSnapshot)
        }
        for category in categories { names[category.id.uuidString] = category.systemKey == nil ? category.name : tr(category.name) }
        return names.map { (id: $0.key, name: $0.value) }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
    private var hasFilters: Bool { accountID != nil || categoryKey != nil || allMonths || allCurrencies }

    var body: some View {
        @Bindable var session = session
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                NotesTitle(title: fixedCategoryTitle ?? (pendingOnly ? "De verificat" : kind == .income ? "Încasări" : kind == .expense ? "Cheltuieli" : "Tranzacții"))
                if pendingOnly {
                    Text(tr("Aceste propuneri nu intră în total.")).font(.system(size: 14, weight: .medium, design: .rounded)).foregroundStyle(.secondary).padding(.top, 12)
                } else if allMonths {
                    Button(tr("Toate lunile")) { withAnimation(motion) { allMonths = false } }
                        .font(.system(size: 17, weight: .medium, design: .rounded)).foregroundStyle(.secondary).frame(minHeight: 44)
                } else { NotesMonthButton(month: $session.month) }
                if !pendingOnly && fixedCategoryKey == nil {
                    LedgerKindFilter(selection: $kind).padding(.top, 8).padding(.bottom, 6)
                        .onChange(of: kind) { _, _ in searchFocused = false }
                }
                if (kind == .income || kind == .expense) && !pendingOnly && !allCurrencies {
                    Text(shortMoney(filtered.reduce(Decimal(0)) { $0 + $1.money.decimalValue }, currency: code))
                        .font(.system(size: 20, weight: .semibold, design: .rounded)).foregroundStyle(kind == .income ? BudgetStyle.accent : .primary)
                        .contentTransition(.numericText()).padding(.top, 6).padding(.bottom, 8)
                        .accessibilityIdentifier(kind == .income ? "history.incomeTotal" : "history.expenseTotal")
                }
                if showsSearch {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                        TextField(tr("Caută"), text: $search).focused($searchFocused).submitLabel(.search)
                            .accessibilityIdentifier("history.searchField").onSubmit { searchFocused = false }.onAppear { searchFocused = true }
                        Button { withAnimation(motion) { search = ""; showsSearch = false; searchFocused = false } } label: {
                            Image(systemName: "xmark").font(.system(size: 12, weight: .medium, design: .rounded)).frame(width: 32, height: 44)
                        }.accessibilityLabel(tr("Închide căutarea")).accessibilityIdentifier("history.closeSearch")
                    }.font(.system(size: 16, weight: .medium, design: .rounded)).padding(.top, 8).transition(.move(edge: .top).combined(with: .opacity))
                }
                if hasFilters {
                    HStack {
                        Text(filterDescription).font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(.secondary).lineLimit(2)
                        Spacer()
                        Button(tr("Resetează filtrele"), action: reset).font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(BudgetStyle.accent)
                    }.padding(.top, 8).transition(.opacity)
                }
            }
            .padding(.top, 8).padding(.bottom, 10).padding(.horizontal, 28)
            .animation(motion, value: showsSearch).animation(motion, value: hasFilters)
            .animation(motion, value: kind)
            List {
            if filtered.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text(tr(pendingOnly ? "Totul e la zi" : kind == .income && search.isEmpty ? "Fără încasări" : entries.isEmpty ? "Fără tranzacții" : "Niciun rezultat"))
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                    Text(tr(pendingOnly ? "Nu ai propuneri de verificat." : kind == .income && search.isEmpty ? "Adaugă un venit din butonul de jos." : entries.isEmpty ? "Adaugă prima tranzacție din butonul de jos." : "Încearcă altă căutare sau schimbă filtrele."))
                        .font(.system(size: 14, weight: .medium, design: .rounded)).foregroundStyle(.secondary)
                }.padding(.vertical, 24).listRowInsets(EdgeInsets(top: 0, leading: 28, bottom: 0, trailing: 28))
                    .listRowSeparator(.hidden).listRowBackground(Color.clear).accessibilityIdentifier("history.empty")
            }
            ForEach(days, id: \.self) { day in
                Section {
                    ForEach(filtered.filter { Calendar.current.isDate($0.occurredAt, inSameDayAs: day) }) { entry in
                        Button {
                            if pendingOnly { pendingEditor = entry.id }
                            else { session.sheet = .edit(entry.id) }
                        } label: { LedgerEntryRow(entry: entry, accounts: accounts) }
                            .buttonStyle(.plain).listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 0, leading: 28, bottom: 0, trailing: 28))
                            .listRowSeparatorTint(BudgetStyle.separator)
                            .swipeActions {
                                Button(tr("Șterge"), role: .destructive) {
                                    do { session.show(try LedgerRepository.deleteEntry(entry, in: context)) }
                                    catch { self.error = "Nu am putut salva. Încearcă din nou." }
                                }
                            }
                    }
                } header: {
                    Text(dayLabel(day)).font(.system(size: 15, weight: .medium, design: .rounded)).foregroundStyle(.secondary).textCase(nil)
                        .padding(.top, 12).padding(.bottom, 1)
                }
            }
            }
            .listStyle(.plain).scrollContentBackground(.hidden)
            .animation(motion, value: filtered.map(\.id))
            .scrollDismissesKeyboard(.interactively)
        }
        .background(BudgetStyle.background)
        .navigationTitle("").navigationBarTitleDisplayMode(.inline).toolbarRole(.editor)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    withAnimation(motion) { showsSearch.toggle(); if !showsSearch { search = "" } }
                    searchFocused = showsSearch
                } label: { Image(systemName: "magnifyingglass").font(.system(size: 17, weight: .medium, design: .rounded)).foregroundStyle(.primary) }
                    .accessibilityLabel(tr("Caută")).accessibilityIdentifier("history.search")
            }
            if !pendingOnly { ToolbarItem(placement: .primaryAction) { filterMenu } }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { if !pendingOnly { NotesComposeFooter() } }
        .fullScreenCover(isPresented: Binding(get: { pendingEditor != nil }, set: { if !$0 { pendingEditor = nil } })) {
            NavigationStack { LedgerEntryEditor(entryID: pendingEditor) }
        }
        .alert(tr(error ?? ""), isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK", role: .cancel) { } }
    }

    private var filterDescription: String {
        var parts: [String] = []
        if let kind { parts.append(tr(kind.title)) }
        if let accountID, let account = accounts.first(where: { $0.id == accountID }) { parts.append(account.name) }
        if let categoryKey, let option = categoryOptions.first(where: { $0.id == categoryKey }) { parts.append(option.name) }
        if allMonths { parts.append(tr("Toate lunile")) }
        if allCurrencies { parts.append(tr("Toate monedele")) }
        return parts.joined(separator: " · ")
    }
    private var filterMenu: some View {
        Menu {
            Toggle(tr("Toate lunile"), isOn: $allMonths)
            Toggle(tr("Toate monedele"), isOn: $allCurrencies)
            Picker(tr("Moneda"), selection: Binding(get: { code }, set: { session.currency = $0; allCurrencies = false })) {
                ForEach(Set(entries.map(\.currencyCode) + accounts.map(\.currencyCode) + [code]).sorted(), id: \.self) { Text($0).tag($0) }
            }
            if fixedCategoryKey == nil {
                Picker(tr("Categorie"), selection: $categoryKey) {
                    Text(tr("Toate categoriile")).tag(nil as String?)
                    ForEach(categoryOptions, id: \.id) { Text($0.name).tag(Optional($0.id)) }
                }
            }
            Picker(tr("Cont"), selection: $accountID) {
                Text(tr("Toate conturile")).tag(nil as UUID?)
                ForEach(accounts) { Text($0.name).tag(Optional($0.id)) }
            }
            Button(tr("Resetează filtrele"), action: reset)
        } label: { Image(systemName: hasFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease").font(.system(size: 17, weight: .medium, design: .rounded)).foregroundStyle(.primary) }
            .accessibilityLabel(tr("Filtre")).accessibilityIdentifier("history.filters")
    }
    private func reset() { withAnimation(motion) { kind = initialKind; accountID = nil; categoryKey = nil; allMonths = false; allCurrencies = false; search = "" } }
}
