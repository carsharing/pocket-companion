import Combine
import Foundation
import PetCore
import WidgetKit

@MainActor
final class CompanionModel: ObservableObject {
    @Published private(set) var state: PetState
    @Published var toast: String?
    /// A stage the player hasn't seen yet, shown as a celebration.
    @Published var celebration: Stage?

    private let store = PetStore.shared
    private var ticker: AnyCancellable?
    private var toastTask: Task<Void, Never>?
    private static let seenStageKey = "lastSeenStage"

    init() {
        let initial = PetStore.shared.update { _ in ActionOutcome.done("") }.0
        state = initial.advanced(to: Date())
        if store.defaults.string(forKey: Self.seenStageKey) == nil {
            store.defaults.set(initial.stage.rawValue, forKey: Self.seenStageKey)
        }
        ticker = Timer.publish(every: 20, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.refresh() }
        checkCelebration()
    }

    var isWidgetSyncAvailable: Bool { store.isShared }

    var notificationsEnabled: Bool {
        get { store.notificationsEnabled }
        set {
            objectWillChange.send()
            store.notificationsEnabled = newValue
            ReminderScheduler.reschedule(for: state)
        }
    }

    /// Catches the on-screen state up with time and with anything the widget did.
    func refresh() {
        state = store.current()
        checkCelebration()
    }

    func perform(_ action: CareAction) {
        let (newState, outcome) = Companion.perform(action)
        apply(newState, outcome)
    }

    func finishGame(score: Int) {
        let (newState, outcome) = Companion.commit { $0.applyGameResult(score: score) }
        apply(newState, outcome)
    }

    func tuckIn() {
        let (newState, outcome) = Companion.commit { $0.tuckIn() }
        apply(newState, outcome)
    }

    func rename(to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let (newState, _) = Companion.commit { state in
            state.name = String(trimmed.prefix(20))
            return .done("")
        }
        state = newState.advanced(to: Date())
    }

    /// Starts over with a fresh egg, keeping the name.
    func startOver() {
        let fresh = PetState(name: state.name)
        store.save(fresh)
        store.defaults.set(Stage.egg.rawValue, forKey: Self.seenStageKey)
        WidgetCenter.shared.reloadAllTimelines()
        ReminderScheduler.reschedule(for: fresh)
        state = fresh
        celebration = nil
    }

    func dismissCelebration() {
        store.defaults.set(state.stage.rawValue, forKey: Self.seenStageKey)
        celebration = nil
    }

    private func apply(_ newState: PetState, _ outcome: ActionOutcome) {
        state = newState
        show(outcome.message)
        checkCelebration()
    }

    private func checkCelebration() {
        let seen = store.defaults.string(forKey: Self.seenStageKey)
        if seen != state.stage.rawValue && celebration == nil {
            celebration = state.stage
        }
    }

    private func show(_ message: String) {
        guard !message.isEmpty else { return }
        toast = message
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            guard !Task.isCancelled else { return }
            self?.toast = nil
        }
    }
}
