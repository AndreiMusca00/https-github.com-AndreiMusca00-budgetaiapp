import SwiftUI

/// The mesh washes inward from every screen edge, with a feathered leading contour.
struct VoiceInwardReveal: AnimatableModifier {
    var progress: CGFloat
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        content.mask {
            VoiceInwardMask(progress: progress)
                .fill(.white, style: FillStyle(eoFill: true))
                .blur(radius: progress <= 0 || progress >= 1 ? 0 : 18 + 36 * progress)
                .ignoresSafeArea()
        }
    }
}

private struct VoiceInwardMask: Shape {
    var progress: CGFloat

    func path(in rect: CGRect) -> Path {
        let p = min(1, max(0, progress))
        guard p > 0 else { return Path() }
        var path = Path(rect.insetBy(dx: -160, dy: -160))
        guard p < 0.999 else { return path }
        // The central opening contracts smoothly; the overscan keeps the first frame outside the display.
        let width = (rect.width + 72) * (1 - p)
        let height = (rect.height + 72) * (1 - p)
        let opening = CGRect(x: rect.midX - width / 2, y: rect.midY - height / 2, width: width, height: height)
        path.addRoundedRect(in: opening, cornerSize: CGSize(width: min(52 + 72 * p, width / 2),
                                                           height: min(52 + 72 * p, height / 2)))
        return path
    }
}
