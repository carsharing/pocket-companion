import Combine
import PetCore
import SwiftUI

/// Mini-game: drag your companion left and right to catch falling treats for 30 seconds.
struct TreatCatchGame: View {
    var state: PetState
    /// Called with the score, or nil if the player quit early.
    var onFinish: (Int?) -> Void

    @StateObject private var engine = TreatCatchEngine()
    private let frames = Timer.publish(every: 1.0 / 60, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(colors: [Color(red: 0.75, green: 0.88, blue: 1), Color(red: 1, green: 0.93, blue: 0.85)],
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()

                ForEach(engine.treats) { treat in
                    TreatView(kind: treat.kind)
                        .frame(width: 34, height: 34)
                        .rotationEffect(.degrees(treat.spin))
                        .position(x: treat.x * geo.size.width, y: treat.y * geo.size.height)
                }

                ForEach(engine.pops) { pop in
                    Text("+1")
                        .font(.system(.headline, design: .rounded).weight(.heavy))
                        .foregroundStyle(.orange)
                        .opacity(pop.life)
                        .position(x: pop.x * geo.size.width, y: (pop.y - (1 - pop.life) * 0.06) * geo.size.height)
                }

                CreatureView(
                    stage: state.stage, form: state.adultForm, mood: .happy,
                    activity: engine.lastCatchAge < 0.4 ? .dancing : .bouncing,
                    phase: engine.time
                )
                .frame(width: 110, height: 110)
                .position(x: engine.playerX * geo.size.width, y: TreatCatchEngine.playerY * geo.size.height)

                hud
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                engine.playerX = min(0.92, max(0.08, value.location.x / geo.size.width))
            })
        }
        .onReceive(frames) { _ in engine.step(dt: 1.0 / 60) }
    }

    private var hud: some View {
        VStack {
            HStack {
                Button { onFinish(nil) } label: {
                    Image(systemName: "xmark").font(.headline).padding(10)
                        .background(.ultraThinMaterial, in: Circle())
                }
                Spacer()
                Label("\(engine.score)", systemImage: "star.fill")
                    .font(.system(.title2, design: .rounded).weight(.bold))
                Spacer()
                Text("\(Int(ceil(engine.timeLeft)))s")
                    .font(.system(.title3, design: .rounded).weight(.semibold).monospacedDigit())
                    .frame(width: 50)
            }
            .foregroundStyle(Color(white: 0.2))
            .padding(.horizontal)

            Spacer()

            if engine.isOver {
                VStack(spacing: 12) {
                    Text("Time's up!").font(.system(.largeTitle, design: .rounded).weight(.bold))
                    Text("\(state.name) caught \(engine.score) treats").font(.title3)
                    Button("Done") { onFinish(engine.score) }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                }
                .padding(28)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            } else if engine.time < 2.5 {
                Text("Drag to catch the treats!")
                    .font(.headline)
                    .padding(12)
                    .background(.thinMaterial, in: Capsule())
            }
            Spacer()
        }
    }
}

private struct TreatView: View {
    var kind: TreatCatchEngine.Treat.Kind

    var body: some View {
        switch kind {
        case .onigiri:
            ZStack {
                OnigiriShape().fill(.white).overlay(OnigiriShape().stroke(Color.gray.opacity(0.5), lineWidth: 1.5))
                Rectangle().fill(Color(red: 0.15, green: 0.25, blue: 0.2))
                    .frame(width: 14, height: 11).offset(y: 9)
            }
        case .berry:
            ZStack {
                HeartShape().fill(Color(red: 0.95, green: 0.3, blue: 0.4)).rotationEffect(.degrees(180))
                Capsule().fill(Color.green).frame(width: 10, height: 5).offset(y: -15)
            }
        case .star:
            StarShape().fill(Color.yellow).overlay(StarShape().stroke(Color.orange, lineWidth: 1.5))
        }
    }
}

@MainActor
final class TreatCatchEngine: ObservableObject {
    struct Treat: Identifiable {
        enum Kind: CaseIterable { case onigiri, berry, star }
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var speed: CGFloat
        var spin: Double
        var kind: Kind
    }

    struct Pop: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var life: Double
    }

    static let duration: Double = 30
    static let playerY: CGFloat = 0.82

    @Published var playerX: CGFloat = 0.5
    @Published private(set) var treats: [Treat] = []
    @Published private(set) var pops: [Pop] = []
    @Published private(set) var score = 0
    @Published private(set) var time: Double = 0
    @Published private(set) var lastCatchAge: Double = 10

    private var spawnTimer: Double = 0.5

    var timeLeft: Double { max(0, Self.duration - time) }
    var isOver: Bool { time >= Self.duration }

    func step(dt: Double) {
        guard !isOver else { return }
        time += dt
        lastCatchAge += dt

        // Treats come faster as the round goes on.
        spawnTimer -= dt
        if spawnTimer <= 0 {
            spawnTimer = max(0.35, 0.85 - time * 0.015)
            treats.append(Treat(
                x: .random(in: 0.08...0.92),
                y: -0.05,
                speed: .random(in: 0.28...0.4) + CGFloat(time) * 0.006,
                spin: .random(in: 0...360),
                kind: Treat.Kind.allCases.randomElement()!
            ))
        }

        var remaining: [Treat] = []
        for var treat in treats {
            treat.y += treat.speed * CGFloat(dt)
            treat.spin += 90 * dt
            let caught = abs(treat.y - Self.playerY) < 0.05 && abs(treat.x - playerX) < 0.11
            if caught {
                score += 1
                lastCatchAge = 0
                pops.append(Pop(x: treat.x, y: treat.y - 0.05, life: 1))
            } else if treat.y < 1.1 {
                remaining.append(treat)
            }
        }
        treats = remaining
        pops = pops.compactMap { pop in
            var p = pop
            p.life -= dt * 1.5
            return p.life > 0 ? p : nil
        }
        if isOver { treats = [] }
    }
}
