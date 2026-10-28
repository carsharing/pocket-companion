import SwiftUI

/// A curved line. Positive `bend` curves downwards (a smile), negative upwards.
struct CurveShape: Shape {
    var bend: CGFloat

    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.midY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.midY),
                       control: CGPoint(x: r.midX, y: r.midY + bend * r.height))
        return p
    }
}

struct HeartShape: Shape {
    func path(in r: CGRect) -> Path {
        let w = r.width, h = r.height, x = r.minX, y = r.minY
        var p = Path()
        p.move(to: CGPoint(x: x + w * 0.5, y: y + h))
        p.addCurve(to: CGPoint(x: x, y: y + h * 0.3),
                   control1: CGPoint(x: x + w * 0.1, y: y + h * 0.7),
                   control2: CGPoint(x: x, y: y + h * 0.5))
        p.addArc(center: CGPoint(x: x + w * 0.25, y: y + h * 0.28), radius: w * 0.25,
                 startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        p.addArc(center: CGPoint(x: x + w * 0.75, y: y + h * 0.28), radius: w * 0.25,
                 startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        p.addCurve(to: CGPoint(x: x + w * 0.5, y: y + h),
                   control1: CGPoint(x: x + w, y: y + h * 0.5),
                   control2: CGPoint(x: x + w * 0.9, y: y + h * 0.7))
        p.closeSubpath()
        return p
    }
}

struct StarShape: Shape {
    var points = 5
    var innerRatio: CGFloat = 0.45

    func path(in r: CGRect) -> Path {
        let center = CGPoint(x: r.midX, y: r.midY)
        let outer = min(r.width, r.height) / 2
        var p = Path()
        for i in 0..<(points * 2) {
            let radius = i.isMultiple(of: 2) ? outer : outer * innerRatio
            let angle = Double(i) * .pi / Double(points) - .pi / 2
            let pt = CGPoint(x: center.x + CGFloat(cos(angle)) * radius, y: center.y + CGFloat(sin(angle)) * radius)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}

/// Rounded rice-ball triangle.
struct OnigiriShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.maxY * 0.92 + r.minY * 0.08),
                       control: CGPoint(x: r.maxX - r.width * 0.05, y: r.midY))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: r.maxY * 0.92 + r.minY * 0.08),
                       control: CGPoint(x: r.midX, y: r.maxY + r.height * 0.12))
        p.addQuadCurve(to: CGPoint(x: r.midX, y: r.minY),
                       control: CGPoint(x: r.minX + r.width * 0.05, y: r.midY))
        p.closeSubpath()
        return p
    }
}

extension View {
    /// Places a view inside a 100×100 design grid scaled by `s`, centred on (x, y).
    func place(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ s: CGFloat) -> some View {
        frame(width: w * s, height: h * s).position(x: x * s, y: y * s)
    }
}
