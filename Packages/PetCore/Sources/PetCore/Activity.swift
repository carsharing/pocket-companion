import Foundation

/// What the companion is visibly doing at a moment. The widget can't animate continuously,
/// so it changes activity every few minutes to look alive.
public enum Activity: String, Codable, CaseIterable, Sendable {
    case idle, bouncing, ball, butterfly, lookingAround, dancing
    case eating, bathing, beingPetted
    case sleeping, sulking, wobbling

    public var caption: String {
        switch self {
        case .idle: return "Hanging out"
        case .bouncing: return "Bouncing around"
        case .ball: return "Playing with a ball"
        case .butterfly: return "Watching a butterfly"
        case .lookingAround: return "Looking around"
        case .dancing: return "Dancing"
        case .eating: return "Munching"
        case .bathing: return "Bath time"
        case .beingPetted: return "Enjoying cuddles"
        case .sleeping: return "Fast asleep"
        case .sulking: return "Waiting for you"
        case .wobbling: return "Wobbling"
        }
    }
}

public enum Forecast {
    /// Length of one widget "scene". Activities change on these boundaries.
    public static let slot: TimeInterval = 15 * 60

    public static func activity(for state: PetState, at date: Date, calendar: Calendar = .current) -> Activity {
        if state.stage == .egg { return .wobbling }
        if state.isAsleep(calendar: calendar) { return .sleeping }

        if let recent = state.recentAction(at: date) {
            switch recent {
            case .feed: return .eating
            case .play: return .ball
            case .pet: return .beingPetted
            case .clean: return .bathing
            }
        }

        switch state.mood(calendar: calendar) {
        case .hungry, .dirty, .sad, .tired: return .sulking
        default: break
        }

        var options: [Activity] = [.idle, .bouncing, .ball, .butterfly, .lookingAround]
        if state.mood(calendar: calendar) == .happy { options.append(.dancing) }
        let slotIndex = UInt64(max(0, date.timeIntervalSince1970 / slot))
        return options[Int(mix(slotIndex) % UInt64(options.count))]
    }

    /// Predicted states for the widget timeline, one per `interval`, starting at `start`.
    public static func timeline(
        from state: PetState,
        start: Date,
        count: Int,
        interval: TimeInterval = slot,
        calendar: Calendar = .current
    ) -> [(date: Date, state: PetState)] {
        var current = state.advanced(to: start, calendar: calendar)
        var result: [(date: Date, state: PetState)] = [(start, current)]
        var t = start
        for _ in 1..<max(1, count) {
            t = t.addingTimeInterval(interval)
            current.advance(to: t, calendar: calendar)
            result.append((t, current))
        }
        return result
    }

    /// Start of the slot containing `date`, so timeline entries line up with activity changes.
    public static func slotStart(for date: Date) -> Date {
        let seconds = (date.timeIntervalSince1970 / slot).rounded(.down) * slot
        return Date(timeIntervalSince1970: seconds)
    }

    /// SplitMix64 finaliser, so neighbouring slots pick unrelated activities.
    static func mix(_ value: UInt64) -> UInt64 {
        var z = value &+ 0x9E37_79B9_7F4A_7C15
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// Upcoming moments worth a gentle notification.
public struct CareReminder: Equatable, Sendable {
    public enum Kind: String, Sendable { case hungry, lonely, dirty, evolving }
    public var kind: Kind
    public var date: Date
}

public enum ReminderPlanner {
    /// Finds the first awake moment within `horizon` when each need becomes pressing,
    /// plus the next evolution.
    public static func upcoming(
        for state: PetState,
        from now: Date,
        horizon: TimeInterval = 36 * 3600,
        calendar: Calendar = .current
    ) -> [CareReminder] {
        var reminders: [CareReminder] = []
        var pending: Set<CareReminder.Kind> = [.hungry, .lonely, .dirty]
        var current = state.advanced(to: now, calendar: calendar)

        // Only warn about needs that aren't already pressing; those were notified before or are on screen.
        if current.fullness < 0.25 { pending.remove(.hungry) }
        if current.happiness < 0.3 { pending.remove(.lonely) }
        if current.cleanliness < 0.25 { pending.remove(.dirty) }

        var t = now
        let end = now.addingTimeInterval(horizon)
        while t < end, !pending.isEmpty {
            t = t.addingTimeInterval(10 * 60)
            current.advance(to: t, calendar: calendar)
            guard current.stage != .egg, !current.isAsleep(calendar: calendar) else { continue }
            if pending.contains(.hungry), current.fullness < 0.25 {
                reminders.append(CareReminder(kind: .hungry, date: t)); pending.remove(.hungry)
            }
            if pending.contains(.lonely), current.happiness < 0.3 {
                reminders.append(CareReminder(kind: .lonely, date: t)); pending.remove(.lonely)
            }
            if pending.contains(.dirty), current.cleanliness < 0.25 {
                reminders.append(CareReminder(kind: .dirty, date: t)); pending.remove(.dirty)
            }
        }

        if let next = Evolution.nextStageDate(for: state), next.1 > now, next.1 < end {
            let date = next.1
            // Don't wake anyone up for it; announce in the morning instead.
            let announce = DayCycle.isNight(date, calendar: calendar) ? DayCycle.nextWake(after: date, calendar: calendar) : date
            reminders.append(CareReminder(kind: .evolving, date: announce))
        }
        return reminders.sorted { $0.date < $1.date }
    }
}
