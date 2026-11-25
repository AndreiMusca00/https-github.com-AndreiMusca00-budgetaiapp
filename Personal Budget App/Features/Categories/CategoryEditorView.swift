import SwiftUI
import SwiftData

struct CategoryEditorView: View {
    var category: ExpenseCategory?
    var kind: EntryKind = .expense
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var emoji = "🧾"
    @State private var didLoad = false
    @State private var errorMessage: String?
    @FocusState private var editsName: Bool
    @FocusState private var editsEmoji: Bool

    private let suggestions = [
        "📺", "☁️", "📶", "🛒", "☕️", "🍽️", "🚗", "🏠", "💡",
        "💊", "🛍️", "🎬", "📱", "✈️", "🎁",
        "🐾", "🎓", "🏋️", "💼", "🧾", "🍔",
        "🥦", "🍼", "🏦", "💳", "🎮", "🚲",
        "📚", "🍕", "🚕", "🌿", "💰", "✨"
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    TextField("🧾", text: $emoji)
                        .font(.system(size: 44)).multilineTextAlignment(.center)
                        .frame(width: 90, height: 90)
                        .budgetGlass()
                        .focused($editsEmoji)
                        .accessibilityLabel("Emoji")
                        .accessibilityIdentifier("category.emoji")
                        .onChange(of: emoji) { _, new in
                            if new.count > 1 { emoji = String(new.suffix(1)) }
                        }
                    TextField(tr("Numele categoriei"), text: $name)
                        .font(.title3.weight(.medium)).multilineTextAlignment(.center)
                        .textInputAutocapitalization(.sentences)
                        .focused($editsName).submitLabel(.done)
                        .onSubmit { editsName = false }
                        .padding(.vertical, 16)
                        .accessibilityIdentifier("category.name")
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 12) {
                        ForEach(suggestions, id: \.self) { option in
                            Button { editsName = false; editsEmoji = false; emoji = option } label: {
                                Text(option).font(.system(size: 27))
                                    .frame(maxWidth: .infinity, minHeight: 48)
                                    .background(emoji == option ? BudgetStyle.accent.opacity(0.17) : .clear,
                                                in: RoundedRectangle(cornerRadius: 15))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Emoji \(option)")
                        }
                    }
                }
                .frame(maxWidth: 440).padding(24).frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(BudgetStyle.background)
            .navigationTitle(tr(category == nil ? "Categorie nouă" : "Editează categoria"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(tr("Închide")) { dismiss() }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(tr("Gata")) { editsName = false; editsEmoji = false }
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 12) {
                    if let errorMessage {
                        Text(tr(errorMessage)).font(.footnote).foregroundStyle(.red)
                            .accessibilityIdentifier("category.error")
                    }
                    Button(tr("Salvează categoria"), action: save)
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("category.save")
                }
                .frame(maxWidth: 440).padding(24).frame(maxWidth: .infinity)
                .background(.ultraThinMaterial)
            }
            .onAppear {
                guard !didLoad else { return }
                didLoad = true
                name = category?.name ?? ""
                emoji = category?.emoji ?? "🧾"
            }
        }
    }

    private func save() {
        do {
            try ExpenseRepository.saveCategory(category, name: name, emoji: emoji, kind: kind, in: context)
            dismiss()
        } catch let error as ExpenseRepository.ValidationError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "Categoria nu a putut fi salvată. Încearcă din nou."
        }
    }
}
