import SwiftUI
import SwiftData

struct HomeView: View {
    let preferences: UserPreferences
    let referenceDate: Date
    @Environment(LedgerSession.self) private var session
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var entries: [LedgerEntry]
    @Query private var budgets: [MonthlyBudget]
    @Query private var accounts: [BudgetAccount]
    @Query private var rules: [RecurrenceRule]
    @Query(sort: \ExpenseCategory.sortOrder) private var categories: [ExpenseCategory]
    @State private var error: String?
    @State private var preparedExamples = false
    @State private var focus: HomeFocus?
    @State private var accountKind: EntryKind?
    @State private var chartScrollID: String?
    @State private var ruleEditor: HomeRuleEditorRoute?
    private var code: String { session.currency ?? preferences.currencyCode }
    private var spent: Decimal { LedgerMath.total(.expense, entries: entries, month: session.month, currency: code) }
    private var income: Decimal { LedgerMath.total(.income, entries: entries, month: session.month, currency: code) }
    private var budget: MonthlyBudget? { budgets.first { $0.categoryID == nil && $0.monthKey == LedgerMath.monthKey(session.month) && $0.currencyCode == code } }
    private var pending: [LedgerEntry] { entries.filter { !$0.isConfirmed }.sorted { $0.createdAt > $1.createdAt } }
    private var chartRows: [CategorySpendingSummary] {
        CategorySpendingSummary.rows(entries: entries, categories: categories, budgets: budgets,
                                    month: session.month, currency: code).filter { $0.count > 0 && $0.spent > 0 }
    }
    private var currencies: [String] { Set(accounts.map(\.currencyCode) + budgets.map(\.currencyCode) + [preferences.currencyCode]).sorted() }
    private var motion: Animation? { reduceMotion ? nil : .smooth(duration: 0.4) }

    private var focusMotion: Animation? { reduceMotion ? nil : .spring(duration: 0.72, bounce: 0.08) }
    private var focusFade: AnyTransition { reduceMotion ? .identity : .opacity.combined(with: .scale(scale: 0.98, anchor: .top)) }
    private var focusedRecords: [EntryRecord] {
        guard let focus, let period = Calendar.current.dateInterval(of: .month, for: session.month) else { return [] }
        if let accountID = focus.accountID {
            return AccountActivity.records(accountID: accountID, entries: entries, month: session.month, kind: accountKind)
        }
        guard let selection = focus.transaction else { return [] }
        return entries.filter {
            $0.isConfirmed && $0.kind == selection.kind && $0.currencyCode == code &&
            $0.occurredAt >= period.start && $0.occurredAt < period.end &&
            (selection.categoryKey == nil || LedgerCategoryKey.of($0) == selection.categoryKey)
        }.sorted {
            if $0.occurredAt != $1.occurredAt { return $0.occurredAt > $1.occurredAt }
            if $0.createdAt != $1.createdAt { return $0.createdAt > $1.createdAt }
            return $0.id.uuidString < $1.id.uuidString
        }.map { EntryRecord($0) }
    }
    private func focusMetadata(_ selection: HomeTransactionFocus) -> (title: String, emoji: String) {
        if let category = categories.first(where: { $0.id.uuidString == selection.categoryKey }) {
            return (category.systemKey == nil ? category.name : tr(category.name), category.emoji)
        }
        return (selection.translatesName ? tr(selection.name) : selection.name, selection.emoji)
    }
    private func select(_ selection: HomeFocus?) {
        withAnimation(focusMotion) {
            if focus?.id != selection?.id { accountKind = nil }
            focus = selection
        }
    }

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                header.frame(maxWidth: 520).padding(.horizontal, 28).padding(.top, 12)
                    .frame(maxWidth: .infinity)
                ScrollViewReader { scroll in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            Color.clear.frame(height: 0).id("home.top")
                            if focus == nil {
                                VStack(alignment: .leading, spacing: 0) {
                                    if !pending.isEmpty {
                                        reviewCards(width: min(296, max(220, proxy.size.width - 90))).padding(.top, 18)
                                    }
                                    accountsOverview.homeIllustrationAnchor(.accounts)
                                        .padding(.top, pending.isEmpty ? 28 : 24)
                                }.transition(reduceMotion ? .identity : .homeContext)
                            }
                            expenseCard.homeIllustrationAnchor(.expenses)
                                .padding(.top, focus == nil ? 30 : 24)
                            if focus == nil {
                                HomePaymentCalendar(items: paymentItems, currency: code, period: LedgerMath.monthKey(session.month) + code,
                                    onManage: { session.sheet = .recurrences },
                                    onEdit: { ruleEditor = HomeRuleEditorRoute(ruleID: $0) },
                                    onConfirm: { session.sheet = .occurrence($0.ruleID, $0.dueDate) })
                                    .homeIllustrationAnchor(.payments)
                                    .padding(.top, 28).transition(reduceMotion ? .identity : .homeContext)
                            }
                            if focus != nil {
                                if focus?.accountID != nil {
                                    LedgerKindFilter(selection: $accountKind, accessibilityPrefix: "home.accountFocus.kind")
                                        .padding(.top, 18).transition(.opacity)
                                }
                                HomeFocusTransactions(records: focusedRecords, kind: focus?.accountID == nil ? focus?.transaction?.kind : accountKind,
                                    accountNames: Dictionary(uniqueKeysWithValues: accounts.map { ($0.id, $0.name) }),
                                    focusedAccountID: focus?.accountID,
                                    onEdit: { session.sheet = .edit($0) })
                                    .padding(.top, focus?.accountID == nil ? 24 : 12).transition(.opacity)
                            }
                            Spacer(minLength: 40)
                        }.frame(maxWidth: 520, minHeight: max(0, proxy.size.height - 86), alignment: .topLeading)
                            .padding(.horizontal, 28).frame(maxWidth: .infinity)
                    }.scrollBounceBehavior(.basedOnSize)
                        .onChange(of: focus?.id) { _, _ in
                            withAnimation(focusMotion) { scroll.scrollTo("home.top", anchor: .top) }
                        }
                }
            }
            .backgroundPreferenceValue(HomeIllustrationAnchors.self) { anchors in
                HomeIllustratedBackdrop(anchors: focus == nil ? anchors : [:])
                    .ignoresSafeArea().transition(.opacity)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { NotesComposeFooter(showsVoice: focus == nil) }
        .background(BudgetStyle.background.ignoresSafeArea())
        .navigationTitle(tr("Acasă")).toolbar(.hidden, for: .navigationBar)
        .animation(motion, value: spent).animation(motion, value: income)
        .animation(motion, value: budget?.limitMinorUnits)
        .animation(motion, value: focusedBudget?.limitMinorUnits)
        .animation(motion, value: accountRows.map(\.balance))
        .animation(motion, value: LedgerMath.monthKey(session.month) + code)
        .animation(motion, value: pending.map(\.id))
        .animation(motion, value: chartRows.map(\.spent))
        .animation(focusMotion, value: focus?.id)
        .onChange(of: LedgerMath.monthKey(session.month) + code) { _, _ in chartScrollID = nil }
        .onChange(of: preferences.currencyCode) { _, value in session.currency = value }
        .task {
            #if DEBUG
            guard !preparedExamples else { return }
            preparedExamples = true
            do {
                try HomeReviewExamples.prepare(currency: code, in: context)
                try PaymentCalendarExamples.refreshCategoryAssignments(in: context)
                let args = ProcessInfo.processInfo.arguments
                if args.contains("-budget-payment-calendar-tests") || args.contains("-budget-payment-calendar-examples") {
                    try PaymentCalendarExamples.prepare(currency: code, asOf: referenceDate, in: context)
                    if args.contains("-budget-payment-status-preview") {
                        try PaymentCalendarExamples.prepareStatusPreview(asOf: referenceDate, in: context)
                    }
                }
            }
            catch { self.error = "Nu am putut salva. Încearcă din nou." }
            #endif
        }
        .sheet(item: $ruleEditor) { route in
            NavigationStack { RecurrenceEditorView(ruleID: route.ruleID) }.environment(session)
        }
        .alert(tr("Nu am putut salva. Încearcă din nou."), isPresented: Binding(
            get: { error != nil }, set: { if !$0 { error = nil } }
        )) { Button("OK", role: .cancel) {} } message: { Text(tr(error ?? "")) }
    }

    private var header: some View {
        @Bindable var session = session
        return HStack {
            NotesMonthButton(month: $session.month, includesYear: !Calendar.current.isDate(session.month, equalTo: referenceDate, toGranularity: .year))
            Spacer()
            if focus != nil {
                Button { select(nil) } label: {
                    Image(systemName: "xmark").font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary).frame(width: 40, height: 40)
                        .glassEffect(.regular.interactive(), in: Circle())
                }.buttonStyle(.plain).accessibilityLabel(tr("Revino la Acasă"))
                    .accessibilityIdentifier("home.focus.close").transition(focusFade)
            } else {
                HStack(spacing: 10) {
                    menu
                    NavigationLink { LedgerSettingsView() } label: {
                        Image(systemName: "gearshape").font(.system(size: 18, weight: .medium, design: .rounded))
                            .foregroundStyle(.primary).frame(width: 40, height: 40)
                            .glassEffect(.regular.interactive(), in: Circle())
                    }.buttonStyle(.plain).accessibilityLabel(tr("Setări")).accessibilityIdentifier("home.settings")
                }.transition(focusFade)
            }
        }
    }

    private var paymentItems: [PaymentCalendarItem] {
        PaymentCalendarProjection.items(rules: rules, entries: entries, month: session.month, currency: code, asOf: referenceDate)
    }
    private var accountRows: [AccountOverviewSummary] {
        AccountOverviewSummary.rows(accounts: accounts, entries: entries, month: session.month, asOf: referenceDate)
    }
    private var accountsOverview: some View {
        HomeAccountsOverview(rows: accountRows, currency: code, income: income, month: session.month,
                             onIncome: { select(.transactions(.income)) }, onAccounts: { session.sheet = .accounts },
                             onAccount: { select(.account($0)) })
    }
    private var focusedBudget: MonthlyBudget? {
        guard let focus = focus?.transaction, focus.kind == .expense else { return nil }
        return budgets.first {
            $0.monthKey == LedgerMath.monthKey(session.month) && $0.currencyCode == code &&
            (focus.categoryKey == nil ? $0.categoryID == nil : $0.categoryID?.uuidString == focus.categoryKey)
        }
    }
    private var focusedTotal: Decimal {
        focusedRecords.reduce(0) { $0 + MoneyAmount(minorUnits: $1.amount, fractionDigits: $1.digits).decimalValue }
    }
    private var focusUsage: MonthlyBudgetProgress { .init(spent: focusedTotal, limit: focusedBudget?.money.decimalValue) }
    private var focusTint: Color? {
        guard focus?.transaction?.kind == .expense else { return nil }
        return switch focusUsage.status {
        case .neutral: nil
        case .warning: Color.orange.opacity(0.30)
        case .exceeded: Color.red.opacity(0.30)
        }
    }
    private var canEditFocusedBudget: Bool {
        guard let focus = focus?.transaction, focus.kind == .expense else { return false }
        return focus.categoryKey == nil || categories.contains { $0.id.uuidString == focus.categoryKey }
    }
    private func editFocusedBudget() {
        guard let focus = focus?.transaction, canEditFocusedBudget else { return }
        if let key = focus.categoryKey, let category = categories.first(where: { $0.id.uuidString == key }) {
            session.sheet = .categoryBudget(session.month, code, category.id)
        } else {
            session.sheet = .budget(session.month, code)
        }
    }

    // The overview sits on the page; only a focused category gets a quiet glass surface.
    private var expenseCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            if let accountID = focus?.accountID, let account = accountRows.first(where: { $0.id == accountID }) {
                HomeAccountFocusSummary(account: account, month: session.month)
                    .padding(20)
                    .transition(.opacity.animation(.easeIn(duration: 0.2).delay(0.08)))
            } else if let focus = focus?.transaction {
                let metadata = focusMetadata(focus)
                HomeFocusSummary(selection: focus, title: metadata.title, emoji: metadata.emoji,
                    records: focusedRecords, currency: code, period: LedgerMath.monthKey(session.month) + code,
                    limit: focusedBudget?.money.decimalValue,
                    canEditBudget: canEditFocusedBudget, onBudget: editFocusedBudget)
                    .padding(20)
                    .transition(.opacity.animation(.easeIn(duration: 0.2).delay(0.08)))
            } else {
                expenseOverview.transition(.opacity.animation(.easeOut(duration: 0.12)))
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
            .modifier(HomeFocusSurface(active: focus != nil, tint: focusTint))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(focus == nil ? "home.expenses.overview" : "home.focus.summary")
    }

    private var expenseOverview: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .center, spacing: 14) {
                Button { select(.transactions(.expenses)) } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        total(title: "Cheltuieli", amount: spent, identifier: "home.spent", isIncome: false, showsDirection: false)
                        if let budget {
                            Text(remainingText(limit: budget.money.decimalValue))
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(spent > budget.money.decimalValue ? Color.orange : .secondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .contentTransition(.numericText()).accessibilityIdentifier("home.remaining")
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityIdentifier("home.expenses")
                budgetChart
            }
            if !chartRows.isEmpty {
                HomeCategoryChart(rows: chartRows, currency: code, period: LedgerMath.monthKey(session.month) + code,
                                  visibleCategory: $chartScrollID, onSelect: { select(.transactions(HomeTransactionFocus($0))) })
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
    }

    private var budgetChart: some View {
        let limit = budget?.money.decimalValue
        let chart = HomeBudgetChart(spent: spent, limit: limit, currency: code, period: LedgerMath.monthKey(session.month) + code)
        return Button { session.sheet = .budget(session.month, code) } label: {
            chart
        }.buttonStyle(.plain)
            .accessibilityLabel(tr(limit == nil ? "Setează bugetul" : "Buget lunar"))
            .accessibilityValue(chart.percentage)
            .accessibilityIdentifier("home.budget")
    }

    private func remainingText(limit: Decimal) -> String {
        let remaining = limit - spent
        if AppCopy.shared.language == .romanian {
            return remaining >= 0 ? "Mai ai \(shortMoney(remaining, currency: code)) din buget." : "Ai depășit bugetul cu \(shortMoney(abs(remaining), currency: code))."
        }
        return remaining >= 0 ? "\(shortMoney(remaining, currency: code)) left in your budget." : "\(shortMoney(abs(remaining), currency: code)) over budget."
    }

    private func total(title: String, amount: Decimal, identifier: String, isIncome: Bool, showsDirection: Bool = true) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Label(tr(title), systemImage: isIncome ? "arrow.down.left" : "arrow.up.right")
                    .font(.system(size: 14, weight: .medium, design: .rounded)).foregroundStyle(.secondary)
                    .letterBounce(delay: 0.04)
                Spacer()
                if showsDirection {
                    Image(systemName: isIncome ? "arrow.down.left" : "arrow.up.right")
                        .font(.system(size: 12, weight: .semibold)).foregroundStyle(isIncome ? BudgetStyle.accent : .secondary)
                        .frame(width: 26, height: 26).background(BudgetStyle.accent.opacity(0.055), in: Circle())
                        .accessibilityHidden(true)
                }
            }
            Text(shortMoney(amount, currency: code))
                .font(.system(size: showsDirection ? 36 : 32, weight: .semibold, design: .rounded)).tracking(-1).lineLimit(1).minimumScaleFactor(0.45)
                .foregroundStyle(isIncome ? BudgetStyle.accent : .primary).contentTransition(.numericText())
                .accessibilityIdentifier(identifier).accessibilityLabel(formattedMoney(amount, currency: code))
        }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
    }

    private func reviewCards(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            NavigationLink { TransactionHistoryView(pendingOnly: true) } label: {
                HStack(spacing: 7) {
                    Text(tr("De verificat"))
                    Text("\(pending.count)").font(.system(size: 11, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 6).padding(.vertical, 2).background(BudgetStyle.accent.opacity(0.07), in: Capsule())
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 10, weight: .medium))
                }.font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(.secondary).frame(minHeight: 32).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityIdentifier("home.review")
                .accessibilityLabel("\(pending.count) " + tr("tranzacții de verificat"))
            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(pending) { entry in
                        HomePendingCard(entry: entry).frame(width: width)
                            .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    }
                }.scrollTargetLayout().padding(.vertical, 4).padding(.horizontal, 2)
            }.scrollIndicators(.hidden).scrollTargetBehavior(.viewAligned).scrollClipDisabled()
                .accessibilityIdentifier("home.pendingCards")
        }
    }

    private var menu: some View {
        Menu {
            NavigationLink { TransactionHistoryView() } label: { Label(tr("Tranzacții"), systemImage: "list.bullet") }
                .accessibilityIdentifier("home.menu.transactions")
            NavigationLink { CategorySpendingView() } label: { Label(tr("Categorii"), systemImage: "square.grid.2x2") }
                .accessibilityIdentifier("home.menu.categories")
            Divider()
            Button(tr("Buget lunar")) { session.sheet = .budget(session.month, code) }.accessibilityIdentifier("home.editBudget")
            Button(tr("Bugete pe categorii")) { session.sheet = .budgets(session.month, code) }.accessibilityIdentifier("home.budgets")
            Button(tr("Conturi")) { session.sheet = .accounts }.accessibilityIdentifier("home.accounts")
            Button(tr("Recurente")) { session.sheet = .recurrences }.accessibilityIdentifier("home.recurrences")
            if rules.contains(where: { PaymentCalendarExamples.contains($0.id) }) {
                Button(tr("Șterge exemplele din calendar"), role: .destructive) {
                    do { session.show(try PaymentCalendarExamples.remove(in: context)) }
                    catch { self.error = "Nu am putut salva. Încearcă din nou." }
                }.accessibilityIdentifier("home.clearPaymentExamples")
            }
            if currencies.count > 1 {
                Picker(tr("Moneda"), selection: Binding(get: { code }, set: { session.currency = $0 })) {
                    ForEach(currencies, id: \.self) { Text($0).tag($0) }
                }.accessibilityIdentifier("home.currency")
            }
            #if DEBUG
            if entries.contains(where: \.isHomeExample) {
                Divider()
                Button(tr("Șterge exemplele"), role: .destructive) {
                    do { session.show(try HomeReviewExamples.remove(in: context)) }
                    catch { self.error = "Nu am putut salva. Încearcă din nou." }
                }.accessibilityIdentifier("home.clearExamples")
            }
            #endif
        } label: {
            Image(systemName: "ellipsis").font(.system(size: 18, weight: .medium, design: .rounded)).foregroundStyle(.primary)
                .frame(width: 40, height: 40).glassEffect(.regular.interactive(), in: Circle())
        }.buttonStyle(.plain).accessibilityLabel(tr("Mai multe")).accessibilityIdentifier("home.menu")
    }
}

private struct HomeRuleEditorRoute: Identifiable {
    let id = UUID()
    let ruleID: UUID
}

private struct HomeFocusSurface: ViewModifier {
    let active: Bool
    let tint: Color?
    @ViewBuilder func body(content: Content) -> some View {
        if active {
            content.glassEffect(.regular.tint(tint), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        } else { content }
    }
}
