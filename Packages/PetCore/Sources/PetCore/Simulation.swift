import Foundation

/// Tunable numbers for the care loop. Rates are per hour.
public enum Rules {
    public static let hatchAfter: TimeInterval = 20 * 60
    public static let childAfter: TimeInterval = 24 * 3600
    public static let adultAfter: TimeInterval = 72 * 3600

    static let awakeDecay = Rates(fullness: -0.055, happiness: -0.045, energy: -0.045, cleanliness: -0.03)
    static let asleepDecay = Rates(fullness: -0.02, happiness: -0.01, energy: 0.10, cleanliness: -0.01)

    /// Below this energy, a daytime nap starts; it ends once energy is back above `napWakeEnergy`.
    static let napStartEnergy = 0.12
    static let napWakeEnergy = 0.85

    /// Simulation step. Small enough that sleep/nap boundaries land within a few minutes.
    static let step: TimeInterval = 5 * 60
    /// Absences longer than this are simulated as if they were this long; stats bottom out well before.
    static let maxSimulated: TimeInterval = 14 * 24 * 3600

    /// How long a care action keeps showing its reaction (eating, playing...).
    public static let reactionDuration: TimeInterval = 10 * 60
}

struct Rates {
    var fullness: Double
    var happiness: Double
    var energy: Double
    var cleanliness: Double
}

public enum DayCycle {
    public static let bedtimeHour = 22
    public static let wakeHour = 7

    public static func isNight(_ date: Date, calendar: Calendar = .current) -> Bool {
        let hour = calendar.component(.hour, from: date)
        return hour >= bedtimeHour || hour < wakeHour
    }

    /// Next morning wake-up time at or after `date`.
    public static func nextWake(after date: Date, calendar: Calendar = .current) -> Date {
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = wakeHour
        let todayWake = calendar.date(from: components) ?? date
        if todayWake > date { return todayWake }
        return calendar.date(byAdding: .day, value: 1, to: todayWake) ?? date
    }
}

public enum ActionOutcome: Equatable, Sendable {
    case done(String)
    case refused(String)

    public var message: String {
        switch self {
        case .done(let m), .refused(let m): return m
        }
    }

    public var succeeded: Bool {
        if case .done = self { return true }
        return false
    }
}

extension PetState {
    /// Returns the state as it will be at `date`, letting time pass in small steps.
    public func advanced(to date: Date, calendar: Calendar = .current) -> PetState {
        var copy = self
        copy.advance(to: date, calendar: calendar)
        return copy
    }

    public mutating func advance(to date: Date, calendar: Calendar = .current) {
        // Ignore clocks moving backwards; the next real update catches up.
        guard date > lastUpdate else { return }
        var t = max(lastUpdate, date.addingTimeInterval(-Rules.maxSimulated))
        lastUpdate = t
        while t < date {
            let next = min(date, t.addingTimeInterval(Rules.step))
            tick(from: t, to: next, calendar: calendar)
            t = next
        }
        lastUpdate = date
    }

    private mutating func tick(from start: Date, to end: Date, calendar: Calendar) {
        let dt = end.timeIntervalSince(start)
        let hours = dt / 3600

        if stage != .egg {
            let night = DayCycle.isNight(start, calendar: calendar)
            if night { isNapping = false }
            let asleep = night || isNapping
            let rates = asleep ? Rules.asleepDecay : Rules.awakeDecay
            fullness = clamp(fullness + rates.fullness * hours)
            happiness = clamp(happiness + rates.happiness * hours)
            energy = clamp(energy + rates.energy * hours)
            cleanliness = clamp(cleanliness + rates.cleanliness * hours)

            if !night {
                if !isNapping && energy < Rules.napStartEnergy { isNapping = true }
                else if isNapping && energy >= Rules.napWakeEnergy { isNapping = false }
            }

            care.wellbeingSeconds += wellbeing * dt
            care.trackedSeconds += dt
        }

        updateStage(at: end)
    }

    private mutating func updateStage(at date: Date) {
        let age = self.age(at: date)
        let target: Stage
        if age >= Rules.adultAfter { target = .adult }
        else if age >= Rules.childAfter { target = .child }
        else if age >= Rules.hatchAfter { target = .baby }
        else { target = .egg }

        guard target != stage else { return }
        stage = target
        lastEvolutionDate = date
        if target == .adult && adultForm == nil {
            adultForm = Evolution.adultForm(for: care)
        }
    }

    /// Applies a care action at `date`, after catching up on elapsed time.
    @discardableResult
    public mutating func perform(_ action: CareAction, at date: Date = Date(), calendar: Calendar = .current) -> ActionOutcome {
        advance(to: date, calendar: calendar)

        if stage == .egg {
            guard action == .pet else { return .refused("It's still an egg. Try petting it!") }
            recordAction(action, at: date)
            return .done("The egg wiggles happily.")
        }

        if isAsleep(calendar: calendar) {
            guard action == .pet else { return .refused("Shh… \(name) is sleeping.") }
            happiness = clamp(happiness + 0.05)
            recordAction(action, at: date)
            return .done("\(name) smiles in their sleep.")
        }

        switch action {
        case .feed:
            if fullness > 0.95 { return .refused("\(name) is too full to eat.") }
            fullness = clamp(fullness + 0.35)
            happiness = clamp(happiness + 0.03)
            cleanliness = clamp(cleanliness - 0.03)
            recordAction(action, at: date)
            return .done("Yum! \(name) munches happily.")
        case .play:
            if energy < 0.15 { return .refused("\(name) is too tired to play.") }
            happiness = clamp(happiness + 0.25)
            energy = clamp(energy - 0.12)
            fullness = clamp(fullness - 0.05)
            cleanliness = clamp(cleanliness - 0.05)
            recordAction(action, at: date)
            return .done("\(name) chases the ball!")
        case .pet:
            happiness = clamp(happiness + 0.1)
            recordAction(action, at: date)
            return .done("\(name) loves that.")
        case .clean:
            if cleanliness > 0.95 { return .refused("\(name) is already squeaky clean.") }
            cleanliness = 1
            happiness = clamp(happiness + 0.03)
            recordAction(action, at: date)
            return .done("Splish splash! All clean.")
        }
    }

    /// Rewards a finished mini-game. `score` is the number of treats caught.
    @discardableResult
    public mutating func applyGameResult(score: Int, at date: Date = Date(), calendar: Calendar = .current) -> ActionOutcome {
        advance(to: date, calendar: calendar)
        guard stage != .egg, !isAsleep(calendar: calendar) else {
            return .refused("\(name) can't play right now.")
        }
        happiness = clamp(happiness + min(0.45, 0.1 + Double(score) * 0.02))
        energy = clamp(energy - 0.12)
        fullness = clamp(fullness - 0.06 + min(0.15, Double(score) * 0.005))
        recordAction(.play, at: date)
        return .done("\(name) had a blast! Caught \(score) treats.")
    }

    /// Starts a nap early, e.g. when tucked in from the app.
    @discardableResult
    public mutating func tuckIn(at date: Date = Date(), calendar: Calendar = .current) -> ActionOutcome {
        advance(to: date, calendar: calendar)
        guard stage != .egg else { return .refused("Eggs don't need tucking in.") }
        if isAsleep(calendar: calendar) { return .refused("\(name) is already asleep.") }
        if energy > 0.6 { return .refused("\(name) isn't sleepy yet.") }
        isNapping = true
        return .done("\(name) curls up for a nap.")
    }

    private mutating func recordAction(_ action: CareAction, at date: Date) {
        care.record(action)
        lastAction = action
        lastActionDate = date
    }

    /// The action whose reaction should still be visible at `date`.
    public func recentAction(at date: Date) -> CareAction? {
        guard let action = lastAction, let when = lastActionDate else { return nil }
        let elapsed = date.timeIntervalSince(when)
        return (0..<Rules.reactionDuration).contains(elapsed) ? action : nil
    }
}

@inline(__always)
func clamp(_ value: Double) -> Double { min(1, max(0, value)) }
