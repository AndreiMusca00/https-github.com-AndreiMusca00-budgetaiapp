import SwiftUI
import UIKit

struct DictationPanel: View {
    let dictation: SpeechDictationController
    @Environment(\.openURL) private var openURL

    private var status: String {
        switch dictation.phase {
        case .idle: dictation.text.isEmpty ? "Gata când ești tu" : "Text transcris"
        case .authorizing: "Se pregătește…"
        case .listening: "Te ascult…"
        case .finishing: "Ultimele cuvinte…"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                Label(status, systemImage: dictation.phase == .listening ? "waveform" : "text.alignleft")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(BudgetStyle.accent)
                    .symbolEffect(.variableColor, isActive: dictation.phase == .listening)
                Spacer(minLength: 8)
                if !dictation.text.isEmpty && dictation.phase == .idle {
                    Button("Șterge", systemImage: "trash") { dictation.clear() }
                        .labelStyle(.iconOnly)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 44, minHeight: 44)
                        .accessibilityIdentifier("dictation.clear")
                }
            }

            Text(dictation.text.isEmpty ? "O cheltuială,\ncâteva cuvinte." : dictation.text)
                .font(.system(.title2, design: .rounded, weight: dictation.text.isEmpty ? .regular : .medium))
                .foregroundStyle(dictation.text.isEmpty ? .secondary : .primary)
                .frame(maxWidth: .infinity, minHeight: 100, alignment: .topLeading)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
                .accessibilityIdentifier("dictation.transcript")

            if let failure = dictation.failure {
                VStack(alignment: .leading, spacing: 12) {
                    Text(failure.message).font(.footnote).foregroundStyle(.secondary)
                    if failure.offersSettings, let url = URL(string: UIApplication.openSettingsURLString) {
                        Button("Deschide Configurări") { openURL(url) }
                            .font(.footnote.weight(.semibold))
                    }
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BudgetStyle.card, in: RoundedRectangle(cornerRadius: 26))
        .overlay {
            RoundedRectangle(cornerRadius: 26)
                .strokeBorder(BudgetStyle.accent.opacity(dictation.phase == .listening ? 0.6 : 0.16), lineWidth: 1)
        }
        .shadow(color: BudgetStyle.accent.opacity(dictation.phase == .listening ? 0.08 : 0), radius: 30)
    }
}
