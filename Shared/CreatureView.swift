import SwiftUI
import PetCore

/// Draws the companion in a 100×100 design grid, scaled to fit.
///
/// The artwork itself lives in `CreatureArt` (generated from art/art.py). This view picks the
/// right species, pose and expression, and animates parts of it.
///
/// Pass `phase` (seconds, from a `TimelineView`) to animate. Leave it nil for a still pose,
/// as widgets do; each activity then has a recognisable frozen frame.
struct CreatureView: View {
    var stage: Stage
    var form: AdultForm?
    var mood: Mood
    var activity: Activity
    var need: CareAction? = nil
    var isDirty = false
    var phase: Double? = nil

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height) / 100
            ZStack {
                groundShadow(s)
                ArtFigure(layers: layers, tags: tags, rig: rig, s: s, motion: partMotion, extras: partExtras)
                    .scaleEffect(x: motion.squashX, y: motion.squashY, anchor: UnitPoint(x: 0.48, y: 0.88))
                    .rotationEffect(.degrees(motion.tilt), anchor: UnitPoint(x: 0.48, y: 0.88))
                    .offset(y: motion.hop * s)
                    .shadow(color: glow.opacity(0.55), radius: 5 * s)
                PropsLayer(activity: activity, mood: mood, need: need, isDirty: isDirty && !isCurled,
                           s: s, t: t, animated: animated)
            }
            .frame(width: 100 * s, height: 100 * s)
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private var animated: Bool { phase != nil }
    private var t: Double { phase ?? 0 }

    // MARK: Choosing the artwork

    private var isCurled: Bool { stage == .egg || activity == .sleeping }

    private var species: AdultForm {
        stage == .adult ? (form ?? .fox) : .fox
    }

    private var layers: [ArtLayer] {
        if stage == .egg { return CreatureArt.den }
        switch (species, isCurled) {
        case (.fox, false): return CreatureArt.fox
        case (.fox, true): return CreatureArt.foxAsleep
        case (.kitsune, false): return CreatureArt.kitsune
        case (.kitsune, true): return CreatureArt.kitsuneAsleep
        case (.bunny, false): return CreatureArt.bunny
        case (.bunny, true): return CreatureArt.bunnyAsleep
        case (.cat, false): return CreatureArt.cat
        case (.cat, true): return CreatureArt.catAsleep
        case (.dragon, false): return CreatureArt.dragon
        case (.dragon, true): return CreatureArt.dragonAsleep
        }
    }

    private var rig: StageRig {
        if stage == .egg { return CreatureArt.adultRig }
        if isCurled {
            // The curled pose has no separate parts to re-proportion; just scale it.
            let figure: CGFloat = stage == .baby ? 0.8 : stage == .child ? 0.9 : 1
            return StageRig(figure: figure, parts: [:])
        }
        switch stage {
        case .baby: return CreatureArt.babyRig
        case .child: return CreatureArt.childRig
        default: return CreatureArt.adultRig
        }
    }

    private var glow: Color {
        stage == .adult && form == .kitsune ? Color(red: 1, green: 0.48, blue: 0.69) : .clear
    }

    private var isBlinking: Bool {
        animated && t.truncatingRemainder(dividingBy: 3.7) < 0.14
    }

    private var tags: Set<String> {
        if isCurled { return ["eyes.closed", "mouth.sleep"] }
        var tags: Set<String> = []
        switch activity {
        case .dancing, .beingPetted, .bathing: tags.insert("eyes.happy")
        default: tags.insert(isBlinking ? "eyes.blink" : "eyes.open")
        }
        if activity == .eating {
            tags.insert(animated && sin(t * 8) > 0 ? "mouth.smile" : "mouth.eat")
        } else if mood == .happy || [.dancing, .ball, .bouncing, .beingPetted].contains(activity) {
            tags.insert("mouth.happy")
        } else if [.sad, .hungry, .dirty, .tired].contains(mood) {
            tags.insert("mouth.frown")
        } else {
            tags.insert("mouth.smile")
        }
        if mood == .sad { tags.insert("brows.sad") }
        return tags
    }

    // MARK: Motion

    private struct Motion {
        var hop: CGFloat = 0
        var tilt: Double = 0
        var squashX: CGFloat = 1
        var squashY: CGFloat = 1
    }

    /// Whole-figure movement.
    private var motion: Motion {
        var m = Motion()
        guard !isCurled else { return m }
        switch activity {
        case .bouncing:
            if animated {
                let p = abs(sin(t * 3.4))
                m.hop = -p * 10
                let land = max(0, 0.25 - p) * 0.4
                m.squashY = 1 - land; m.squashX = 1 + land
            } else {
                m.hop = -7
            }
        case .dancing:
            m.tilt = animated ? sin(t * 5) * 6 : 5
            m.hop = animated ? -abs(sin(t * 5)) * 3 : -2
        case .ball:
            m.hop = animated ? -abs(sin(t * 4)) * 2.5 : 0
        case .sulking:
            m.squashY = 0.97; m.squashX = 1.02
        case .eating:
            let chew = animated ? sin(t * 8) * 0.015 : 0
            m.squashY = 1 - chew; m.squashX = 1 + chew
        default:
            let breath = animated ? sin(t * 2) * 0.012 : 0
            m.squashY = 1 + breath; m.squashX = 1 - breath
        }
        return m
    }

    /// Tail wag, head tilt, where the face looks, and breathing while asleep.
    private func partMotion(_ part: ArtPart) -> PartMotion {
        var m = PartMotion()
        if isCurled {
            if part == .body || part == .head || part == .face {
                let breath = animated ? sin(t * 1.4) * 0.025 : 0
                m.scaleY = 1 + breath
                m.scaleX = 1 - breath * 0.4
                m.scalePivot = CGPoint(x: 48, y: 88)
            }
            return m
        }
        switch part {
        case .tail:
            m.pivot = CreatureArt.tailRoot
            let speed: Double = [.dancing, .ball, .bouncing, .beingPetted].contains(activity) ? 7 : 2.2
            let amount: Double = activity == .sulking ? 2 : [.dancing, .ball, .beingPetted].contains(activity) ? 12 : 6
            m.rotation = animated ? sin(t * speed) * amount : (activity == .sulking ? -4 : 6)
        case .head, .face:
            m.pivot = CreatureArt.neck
            switch activity {
            case .lookingAround: m.rotation = animated ? sin(t * 0.8) * 7 : -6
            case .butterfly: m.rotation = animated ? -6 + sin(t * 0.9) * 3 : -7
            case .ball: m.rotation = animated ? 5 + sin(t * 4) * 2 : 6
            case .beingPetted: m.rotation = animated ? sin(t * 2.5) * 6 : 7
            case .dancing: m.rotation = animated ? sin(t * 5) * 5 : -5
            case .sulking: m.rotation = 5
            default: m.rotation = animated ? sin(t * 0.6) * 2 : 0
            }
            if part == .face { m.offset = look }
        default:
            break
        }
        return m
    }

    private var look: CGSize {
        switch activity {
        case .lookingAround: return CGSize(width: animated ? sin(t * 0.8) * 1.6 : -1.4, height: 0)
        case .butterfly: return CGSize(width: 1, height: -1.2)
        case .ball: return CGSize(width: 1.3, height: 0.8)
        case .eating: return CGSize(width: 1, height: 0.8)
        default: return .zero
        }
    }

    /// Dirt smudges ride along with the body.
    private func partExtras(_ part: ArtPart) -> AnyView? {
        guard isDirty, !isCurled, part == .body else { return nil }
        return AnyView(Smudges())
    }

    private func groundShadow(_ s: CGFloat) -> some View {
        let k = (1 + motion.hop / 30) * rig.figure
        return Ellipse()
            .fill(Color.black.opacity(0.13))
            .place(48, 88.6, (isCurled ? 54 : 50) * k, 5 * k, s)
    }
}

private struct Smudges: View {
    var body: some View {
        GeometryReader { geo in
            let s = geo.size.width / 100
            ZStack {
                Ellipse().fill(Color.brown.opacity(0.35)).place(38, 66, 8, 5, s)
                Ellipse().fill(Color.brown.opacity(0.3)).place(48, 73, 6, 4, s)
                Ellipse().fill(Color.brown.opacity(0.3)).place(31, 71, 5, 3.5, s)
            }
        }
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
            case .sleeping, .wobbling: zzz
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
        let base: CGFloat = activity == .wobbling ? 0 : 6
        return ZStack {
            ForEach(0..<3, id: \.self) { i in
                let c = cycle(0.25, offset: Double(i) / 3)
                Text("z")
                    .font(.system(size: (8 + 6 * c) * s, weight: .heavy, design: .rounded))
                    .foregroundStyle(indigo.opacity(Double(1 - c * 0.7)))
                    .position(x: (66 + 18 * c) * s, y: (52 + base - 34 * c) * s)
            }
        }
    }

    private var ball: some View {
        let x: CGFloat = animated ? 82 + CGFloat(sin(t * 4)) * 4 : 82
        let y: CGFloat = animated ? 82 - abs(CGFloat(cos(t * 4))) * 10 : 81
        return ZStack {
            Circle().fill(Color(red: 1, green: 0.42, blue: 0.4))
            Circle().trim(from: 0, to: 0.5).fill(.white).rotationEffect(.degrees(animated ? t * 200 : 30))
            Circle().stroke(ArtLayer.outline, lineWidth: 1.4 * s)
        }
        .place(x, y, 12, 12, s)
    }

    private var butterfly: some View {
        let x: CGFloat = animated ? 88 + CGFloat(sin(t * 0.9)) * 5 : 88
        let y: CGFloat = animated ? 28 + CGFloat(cos(t * 1.3)) * 5 : 28
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
                .overlay(OnigiriShape().stroke(ArtLayer.outline, lineWidth: 1.2 * s))
                .place(81, 81, 15, 13, s)
            Rectangle().fill(Color(red: 0.15, green: 0.25, blue: 0.2)).place(81, 85, 7.5, 5.5, s)
            Circle().fill(.white).place(73, 86, 2, 2, s)
            Circle().fill(.white).place(75, 83, 1.5, 1.5, s)
        }
    }

    private var bubbles: some View {
        ZStack {
            ForEach(0..<6, id: \.self) { i in
                let c = cycle(0.3, offset: Double(i) / 6)
                let x = 20 + CGFloat(i) * 12 + CGFloat(sin(Double(c) * 6 + Double(i))) * 3
                let size = 5 + CGFloat(i % 3) * 2.5
                Circle()
                    .fill(Color.white.opacity(0.5))
                    .overlay(Circle().stroke(Color(red: 0.55, green: 0.8, blue: 1), lineWidth: 1 * s))
                    .place(x, 84 - 66 * c, size, size, s)
            }
            // A foam cap on the head.
            Ellipse().fill(.white).place(60, 25, 24, 8, s)
            Circle().fill(.white).place(55, 21, 10, 10, s)
            Circle().fill(.white).place(65, 20, 11, 11, s)
        }
    }

    private var hearts: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                let c = cycle(0.35, offset: Double(i) / 3)
                HeartShape()
                    .fill(Color(red: 1, green: 0.4, blue: 0.55).opacity(Double(1 - c * 0.8)))
                    .place(CGFloat([30, 88, 20][i]), 34 - 24 * c, 8 + 3 * c, 7 + 3 * c, s)
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
                    .position(x: (i == 0 ? 12 : 90) * s, y: (44 - 24 * c) * s)
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
        let edge = ArtLayer.outline.opacity(0.5)
        return ZStack {
            Ellipse().fill(.white).overlay(Ellipse().stroke(edge, lineWidth: 1 * s))
                .place(20, 14, 22, 19, s)
            Circle().fill(.white).overlay(Circle().stroke(edge, lineWidth: 1 * s))
                .place(31, 26, 4.5, 4.5, s)
            Circle().fill(.white).overlay(Circle().stroke(edge, lineWidth: 1 * s))
                .place(34.5, 30.5, 2.8, 2.8, s)
            Image(systemName: needSymbol).resizable().scaledToFit()
                .foregroundStyle(Color(red: 0.95, green: 0.5, blue: 0.4))
                .place(20, 14, 10, 10, s)
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
                    .place(i == 0 ? 10 : 90, 66 - 18 * c, 10, 4, s)
            }
        }
    }
}

extension CreatureView {
    /// Convenience for drawing straight from a state.
    init(state: PetState, activity: Activity, phase: Double? = nil) {
        self.init(
            stage: state.stage,
            form: state.adultForm,
            mood: state.mood(),
            activity: activity,
            need: state.topNeed(),
            isDirty: state.cleanliness < 0.35,
            phase: phase
        )
    }
}
