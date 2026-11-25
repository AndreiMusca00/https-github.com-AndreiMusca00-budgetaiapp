import SwiftUI

struct VoiceEntryOverlay: View {
    let localeIdentifier: String
    let onComplete: (String) throws -> Void
    let onDismiss: () -> Void
    let onLanguageSettings: () -> Void
    var simulatedTranscript: String?
    @State private var dictation = SpeechDictationController()
    @State private var finishing = false
    @State private var completed = false
    @State private var error: String?

    var body: some View {
        DictationOverlayView(dictation: dictation, localeIdentifier: localeIdentifier,
            onStop: stop, onCancel: cancel, onLanguageSettings: languageSettings,
            autoStart: simulatedTranscript == nil)
            .task {
                #if DEBUG
                if let simulatedTranscript { dictation.loadTestTranscript(simulatedTranscript) }
                #endif
            }
            .onChange(of: dictation.phase) { _, phase in
                if finishing && phase == .idle { complete() }
            }
            .onDisappear { dictation.cancel() }
            .alert(tr("Nu am putut salva. Încearcă din nou."), isPresented: Binding(
                get: { error != nil }, set: { if !$0 { error = nil } }
            )) { Button("OK", role: .cancel) {} } message: { Text(tr(error ?? "")) }
    }

    private func stop() {
        guard !finishing && !completed else { return }
        finishing = true
        switch dictation.phase {
        case .listening: dictation.stop()
        case .finishing: break
        case .authorizing: dictation.cancel(); complete()
        case .idle: complete()
        }
    }
    private func complete() {
        guard !completed else { return }
        do {
            let text = dictation.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty { try onComplete(text) }
            completed = true
            onDismiss()
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? "Nu am putut salva. Încearcă din nou."
            finishing = false
        }
    }
    private func cancel() {
        completed = true
        dictation.cancel(discardCurrentSession: true)
        onDismiss()
    }
    private func languageSettings() {
        cancel()
        onLanguageSettings()
    }
}
