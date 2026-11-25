import Foundation

/// One shared inner contour keeps adjacent category surfaces connected.
struct SpendingOrbitGeometry {
    static let restingDepth = 0.28
    struct Segment {
        let index: Int
        let start: Double
        let span: Double
        let innerRadius: Double
        var middle: Double { start + span / 2 }
    }

    let segments: [Segment]

    init(shares: [Double], focusedIndex: Int? = nil, expansion: Double = 0) {
        let positive = shares.map { $0.isFinite ? max(0, $0) : 0 }
        let total = positive.reduce(0, +)
        guard total > 0 else { segments = []; return }
        let base = positive.map { $0 / total }
        let focus = focusedIndex.flatMap { base.indices.contains($0) && base[$0] > 0 ? $0 : nil }
        let progress = focus == nil ? 0 : min(1, max(0, expansion))
        let weights = base.enumerated().map { index, value in value * (1 - progress) + (index == focus ? progress : 0) }
        var start = -Double.pi / 2 - base[0] * .pi
        if let focus {
            let originalMiddle = start + (base.prefix(focus).reduce(0, +) + base[focus] / 2) * 2 * .pi
            start = originalMiddle - (weights.prefix(focus).reduce(0, +) + weights[focus] / 2) * 2 * .pi
        }
        var result: [Segment] = []
        for index in weights.indices {
            let span = weights[index] * 2 * Double.pi
            let depth = Self.restingDepth * (1 - progress) + (index == focus ? progress : 0)
            if span > 0.000001 {
                result.append(Segment(index: index, start: start, span: span, innerRadius: max(0, 1 - depth)))
            }
            start += span
        }
        segments = result
    }

    func segment(at angle: Double) -> Segment? {
        segments.first { Self.positiveAngle(angle - $0.start) < $0.span + 0.0000001 }
    }

    func innerRadius(at angle: Double) -> Double {
        guard let current = segment(at: angle) else { return 1 }
        guard segments.count > 1 else { return current.innerRadius }
        for index in segments.indices {
            let right = segments[index]
            let left = segments[(index + segments.count - 1) % segments.count]
            let width = min(0.18, left.span * 0.23, right.span * 0.23)
            guard width > 0 else { continue }
            let distance = atan2(sin(angle - right.start), cos(angle - right.start))
            if abs(distance) <= width {
                let t = (distance + width) / (2 * width)
                let eased = t * t * (3 - 2 * t)
                return left.innerRadius + (right.innerRadius - left.innerRadius) * eased
            }
        }
        return current.innerRadius
    }

    static func positiveAngle(_ value: Double) -> Double {
        let result = value.truncatingRemainder(dividingBy: 2 * .pi)
        return result < 0 ? result + 2 * .pi : result
    }
}


/// Extra travel keeps the soft leading edge outside the circle at both endpoints.
enum OrbitSlideGeometry {
    static func front(progress: Double) -> Double { -0.16 + 1.32 * min(1, max(0, progress)) }
}
