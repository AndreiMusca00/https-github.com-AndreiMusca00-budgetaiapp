import SwiftUI

struct PreferenceOption: Identifiable {
    let id: String
    let title: String
    let subtitle: String
}

struct PreferencePicker: View {
    let title: String
    let options: [PreferenceOption]
    @Binding var selectedID: String?
    var searchPrompt = "Caută"
    var closeTitle = "Închide"

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var filteredOptions: [PreferenceOption] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return options }
        return options.filter {
            "\($0.id) \($0.title) \($0.subtitle)".localizedStandardContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            List(filteredOptions) { option in
                Button {
                    selectedID = option.id
                    dismiss()
                } label: {
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(option.title).foregroundStyle(.primary)
                            Text(option.subtitle).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if selectedID == option.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(BudgetStyle.accent)
                        }
                    }
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .accessibilityAddTraits(selectedID == option.id ? .isSelected : [])
            }
            .scrollContentBackground(.hidden)
            .background(BudgetStyle.background)
            .overlay {
                if filteredOptions.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }
            .searchable(text: $query, prompt: Text(searchPrompt))
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(closeTitle) { dismiss() }
                }
            }
        }
    }
}
