import PetCore
import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var model: CompanionModel
    @State private var showingGame = false
    @State private var showingSettings = false
    @State private var petBounce = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let dark = Sky.isDark(at: context.date)
            ZStack {
                Sky.gradient(at: context.date).ignoresSafeArea()
                if dark { StarsBackdrop().ignoresSafeArea() }

                VStack(spacing: 16) {
                    header(dark: dark)
                    Spacer(minLength: 0)
                    stage(dark: dark)
                    Spacer(minLength: 0)
                    statusCard
                    actions
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

                if let toast = model.toast {
                    VStack {
                        Text(toast)
                            .font(.callout.weight(.semibold))
                            .padding(.horizontal, 16).padding(.vertical, 10)
                            .background(.thinMaterial, in: Capsule())
                            .transition(.move(edge: .top).combined(with: .opacity))
                        Spacer()
                    }
                    .padding(.top, 60)
                }
            }
            .animation(.spring(duration: 0.4), value: model.toast)
        }
        .fullScreenCover(isPresented: $showingGame) {
            TreatCatchGame(state: model.state) { score in
                showingGame = false
                if let score { model.finishGame(score: score) }
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView().environmentObject(model)
        }
        .overlay {
            if let stage = model.celebration {
                CelebrationView(stage: stage, state: model.state) { model.dismissCelebration() }
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut, value: model.celebration)
    }

    private func header(dark: Bool) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.state.name)
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                Text(subtitle)
                    .font(.subheadline.weight(.medium))
                    .opacity(0.75)
            }
            Spacer()
            Button { showingSettings = true } label: {
                Image(systemName: "gearshape.fill")
                    .font(.title3)
                    .padding(10)
                    .background(.ultraThinMaterial, in: Circle())
            }
        }
        .foregroundStyle(dark ? .white : Color(white: 0.15))
        .padding(.top, 8)
    }

    private var subtitle: String {
        let s = model.state
        let age = Int(s.age(at: Date()) / 86400)
        let stage = s.stage == .adult ? (s.adultForm?.displayName ?? "Adult") : s.stage.displayName
        return s.stage == .egg ? "An egg, waiting to hatch" : "\(stage) · day \(age + 1)"
    }

    private func stage(dark: Bool) -> some View {
        ZStack(alignment: .bottom) {
            Ground(dark: dark)
                .frame(height: 70)
                .offset(y: 30)
            TimelineView(.animation) { context in
                let activity = Forecast.activity(for: model.state, at: context.date)
                CreatureView(state: model.state, activity: activity, at: context.date,
                             phase: context.date.timeIntervalSinceReferenceDate)
            }
            .frame(maxWidth: 300, maxHeight: 300)
            .scaleEffect(petBounce ? 1.06 : 1, anchor: .bottom)
            .contentShape(Rectangle())
            .onTapGesture {
                model.perform(.pet)
                withAnimation(.spring(response: 0.25, dampingFraction: 0.4)) { petBounce = true }
                withAnimation(.spring().delay(0.15)) { petBounce = false }
            }
            .accessibilityLabel("\(model.state.name), \(model.state.mood().label)")
            .accessibilityHint("Tap to pet")
        }
    }

    private var statusCard: some View {
        let s = model.state
        let mood = s.mood()
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("\(mood.emoji) \(mood.label)")
                    .font(.headline)
                Spacer()
                Text(Forecast.activity(for: s, at: Date()).caption)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if s.stage != .egg { Stats(state: s) }
            else {
                ProgressView(value: min(1, s.age(at: Date()) / Rules.hatchAfter)) {
                    Text("Hatching… pet the egg to keep it warm").font(.subheadline)
                }
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var actions: some View {
        let asleep = model.state.isAsleep()
        return VStack(spacing: 10) {
            HStack(spacing: 10) {
                ForEach(CareAction.allCases, id: \.self) { action in
                    ActionButton(title: action.verb, symbol: action.systemImage, tint: action.tint) {
                        model.perform(action)
                    }
                }
            }
            HStack(spacing: 10) {
                ActionButton(title: "Treat Catch", symbol: "gamecontroller.fill", tint: Color(red: 0.6, green: 0.5, blue: 1)) {
                    showingGame = true
                }
                .disabled(model.state.stage == .egg || asleep)
                .opacity(model.state.stage == .egg || asleep ? 0.5 : 1)
                ActionButton(title: "Nap", symbol: "moon.zzz.fill", tint: Color(red: 0.4, green: 0.45, blue: 0.8)) {
                    model.tuckIn()
                }
                .disabled(model.state.stage == .egg || asleep)
                .opacity(model.state.stage == .egg || asleep ? 0.5 : 1)
            }
        }
    }
}

struct ActionButton: View {
    var title: String
    var symbol: String
    var tint: Color
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: symbol).font(.system(size: 20, weight: .semibold))
                Text(title).font(.caption.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .foregroundStyle(.white)
            .background(tint.gradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// A few fixed twinkling dots for the night sky.
struct StarsBackdrop: View {
    private let stars: [(CGFloat, CGFloat, CGFloat)] = (0..<40).map { i in
        let x = CGFloat((i * 37) % 100) / 100
        let y = CGFloat((i * 53) % 60) / 100
        return (x, y, CGFloat(1 + (i % 3)))
    }

    var body: some View {
        GeometryReader { geo in
            ForEach(stars.indices, id: \.self) { i in
                Circle()
                    .fill(.white.opacity(0.7))
                    .frame(width: stars[i].2, height: stars[i].2)
                    .position(x: stars[i].0 * geo.size.width, y: stars[i].1 * geo.size.height)
            }
        }
    }
}

struct CelebrationView: View {
    var stage: Stage
    var state: PetState
    var dismiss: () -> Void

    private var title: String {
        switch stage {
        case .egg: return "A new egg!"
        case .baby: return "It hatched!"
        case .child: return "\(state.name) grew up!"
        case .adult: return "\(state.name) became \(state.adultForm?.displayName ?? "an adult")!"
        }
    }

    private var detail: String {
        switch stage {
        case .egg: return "Keep it warm and it will hatch soon."
        case .baby: return "Say hello to \(state.name). Feed, play and cuddle to help them grow."
        case .child: return "How you care for \(state.name) now decides who they become."
        case .adult: return state.adultForm?.blurb ?? ""
        }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: 14) {
                TimelineView(.animation) { context in
                    CreatureView(state: state, activity: .dancing, phase: context.date.timeIntervalSinceReferenceDate)
                }
                .frame(width: 180, height: 180)
                Text(title).font(.system(.title, design: .rounded).weight(.bold))
                Text(detail).multilineTextAlignment(.center).foregroundStyle(.secondary)
                Button("Yay!", action: dismiss)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
            .padding(24)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .padding(32)
        }
    }
}
