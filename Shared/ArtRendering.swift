import SwiftUI

/// Body parts, in drawing order. The app moves some of them separately (tail wag, head tilt).
enum ArtPart: String, CaseIterable {
    case back, tail, legsFar, body, legsNear, head, face, front
}

struct PartTransform {
    var tx: CGFloat = 0
    var ty: CGFloat = 0
    var sx: CGFloat = 1
    var sy: CGFloat = 1
    var pivot: CGPoint = .zero
}

/// Proportions for a life stage: per-part adjustments plus a whole-figure scale around the ground.
struct StageRig {
    var figure: CGFloat
    var parts: [ArtPart: PartTransform]
}

/// One filled or stroked shape of the artwork, in a 100×100 grid.
struct ArtLayer {
    var part: ArtPart
    /// Expression variant ("eyes.open", "mouth.happy"...); nil layers are always drawn.
    var tag: String?
    var fill: Color?
    var stroke: Bool
    var width: CGFloat
    var opacity: Double
    var path: Path

    static let outline = Color(hex: "3B1E18")

    /// Parses the line format written by art/generate_swift.py.
    static func parse(_ text: String) -> [ArtLayer] {
        text.split(separator: "\n").compactMap { line in
            let f = line.split(separator: "|", maxSplits: 6, omittingEmptySubsequences: false)
            guard f.count == 7, let part = ArtPart(rawValue: String(f[0])) else { return nil }
            return ArtLayer(
                part: part,
                tag: f[1] == "-" ? nil : String(f[1]),
                fill: f[2] == "-" ? nil : Color(hex: String(f[2])),
                stroke: f[3] == "1",
                width: CGFloat(Double(f[4]) ?? 1.7),
                opacity: Double(f[5]) ?? 1,
                path: SVGPath.parse(String(f[6]))
            )
        }
    }
}

extension Color {
    init(hex: String) {
        let v = UInt32(hex, radix: 16) ?? 0
        self.init(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
    }
}

/// Minimal SVG path parser for the absolute M/L/C/Q/Z commands the art uses.
enum SVGPath {
    static func parse(_ d: String) -> Path {
        var path = Path()
        var numbers: [CGFloat] = []
        var command: Character = "M"
        var token = ""

        func flushToken() {
            if !token.isEmpty, let v = Double(token) { numbers.append(CGFloat(v)) }
            token = ""
        }
        func point(_ i: Int) -> CGPoint { CGPoint(x: numbers[i], y: numbers[i + 1]) }
        func apply() {
            switch command {
            case "M":
                var i = 0
                while i + 1 < numbers.count {
                    if i == 0 { path.move(to: point(i)) } else { path.addLine(to: point(i)) }
                    i += 2
                }
            case "L":
                var i = 0
                while i + 1 < numbers.count { path.addLine(to: point(i)); i += 2 }
            case "C":
                var i = 0
                while i + 5 < numbers.count {
                    path.addCurve(to: point(i + 4), control1: point(i), control2: point(i + 2)); i += 6
                }
            case "Q":
                var i = 0
                while i + 3 < numbers.count { path.addQuadCurve(to: point(i + 2), control: point(i)); i += 4 }
            case "Z":
                path.closeSubpath()
            default:
                break
            }
            numbers.removeAll(keepingCapacity: true)
        }

        for ch in d {
            if "MLCQZ".contains(ch) {
                flushToken(); apply(); command = ch
            } else if ch == "," || ch == " " {
                flushToken()
            } else if ch == "-" && !token.isEmpty {
                flushToken(); token.append(ch)
            } else {
                token.append(ch)
            }
        }
        flushToken(); apply()
        return path
    }
}

/// A stored path in grid units, stretched to whatever frame it is given.
struct ArtShape: Shape {
    var stored: Path

    func path(in rect: CGRect) -> Path {
        stored.applying(CGAffineTransform(scaleX: rect.width / 100, y: rect.height / 100)
            .concatenating(CGAffineTransform(translationX: rect.minX, y: rect.minY)))
    }
}

/// Per-part motion applied on top of the stage rig.
struct PartMotion {
    var rotation: Double = 0
    var pivot: CGPoint = CGPoint(x: 50, y: 50)
    var offset: CGSize = .zero
    var scaleY: CGFloat = 1
    var scaleX: CGFloat = 1
    var scalePivot: CGPoint = CGPoint(x: 50, y: 88)
}

/// Draws a layer set with the chosen expression, in a square of side `100 * s`.
struct ArtFigure: View {
    var layers: [ArtLayer]
    var tags: Set<String>
    var rig: StageRig
    var s: CGFloat
    var motion: (ArtPart) -> PartMotion = { _ in PartMotion() }
    /// Extra views drawn just above a part, in grid coordinates (dirt smudges...).
    var extras: (ArtPart) -> AnyView? = { _ in nil }

    var body: some View {
        ZStack {
            ForEach(ArtPart.allCases, id: \.self) { part in
                partView(part)
            }
        }
        .frame(width: 100 * s, height: 100 * s)
        .scaleEffect(rig.figure, anchor: unit(CreatureArt.ground))
    }

    private func partView(_ part: ArtPart) -> some View {
        let visible = layers.filter { $0.part == part && ($0.tag.map(tags.contains) ?? true) }
        let t = rig.parts[part] ?? PartTransform()
        let m = motion(part)
        return ZStack {
            ForEach(visible.indices, id: \.self) { i in
                layerView(visible[i])
            }
            if let extra = extras(part) { extra }
        }
        .frame(width: 100 * s, height: 100 * s)
        .scaleEffect(x: m.scaleX, y: m.scaleY, anchor: unit(m.scalePivot))
        .rotationEffect(.degrees(m.rotation), anchor: unit(m.pivot))
        .offset(x: m.offset.width * s, y: m.offset.height * s)
        .scaleEffect(x: t.sx, y: t.sy, anchor: unit(t.pivot))
        .offset(x: t.tx * s, y: t.ty * s)
    }

    private func layerView(_ layer: ArtLayer) -> some View {
        let shape = ArtShape(stored: layer.path)
        return ZStack {
            if let fill = layer.fill { shape.fill(fill) }
            if layer.stroke {
                shape.stroke(ArtLayer.outline, style: StrokeStyle(lineWidth: layer.width * s, lineCap: .round, lineJoin: .round))
            }
        }
        .opacity(layer.opacity)
    }

    private func unit(_ p: CGPoint) -> UnitPoint { UnitPoint(x: p.x / 100, y: p.y / 100) }
}
