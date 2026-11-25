import SwiftUI
import SwiftData

struct CategoryManagerView: View {
    var initialKind: EntryKind = .expense
    @State private var kind: EntryKind = .expense
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ExpenseCategory.sortOrder) private var categories: [ExpenseCategory]
    @State private var showsEditor = false
    @State private var editingCategory: ExpenseCategory?
    @State private var categoryToDelete: ExpenseCategory?
    @State private var asksDelete = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Picker("", selection: $kind) {
                    Text(tr("Cheltuială")).tag(EntryKind.expense)
                    Text(tr("Venit")).tag(EntryKind.income)
                }.pickerStyle(.segmented).listRowBackground(Color.clear)
                    .accessibilityIdentifier("categories.kind")
                Section {
                    ForEach(categories.filter { $0.kindRawValue == kind.rawValue }) { category in
                        HStack(spacing: 12) {
                            Button {
                                editingCategory = category
                                showsEditor = true
                            } label: {
                                HStack(spacing: 14) {
                                    Text(category.emoji).font(.system(size: 27)).frame(width: 38)
                                    Text(category.systemKey == nil ? category.name : tr(category.name)).foregroundStyle(.primary)
                                    Spacer(minLength: 4)
                                }
                                .padding(.vertical, 8).contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("category.edit.\(category.name)")
                            Button {
                                categoryToDelete = category
                                asksDelete = true
                            } label: {
                                Image(systemName: "trash")
                                    .font(.subheadline).foregroundStyle(.secondary)
                                    .frame(width: 44, height: 44)
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Șterge \(category.name)")
                            .accessibilityIdentifier("category.delete.\(category.name)")
                        }
                        .listRowBackground(BudgetStyle.card)
                    }
                } footer: {
                    Text(tr("Atinge o categorie pentru a o edita."))
                }
            }
            .scrollContentBackground(.hidden)
            .overlay {
                if categories.filter({ $0.kindRawValue == kind.rawValue }).isEmpty {
                    ContentUnavailableView(tr("Fără categorii"), systemImage: "square.grid.2x2",
                                           description: Text(tr("Adaugă o categorie folosind butonul +.")))
                }
            }
            .background(BudgetStyle.background)
            .navigationTitle(tr("Categorii"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(tr("Gata")) { dismiss() }.accessibilityIdentifier("categories.close")
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        editingCategory = nil
                        showsEditor = true
                    } label: { Image(systemName: "plus") }
                        .accessibilityLabel(tr("Categorie nouă"))
                        .accessibilityIdentifier("categories.add")
                }
            }
            .sheet(isPresented: $showsEditor) { CategoryEditorView(category: editingCategory, kind: kind) }
            .confirmationDialog(tr("Ștergi categoria?"), isPresented: $asksDelete, titleVisibility: .visible) {
                Button(tr("Șterge categoria"), role: .destructive) { deleteCategory() }
            } message: {
                Text(tr("Cheltuielile rămân în istoric. Limitele de buget ale categoriei vor fi eliminate."))
            }
            .alert("Nu am putut șterge categoria", isPresented: Binding(
                get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
            )) { Button("OK", role: .cancel) { } } message: { Text(errorMessage ?? "") }
        }
        .onAppear { kind = initialKind }
    }

    private func deleteCategory() {
        guard let categoryToDelete else { return }
        do { try ExpenseRepository.deleteCategory(categoryToDelete, in: context) }
        catch { errorMessage = "Încearcă din nou. Cheltuielile tale sunt păstrate." }
        self.categoryToDelete = nil
    }
}
