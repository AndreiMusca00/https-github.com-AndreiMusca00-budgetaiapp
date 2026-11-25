import SwiftUI
import SwiftData

struct AccountListView: View {
    var isModal = false
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \BudgetAccount.createdAt) private var accounts: [BudgetAccount]
    @Query private var entries: [LedgerEntry]
    @State private var editor: AccountEditorRoute?
    var body: some View {
        List {
            ForEach([false, true], id: \.self) { archived in
                let group = accounts.filter { $0.isArchived == archived }
                if !group.isEmpty {
                    Section(archived ? tr("Arhivate") : tr("Conturi")) {
                        ForEach(group) { account in
                            Button { editor = AccountEditorRoute(id: account.id) } label: {
                                HStack(spacing: 14) {
                                    Text(account.emoji).font(.system(size: 27)).frame(width: 40)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(account.name).foregroundStyle(.primary)
                                        Text(account.currencyCode).font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(formattedMoney(LedgerMath.balance(account: account, entries: entries), currency: account.currencyCode))
                                        .font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                                }.padding(.vertical, 8)
                            }
                            .accessibilityIdentifier("account.row.\(account.name)")
                            .listRowBackground(BudgetStyle.card)
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden).background(BudgetStyle.background)
        .overlay {
            if accounts.isEmpty {
                ContentUnavailableView(tr("Fără conturi"), systemImage: "wallet.bifold",
                                       description: Text(tr("Adaugă primul cont pentru a înregistra tranzacții.")))
            }
        }
        .navigationTitle(tr("Conturi")).navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isModal {
                ToolbarItem(placement: .cancellationAction) { Button(tr("Gata")) { dismiss() }.accessibilityIdentifier("accounts.close") }
            }
            ToolbarItem(placement: .primaryAction) {
                Button { editor = AccountEditorRoute() } label: { Image(systemName: "plus") }
                    .accessibilityLabel(tr("Cont nou")).accessibilityIdentifier("accounts.add")
            }
        }
        .sheet(item: $editor) { route in NavigationStack { AccountEditorView(accountID: route.accountID) } }
    }
}

private struct AccountEditorRoute: Identifiable {
    let id = UUID()
    var accountID: UUID?
    init(id: UUID? = nil) { accountID = id }
}
