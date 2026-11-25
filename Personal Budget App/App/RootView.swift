import SwiftUI

struct RootView: View {
    @Environment(PreferencesStore.self) private var preferences
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if let savedPreferences = preferences.preferences {
                LedgerAppView(preferences: savedPreferences)
                    .transition(.opacity)
            } else {
                OnboardingView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: reduceMotion ? 0.15 : 0.3), value: preferences.preferences != nil)
    }
}
