import Foundation

/// Replaces partial hypotheses within a session and appends only between sessions.
struct DictationTranscript {
    private var committed = ""
    private var partial = ""
    private var sessionBaseline = ""

    var text: String {
        [committed, partial].filter { !$0.isEmpty }.joined(separator: " ")
    }

    mutating func beginSession() {
        sessionBaseline = text
        committed = text
        partial = ""
    }

    mutating func updatePartial(_ value: String) {
        partial = value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    mutating func finishSession() {
        committed = text
        partial = ""
    }

    mutating func discardCurrentSession() {
        committed = sessionBaseline
        partial = ""
    }

    mutating func clear() {
        committed = ""
        partial = ""
        sessionBaseline = ""
    }
}
