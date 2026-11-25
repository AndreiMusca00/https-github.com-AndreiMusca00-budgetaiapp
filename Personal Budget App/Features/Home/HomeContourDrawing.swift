import SwiftUI

/// Every contour is a native path. Trimming the paths draws the illustration at launch.
struct HomeContourDrawing: View {
    let section: HomeIllustrationSection
    let revealed: Bool
    let ink: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var drawing: HomeContourPaths {
        switch section {
        case .accounts: HomeContourPaths.accounts
        case .expenses: HomeContourPaths.expenses
        case .payments: HomeContourPaths.payments
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let drawing = drawing
            let scale = min(proxy.size.width / drawing.size.width, proxy.size.height / drawing.size.height)
            ZStack {
                ForEach(drawing.strokes.indices, id: \.self) { index in
                    HomeContourStroke(drawing: drawing.strokes[index], canvas: drawing.size)
                        .trim(from: 0, to: revealed || reduceMotion ? 1 : 0)
                        .stroke(ink, style: StrokeStyle(lineWidth: drawing.lineWidth * scale, lineCap: .round, lineJoin: .round))
                        .animation(reduceMotion ? nil : .easeInOut(duration: 1.65).delay(Double(index) * 0.035), value: revealed)
                }
            }.frame(width: proxy.size.width, height: proxy.size.height)
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
}

private struct HomeContourStroke: Shape {
    let drawing: Path
    let canvas: CGSize
    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width / canvas.width, rect.height / canvas.height)
        let transform = CGAffineTransform(translationX: rect.midX - canvas.width * scale / 2,
                                         y: rect.midY - canvas.height * scale / 2).scaledBy(x: scale, y: scale)
        return drawing.applying(transform)
    }
}

private struct HomeContourPaths {
    let size: CGSize
    let lineWidth: CGFloat
    let strokes: [Path]

    private static func line(_ points: [CGPoint]) -> Path {
        Path { path in
            guard let first = points.first else { return }
            path.move(to: first)
            for point in points.dropFirst() { path.addLine(to: point) }
        }
    }
    private static func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }

    static let accounts: Self = {
        var strokes: [Path] = []
        // Money sack: bow, binding and the two large side contours.
        strokes.append(Path { p in
            p.move(to: point(245, 100))
            p.addCurve(to: point(205, 23), control1: point(231, 78), control2: point(175, 43))
            p.addCurve(to: point(284, 27), control1: point(229, -4), control2: point(259, 19))
            p.addCurve(to: point(347, 15), control1: point(305, 32), control2: point(322, -2))
            p.addCurve(to: point(394, 61), control1: point(388, -8), control2: point(425, 22))
            p.addCurve(to: point(335, 111), control1: point(381, 85), control2: point(351, 92))
        })
        strokes.append(Path { p in
            p.move(to: point(232, 103))
            p.addCurve(to: point(228, 132), control1: point(207, 101), control2: point(204, 129))
            p.addLine(to: point(337, 145))
            p.addCurve(to: point(347, 116), control1: point(363, 149), control2: point(369, 120))
            p.addLine(to: point(232, 103))
        })
        strokes.append(Path { p in
            p.move(to: point(225, 132))
            p.addCurve(to: point(-35, 451), control1: point(106, 155), control2: point(22, 286))
            p.move(to: point(335, 145))
            p.addCurve(to: point(486, 448), control1: point(429, 177), control2: point(491, 321))
        })
        strokes.append(Path { p in
            p.move(to: point(317, 243))
            p.addCurve(to: point(228, 222), control1: point(308, 203), control2: point(249, 198))
            p.addCurve(to: point(242, 289), control1: point(192, 250), control2: point(203, 276))
            p.addCurve(to: point(305, 342), control1: point(280, 302), control2: point(325, 308))
            p.addCurve(to: point(203, 333), control1: point(283, 380), control2: point(217, 371))
        })
        strokes.append(line([point(275, 185), point(237, 391)]))
        // Two coin stacks, with open elliptical seams.
        for (x, y, width, height) in [(CGFloat(505), CGFloat(260), CGFloat(166), CGFloat(122)), (365, 337, 174, 116)] {
            strokes.append(Path(ellipseIn: CGRect(x: x, y: y, width: width, height: 55)))
            strokes.append(Path { p in
                p.move(to: point(x, y + 27)); p.addLine(to: point(x, y + height - 25))
                p.addCurve(to: point(x + width, y + height - 25),
                           control1: point(x + 10, y + height + 12), control2: point(x + width - 10, y + height + 12))
                p.addLine(to: point(x + width, y + 27))
            })
            strokes.append(Path { p in
                p.move(to: point(x, y + 67))
                p.addCurve(to: point(x + width, y + 67), control1: point(x + 12, y + 102), control2: point(x + width - 12, y + 102))
            })
        }
        // The card tilts toward the right edge, with its stripe and two short marks.
        let transform = CGAffineTransform(translationX: 857, y: 312).rotated(by: -0.16).translatedBy(x: -857, y: -312)
        strokes.append(Path(roundedRect: CGRect(x: 693, y: 217, width: 345, height: 196), cornerRadius: 22).applying(transform))
        strokes.append(line([point(694, 260), point(1038, 260)]).applying(transform))
        strokes.append(line([point(729, 363), point(784, 363)]).applying(transform))
        strokes.append(line([point(813, 363), point(846, 363)]).applying(transform))
        return Self(size: CGSize(width: 1000, height: 455), lineWidth: 12, strokes: strokes)
    }()

    static let expenses: Self = {
        var strokes: [Path] = []
        strokes.append(Path { p in
            p.move(to: point(485, 388)); p.addLine(to: point(518, 274))
            p.addCurve(to: point(483, 237), control1: point(526, 244), control2: point(512, 237))
            p.addLine(to: point(151, 237))
            p.addCurve(to: point(115, 271), control1: point(126, 237), control2: point(119, 248))
            p.addLine(to: point(62, 545))
            p.addCurve(to: point(93, 580), control1: point(56, 569), control2: point(67, 580))
            p.addLine(to: point(350, 580))
        })
        strokes.append(Path { p in
            p.move(to: point(180, 270))
            p.addCurve(to: point(294, 125), control1: point(183, 166), control2: point(230, 105))
            p.addCurve(to: point(350, 272), control1: point(356, 139), control2: point(367, 186))
        })
        strokes.append(Path { p in
            p.move(to: point(307, 270))
            p.addCurve(to: point(412, 110), control1: point(318, 161), control2: point(348, 94))
            p.addCurve(to: point(452, 270), control1: point(474, 127), control2: point(476, 191))
        })
        strokes.append(Path { p in
            p.move(to: point(637, 436))
            p.addCurve(to: point(650, 381), control1: point(674, 440), control2: point(682, 410))
            p.addCurve(to: point(580, 361), control1: point(636, 363), control2: point(613, 366))
            p.addLine(to: point(427, 349))
            p.addCurve(to: point(388, 380), control1: point(401, 347), control2: point(394, 355))
            p.addLine(to: point(333, 632))
            p.addLine(to: point(369, 613)); p.addLine(to: point(398, 645))
            p.addLine(to: point(434, 620)); p.addLine(to: point(463, 652))
            p.addLine(to: point(500, 628)); p.addLine(to: point(531, 656))
            p.addLine(to: point(586, 403))
            p.addCurve(to: point(636, 370), control1: point(594, 376), control2: point(609, 366))
        })
        strokes.append(line([point(418, 412), point(537, 423)]))
        strokes.append(line([point(405, 466), point(523, 477)]))
        strokes.append(line([point(391, 521), point(491, 530)]))
        return Self(size: CGSize(width: 700, height: 700), lineWidth: 14, strokes: strokes)
    }()

    static let payments: Self = {
        var strokes: [Path] = []
        let transform = CGAffineTransform(translationX: 320, y: 255).rotated(by: -0.12).translatedBy(x: -320, y: -255)
        strokes.append(Path(roundedRect: CGRect(x: -8, y: 70, width: 658, height: 455), cornerRadius: 38).applying(transform))
        strokes.append(line([point(-8, 174), point(650, 174)]).applying(transform))
        for x in [CGFloat(90), 270, 450] {
            strokes.append(Path(roundedRect: CGRect(x: x, y: 18, width: 47, height: 112), cornerRadius: 23).applying(transform))
        }
        for y in [CGFloat(234), 358] {
            for x in [CGFloat(72), 259, 446] {
                strokes.append(Path(roundedRect: CGRect(x: x, y: y, width: 112, height: 57), cornerRadius: 12).applying(transform))
            }
        }
        strokes.append(Path { p in
            p.move(to: point(730, 241))
            p.addCurve(to: point(961, 228), control1: point(754, 137), control2: point(907, 125))
        })
        strokes.append(line([point(910, 218), point(961, 228), point(965, 178)]))
        strokes.append(Path { p in
            p.move(to: point(962, 286))
            p.addCurve(to: point(720, 325), control1: point(938, 397), control2: point(781, 420))
        })
        strokes.append(line([point(716, 376), point(720, 325), point(770, 339)]))
        return Self(size: CGSize(width: 1000, height: 455), lineWidth: 12, strokes: strokes)
    }()
}
