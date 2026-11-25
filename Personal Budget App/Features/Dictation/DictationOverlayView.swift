import SwiftUI
import UIKit

struct DictationOverlayView: View {
    let dictation: SpeechDictationController
    let localeIdentifier: String
    let onStop: () -> Void
    let onCancel: () -> Void
    let onLanguageSettings: () -> Void
    var autoStart = true

    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var reveal: CGFloat = 0
    @State private var controlsVisible = false

    private var flag: String { BudgetLanguage.matching(localeIdentifier)?.flag ?? "🌐" }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(action: onLanguageSettings) {
                    Text(flag).font(.system(size: 26))
                        .frame(width: 48, height: 48)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay { Circle().strokeBorder(.white.opacity(0.16), lineWidth: 1) }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Limba pentru dictare: \(SpeechLanguage(id: localeIdentifier).name)")
                .accessibilityHint("Oprește dictarea și deschide setările limbii.")
                .accessibilityIdentifier("dictation.languageSettings")
            }
            .padding(.horizontal, 24).padding(.top, 12)

            GeometryReader { geometry in
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 0) {
                            if dictation.text.isEmpty {
                                Text(tr(dictation.phase == .authorizing ? "Un moment…" : "Spune ce ai cheltuit."))
                                    .font(.system(.title2, design: .rounded, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.85))
                                    .multilineTextAlignment(.center)
                                    .shadow(color: .black.opacity(0.4), radius: 12)
                            } else {
                                LiveDictationText(text: dictation.text)
                            }
                            Color.clear.frame(height: 1).id("transcriptEnd")
                        }
                        .frame(maxWidth: 520, minHeight: geometry.size.height)
                        .padding(.horizontal, 32).frame(maxWidth: .infinity)
                    }
                    .scrollIndicators(.hidden)
                    .onChange(of: dictation.text) { _, _ in
                        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                            proxy.scrollTo("transcriptEnd", anchor: .bottom)
                        }
                    }
                }
            }

            if let failure = dictation.failure {
                VStack(spacing: 10) {
                    Text(tr(failure.message)).font(.footnote).foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                    if failure.offersSettings, let url = URL(string: UIApplication.openSettingsURLString) {
                        Button(tr("Deschide Configurări")) { openURL(url) }
                            .font(.footnote.weight(.semibold)).foregroundStyle(.white).underline()
                    }
                }
                .frame(maxWidth: 480).padding(.horizontal, 28).padding(.bottom, 16)
            }

            HStack(spacing: 16) {
                Spacer()
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 19, weight: .semibold)).foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay { Circle().strokeBorder(.white.opacity(0.16), lineWidth: 1) }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tr("Anulează dictarea"))
                .accessibilityHint("Elimină cuvintele din această dictare și închide microfonul.")
                .accessibilityIdentifier("dictation.cancel")
                Button(action: onStop) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 22, weight: .semibold)).foregroundStyle(.white)
                        .frame(width: 72, height: 72)
                        .background { Circle().fill(BudgetStyle.buttonGradient) }
                        .overlay { Circle().strokeBorder(.white.opacity(0.3), lineWidth: 1) }
                        .shadow(color: BudgetStyle.accent.opacity(0.2), radius: 22, y: 8)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tr("Oprește dictarea"))
                .accessibilityIdentifier("dictation.stop")
                .disabled(dictation.phase == .finishing)
            }
            .padding(.horizontal, 24).padding(.vertical, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .opacity(controlsVisible ? 1 : 0)
        .offset(y: controlsVisible || reduceMotion ? 0 : 6)
        .background {
            ZStack {
                Color.black.opacity(0.16)
                DictationMeshBackground(isListening: dictation.phase == .listening, audioLevel: dictation.audioLevel).opacity(0.48)
            }
            .modifier(VoiceInwardReveal(progress: reveal))
            .ignoresSafeArea()
        }
        .task {
            if reduceMotion {
                reveal = 1; controlsVisible = true
            } else {
                do { try await Task.sleep(for: .milliseconds(24)) } catch { return }
                withAnimation(.timingCurve(0.22, 0.70, 0.18, 1, duration: 1.2)) { reveal = 1 }
                withAnimation(.smooth(duration: 0.45).delay(0.28)) { controlsVisible = true }
            }
            guard autoStart else { return }
            dictation.start(localeIdentifier: localeIdentifier)
        }
        .onChange(of: reduceMotion) { _, enabled in
            if enabled { reveal = 1; controlsVisible = true }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { onStop() }
            else if phase == .inactive && dictation.phase == .listening { onStop() }
        }
        .onDisappear {
            // Stop closes the overlay immediately, while already captured final words may still arrive.
            if dictation.phase != .finishing { dictation.cancel() }
        }
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape, onCancel)
    }
}
