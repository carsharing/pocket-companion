import Foundation

/// Life stages. The companion always moves forward and never dies.
public enum Stage: String, Codable, CaseIterable, Sendable {
    case egg, baby, child, adult

    public var displayName: String {
        switch self {
        case .egg: return "Egg"
        case .baby: return "Baby"
        case .child: return "Child"
        case .adult: return "Adult"
        }
    }
}

/// The adult a child grows into depends on how it was cared for.
public enum AdultForm: String, Codable, CaseIterable, Sendable {
    /// Balanced, attentive care.
    case sprout
    /// Played with a lot.
    case bouncy
    /// Fed a lot.
    case gourmet
    /// Petted a lot while kept very happy.
    case sparkle
    /// Left alone a lot. Still cute, just dreamy.
    case cloud

    public var displayName: String {
        switch self {
        case .sprout: return "Sprout"
        case .bouncy: return "Bouncy"
        case .gourmet: return "Gourmet"
        case .sparkle: return "Sparkle"
        case .cloud: return "Cloud"
        }
    }

    public var blurb: String {
        switch self {
        case .sprout: return "Raised with balanced, steady care. Grew a little leaf!"
        case .bouncy: return "So many games together. Can't stop hopping."
        case .gourmet: return "Loves snacks more than anything."
        case .sparkle: return "Showered with affection. Glows with joy."
        case .cloud: return "Spent a lot of time alone, daydreaming."
        }
    }
}

public enum Mood: String, Codable, CaseIterable, Sendable {
    case sleeping, hungry, dirty, sad, tired, happy, content, egg

    public var label: String {
        switch self {
        case .sleeping: return "Sleeping"
        case .hungry: return "Hungry"
        case .dirty: return "Needs a bath"
        case .sad: return "Lonely"
        case .tired: return "Sleepy"
        case .happy: return "Happy"
        case .content: return "Content"
        case .egg: return "Warm and cozy"
        }
    }

    public var emoji: String {
        switch self {
        case .sleeping: return "💤"
        case .hungry: return "🍙"
        case .dirty: return "🫧"
        case .sad: return "🥺"
        case .tired: return "🥱"
        case .happy: return "💖"
        case .content: return "🙂"
        case .egg: return "🥚"
        }
    }
}

public enum CareAction: String, Codable, CaseIterable, Sendable {
    case feed, play, pet, clean

    public var verb: String {
        switch self {
        case .feed: return "Feed"
        case .play: return "Play"
        case .pet: return "Pet"
        case .clean: return "Bath"
        }
    }

    public var systemImage: String {
        switch self {
        case .feed: return "fork.knife"
        case .play: return "soccerball"
        case .pet: return "hand.wave.fill"
        case .clean: return "bubbles.and.sparkles.fill"
        }
    }
}

/// Running record of how the companion was cared for, used to pick its adult form.
public struct CareLog: Codable, Equatable, Sendable {
    public var feeds: Int = 0
    public var plays: Int = 0
    public var pets: Int = 0
    public var cleans: Int = 0
    /// Time integral of wellbeing (0...1) since hatching, in seconds.
    public var wellbeingSeconds: Double = 0
    public var trackedSeconds: Double = 0

    public init() {}

    public var averageWellbeing: Double {
        trackedSeconds > 0 ? wellbeingSeconds / trackedSeconds : 0.7
    }

    mutating func record(_ action: CareAction) {
        switch action {
        case .feed: feeds += 1
        case .play: plays += 1
        case .pet: pets += 1
        case .clean: cleans += 1
        }
    }
}

public struct PetState: Codable, Equatable, Sendable {
    public var name: String
    public var birthDate: Date
    /// The moment the stats below describe.
    public var lastUpdate: Date

    // All stats range 0...1, higher is better.
    public var fullness: Double
    public var happiness: Double
    public var energy: Double
    public var cleanliness: Double

    /// A daytime nap triggered by running out of energy.
    public var isNapping: Bool
    public var stage: Stage
    public var adultForm: AdultForm?
    /// Body colour hue (0...1), picked at birth.
    public var hue: Double
    public var care: CareLog
    public var lastAction: CareAction?
    public var lastActionDate: Date?
    /// When the most recent stage change happened, for celebrations.
    public var lastEvolutionDate: Date?

    public init(name: String = "Mochi", birthDate: Date = Date(), hue: Double = Double.random(in: 0...1)) {
        self.name = name
        self.birthDate = birthDate
        self.lastUpdate = birthDate
        self.fullness = 0.8
        self.happiness = 0.8
        self.energy = 0.9
        self.cleanliness = 1
        self.isNapping = false
        self.stage = .egg
        self.adultForm = nil
        self.hue = hue
        self.care = CareLog()
        self.lastAction = nil
        self.lastActionDate = nil
        self.lastEvolutionDate = nil
    }

    public var wellbeing: Double {
        (fullness + happiness + energy + cleanliness) / 4
    }

    public func age(at date: Date) -> TimeInterval {
        max(0, date.timeIntervalSince(birthDate))
    }

    public func isAsleep(calendar: Calendar = .current) -> Bool {
        stage != .egg && (DayCycle.isNight(lastUpdate, calendar: calendar) || isNapping)
    }

    public func mood(calendar: Calendar = .current) -> Mood {
        if stage == .egg { return .egg }
        if isAsleep(calendar: calendar) { return .sleeping }
        if fullness < 0.25 { return .hungry }
        if cleanliness < 0.25 { return .dirty }
        if happiness < 0.3 { return .sad }
        if energy < 0.2 { return .tired }
        if wellbeing > 0.7 && happiness > 0.65 { return .happy }
        return .content
    }

    /// The most pressing need, if any, for short status text.
    public func topNeed(calendar: Calendar = .current) -> CareAction? {
        guard stage != .egg, !isAsleep(calendar: calendar) else { return nil }
        let needs: [(CareAction, Double)] = [
            (.feed, fullness), (.clean, cleanliness), (.play, happiness),
        ]
        guard let lowest = needs.min(by: { $0.1 < $1.1 }), lowest.1 < 0.5 else { return nil }
        return lowest.0
    }
}
