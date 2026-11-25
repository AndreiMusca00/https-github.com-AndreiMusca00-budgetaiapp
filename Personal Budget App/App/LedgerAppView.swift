import SwiftUI
import SwiftData

struct LedgerAppView: View {
    let preferences: UserPreferences
    @Environment(\.modelContext) private var context
    @Environment(ExpenseRouter.self) private var router
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var session = LedgerSession()
    @State private var referenceDate = Date.now

    var body: some View {
        ZStack {
            NavigationStack {
                HomeView(preferences: preferences, referenceDate: referenceDate)
            }.accessibilityHidden(session.showsDictation)
            if session.showsDictation {
                VoiceEntryOverlay(localeIdentifier: preferences.speechLocaleIdentifier, onComplete: { text in
                    session.show(try PendingEntryRepository.voice(text: text,
                        currency: session.currency ?? preferences.currencyCode, in: context))
                }, onDismiss: { session.showsDictation = false }, onLanguageSettings: {
                    session.showsDictation = false; session.sheet = .preferences
                }, simulatedTranscript: speechTestTranscript)
                .transition(.asymmetric(insertion: .identity, removal: .opacity)).zIndex(10)
            }
        }
        .animation(reduceMotion ? nil : .smooth(duration: 0.35), value: session.showsDictation)
        .overlay(alignment: .bottom) {
            if !session.showsDictation {
                LedgerToast().padding(.bottom, 144)
                    .animation(reduceMotion ? nil : .smooth(duration: 0.35), value: session.toast != nil)
            }
        }
        .background(BudgetStyle.background)
        .environment(session)
        .sheet(item: presentation(fullScreen: false), onDismiss: processRoute) { destination in
            NavigationStack {
                switch destination {
                case .create(let kind): LedgerEntryEditor(initialKind: kind)
                case .edit(let id): LedgerEntryEditor(entryID: id)
                case .occurrence(let id, let date): LedgerEntryEditor(ruleID: id, dueDate: date)
                case .accounts: AccountListView(isModal: true)
                case .preferences:
                    PreferencesEditor(focus: .language)
                        .toolbar { ToolbarItem(placement: .cancellationAction) { Button(tr("Închide")) { session.sheet = nil } } }
                case .recurrences: RecurringListView(isModal: true)
                case .budget(let date, let currency): MonthlyBudgetEditor(month: date, currency: currency)
                case .categoryBudget(let date, let currency, let id): MonthlyBudgetEditor(month: date, currency: currency, categoryID: id)
                case .budgets(let date, let currency): BudgetPlanView(month: date, currency: currency)
                case .drafts:
                    TransactionHistoryView(pendingOnly: true)
                        .toolbar { ToolbarItem(placement: .cancellationAction) { Button(tr("Gata")) { session.sheet = nil } } }
                }
            }
            .environment(session)
        }
        .fullScreenCover(item: presentation(fullScreen: true), onDismiss: processRoute) { destination in
            NavigationStack {
                switch destination {
                case .create(let kind): LedgerEntryEditor(initialKind: kind)
                case .edit(let id): LedgerEntryEditor(entryID: id)
                case .occurrence(let id, let date): LedgerEntryEditor(ruleID: id, dueDate: date)
                default: EmptyView()
                }
            }.environment(session)
        }
        .task { processRoute() }
        .onChange(of: router.request?.id) { _, _ in processRoute() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { referenceDate = .now; processRoute() }
        }
    }
    private var speechTestTranscript: String? {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-budget-voice-tests") { return "Am cheltuit 35 de lei pe cafea." }
        #endif
        return nil
    }
    private func presentation(fullScreen: Bool) -> Binding<LedgerSheet?> {
        Binding(get: { session.sheet.flatMap { $0.presentsFullScreen == fullScreen ? $0 : nil } }, set: { value in
            if let value { session.sheet = value }
            else if session.sheet?.presentsFullScreen == fullScreen { session.sheet = nil }
        })
    }
    private func processRoute() {
        guard let request = router.request else { return }
        session.showsDictation = false
        if session.sheet != nil { session.sheet = nil; return }
        router.request = nil
        switch request.route {
        case .manual: session.sheet = .create(.expense)
        case .income: session.sheet = .create(.income)
        case .transfer: session.sheet = .create(.transfer)
        }
    }
}
