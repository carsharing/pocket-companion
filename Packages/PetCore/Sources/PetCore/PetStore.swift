import Foundation

/// Persists the companion where both the app and the widget can see it.
///
/// Sideloading tools re-sign the app and may rename the App Group, so the group id is
/// looked up at runtime from several Info.plist keys and verified before use.
public final class PetStore: @unchecked Sendable {
    public static let shared = PetStore()

    private static let stateKey = "petState.v1"
    private static let notificationsKey = "notificationsEnabled"

    public let defaults: UserDefaults
    /// The App Group in use, or nil when falling back to app-only storage.
    public let appGroup: String?
    private let lock = NSLock()

    public init(defaults: UserDefaults, appGroup: String?) {
        self.defaults = defaults
        self.appGroup = appGroup
    }

    private convenience init() {
        if let group = PetStore.resolveAppGroup(), let suite = UserDefaults(suiteName: group) {
            self.init(defaults: suite, appGroup: group)
        } else {
            self.init(defaults: .standard, appGroup: nil)
        }
    }

    /// True when the widget and the app share storage.
    public var isShared: Bool { appGroup != nil }

    public static func resolveAppGroup(bundle: Bundle = .main) -> String? {
        var candidates: [String] = []
        // AltStore rewrites groups and lists the new ids here.
        if let alt = bundle.object(forInfoDictionaryKey: "ALTAppGroups") as? [String] { candidates += alt }
        if let own = bundle.object(forInfoDictionaryKey: "PCAppGroup") as? String { candidates.append(own) }
        return candidates.first { id in
            FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id) != nil
        }
    }

    public func load() -> PetState? {
        lock.lock(); defer { lock.unlock() }
        guard let data = defaults.data(forKey: Self.stateKey) else { return nil }
        return try? JSONDecoder().decode(PetState.self, from: data)
    }

    public func save(_ state: PetState) {
        lock.lock(); defer { lock.unlock() }
        if let data = try? JSONEncoder().encode(state) {
            defaults.set(data, forKey: Self.stateKey)
        }
    }

    /// Loads (creating a fresh egg on first run), applies `change`, saves, and returns the result.
    @discardableResult
    public func update<T>(_ change: (inout PetState) -> T) -> (PetState, T) {
        var state = load() ?? PetState()
        let result = change(&state)
        save(state)
        return (state, result)
    }

    /// Current state caught up to `date`, without saving.
    public func current(at date: Date = Date()) -> PetState {
        (load() ?? PetState()).advanced(to: date)
    }

    public var notificationsEnabled: Bool {
        get { defaults.object(forKey: Self.notificationsKey) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Self.notificationsKey) }
    }
}
