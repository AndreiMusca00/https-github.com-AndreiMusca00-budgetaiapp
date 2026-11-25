import SwiftUI

/// A bowed front shared by the mesh and native glass contours.
struct OrganicSlideFront: Shape {
    var progress: Double
    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }
    func path(in rect: CGRect) -> Path {
        let p = min(1, max(0, progress))
        let front = OrbitSlideGeometry.front(progress: p)
        let x = rect.minX + rect.width * front
        let bow = rect.width * 0.13 * sin(p * .pi)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX - rect.width, y: rect.minY - rect.height))
        path.addLine(to: CGPoint(x: x - bow, y: rect.minY - rect.height))
        path.addLine(to: CGPoint(x: x - bow, y: rect.minY))
        path.addCurve(to: CGPoint(x: x + bow, y: rect.midY),
            control1: CGPoint(x: x - bow * 0.9, y: rect.minY + rect.height * 0.18),
            control2: CGPoint(x: x + bow * 1.3, y: rect.minY + rect.height * 0.28))
        path.addCurve(to: CGPoint(x: x - bow * 0.6, y: rect.maxY),
            control1: CGPoint(x: x + bow * 0.8, y: rect.minY + rect.height * 0.72),
            control2: CGPoint(x: x - bow, y: rect.minY + rect.height * 0.82))
        path.addLine(to: CGPoint(x: x - bow * 0.6, y: rect.maxY + rect.height))
        path.addLine(to: CGPoint(x: rect.minX - rect.width, y: rect.maxY + rect.height))
        path.closeSubpath()
        return path
    }
}
