import SwiftUI
import SwiftData

struct LedgerSettingsView: View {
    @State private var showsCategories = false
    @Environment(PreferencesStore.self) private var preferences
    @Environment(LedgerSession.self) private var session
    @Query private var entries: [LedgerEntry]
    var body: some View {
        Group {
            List {
                Section {
                    NavigationLink { AccountListView() } label: { Label(tr("Conturi"), systemImage: "wallet.bifold") }
                        .accessibilityIdentifier("settings.accounts")
                    Button { session.sheet = .budgets(.now, preferences.preferences?.currencyCode ?? "RON") } label: {
                        Label(tr("Bugete pe categorii"), systemImage: "chart.pie").foregroundStyle(.primary)
                    }.accessibilityIdentifier("settings.budgets")
                    NavigationLink { RecurringListView() } label: { Label(tr("Recurente"), systemImage: "repeat") }
                        .accessibilityIdentifier("settings.recurring")
                    Button { showsCategories = true } label: {
                        Label(tr("Categorii"), systemImage: "square.grid.2x2").foregroundStyle(.primary)
                    }.accessibilityIdentifier("settings.categories")
                    if entries.contains(where: { !$0.isConfirmed }) {
                        Button { session.sheet = .drafts } label: {
                            Label("\(tr("De verificat")) · \(entries.filter { !$0.isConfirmed }.count)", systemImage: "tray")
                                .foregroundStyle(.primary)
                        }.accessibilityIdentifier("settings.drafts")
                    }
                    NavigationLink { PreferencesEditor() } label: { Label(tr("Preferințe"), systemImage: "globe") }
                        .accessibilityIdentifier("settings.preferences")
                }
                .listRowBackground(BudgetStyle.card)
                Section {
                    Text(tr("Datele sunt salvate pe acest iPhone.")).font(.footnote).foregroundStyle(.secondary)
                }.listRowBackground(Color.clear)
            }
            .scrollContentBackground(.hidden).background(BudgetStyle.background).navigationTitle(tr("Setări"))
            .toolbar(.visible, for: .navigationBar).toolbarRole(.editor)
            .sheet(isPresented: $showsCategories) { CategoryManagerView() }
        }
    }
}
