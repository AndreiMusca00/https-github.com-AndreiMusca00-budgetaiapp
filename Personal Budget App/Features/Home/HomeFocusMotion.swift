import SwiftUI

private struct HomeRetreat: ViewModifier {
    var hidden: Bool
    func body(content: Content) -> some View {
        content.opacity(hidden ? 0 : 1).blur(radius: hidden ? 6 : 0)
            .scaleEffect(hidden ? 0.96 : 1, anchor: .top)
            .offset(y: hidden ? -16 : 0)
    }
}

extension AnyTransition {
    static var homeContext: AnyTransition {
        .asymmetric(
            insertion: .modifier(active: HomeRetreat(hidden: true), identity: HomeRetreat(hidden: false))
                .animation(.smooth(duration: 0.32).delay(0.08)),
            removal: .modifier(active: HomeRetreat(hidden: true), identity: HomeRetreat(hidden: false))
                .animation(.easeOut(duration: 0.2))
        )
    }
}

struct HomeCascadeReveal: ViewModifier {
    let delay: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    func body(content: Content) -> some View {
        let visible = appeared || reduceMotion
        content.opacity(visible ? 1 : 0).offset(y: visible ? 0 : 18)
            .scaleEffect(visible ? 1 : 0.98, anchor: .topLeading).blur(radius: visible ? 0 : 3)
            .task {
                guard !appeared else { return }
                if !reduceMotion {
                    do { try await Task.sleep(for: .milliseconds(24)) } catch { return }
                }
                withAnimation(reduceMotion ? nil : .spring(duration: 0.5, bounce: 0.12).delay(delay)) { appeared = true }
            }
    }
}
