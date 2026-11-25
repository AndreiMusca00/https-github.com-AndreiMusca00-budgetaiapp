import SwiftUI
import SwiftData

struct CategoryPickerView: View {
    @Binding var selection: UUID?
    var kind: EntryKind = .expense
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ExpenseCategory.sortOrder) private var categories: [ExpenseCategory]
    @State private var showsManager = false

    var body: some View {
        NavigationStack {
            List {
                row(name: tr("Necategorizat"), emoji: "🧾", id: nil)
                ForEach(categories.filter { $0.kindRawValue == kind.rawValue }) { category in
                    row(name: category.systemKey == nil ? category.name : tr(category.name), emoji: category.emoji, id: category.id)
                }
            }
            .listStyle(.plain).scrollContentBackground(.hidden).background(BudgetStyle.background)
            .navigationTitle(tr("Categorie"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(tr("Gata")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(tr("Gestionează")) { showsManager = true }
                        .accessibilityIdentifier("category.manage")
                }
            }
            .sheet(isPresented: $showsManager) { CategoryManagerView(initialKind: kind) }
        }
    }

    private func row(name: String, emoji: String, id: UUID?) -> some View {
        Button {
            selection = id
            dismiss()
        } label: {
            HStack(spacing: 14) {
                Text(emoji).font(.system(size: 25)).frame(width: 36)
                Text(name).font(.system(size: 16, weight: .semibold, design: .rounded)).foregroundStyle(.primary)
                Spacer()
                if selection == id {
                    Image(systemName: "checkmark").font(.subheadline.weight(.semibold))
                        .foregroundStyle(BudgetStyle.accent)
                }
            }
            .padding(.vertical, 8)
        }
        .listRowBackground(Color.clear)
        .accessibilityIdentifier("category.pick.\(name)")
    }
}
