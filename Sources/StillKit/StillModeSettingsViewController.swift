import UIKit

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

        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (vc: StillModeSettingsViewController, _) in
            vc.reconfigureSliderValueRows()
        }
    }

    private func reconfigureSliderValueRows() {
        var paths: [IndexPath] = []
        for (sectionIndex, section) in sections.enumerated() {
            for (rowIndex, row) in section.rows.enumerated() {
                if case .sliderValue = row {
                    paths.append(IndexPath(item: rowIndex, section: sectionIndex))
                }
            }
        }
        if !paths.isEmpty {
            collectionView.reconfigureItems(at: paths)
        }
    }

    private func registerViews() {
        toggleRegistration = .init { [weak self] cell, _, setting in
            guard let self else { return }
            let rowView = cell.stillHostedView { StillToggleRowView() }
            let isOn = self.store.bool(for: setting, modeID: self.modeID)
            rowView.configure(title: setting.title, isOn: isOn) { [weak self] newValue in
                guard let self else { return }
                StillHaptics.touch()
                self.store.setBool(newValue, key: setting.key, modeID: self.modeID)
                self.onChange(setting.key)
            }
        }

        stepperRegistration = .init { [weak self] cell, _, setting in
            guard let self, case .stepper(let range, let step, _) = setting.kind else { return }
            let rowView = cell.stillHostedView { StillStepperRowView() }
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
            let slider = cell.stillHostedView { StillSettingSlider() }
            let current = self.store.double(for: setting, modeID: self.modeID)
            slider.configure(setting: setting, range: range, value: current) { [weak self] snapped in
                guard let self else { return }
                let previous = self.store.double(for: setting, modeID: self.modeID)
                guard abs(snapped - previous) > 1e-9 else { return }
                let previousLabel = setting.formattedSliderValue(previous)
                let nextLabel = setting.formattedSliderValue(snapped)
                if step != nil { StillHaptics.tick() }
                self.store.setDouble(snapped, key: setting.key, modeID: self.modeID)
                self.onChange(setting.key)
                if nextLabel != previousLabel {
                    let valueIndexPath = IndexPath(item: max(0, indexPath.item - 1), section: indexPath.section)
                    self.collectionView.reconfigureItems(at: [valueIndexPath])
                }
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
    private let titleLabel = UILabel.stillSettingTitle()
    private let toggle = UISwitch()
    private var onToggle: ((Bool) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        toggle.setContentHuggingPriority(.required, for: .horizontal)
        toggle.setContentCompressionResistancePriority(.required, for: .horizontal)
        toggle.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.onToggle?(self.toggle.isOn)
        }, for: .valueChanged)

        stack.spacing = StillSpace.s3
        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(toggle)
        addSubview(stack)
        stack.pinToEdges(of: self)

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
        stack.applyAccessibleAxis(for: traitCollection)
    }
}

@MainActor
private final class StillStepperRowView: UIView {
    private let stack = UIStackView()
    private let textStack = UIStackView()
    private let titleLabel = UILabel.stillSettingTitle()
    private let valueLabel = UILabel()
    private let stepper = UIStepper()
    private var onChange: ((Int) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        valueLabel.font = StillFont.rounded(.body)
        valueLabel.textColor = Still.labelSecondary
        valueLabel.adjustsFontForContentSizeCategory = true
        valueLabel.setContentHuggingPriority(.required, for: .horizontal)
        valueLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        textStack.spacing = StillSpace.s2
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
        stack.addArrangedSubview(textStack)
        stack.addArrangedSubview(stepper)
        addSubview(stack)
        stack.pinToEdges(of: self)

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
        stack.applyAccessibleAxis(for: traitCollection)
        textStack.applyAccessibleAxis(for: traitCollection)
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

    func configure(setting: StillSetting, range: ClosedRange<Double>,
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

private extension UILabel {
    static func stillSettingTitle() -> UILabel {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .body)
        label.textColor = Still.label
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        return label
    }
}

private extension UIStackView {
    func applyAccessibleAxis(for traits: UITraitCollection) {
        let accessible = traits.preferredContentSizeCategory.isAccessibilityCategory
        axis = accessible ? .vertical : .horizontal
        alignment = accessible ? .leading : .center
    }
}
