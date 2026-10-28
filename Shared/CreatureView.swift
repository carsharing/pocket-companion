import SwiftUI
import PetCore

/// Draws the companion in a 100×100 design grid, scaled to fit.
///
/// Pass `phase` (seconds, from a `TimelineView`) to animate. Leave it nil for a still pose,
/// as widgets do; each activity then has a recognisable frozen frame.
struct CreatureView: View {
    var stage: Stage
    var form: AdultForm?
    var mood: Mood
    var activity: Activity
    var hue: Double
    var need: CareAction? = nil
    var isDirty = false
    var hatchProgress: Double = 0
    var phase: Double? = nil

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height) / 100
            ZStack {
                if stage == .egg {
                    groundShadow(s, hop: 0)
                    EggView(hue: hue, progress: hatchProgress, s: s)
                        .rotationEffect(.degrees(eggTilt), anchor: UnitPoint(x: 0.5, y: 0.88))
                } else {
                    groundShadow(s, hop: motion.hop)
                    BlobBody(look: look, palette: palette, s: s, stage: stage, form: form,
                             mood: mood, activity: activity, isDirty: isDirty, blink: isBlinking, phase: t)
                        .scaleEffect(x: motion.squashX, y: motion.squashY, anchor: .bottom)
                        .rotationEffect(.degrees(motion.tilt), anchor: UnitPoint(x: 0.5, y: 0.87))
                        .offset(y: motion.hop * s)
                    PropsLayer(activity: activity, mood: mood, need: need, isDirty: isDirty, s: s, t: t, animated: animated)
                }
            }
            .frame(width: 100 * s, height: 100 * s)
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private var animated: Bool { phase != nil }
    private var t: Double { phase ?? 0 }

    private var palette: CreaturePalette { CreaturePalette(hue: hue, form: stage == .adult ? form : nil) }

    private var isBlinking: Bool {
        animated && t.truncatingRemainder(dividingBy: 3.7) < 0.14
    }

    private var eggTilt: Double {
        let urgency = hatchProgress > 0.75 ? 2.5 : 1
        guard animated else { return 4 }
        // Wobble in short bursts rather than constantly.
        let burst = max(0, sin(t * 0.9))
        return sin(t * 9) * 6 * burst * urgency
    }

    private var look: CGPoint {
        switch activity {
        case .lookingAround: return CGPoint(x: animated ? sin(t * 0.8) * 2.5 : -2.2, y: 0)
        case .butterfly: return CGPoint(x: animated ? -1.5 + sin(t * 0.9) * 1.2 : -1.6, y: -2)
        case .ball: return CGPoint(x: 2.2, y: 1.2)
        case .eating: return CGPoint(x: 1.5, y: 1.5)
        default: return .zero
        }
    }

    private struct Motion {
        var hop: CGFloat = 0
        var tilt: Double = 0
        var squashX: CGFloat = 1
        var squashY: CGFloat = 1
    }

    private var motion: Motion {
        var m = Motion()
        switch activity {
        case .bouncing:
            if animated {
                let p = abs(sin(t * 3.4))
                m.hop = -p * 12
                let land = max(0, 0.25 - p) * 0.5
                m.squashY = 1 - land; m.squashX = 1 + land
            } else {
                m.hop = -8; m.squashY = 1.05; m.squashX = 0.96
            }
        case .dancing:
            m.tilt = animated ? sin(t * 5) * 10 : 9
            m.hop = animated ? -abs(sin(t * 5)) * 4 : -2
        case .ball:
            m.tilt = animated ? sin(t * 4) * 4 : 5
            m.hop = animated ? -abs(sin(t * 4)) * 4 : -2
        case .lookingAround:
            m.tilt = animated ? sin(t * 0.8) * 5 : -5
        case .butterfly:
            m.tilt = -4
        case .beingPetted:
            m.tilt = animated ? sin(t * 2.5) * 6 : 6
            m.squashY = 0.96; m.squashX = 1.04
        case .eating:
            let chew = animated ? sin(t * 8) * 0.025 : 0
            m.squashY = 1 - chew; m.squashX = 1 + chew
        case .sleeping:
            let breath = animated ? sin(t * 1.4) * 0.03 : 0
            m.squashY = 0.97 + breath; m.squashX = 1.03 - breath
        case .sulking:
            m.squashY = 0.95; m.squashX = 1.04
            m.hop = animated ? sin(t * 1.2) * 0.6 : 0
        case .bathing:
            m.tilt = animated ? sin(t * 6) * 3 : 0
        case .idle, .wobbling:
            m.hop = animated ? sin(t * 2) * 1.2 : 0
            let breath = animated ? sin(t * 2) * 0.015 : 0
            m.squashY = 1 + breath; m.squashX = 1 - breath
        }
        return m
    }

    private func groundShadow(_ s: CGFloat, hop: CGFloat) -> some View {
        let shrink = 1 + hop / 30
        return Ellipse()
            .fill(Color.black.opacity(0.13))
            .place(50, 89, 56 * shrink, 6 * shrink, s)
    }
}

struct CreaturePalette {
    var body: Color
    var dark: Color
    var belly: Color
    var cheek = Color(red: 1, green: 0.55, blue: 0.62)

    init(hue: Double, form: AdultForm?) {
        var h = hue, sat = 0.42
        switch form {
        case .cloud: h = 0.6; sat = 0.1
        case .sparkle: h = 0.78; sat = 0.35
        case .sprout: h = 0.32; sat = 0.38
        default: break
        }
        body = Color(hue: h, saturation: sat, brightness: 0.97)
        dark = Color(hue: h, saturation: min(1, sat + 0.2), brightness: 0.62)
        belly = Color(hue: h, saturation: sat * 0.35, brightness: 1)
    }
}

// MARK: - Body

private struct BodyMetrics {
    var width: CGFloat
    var height: CGFloat
    var centerY: CGFloat
    var eyeSize: CGSize

    var top: CGFloat { centerY - height / 2 }
    var bottom: CGFloat { centerY + height / 2 }
    var eyeY: CGFloat { centerY - height * 0.1 }
    var eyeSpacing: CGFloat { width * 0.17 }

    init(stage: Stage, form: AdultForm?) {
        switch stage {
        case .egg, .baby:
            width = 50; height = 42; eyeSize = CGSize(width: 7, height: 9)
        case .child:
            width = 58; height = 52; eyeSize = CGSize(width: 6.5, height: 8.5)
        case .adult:
            width = form == .gourmet ? 74 : 66
            height = form == .gourmet ? 58 : 60
            eyeSize = CGSize(width: 6.5, height: 8.5)
        }
        centerY = 87 - height / 2
    }
}

private struct BlobBody: View {
    var look: CGPoint
    var palette: CreaturePalette
    var s: CGFloat
    var stage: Stage
    var form: AdultForm?
    var mood: Mood
    var activity: Activity
    var isDirty: Bool
    var blink: Bool
    var phase: Double

    private var m: BodyMetrics { BodyMetrics(stage: stage, form: form) }

    var body: some View {
        ZStack {
            backAccessory
            if stage != .baby { feet }
            torso
            if stage != .baby { arms }
            belly
            if isDirty { smudges }
            FaceView(m: m, look: look, palette: palette, s: s, mood: mood, activity: activity, blink: blink, stage: stage)
            frontAccessory
        }
    }

    @ViewBuilder private var torso: some View {
        let gradient = LinearGradient(colors: [palette.belly, palette.body], startPoint: .top, endPoint: .center)
        if stage == .adult && form == .cloud {
            CloudShape()
                .fill(gradient)
                .shadow(color: palette.dark.opacity(0.35), radius: 1.5 * s, y: 1 * s)
                .place(50, m.centerY, m.width + 8, m.height, s)
        } else {
            ZStack {
                BlobShape().fill(gradient)
                BlobShape().stroke(palette.dark, lineWidth: 1.6 * s)
            }
            .shadow(color: form == .sparkle && stage == .adult ? Color.purple.opacity(0.5) : .clear, radius: 6 * s)
            .place(50, m.centerY, m.width, m.height, s)
        }
    }

    private var belly: some View {
        Ellipse()
            .fill(palette.belly.opacity(0.8))
            .place(50, m.centerY + m.height * 0.22, m.width * 0.5, m.height * 0.36, s)
    }

    private var feet: some View {
        ZStack {
            Ellipse().fill(palette.dark).place(50 - m.width * 0.22, m.bottom - 1.5, 15, 7, s)
            Ellipse().fill(palette.dark).place(50 + m.width * 0.22, m.bottom - 1.5, 15, 7, s)
        }
    }

    private var arms: some View {
        let raised = activity == .dancing || activity == .bouncing || activity == .ball
        let wave = activity == .dancing ? sin(phase * 5) * 20 : 0
        let angle: Double = raised ? 40 + wave : 15
        return ZStack {
            Ellipse().fill(palette.body).overlay(Ellipse().stroke(palette.dark, lineWidth: 1.3 * s))
                .rotationEffect(.degrees(angle))
                .place(50 - m.width / 2 + 1, m.centerY + (raised ? -2 : 6), 10, 15, s)
            Ellipse().fill(palette.body).overlay(Ellipse().stroke(palette.dark, lineWidth: 1.3 * s))
                .rotationEffect(.degrees(-angle))
                .place(50 + m.width / 2 - 1, m.centerY + (raised ? -2 : 6), 10, 15, s)
        }
    }

    private var smudges: some View {
        ZStack {
            Ellipse().fill(Color.brown.opacity(0.35)).place(50 - m.width * 0.25, m.centerY + 10, 8, 5, s)
            Ellipse().fill(Color.brown.opacity(0.3)).place(50 + m.width * 0.2, m.centerY + 16, 6, 4, s)
            Ellipse().fill(Color.brown.opacity(0.3)).place(50 + m.width * 0.28, m.top + 10, 5, 3.5, s)
        }
    }

    /// Ears sit behind the body.
    @ViewBuilder private var backAccessory: some View {
        if stage == .adult && form == .bouncy {
            ZStack {
                ear.rotationEffect(.degrees(-14)).place(50 - m.width * 0.2, m.top - 8, 12, 30, s)
                ear.rotationEffect(.degrees(14)).place(50 + m.width * 0.2, m.top - 8, 12, 30, s)
            }
        }
    }

    private var ear: some View {
        ZStack {
            Capsule().fill(palette.body)
            Capsule().stroke(palette.dark, lineWidth: 1.4 * s)
            Capsule().fill(palette.cheek.opacity(0.55)).padding(.horizontal, 3.2 * s).padding(.vertical, 5 * s)
        }
    }

    @ViewBuilder private var frontAccessory: some View {
        switch (stage, form) {
        case (.baby, _):
            CurveShape(bend: -1.2)
                .stroke(palette.dark, style: StrokeStyle(lineWidth: 1.6 * s, lineCap: .round))
                .rotationEffect(.degrees(-60))
                .place(52, m.top - 2, 8, 5, s)
        case (.child, _):
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    Capsule().fill(palette.dark)
                        .rotationEffect(.degrees(Double(i - 1) * 25))
                        .place(50 + CGFloat(i - 1) * 4, m.top - 1, 2.6, 8, s)
                }
            }
        case (.adult, .sprout?):
            ZStack {
                Capsule().fill(Color(red: 0.3, green: 0.55, blue: 0.25)).place(50, m.top - 4, 2.2, 10, s)
                LeafShape().fill(Color(red: 0.42, green: 0.75, blue: 0.35)).rotationEffect(.degrees(-25))
                    .place(44, m.top - 9, 13, 7, s)
                LeafShape().fill(Color(red: 0.5, green: 0.82, blue: 0.4)).rotationEffect(.degrees(25))
                    .place(56, m.top - 9, 13, 7, s)
            }
        case (.adult, .gourmet?):
            ZStack {
                Circle().fill(.white).place(43, m.top - 9, 12, 12, s)
                Circle().fill(.white).place(57, m.top - 9, 12, 12, s)
                Circle().fill(.white).place(50, m.top - 13, 14, 14, s)
                RoundedRectangle(cornerRadius: 1.5 * s).fill(.white)
                    .overlay(RoundedRectangle(cornerRadius: 1.5 * s).stroke(Color.gray.opacity(0.4), lineWidth: 1 * s))
                    .place(50, m.top - 2, 22, 7, s)
            }
        case (.adult, .sparkle?):
            ZStack {
                Capsule().fill(palette.dark).place(50, m.top - 5, 1.8, 11, s)
                StarShape().fill(Color.yellow)
                    .overlay(StarShape().stroke(Color.orange, lineWidth: 1 * s))
                    .rotationEffect(.degrees(phase * 30))
                    .place(50, m.top - 12, 12, 12, s)
            }
        case (.adult, .cloud?):
            Image(systemName: "drop.fill")
                .resizable().scaledToFit()
                .foregroundStyle(Color(red: 0.55, green: 0.75, blue: 1))
                .place(76, m.top + 2 + CGFloat(sin(phase * 1.5)) * 2, 6, 8, s)
        default:
            EmptyView()
        }
    }
}

// MARK: - Face

private struct FaceView: View {
    var m: BodyMetrics
    var look: CGPoint
    var palette: CreaturePalette
    var s: CGFloat
    var mood: Mood
    var activity: Activity
    var blink: Bool
    var stage: Stage

    private enum EyeStyle { case open, happy, closed, blink }

    private var eyeStyle: EyeStyle {
        if activity == .sleeping { return .closed }
        if activity == .dancing || activity == .beingPetted || activity == .bathing { return .happy }
        if blink { return .blink }
        return .open
    }

    var body: some View {
        ZStack {
            eye(x: 50 - m.eyeSpacing)
            eye(x: 50 + m.eyeSpacing)
            Ellipse().fill(palette.cheek.opacity(0.45)).place(50 - m.eyeSpacing - 6, m.eyeY + 7, 8, 4.5, s)
            Ellipse().fill(palette.cheek.opacity(0.45)).place(50 + m.eyeSpacing + 6, m.eyeY + 7, 8, 4.5, s)
            if mood == .sad && activity != .sleeping {
                brows
                tear
            }
            mouth
        }
    }

    @ViewBuilder private func eye(x: CGFloat) -> some View {
        let ink = Color(white: 0.15)
        switch eyeStyle {
        case .open:
            ZStack {
                Ellipse().fill(ink).place(x + look.x, m.eyeY + look.y, m.eyeSize.width, m.eyeSize.height, s)
                Circle().fill(.white).place(x + look.x + 1.3, m.eyeY + look.y - 1.8, 2.6, 2.6, s)
            }
        case .happy:
            CurveShape(bend: -1.4)
                .stroke(ink, style: StrokeStyle(lineWidth: 1.8 * s, lineCap: .round))
                .place(x, m.eyeY, m.eyeSize.width + 1, 5, s)
        case .closed:
            CurveShape(bend: 1.2)
                .stroke(ink, style: StrokeStyle(lineWidth: 1.6 * s, lineCap: .round))
                .place(x, m.eyeY + 1, m.eyeSize.width + 1, 4, s)
        case .blink:
            Capsule().fill(ink).place(x, m.eyeY + 1, m.eyeSize.width, 1.6, s)
        }
    }

    private var brows: some View {
        let ink = Color(white: 0.2)
        return ZStack {
            Capsule().fill(ink).rotationEffect(.degrees(-18)).place(50 - m.eyeSpacing, m.eyeY - 7, 6, 1.4, s)
            Capsule().fill(ink).rotationEffect(.degrees(18)).place(50 + m.eyeSpacing, m.eyeY - 7, 6, 1.4, s)
        }
    }

    private var tear: some View {
        Image(systemName: "drop.fill").resizable().scaledToFit()
            .foregroundStyle(Color(red: 0.5, green: 0.75, blue: 1))
            .place(50 + m.eyeSpacing + 3, m.eyeY + 7, 3, 4.5, s)
    }

    @ViewBuilder private var mouth: some View {
        let ink = Color(white: 0.2)
        let y = m.eyeY + 8.5
        if activity == .sleeping {
            Ellipse().stroke(ink, lineWidth: 1.2 * s).place(50, y, 3, 2.5, s)
        } else if activity == .eating {
            Ellipse().fill(Color(red: 0.55, green: 0.15, blue: 0.2)).place(50, y + 0.5, 5.5, 5, s)
        } else if mood == .happy || activity == .dancing || activity == .ball || activity == .bouncing || activity == .beingPetted {
            ZStack {
                OpenSmileShape().fill(Color(red: 0.55, green: 0.15, blue: 0.2))
                OpenSmileShape().fill(Color(red: 1, green: 0.5, blue: 0.55)).scaleEffect(x: 0.55, y: 0.45, anchor: .bottom)
            }
            .place(50, y + 1, 9, 5, s)
        } else if mood == .sad || mood == .hungry || mood == .dirty || mood == .tired {
            CurveShape(bend: -1)
                .stroke(ink, style: StrokeStyle(lineWidth: 1.4 * s, lineCap: .round))
                .place(50, y + 1.5, 6, 3, s)
        } else {
            CurveShape(bend: 1)
                .stroke(ink, style: StrokeStyle(lineWidth: 1.4 * s, lineCap: .round))
                .place(50, y, 7, 3.5, s)
        }
    }
}

// MARK: - Egg

private struct EggView: View {
    var hue: Double
    var progress: Double
    var s: CGFloat

    var body: some View {
        let spot = Color(hue: hue, saturation: 0.45, brightness: 0.9)
        ZStack {
            EggShape()
                .fill(LinearGradient(colors: [.white, Color(red: 1, green: 0.95, blue: 0.86)], startPoint: .top, endPoint: .bottom))
                .overlay(EggShape().stroke(Color(red: 0.8, green: 0.72, blue: 0.58), lineWidth: 1.6 * s))
                .place(50, 62, 46, 54, s)
            Circle().fill(spot).place(40, 52, 10, 10, s)
            Circle().fill(spot).place(58, 66, 13, 13, s)
            Circle().fill(spot).place(44, 76, 7, 7, s)
            Circle().fill(spot).place(60, 47, 6, 6, s)
            if progress > 0.6 { crack }
        }
    }

    private var crack: some View {
        Path { p in
            p.move(to: CGPoint(x: 34 * s, y: 58 * s))
            p.addLine(to: CGPoint(x: 40 * s, y: 54 * s))
            p.addLine(to: CGPoint(x: 45 * s, y: 60 * s))
            p.addLine(to: CGPoint(x: 51 * s, y: 54 * s))
            p.addLine(to: CGPoint(x: 56 * s, y: 59 * s))
        }
        .stroke(Color(red: 0.55, green: 0.45, blue: 0.35), style: StrokeStyle(lineWidth: 1.4 * s, lineCap: .round, lineJoin: .round))
    }
}

// MARK: - Props and effects

private struct PropsLayer: View {
    var activity: Activity
    var mood: Mood
    var need: CareAction?
    var isDirty: Bool
    var s: CGFloat
    var t: Double
    var animated: Bool

    var body: some View {
        ZStack {
            switch activity {
            case .sleeping: zzz
            case .ball: ball
            case .butterfly: butterfly
            case .eating: onigiri
            case .bathing: bubbles
            case .beingPetted: hearts
            case .dancing: notes
            case .sulking: thought
            default: EmptyView()
            }
            if isDirty && activity != .bathing && activity != .sleeping { stink }
        }
    }

    /// 0...1 repeating progress with an offset, for drifting effects.
    private func cycle(_ speed: Double, offset: Double = 0) -> CGFloat {
        guard animated else { return CGFloat(offset.truncatingRemainder(dividingBy: 1)) }
        return CGFloat((t * speed + offset).truncatingRemainder(dividingBy: 1))
    }

    private var zzz: some View {
        let indigo = Color(red: 0.4, green: 0.42, blue: 0.85)
        return ZStack {
            ForEach(0..<3, id: \.self) { i in
                let c = cycle(0.25, offset: Double(i) / 3)
                Text("z")
                    .font(.system(size: (8 + 6 * c) * s, weight: .heavy, design: .rounded))
                    .foregroundStyle(indigo.opacity(Double(1 - c * 0.7)))
                    .position(x: (68 + 16 * c) * s, y: (44 - 32 * c) * s)
            }
        }
    }

    private var ball: some View {
        let x: CGFloat = animated ? 80 + CGFloat(sin(t * 4)) * 5 : 81
        let y: CGFloat = animated ? 82 - abs(CGFloat(cos(t * 4))) * 12 : 76
        return ZStack {
            Circle().fill(Color(red: 1, green: 0.42, blue: 0.4))
            Circle().trim(from: 0, to: 0.5).fill(.white).rotationEffect(.degrees(animated ? t * 200 : 30))
            Circle().stroke(Color(red: 0.7, green: 0.2, blue: 0.2), lineWidth: 1.2 * s)
        }
        .place(x, y, 13, 13, s)
    }

    private var butterfly: some View {
        let x: CGFloat = animated ? 24 + CGFloat(sin(t * 0.9)) * 9 : 24
        let y: CGFloat = animated ? 24 + CGFloat(cos(t * 1.3)) * 5 : 24
        let flap: CGFloat = animated ? 0.4 + 0.6 * abs(CGFloat(sin(t * 10))) : 0.9
        let wing = Color(red: 1, green: 0.7, blue: 0.3)
        return ZStack {
            Ellipse().fill(wing).frame(width: 6 * s, height: 8 * s).offset(x: -3 * s * flap)
                .scaleEffect(x: flap, y: 1)
            Ellipse().fill(wing).frame(width: 6 * s, height: 8 * s).offset(x: 3 * s * flap)
                .scaleEffect(x: flap, y: 1)
            Capsule().fill(Color(white: 0.25)).frame(width: 1.6 * s, height: 7 * s)
        }
        .position(x: x * s, y: y * s)
    }

    private var onigiri: some View {
        ZStack {
            OnigiriShape().fill(.white)
                .overlay(OnigiriShape().stroke(Color.gray.opacity(0.5), lineWidth: 1 * s))
                .place(79, 80, 16, 14, s)
            Rectangle().fill(Color(red: 0.15, green: 0.25, blue: 0.2)).place(79, 84, 8, 6, s)
            Circle().fill(.white).place(70, 86, 2, 2, s)
            Circle().fill(.white).place(73, 83, 1.5, 1.5, s)
        }
    }

    private var bubbles: some View {
        ZStack {
            ForEach(0..<6, id: \.self) { i in
                let c = cycle(0.3, offset: Double(i) / 6)
                let x = 22 + CGFloat(i) * 11 + CGFloat(sin(Double(c) * 6 + Double(i))) * 3
                let size = 5 + CGFloat(i % 3) * 2.5
                Circle()
                    .fill(Color.white.opacity(0.5))
                    .overlay(Circle().stroke(Color(red: 0.55, green: 0.8, blue: 1), lineWidth: 1 * s))
                    .place(x, 82 - 62 * c, size, size, s)
            }
            // A foam cap on the head.
            Ellipse().fill(.white).place(50, 34, 26, 9, s)
            Circle().fill(.white).place(44, 30, 10, 10, s)
            Circle().fill(.white).place(55, 29, 12, 12, s)
        }
    }

    private var hearts: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                let c = cycle(0.35, offset: Double(i) / 3)
                HeartShape()
                    .fill(Color(red: 1, green: 0.4, blue: 0.55).opacity(Double(1 - c * 0.8)))
                    .place(26 + CGFloat(i) * 22, 38 - 26 * c, 8 + 3 * c, 7 + 3 * c, s)
            }
        }
    }

    private var notes: some View {
        let color = Color(red: 0.45, green: 0.4, blue: 0.9)
        return ZStack {
            ForEach(0..<2, id: \.self) { i in
                let c = cycle(0.4, offset: Double(i) / 2)
                Text(i == 0 ? "♪" : "♫")
                    .font(.system(size: 12 * s, weight: .bold))
                    .foregroundStyle(color.opacity(Double(1 - c * 0.7)))
                    .position(x: (i == 0 ? 20 : 80) * s, y: (40 - 24 * c) * s)
            }
        }
    }

    private var needSymbol: String {
        switch need {
        case .feed?: return "fork.knife"
        case .clean?: return "bubbles.and.sparkles.fill"
        case .play?: return "soccerball"
        default: return mood == .tired ? "moon.zzz.fill" : "heart.fill"
        }
    }

    private var thought: some View {
        ZStack {
            Circle().fill(.white).overlay(Circle().stroke(Color.gray.opacity(0.4), lineWidth: 1 * s))
                .place(80, 22, 22, 20, s)
            Circle().fill(.white).overlay(Circle().stroke(Color.gray.opacity(0.4), lineWidth: 1 * s))
                .place(69, 36, 5, 5, s)
            Circle().fill(.white).overlay(Circle().stroke(Color.gray.opacity(0.4), lineWidth: 1 * s))
                .place(65, 42, 3, 3, s)
            Image(systemName: needSymbol).resizable().scaledToFit()
                .foregroundStyle(Color(red: 0.95, green: 0.5, blue: 0.4))
                .place(80, 22, 11, 11, s)
        }
        .offset(y: animated ? CGFloat(sin(t * 1.5)) * 1.5 * s : 0)
    }

    private var stink: some View {
        ZStack {
            ForEach(0..<2, id: \.self) { i in
                let c = cycle(0.3, offset: Double(i) / 2)
                CurveShape(bend: 1)
                    .stroke(Color(red: 0.55, green: 0.6, blue: 0.3).opacity(Double(1 - c)), style: StrokeStyle(lineWidth: 1.4 * s, lineCap: .round))
                    .rotationEffect(.degrees(80))
                    .place(i == 0 ? 18 : 84, 60 - 18 * c, 10, 4, s)
            }
        }
    }
}

extension CreatureView {
    /// Convenience for drawing straight from a state.
    init(state: PetState, activity: Activity, at date: Date = Date(), phase: Double? = nil) {
        let hatch = state.stage == .egg ? min(1, state.age(at: date) / Rules.hatchAfter) : 1
        self.init(
            stage: state.stage,
            form: state.adultForm,
            mood: state.mood(),
            activity: activity,
            hue: state.hue,
            need: state.topNeed(),
            isDirty: state.cleanliness < 0.35,
            hatchProgress: hatch,
            phase: phase
        )
    }
}
