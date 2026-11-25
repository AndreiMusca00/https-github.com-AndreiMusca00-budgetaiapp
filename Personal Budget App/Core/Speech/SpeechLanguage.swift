import Foundation

struct SpeechLanguage: Identifiable, Equatable {
    let id: String

    var name: String {
        Locale(identifier: "ro").localizedString(forIdentifier: id) ?? id
    }

    var nativeName: String {
        Locale(identifier: id).localizedString(forIdentifier: id) ?? id
    }
}
