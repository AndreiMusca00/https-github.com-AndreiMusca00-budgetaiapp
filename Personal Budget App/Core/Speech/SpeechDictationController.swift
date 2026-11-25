import Foundation
import Observation
import Accelerate
@preconcurrency import AVFAudio
@preconcurrency import Speech

@MainActor
@Observable
final class SpeechDictationController {
    enum Phase: Equatable { case idle, authorizing, listening, finishing }
    enum Failure: Equatable {
        case speechPermission, microphonePermission, restricted, unavailable, audioUnavailable, recognition

        var message: String {
            switch self {
            case .speechPermission: "Permite recunoașterea vocală din Configurări pentru a dicta."
            case .microphonePermission: "Permite accesul la microfon din Configurări pentru a dicta."
            case .restricted: "Recunoașterea vocală este restricționată pe acest telefon."
            case .unavailable: "Dictarea în limba aleasă nu este disponibilă momentan. Încearcă din nou."
            case .audioUnavailable: "Microfonul nu este disponibil momentan. Încearcă din nou."
            case .recognition: "Dictarea s-a întrerupt. Poți încerca din nou; textul de până acum a rămas pe ecran."
            }
        }

        var offersSettings: Bool { self == .speechPermission || self == .microphonePermission }
    }

    private(set) var phase: Phase = .idle
    private(set) var failure: Failure?
    private(set) var transcript = DictationTranscript()
    private(set) var audioLevel: Float = 0
    var text: String { transcript.text }

    @ObservationIgnored private let engine = AVAudioEngine()
    @ObservationIgnored private var recognizer: SFSpeechRecognizer?
    @ObservationIgnored private var recognitionTask: SFSpeechRecognitionTask?
    @ObservationIgnored private var request: SFSpeechAudioBufferRecognitionRequest?
    @ObservationIgnored private var permissionTask: Task<Void, Never>?
    @ObservationIgnored private var recordingLimit: Task<Void, Never>?
    @ObservationIgnored private var finalizationLimit: Task<Void, Never>?
    @ObservationIgnored private var sessionID: UUID?
    @ObservationIgnored private var tapInstalled = false
    @ObservationIgnored private var ownsAudioSession = false
    @ObservationIgnored private var interruptionObserver: NSObjectProtocol?
    @ObservationIgnored private var configurationObserver: NSObjectProtocol?

    func start(localeIdentifier: String) {
        guard phase == .idle else { return }
        transcript.beginSession()
        failure = nil
        audioLevel = 0
        phase = .authorizing
        let id = UUID()
        sessionID = id
        permissionTask = Task { [weak self] in
            let status = await Self.speechAuthorization()
            guard let self, self.sessionID == id, !Task.isCancelled else { return }
            guard status == .authorized else {
                self.fail(status == .restricted ? .restricted : .speechPermission, sessionID: id)
                return
            }
            let microphoneAllowed = await AVAudioApplication.requestRecordPermission()
            guard self.sessionID == id, !Task.isCancelled else { return }
            guard microphoneAllowed else {
                self.fail(.microphonePermission, sessionID: id)
                return
            }
            self.beginCapture(localeIdentifier: localeIdentifier, sessionID: id)
        }
    }

    func stop() {
        guard phase == .listening, let id = sessionID else { return }
        phase = .finishing
        stopMicrophone()
        request?.endAudio()
        recordingLimit?.cancel()
        // Keep accepting final words after the microphone stops, without leaving the UI busy indefinitely.
        finalizationLimit = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(3)) } catch { return }
            guard let self, self.sessionID == id else { return }
            self.finishSession()
        }
    }

    func cancel(discardCurrentSession: Bool = false) {
        finishSession(discardCurrentSession: discardCurrentSession)
        if discardCurrentSession { failure = nil }
    }

    #if DEBUG
    func loadTestTranscript(_ text: String) {
        guard phase == .idle else { return }
        transcript.clear(); transcript.beginSession(); transcript.updatePartial(text); transcript.finishSession()
    }
    #endif

    func clear() {
        guard phase == .idle else { return }
        transcript.clear()
        failure = nil
    }

    private static func speechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        let status = SFSpeechRecognizer.authorizationStatus()
        guard status == .notDetermined else { return status }
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
    }

    private func beginCapture(localeIdentifier: String, sessionID id: UUID) {
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier)), recognizer.isAvailable else {
            fail(.unavailable, sessionID: id)
            return
        }
        self.recognizer = recognizer
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true)
            ownsAudioSession = true

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            request.taskHint = .dictation
            request.addsPunctuation = true
            request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
            self.request = request

            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else {
                fail(.audioUnavailable, sessionID: id)
                return
            }
            try input.installAudioTap(
                onBus: 0, bufferSize: AVAudioFrameCount(format.sampleRate * 0.1),
                format: format, tapProvider: Self.audioTap(for: request, controller: self, sessionID: id)
            )
            tapInstalled = true
            recognitionTask = recognizer.recognitionTask(with: request, resultHandler: Self.resultHandler(controller: self, sessionID: id))
            engine.prepare()
            try engine.start()
            phase = .listening
            interruptionObserver = NotificationCenter.default.addObserver(
                forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self, self.sessionID == id else { return }
                    self.cancel()
                }
            }
            configurationObserver = NotificationCenter.default.addObserver(
                forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self, self.sessionID == id else { return }
                    self.cancel()
                }
            }
            recordingLimit = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(55)) } catch { return }
                guard let self, self.sessionID == id else { return }
                self.stop()
            }
        } catch {
            fail(.audioUnavailable, sessionID: id)
        }
    }

    // Audio and Speech invoke their callbacks off the main actor. Only plain result values cross back.
    nonisolated private static func audioTap(
        for request: SFSpeechAudioBufferRecognitionRequest,
        controller: SpeechDictationController,
        sessionID: UUID
    ) -> @Sendable (AVReadOnlyAudioPCMBuffer, AVAudioTime) -> Void {
        { [weak controller] buffer, _ in
            let pcm = AVAudioPCMBuffer(copying: buffer)
            request.append(pcm)
            var rms: Float = 0
            if pcm.frameLength > 0, let samples = pcm.floatChannelData?[0] {
                vDSP_rmsqv(samples, vDSP_Stride(pcm.stride), &rms, vDSP_Length(pcm.frameLength))
            }
            let level = VoiceLevel.normalized(rms: rms)
            // The tap supplies roughly 100 ms of audio: UI updates stay bounded to about 10 Hz.
            Task { @MainActor [weak controller] in
                guard let controller, controller.sessionID == sessionID, controller.phase == .listening else { return }
                controller.audioLevel = VoiceLevel.smoothed(previous: controller.audioLevel, input: level)
            }
        }
    }

    nonisolated private static func resultHandler(
        controller: SpeechDictationController, sessionID: UUID
    ) -> @Sendable (SFSpeechRecognitionResult?, (any Error)?) -> Void {
        { [weak controller] result, error in
            let text = result?.bestTranscription.formattedString
            let isFinal = result?.isFinal ?? false
            let failed = error != nil
            Task { @MainActor [weak controller] in
                controller?.receive(text: text, isFinal: isFinal, failed: failed, sessionID: sessionID)
            }
        }
    }

    private func receive(text: String?, isFinal: Bool, failed: Bool, sessionID id: UUID) {
        guard sessionID == id else { return }
        if let text { transcript.updatePartial(text) }
        if isFinal {
            finishSession()
        } else if failed {
            if phase != .finishing || self.text.isEmpty { failure = .recognition }
            finishSession()
        }
    }

    private func fail(_ failure: Failure, sessionID id: UUID) {
        guard sessionID == id else { return }
        self.failure = failure
        finishSession()
    }

    private func stopMicrophone() {
        audioLevel = 0
        engine.stop()
        if tapInstalled {
            engine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        if ownsAudioSession {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            ownsAudioSession = false
        }
    }

    private func finishSession(discardCurrentSession: Bool = false) {
        sessionID = nil // Invalidate callbacks before cancelling Apple's task.
        permissionTask?.cancel()
        permissionTask = nil
        recordingLimit?.cancel()
        recordingLimit = nil
        finalizationLimit?.cancel()
        finalizationLimit = nil
        stopMicrophone()
        request?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        request = nil
        recognizer = nil
        if let interruptionObserver {
            NotificationCenter.default.removeObserver(interruptionObserver)
            self.interruptionObserver = nil
        }
        if let configurationObserver {
            NotificationCenter.default.removeObserver(configurationObserver)
            self.configurationObserver = nil
        }
        if discardCurrentSession { transcript.discardCurrentSession() }
        else { transcript.finishSession() }
        phase = .idle
    }
}
