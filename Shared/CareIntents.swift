import AppIntents
import PetCore
import WidgetKit

/// The one place care actions go through, from the app or from widget buttons.
enum Companion {
    static let widgetKind = "CompanionWidget"

    @discardableResult
    static func perform(_ action: CareAction, at date: Date = Date()) -> (PetState, ActionOutcome) {
        commit { $0.perform(action, at: date) }
    }

    /// Applies a change to the stored companion, then refreshes widgets and reminders.
    @discardableResult
    static func commit(_ change: (inout PetState) -> ActionOutcome) -> (PetState, ActionOutcome) {
        let (state, outcome) = PetStore.shared.update(change)
        WidgetCenter.shared.reloadAllTimelines()
        ReminderScheduler.reschedule(for: state)
        return (state, outcome)
    }
}

// Widget buttons need one intent type per action. Each is compiled into both the app and the
// widget extension so iOS can run it in either process.

struct FeedIntent: AppIntent {
    static var title: LocalizedStringResource = "Feed your companion"
    static var isDiscoverable = false
    func perform() async throws -> some IntentResult {
        Companion.perform(.feed)
        return .result()
    }
}

struct PlayIntent: AppIntent {
    static var title: LocalizedStringResource = "Play with your companion"
    static var isDiscoverable = false
    func perform() async throws -> some IntentResult {
        Companion.perform(.play)
        return .result()
    }
}

struct PetIntent: AppIntent {
    static var title: LocalizedStringResource = "Pet your companion"
    static var isDiscoverable = false
    func perform() async throws -> some IntentResult {
        Companion.perform(.pet)
        return .result()
    }
}

struct CleanIntent: AppIntent {
    static var title: LocalizedStringResource = "Give your companion a bath"
    static var isDiscoverable = false
    func perform() async throws -> some IntentResult {
        Companion.perform(.clean)
        return .result()
    }
}
