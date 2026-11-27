import Foundation

// MARK: - Declarative mode settings

/// One configurable setting of a `StillGameMode`.
///
/// The host builds an inset-grouped settings list from a mode's `[StillSetting]`, applies
/// every change live (no Save button), and persists values on the device in `UserDefaults`.
public struct StillSetting: Sendable {
    enum Kind: Sendable {
        case toggle(defaultValue: Bool)
        case choice(options: [String], defaultValue: String)
        case stepper(range: ClosedRange<Int>, step: Int, defaultValue: Int)
        case slider(range: ClosedRange<Double>, step: Double?, defaultValue: Double,
                    valueLabel: (@Sendable (Double) -> String)?)
    }

    public let key: String
    public let title: String
    let kind: Kind

    private init(key: String, title: String, kind: Kind) {
        self.key = key
        self.title = title
        self.kind = kind
    }

    /// A boolean switch.
    public static func toggle(_ title: String, key: String, default defaultValue: Bool) -> StillSetting {
        StillSetting(key: key, title: title, kind: .toggle(defaultValue: defaultValue))
    }

    /// One selection from a fixed list of titled options.
    public static func choice(_ title: String, key: String, options: [String],
                              default defaultValue: String) -> StillSetting {
        StillSetting(key: key, title: title, kind: .choice(options: options, defaultValue: defaultValue))
    }

    /// A whole-number stepper within `range`.
    public static func stepper(_ title: String, key: String, range: ClosedRange<Int>,
                               step: Int = 1, default defaultValue: Int) -> StillSetting {
        let safeStep = max(1, step)
        let clamped = min(max(defaultValue, range.lowerBound), range.upperBound)
        return StillSetting(key: key, title: title,
                            kind: .stepper(range: range, step: safeStep, defaultValue: clamped))
    }

    /// A slider within `range`. Pass `step` (for example `1`) for discrete increments.
    public static func slider(_ title: String, key: String, range: ClosedRange<Double>,
                              step: Double? = nil, default defaultValue: Double,
                              valueLabel: (@Sendable (Double) -> String)? = nil) -> StillSetting {
        let clamped = min(max(defaultValue, range.lowerBound), range.upperBound)
        return StillSetting(key: key, title: title,
                            kind: .slider(range: range, step: step, defaultValue: clamped, valueLabel: valueLabel))
    }

    func formattedSliderValue(_ value: Double) -> String {
        guard case .slider(_, let step, _, let label) = kind else { return "\(value)" }
        if let label { return label(value) }
        if let step, step >= 1, step.rounded() == step {
            return "\(Int(value.rounded()))"
        }
        return String(format: "%.2f", value)
    }

    func snappedSliderValue(_ raw: Double) -> Double {
        guard case .slider(let range, let step, _, _) = kind else { return raw }
        var value = min(max(raw, range.lowerBound), range.upperBound)
        if let step, step > 0 {
            let steps = ((value - range.lowerBound) / step).rounded()
            value = range.lowerBound + steps * step
            value = min(max(value, range.lowerBound), range.upperBound)
        }
        return value
    }
}

// MARK: - Persistence store (internal)

final class StillSettingsStore {
    static let selectedModeKey = "StillKit.selectedMode"

    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    static func storageKey(modeID: String, settingKey: String) -> String {
        "StillKit.mode.\(modeID).\(settingKey)"
    }

    var selectedModeID: String? {
        get { defaults.string(forKey: Self.selectedModeKey) }
        set {
            if let newValue {
                defaults.set(newValue, forKey: Self.selectedModeKey)
            } else {
                defaults.removeObject(forKey: Self.selectedModeKey)
            }
        }
    }

    func bool(for setting: StillSetting, modeID: String) -> Bool {
        let key = Self.storageKey(modeID: modeID, settingKey: setting.key)
        if defaults.object(forKey: key) != nil {
            return defaults.bool(forKey: key)
        }
        if case .toggle(let defaultValue) = setting.kind { return defaultValue }
        return false
    }

    func setBool(_ value: Bool, key settingKey: String, modeID: String) {
        defaults.set(value, forKey: Self.storageKey(modeID: modeID, settingKey: settingKey))
    }

    func string(for setting: StillSetting, modeID: String) -> String {
        let key = Self.storageKey(modeID: modeID, settingKey: setting.key)
        if case .choice(let options, let defaultValue) = setting.kind {
            if let stored = defaults.string(forKey: key), options.contains(stored) {
                return stored
            }
            return defaultValue
        }
        return defaults.string(forKey: key) ?? ""
    }

    func setString(_ value: String, key settingKey: String, modeID: String) {
        defaults.set(value, forKey: Self.storageKey(modeID: modeID, settingKey: settingKey))
    }

    func int(for setting: StillSetting, modeID: String) -> Int {
        let key = Self.storageKey(modeID: modeID, settingKey: setting.key)
        switch setting.kind {
        case .stepper(let range, _, let defaultValue):
            if let stored = defaults.object(forKey: key) as? NSNumber {
                return min(max(stored.intValue, range.lowerBound), range.upperBound)
            }
            return defaultValue
        case .slider(let range, _, let defaultValue, _):
            let raw = (defaults.object(forKey: key) as? NSNumber)?.doubleValue ?? defaultValue
            let clamped = min(max(raw, range.lowerBound), range.upperBound)
            return Int(setting.snappedSliderValue(clamped).rounded())
        default:
            return defaults.integer(forKey: key)
        }
    }

    func setInt(_ value: Int, key settingKey: String, modeID: String) {
        defaults.set(value, forKey: Self.storageKey(modeID: modeID, settingKey: settingKey))
    }

    func double(for setting: StillSetting, modeID: String) -> Double {
        let key = Self.storageKey(modeID: modeID, settingKey: setting.key)
        switch setting.kind {
        case .slider(let range, _, let defaultValue, _):
            if let stored = defaults.object(forKey: key) as? NSNumber {
                let clamped = min(max(stored.doubleValue, range.lowerBound), range.upperBound)
                return setting.snappedSliderValue(clamped)
            }
            return defaultValue
        case .stepper(let range, _, let defaultValue):
            if let stored = defaults.object(forKey: key) as? NSNumber {
                return Double(min(max(stored.intValue, range.lowerBound), range.upperBound))
            }
            return Double(defaultValue)
        default:
            return defaults.double(forKey: key)
        }
    }

    func setDouble(_ value: Double, key settingKey: String, modeID: String) {
        defaults.set(value, forKey: Self.storageKey(modeID: modeID, settingKey: settingKey))
    }
}

// MARK: - Settings reader (public)

/// Reads persisted values for one `StillGameMode`.
///
/// Accessed via `context.settings` inside a mode. Always returns a value within the
/// setting's declared range or options, falling back to its default.
public final class StillSettingsReader {
    private let modeID: String
    private let settingsByKey: [String: StillSetting]
    private let store: StillSettingsStore

    init(modeID: String, settings: [StillSetting], store: StillSettingsStore) {
        self.modeID = modeID
        var map: [String: StillSetting] = [:]
        map.reserveCapacity(settings.count)
        for setting in settings {
            if map[setting.key] != nil {
                assertionFailure("StillKit: duplicate setting key '\(setting.key)' for mode '\(modeID)'")
                continue
            }
            map[setting.key] = setting
        }
        self.settingsByKey = map
        self.store = store
    }

    public func bool(_ key: String) -> Bool {
        guard let setting = setting(for: key) else { return false }
        return store.bool(for: setting, modeID: modeID)
    }

    public func string(_ key: String) -> String {
        guard let setting = setting(for: key) else { return "" }
        return store.string(for: setting, modeID: modeID)
    }

    public func int(_ key: String) -> Int {
        guard let setting = setting(for: key) else { return 0 }
        return store.int(for: setting, modeID: modeID)
    }

    public func double(_ key: String) -> Double {
        guard let setting = setting(for: key) else { return 0 }
        return store.double(for: setting, modeID: modeID)
    }

    private func setting(for key: String) -> StillSetting? {
        guard let setting = settingsByKey[key] else {
            assertionFailure("StillKit: unknown setting key '\(key)' for mode '\(modeID)'")
            return nil
        }
        return setting
    }
}

// MARK: - Storage migration (public)

/// One-time migration helper from an existing app's legacy `UserDefaults` keys into
/// StillKit's storage.
///
/// Every method is idempotent: if StillKit already has a saved value at the destination key,
/// it is never overwritten. Once copied, the legacy key is removed.
public struct StillStorageMigration {
    private let store: StillSettingsStore

    init(store: StillSettingsStore) {
        self.store = store
    }

    /// Migrates the saved selected mode identifier from `legacyKey`.
    /// Pass `map` if the mode's identifier changed during adoption.
    public func migrateSelectedMode(fromLegacyKey legacyKey: String,
                                    map: (String) -> String? = { $0 }) {
        guard store.selectedModeID == nil,
              let legacy = store.defaults.string(forKey: legacyKey) else { return }
        if let mapped = map(legacy) {
            store.selectedModeID = mapped
        }
        store.defaults.removeObject(forKey: legacyKey)
    }

    /// Migrates a boolean setting from `legacyKey`.
    public func migrateBool(fromLegacyKey legacyKey: String, toMode modeID: String, settingKey: String) {
        migrateValue(fromLegacyKey: legacyKey, toMode: modeID, settingKey: settingKey) { defaults in
            defaults.object(forKey: legacyKey) != nil ? defaults.bool(forKey: legacyKey) : nil
        }
    }

    /// Migrates a string setting from `legacyKey`.
    public func migrateString(fromLegacyKey legacyKey: String, toMode modeID: String, settingKey: String) {
        migrateValue(fromLegacyKey: legacyKey, toMode: modeID, settingKey: settingKey) { defaults in
            defaults.string(forKey: legacyKey)
        }
    }

    /// Migrates an integer setting from `legacyKey`. Works for both `.stepper` and integer `.slider` settings.
    public func migrateInt(fromLegacyKey legacyKey: String, toMode modeID: String, settingKey: String) {
        migrateValue(fromLegacyKey: legacyKey, toMode: modeID, settingKey: settingKey) { defaults in
            (defaults.object(forKey: legacyKey) as? NSNumber)?.intValue
        }
    }

    /// Migrates a floating-point setting from `legacyKey`.
    public func migrateDouble(fromLegacyKey legacyKey: String, toMode modeID: String, settingKey: String) {
        migrateValue(fromLegacyKey: legacyKey, toMode: modeID, settingKey: settingKey) { defaults in
            (defaults.object(forKey: legacyKey) as? NSNumber)?.doubleValue
        }
    }

    private func migrateValue(fromLegacyKey legacyKey: String, toMode modeID: String,
                              settingKey: String, read: (UserDefaults) -> Any?) {
        let destination = StillSettingsStore.storageKey(modeID: modeID, settingKey: settingKey)
        guard store.defaults.object(forKey: destination) == nil,
              let value = read(store.defaults) else { return }
        store.defaults.set(value, forKey: destination)
        store.defaults.removeObject(forKey: legacyKey)
    }
}
