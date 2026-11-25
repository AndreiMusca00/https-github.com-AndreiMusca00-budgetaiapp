import SwiftUI
import SwiftData

@main
struct Personal_Budget_AppApp: App {
    @State private var preferences: PreferencesStore
    @State private var database: BudgetDatabase
    @State private var router = ExpenseRouter()

    init() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-budget-ui-tests") || ProcessInfo.processInfo.arguments.contains("-budget-onboarding-tests") || ProcessInfo.processInfo.arguments.contains("-budget-orbit-tests") || ProcessInfo.processInfo.arguments.contains("-budget-notes-tests") || ProcessInfo.processInfo.arguments.contains("-budget-review-tests") || ProcessInfo.processInfo.arguments.contains("-budget-voice-tests") || (ProcessInfo.processInfo.arguments.contains("-budget-chart-tests") || ProcessInfo.processInfo.arguments.contains("-budget-payment-calendar-tests")),
           let defaults = UserDefaults(suiteName: "personalBudget.uiChecks") {
            defaults.removePersistentDomain(forName: "personalBudget.uiChecks")
            let preferences = PreferencesStore(defaults: defaults)
            let onboardingTest = ProcessInfo.processInfo.arguments.contains("-budget-onboarding-tests")
            if !onboardingTest { try? preferences.save(UserPreferences(currencyCode: "RON", speechLocaleIdentifier: "ro-RO")) }
            AppCopy.shared.language = .romanian
            _preferences = State(initialValue: preferences)
            let database = BudgetDatabase(inMemory: true, preferredCurrency: onboardingTest ? nil : "RON")
            if ProcessInfo.processInfo.arguments.contains("-budget-orbit-tests") || ProcessInfo.processInfo.arguments.contains("-budget-notes-tests") || (ProcessInfo.processInfo.arguments.contains("-budget-chart-tests") || ProcessInfo.processInfo.arguments.contains("-budget-payment-calendar-tests")), let context = database.container?.mainContext {
                try? OrbitPreviewSeed.insert(in: context)
                if ProcessInfo.processInfo.arguments.contains("-budget-notes-tests") || (ProcessInfo.processInfo.arguments.contains("-budget-chart-tests") || ProcessInfo.processInfo.arguments.contains("-budget-payment-calendar-tests")) {
                    let categories = (try? context.fetch(FetchDescriptor<ExpenseCategory>())) ?? []
                    for (key, amount) in [("home", 150000), ("groceries", 80000), ("shopping", 60000), ("transport", 50000)] {
                        if let category = categories.first(where: { $0.systemKey == key }) {
                            try? LedgerRepository.saveBudget(month: .now, currency: "RON", money: MoneyAmount(minorUnits: Int64(amount), fractionDigits: 2), categoryID: category.id, in: context)
                        }
                    }
                }
            }
            if (ProcessInfo.processInfo.arguments.contains("-budget-chart-tests") || ProcessInfo.processInfo.arguments.contains("-budget-payment-calendar-tests")), let context = database.container?.mainContext,
               let health = (try? context.fetch(FetchDescriptor<ExpenseCategory>()))?.first(where: { $0.systemKey == "health" }) {
                try? LedgerRepository.saveBudget(month: .now, currency: "RON",
                    money: MoneyAmount(minorUnits: 50000, fractionDigits: 2), categoryID: health.id, in: context)
                let categories = (try? context.fetch(FetchDescriptor<ExpenseCategory>())) ?? []
                for (key, amount) in [("shopping", 45000), ("transport", 15000)] {
                    if let category = categories.first(where: { $0.systemKey == key }) {
                        try? LedgerRepository.saveBudget(month: .now, currency: "RON",
                            money: MoneyAmount(minorUnits: Int64(amount), fractionDigits: 2), categoryID: category.id, in: context)
                    }
                }
                if let account = try? LedgerRepository.accounts(in: context).first {
                    for (key, amount) in [("dining", 3000), ("leisure", 2000)] {
                        guard let category = categories.first(where: { $0.systemKey == key }) else { continue }
                        let entry = LedgerEntry(); entry.accountID = account.id; entry.amountMinorUnits = Int64(amount)
                        entry.categoryID = category.id; entry.categorySystemKey = category.systemKey
                        entry.categoryNameSnapshot = category.name; entry.categoryEmojiSnapshot = category.emoji
                        entry.merchant = category.name; context.insert(entry)
                    }
                    try? context.save()
                }
            }
            _database = State(initialValue: database)
            return
        }
        #endif
        let store = PreferencesStore()
        AppCopy.shared.language = store.preferences?.appLanguage ?? BudgetLanguage.preferred(
            deviceLanguages: Locale.preferredLanguages, available: BudgetLanguage.allCases
        ) ?? .english
        _preferences = State(initialValue: store)
        _database = State(initialValue: BudgetDatabase(preferredCurrency: store.preferences?.currencyCode))
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let container = database.container {
                    RootView().modelContainer(container)
                } else {
                    ContentUnavailableView {
                        Label("Datele nu sunt disponibile", systemImage: "externaldrive.badge.exclamationmark")
                    } description: {
                        Text("Nu am putut deschide datele salvate pe telefon.")
                    } actions: {
                        Button("Încearcă din nou") { database.open() }
                            .buttonStyle(.borderedProminent)
                    }
                    .background(BudgetStyle.background)
                }
            }
            .environment(preferences)
            .environment(router)
            .environment(\.locale, preferences.preferences?.locale ?? .current)
            .onChange(of: preferences.preferences) { _, value in
                if let value { AppCopy.shared.language = value.appLanguage; database.configure(currency: value.currencyCode) }
            }
            .fontDesign(.rounded)
            .tint(BudgetStyle.accent)
            .preferredColorScheme(.light)
            .onOpenURL { router.open($0) }
        }
    }
}
