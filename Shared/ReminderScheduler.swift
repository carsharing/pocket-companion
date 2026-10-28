import Foundation
import PetCore
import UserNotifications

/// Schedules gentle local notifications for upcoming needs. Rescheduled after every change,
/// so at most one reminder of each kind is ever pending.
enum ReminderScheduler {
    private static let kinds: [CareReminder.Kind] = [.hungry, .lonely, .dirty, .evolving]

    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func reschedule(for state: PetState, now: Date = Date()) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: kinds.map { "reminder.\($0.rawValue)" })
        guard PetStore.shared.notificationsEnabled else { return }

        for reminder in ReminderPlanner.upcoming(for: state, from: now) {
            let content = UNMutableNotificationContent()
            content.title = state.name
            content.body = message(for: reminder.kind, state: state)
            content.sound = .default
            let delay = max(60, reminder.date.timeIntervalSince(now))
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
            center.add(UNNotificationRequest(identifier: "reminder.\(reminder.kind.rawValue)", content: content, trigger: trigger))
        }
    }

    private static func message(for kind: CareReminder.Kind, state: PetState) -> String {
        switch kind {
        case .hungry: return "My tummy is rumbling… could I have a snack? 🍙"
        case .lonely: return "I miss you! Come play with me? 🥺"
        case .dirty: return "I'm getting a bit grubby. Bath time? 🫧"
        case .evolving:
            switch state.stage {
            case .egg: return "\(state.name) is stretching… they are about to wake up! 🦊"
            case .baby: return "\(state.name) is growing up! Come see 🦊"
            default: return "\(state.name) is changing… come see who they've become! ✨"
            }
        }
    }
}
