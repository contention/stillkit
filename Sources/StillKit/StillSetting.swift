import UIKit

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
        self.settingsByKey = Dictionary(uniqueKeysWithValues: settings.map { ($0.key, $0) })
        self.store = store
    }

    public func bool(_ key: String) -> Bool {
        guard let setting = settingsByKey[key] else {
            assertionFailure("StillKit: unknown setting key '\(key)' for mode '\(modeID)'")
            return false
        }
        return store.bool(for: setting, modeID: modeID)
    }

    public func string(_ key: String) -> String {
        guard let setting = settingsByKey[key] else {
            assertionFailure("StillKit: unknown setting key '\(key)' for mode '\(modeID)'")
            return ""
        }
        return store.string(for: setting, modeID: modeID)
    }

    public func int(_ key: String) -> Int {
        guard let setting = settingsByKey[key] else {
            assertionFailure("StillKit: unknown setting key '\(key)' for mode '\(modeID)'")
            return 0
        }
        return store.int(for: setting, modeID: modeID)
    }

    public func double(_ key: String) -> Double {
        guard let setting = settingsByKey[key] else {
            assertionFailure("StillKit: unknown setting key '\(key)' for mode '\(modeID)'")
            return 0
        }
        return store.double(for: setting, modeID: modeID)
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
        let destination = StillSettingsStore.storageKey(modeID: modeID, settingKey: settingKey)
        guard store.defaults.object(forKey: destination) == nil,
              store.defaults.object(forKey: legacyKey) != nil else { return }
        store.defaults.set(store.defaults.bool(forKey: legacyKey), forKey: destination)
        store.defaults.removeObject(forKey: legacyKey)
    }

    /// Migrates a string setting from `legacyKey`.
    public func migrateString(fromLegacyKey legacyKey: String, toMode modeID: String, settingKey: String) {
        let destination = StillSettingsStore.storageKey(modeID: modeID, settingKey: settingKey)
        guard store.defaults.object(forKey: destination) == nil,
              let legacy = store.defaults.string(forKey: legacyKey) else { return }
        store.defaults.set(legacy, forKey: destination)
        store.defaults.removeObject(forKey: legacyKey)
    }

    /// Migrates an integer setting from `legacyKey`. Works for both `.stepper` and integer `.slider` settings.
    public func migrateInt(fromLegacyKey legacyKey: String, toMode modeID: String, settingKey: String) {
        let destination = StillSettingsStore.storageKey(modeID: modeID, settingKey: settingKey)
        guard store.defaults.object(forKey: destination) == nil,
              let legacy = store.defaults.object(forKey: legacyKey) as? NSNumber else { return }
        store.defaults.set(legacy.intValue, forKey: destination)
        store.defaults.removeObject(forKey: legacyKey)
    }

    /// Migrates a floating-point setting from `legacyKey`.
    public func migrateDouble(fromLegacyKey legacyKey: String, toMode modeID: String, settingKey: String) {
        let destination = StillSettingsStore.storageKey(modeID: modeID, settingKey: settingKey)
        guard store.defaults.object(forKey: destination) == nil,
              let legacy = store.defaults.object(forKey: legacyKey) as? NSNumber else { return }
        store.defaults.set(legacy.doubleValue, forKey: destination)
        store.defaults.removeObject(forKey: legacyKey)
    }
}

// MARK: - Declarative settings screen (internal)

@MainActor
final class StillModeSettingsViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {
    private struct SectionModel {
        let header: String?
        let rows: [RowModel]
    }

    private enum RowModel {
        case toggle(StillSetting)
        case stepper(StillSetting)
        case choiceOption(setting: StillSetting, option: String)
        case sliderValue(StillSetting)
        case sliderControl(StillSetting)
    }

    private let modeID: String
    private let settings: [StillSetting]
    private let store: StillSettingsStore
    private let onChange: @MainActor (String) -> Void
    private var sections: [SectionModel] = []

    private var collectionView: UICollectionView!
    private var toggleRegistration: UICollectionView.CellRegistration<UICollectionViewListCell, StillSetting>!
    private var stepperRegistration: UICollectionView.CellRegistration<UICollectionViewListCell, StillSetting>!
    private var choiceRegistration: UICollectionView.CellRegistration<UICollectionViewListCell, (StillSetting, String)>!
    private var sliderValueRegistration: UICollectionView.CellRegistration<UICollectionViewListCell, StillSetting>!
    private var sliderControlRegistration: UICollectionView.CellRegistration<UICollectionViewListCell, StillSetting>!
    private var headerRegistration: UICollectionView.SupplementaryRegistration<UICollectionViewListCell>!

    init(title: String, modeID: String, settings: [StillSetting], store: StillSettingsStore,
         onChange: @escaping @MainActor (String) -> Void) {
        self.modeID = modeID
        self.settings = settings
        self.store = store
        self.onChange = onChange
        super.init(nibName: nil, bundle: nil)
        self.title = title
        self.sections = Self.buildSections(from: settings)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    private static func buildSections(from settings: [StillSetting]) -> [SectionModel] {
        var result: [SectionModel] = []
        var groupedSimpleRows: [RowModel] = []

        func flushSimpleRows() {
            guard !groupedSimpleRows.isEmpty else { return }
            result.append(SectionModel(header: nil, rows: groupedSimpleRows))
            groupedSimpleRows.removeAll()
        }

        for setting in settings {
            switch setting.kind {
            case .toggle:
                groupedSimpleRows.append(.toggle(setting))
            case .stepper:
                groupedSimpleRows.append(.stepper(setting))
            case .choice(let options, _):
                flushSimpleRows()
                result.append(SectionModel(header: setting.title,
                                           rows: options.map { .choiceOption(setting: setting, option: $0) }))
            case .slider:
                flushSimpleRows()
                result.append(SectionModel(header: nil,
                                           rows: [.sliderValue(setting), .sliderControl(setting)]))
            }
        }
        flushSimpleRows()
        return result
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Still.groupedBackground

        let layout = UICollectionViewCompositionalLayout { [weak self] sectionIndex, environment in
            var config = StillList.insetGrouped()
            if let self, sectionIndex < self.sections.count, self.sections[sectionIndex].header != nil {
                config.headerMode = .supplementary
            } else {
                config.headerMode = .none
            }
            return .list(using: config, layoutEnvironment: environment)
        }

        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = Still.groupedBackground
        collectionView.dataSource = self
        collectionView.delegate = self
        view.addSubview(collectionView)
        registerViews()
    }

    private func registerViews() {
        toggleRegistration = .init { [weak self] cell, _, setting in
            guard let self else { return }
            cell.contentConfiguration = nil
            cell.accessories = []
            cell.backgroundConfiguration = StillList.cellBackground()
            let rowView = cell.contentView.subviews.compactMap { $0 as? StillToggleRowView }.first ?? {
                let v = StillToggleRowView()
                v.translatesAutoresizingMaskIntoConstraints = false
                cell.contentView.addSubview(v)
                let margins = cell.contentView.layoutMarginsGuide
                NSLayoutConstraint.activate([
                    v.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
                    v.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
                    v.topAnchor.constraint(equalTo: margins.topAnchor),
                    v.bottomAnchor.constraint(equalTo: margins.bottomAnchor),
                ])
                return v
            }()
            let isOn = self.store.bool(for: setting, modeID: self.modeID)
            rowView.configure(title: setting.title, isOn: isOn) { [weak self] newValue in
                guard let self else { return }
                StillHaptics.touch(0.5)
                self.store.setBool(newValue, key: setting.key, modeID: self.modeID)
                self.onChange(setting.key)
            }
        }

        stepperRegistration = .init { [weak self] cell, _, setting in
            guard let self, case .stepper(let range, let step, _) = setting.kind else { return }
            cell.contentConfiguration = nil
            cell.accessories = []
            cell.backgroundConfiguration = StillList.cellBackground()
            let rowView = cell.contentView.subviews.compactMap { $0 as? StillStepperRowView }.first ?? {
                let v = StillStepperRowView()
                v.translatesAutoresizingMaskIntoConstraints = false
                cell.contentView.addSubview(v)
                let margins = cell.contentView.layoutMarginsGuide
                NSLayoutConstraint.activate([
                    v.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
                    v.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
                    v.topAnchor.constraint(equalTo: margins.topAnchor),
                    v.bottomAnchor.constraint(equalTo: margins.bottomAnchor),
                ])
                return v
            }()
            let current = self.store.int(for: setting, modeID: self.modeID)
            rowView.configure(title: setting.title, value: current, range: range, step: step) { [weak self] newValue in
                guard let self else { return }
                StillHaptics.tick()
                self.store.setInt(newValue, key: setting.key, modeID: self.modeID)
                self.onChange(setting.key)
            }
        }

        choiceRegistration = .init { [weak self] cell, _, pair in
            guard let self else { return }
            let (setting, option) = pair
            let selected = self.store.string(for: setting, modeID: self.modeID) == option
            var content = UIListContentConfiguration.cell()
            content.text = option
            content.textProperties.font = .preferredFont(forTextStyle: .body)
            content.textProperties.color = Still.label
            content.textProperties.numberOfLines = 0
            content.textProperties.adjustsFontForContentSizeCategory = true
            cell.contentConfiguration = content
            cell.accessories = selected ? [.checkmark()] : []
            cell.backgroundConfiguration = StillList.cellBackground()
            cell.accessibilityTraits = selected ? [.button, .selected] : [.button]
        }

        sliderValueRegistration = .init { [weak self] cell, _, setting in
            guard let self else { return }
            let value = self.store.double(for: setting, modeID: self.modeID)
            var content = UIListContentConfiguration.valueCell()
            content.text = setting.title
            content.secondaryText = setting.formattedSliderValue(value)
            content.textProperties.font = .preferredFont(forTextStyle: .body)
            content.textProperties.color = Still.label
            content.textProperties.numberOfLines = 0
            content.textProperties.adjustsFontForContentSizeCategory = true
            content.secondaryTextProperties.font = StillFont.rounded(.body)
            content.secondaryTextProperties.color = Still.labelSecondary
            content.secondaryTextProperties.adjustsFontForContentSizeCategory = true
            content.prefersSideBySideTextAndSecondaryText = !self.traitCollection.preferredContentSizeCategory.isAccessibilityCategory
            cell.contentConfiguration = content
            cell.accessories = []
            cell.backgroundConfiguration = StillList.cellBackground()
            cell.isAccessibilityElement = false
            cell.accessibilityElementsHidden = true
        }

        sliderControlRegistration = .init { [weak self] cell, indexPath, setting in
            guard let self, case .slider(let range, let step, _, _) = setting.kind else { return }
            cell.contentConfiguration = nil
            cell.accessories = []
            cell.backgroundConfiguration = StillList.cellBackground()
            let slider = cell.contentView.subviews.compactMap { $0 as? StillSettingSlider }.first ?? {
                let s = StillSettingSlider()
                s.translatesAutoresizingMaskIntoConstraints = false
                cell.contentView.addSubview(s)
                let margins = cell.contentView.layoutMarginsGuide
                NSLayoutConstraint.activate([
                    s.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
                    s.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
                    s.topAnchor.constraint(equalTo: margins.topAnchor),
                    s.bottomAnchor.constraint(equalTo: margins.bottomAnchor),
                ])
                return s
            }()
            let current = self.store.double(for: setting, modeID: self.modeID)
            slider.configure(setting: setting, range: range, step: step, value: current) { [weak self] snapped in
                guard let self else { return }
                let previous = self.store.double(for: setting, modeID: self.modeID)
                guard abs(snapped - previous) > 1e-9 else { return }
                if step != nil { StillHaptics.tick() }
                self.store.setDouble(snapped, key: setting.key, modeID: self.modeID)
                self.onChange(setting.key)
                let valueIndexPath = IndexPath(item: max(0, indexPath.item - 1), section: indexPath.section)
                self.collectionView.reconfigureItems(at: [valueIndexPath])
            }
        }

        headerRegistration = .init(elementKind: UICollectionView.elementKindSectionHeader) { [weak self] header, _, indexPath in
            guard let self else { return }
            var content = UIListContentConfiguration.groupedHeader()
            content.text = self.sections[indexPath.section].header
            content.textProperties.color = Still.labelSecondary
            header.contentConfiguration = content
        }
    }

    // MARK: Data source

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        sections.count
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        sections[section].rows.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        switch sections[indexPath.section].rows[indexPath.item] {
        case .toggle(let setting):
            return collectionView.dequeueConfiguredReusableCell(using: toggleRegistration, for: indexPath, item: setting)
        case .stepper(let setting):
            return collectionView.dequeueConfiguredReusableCell(using: stepperRegistration, for: indexPath, item: setting)
        case .choiceOption(let setting, let option):
            return collectionView.dequeueConfiguredReusableCell(using: choiceRegistration, for: indexPath, item: (setting, option))
        case .sliderValue(let setting):
            return collectionView.dequeueConfiguredReusableCell(using: sliderValueRegistration, for: indexPath, item: setting)
        case .sliderControl(let setting):
            return collectionView.dequeueConfiguredReusableCell(using: sliderControlRegistration, for: indexPath, item: setting)
        }
    }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String,
                        at indexPath: IndexPath) -> UICollectionReusableView {
        collectionView.dequeueConfiguredReusableSupplementary(using: headerRegistration, for: indexPath)
    }

    // MARK: Selection

    func collectionView(_ collectionView: UICollectionView, shouldHighlightItemAt indexPath: IndexPath) -> Bool {
        if case .choiceOption = sections[indexPath.section].rows[indexPath.item] { return true }
        return false
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard case .choiceOption(let setting, let option) = sections[indexPath.section].rows[indexPath.item] else { return }
        let current = store.string(for: setting, modeID: modeID)
        guard current != option else { return }
        StillHaptics.tick()
        store.setString(option, key: setting.key, modeID: modeID)
        onChange(setting.key)
        let paths = sections[indexPath.section].rows.indices.map { IndexPath(item: $0, section: indexPath.section) }
        collectionView.reconfigureItems(at: paths)
    }
}

// MARK: - Settings row views (internal)

@MainActor
private final class StillToggleRowView: UIView {
    private let stack = UIStackView()
    private let titleLabel = UILabel()
    private let toggle = UISwitch()
    private var onToggle: ((Bool) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        titleLabel.font = .preferredFont(forTextStyle: .body)
        titleLabel.textColor = Still.label
        titleLabel.numberOfLines = 0
        titleLabel.adjustsFontForContentSizeCategory = true

        toggle.setContentHuggingPriority(.required, for: .horizontal)
        toggle.setContentCompressionResistancePriority(.required, for: .horizontal)
        toggle.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.onToggle?(self.toggle.isOn)
        }, for: .valueChanged)

        stack.spacing = StillSpace.s3
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(toggle)
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        updateAxis()
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (view: StillToggleRowView, _) in
            view.updateAxis()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func configure(title: String, isOn: Bool, onToggle: @escaping (Bool) -> Void) {
        titleLabel.text = title
        toggle.isOn = isOn
        toggle.accessibilityLabel = title
        self.onToggle = onToggle
    }

    private func updateAxis() {
        let accessible = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        stack.axis = accessible ? .vertical : .horizontal
        stack.alignment = accessible ? .leading : .center
    }
}

@MainActor
private final class StillStepperRowView: UIView {
    private let stack = UIStackView()
    private let textStack = UIStackView()
    private let titleLabel = UILabel()
    private let valueLabel = UILabel()
    private let stepper = UIStepper()
    private var onChange: ((Int) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        titleLabel.font = .preferredFont(forTextStyle: .body)
        titleLabel.textColor = Still.label
        titleLabel.numberOfLines = 0
        titleLabel.adjustsFontForContentSizeCategory = true

        valueLabel.font = StillFont.rounded(.body)
        valueLabel.textColor = Still.labelSecondary
        valueLabel.adjustsFontForContentSizeCategory = true
        valueLabel.setContentHuggingPriority(.required, for: .horizontal)
        valueLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        textStack.axis = .horizontal
        textStack.spacing = StillSpace.s2
        textStack.alignment = .center
        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(valueLabel)

        stepper.setContentHuggingPriority(.required, for: .horizontal)
        stepper.setContentCompressionResistancePriority(.required, for: .horizontal)
        stepper.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            let next = Int(self.stepper.value.rounded())
            self.valueLabel.text = "\(next)"
            self.stepper.accessibilityValue = "\(next)"
            self.onChange?(next)
        }, for: .valueChanged)

        stack.spacing = StillSpace.s3
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(textStack)
        stack.addArrangedSubview(stepper)
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        updateAxis()
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (view: StillStepperRowView, _) in
            view.updateAxis()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func configure(title: String, value: Int, range: ClosedRange<Int>, step: Int,
                   onChange: @escaping (Int) -> Void) {
        titleLabel.text = title
        valueLabel.text = "\(value)"
        stepper.minimumValue = Double(range.lowerBound)
        stepper.maximumValue = Double(range.upperBound)
        stepper.stepValue = Double(step)
        stepper.value = Double(value)
        stepper.accessibilityLabel = title
        stepper.accessibilityValue = "\(value)"
        self.onChange = onChange
    }

    private func updateAxis() {
        let accessible = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        stack.axis = accessible ? .vertical : .horizontal
        stack.alignment = accessible ? .leading : .center
        textStack.axis = accessible ? .vertical : .horizontal
        textStack.alignment = accessible ? .leading : .center
    }
}

@MainActor
private final class StillSettingSlider: UISlider {
    private var setting: StillSetting?
    private var onChange: ((Double) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        addAction(UIAction { [weak self] _ in
            self?.handleChange()
        }, for: .valueChanged)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func configure(setting: StillSetting, range: ClosedRange<Double>, step: Double?,
                   value: Double, onChange: @escaping (Double) -> Void) {
        self.setting = setting
        self.onChange = onChange
        minimumValue = Float(range.lowerBound)
        maximumValue = Float(range.upperBound)
        self.value = Float(value)
        accessibilityLabel = setting.title
        accessibilityValue = setting.formattedSliderValue(value)
    }

    private func handleChange() {
        guard let setting else { return }
        let snapped = setting.snappedSliderValue(Double(value))
        accessibilityValue = setting.formattedSliderValue(snapped)
        onChange?(snapped)
    }
}
