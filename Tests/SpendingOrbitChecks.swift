import Foundation

@main
struct SpendingOrbitChecks {
    static func main() {
        let shares = [0.1, 0.4, 0.3, 0.2]
        let original = SpendingOrbitGeometry(shares: shares)
        precondition(abs(original.segments[0].span - .pi / 5) < 0.000001)
        for segment in original.segments {
            precondition(abs(segment.innerRadius - (1 - SpendingOrbitGeometry.restingDepth)) < 0.000001)
        }
        let boundary = original.segments[1].start
        precondition(abs(original.innerRadius(at: boundary) - (1 - SpendingOrbitGeometry.restingDepth)) < 0.000001)
        let epsilon = 0.000001
        precondition(abs(original.innerRadius(at: boundary - epsilon) - original.innerRadius(at: boundary + epsilon)) < 0.0001)
        for focus in shares.indices {
            for progress in stride(from: 0.0, through: 1.0, by: 0.05) {
                let geometry = SpendingOrbitGeometry(shares: shares, focusedIndex: focus, expansion: progress)
                precondition(abs(geometry.segments.reduce(0) { $0 + $1.span } - 2 * .pi) < 0.00001)
                let focused = geometry.segments.first { $0.index == focus }!
                precondition(abs(atan2(sin(focused.middle - original.segments[focus].middle), cos(focused.middle - original.segments[focus].middle))) < 0.00001)
                for angle in stride(from: -Double.pi, through: 3 * .pi, by: 0.025) {
                    let radius = geometry.innerRadius(at: angle)
                    precondition(radius.isFinite && radius >= 0 && radius <= 1)
                    precondition(geometry.segment(at: angle) != nil)
                }
            }
            let expanded = SpendingOrbitGeometry(shares: shares, focusedIndex: focus, expansion: 1)
            precondition(expanded.segments.count == 1 && expanded.segments[0].index == focus)
            precondition(expanded.segments[0].innerRadius == 0)
            let collapsed = SpendingOrbitGeometry(shares: shares, focusedIndex: focus, expansion: 0)
            for i in shares.indices {
                precondition(abs(collapsed.segments[i].start - original.segments[i].start) < 0.000001)
                precondition(abs(collapsed.segments[i].innerRadius - original.segments[i].innerRadius) < 0.000001)
            }
        }
        for values in [[], [0, 0], [1], [0, 1, 0], [0.99, 0.005, 0.005], [-1, .nan, 1]] as [[Double]] {
            let geometry = SpendingOrbitGeometry(shares: values)
            for angle in stride(from: 0.0, through: 2 * .pi, by: 0.05) {
                precondition(geometry.innerRadius(at: angle).isFinite)
            }
        }
        var previousFront = -Double.infinity
        for progress in stride(from: 0.0, through: 1.0, by: 0.01) {
            let front = OrbitSlideGeometry.front(progress: progress)
            precondition(front.isFinite && front >= previousFront)
            previousFront = front
        }
        precondition(OrbitSlideGeometry.front(progress: 0) < 0)
        precondition(OrbitSlideGeometry.front(progress: 1) > 1)
        precondition(OrbitSlideGeometry.front(progress: -1) == OrbitSlideGeometry.front(progress: 0))
        precondition(OrbitSlideGeometry.front(progress: 2) == OrbitSlideGeometry.front(progress: 1))
        print("Passed: equal slice depth, continuous geometry, stable focus, left-to-right reveal and edge cases.")
    }
}
