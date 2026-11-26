import UIKit
import StillKit

/// Displays `StillList.insetGrouped()`, `StillList.cellBackground()`, system controls and
/// destructive actions in Still colours.
@MainActor
final class ListsViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {
    private enum Section: Int, CaseIterable {
        case standard
        case controls
        case destructive
    }

    private var switchOn = true
    private var sliderValue: Float = 0.65
    private var stepperValue = 4

    private var collectionView: UICollectionView!
    private var textRegistration: UICollectionView.CellRegistration<UICollectionViewListCell, (String, String?)>!
    private var switchRegistration: UICollectionView.CellRegistration<UICollectionViewListCell, Void>!
    private var sliderRegistration: UICollectionView.CellRegistration<UICollectionViewListCell, Void>!
    private var stepperRegistration: UICollectionView.CellRegistration<UICollectionViewListCell, Void>!
    private var destructiveRegistration: UICollectionView.CellRegistration<UICollectionViewListCell, String>!
    private var headerRegistration: UICollectionView.SupplementaryRegistration<UICollectionViewListCell>!

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Lists"
        view.backgroundColor = Still.groupedBackground

        var config = StillList.insetGrouped()
        config.headerMode = .supplementary
        let layout = UICollectionViewCompositionalLayout.list(using: config)

        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = Still.groupedBackground
        collectionView.dataSource = self
        collectionView.delegate = self
        view.addSubview(collectionView)
        registerViews()
    }

    private func registerViews() {
        textRegistration = .init { cell, _, pair in
            var content = UIListContentConfiguration.subtitleCell()
            content.text = pair.0
            content.secondaryText = pair.1
            content.textProperties.font = StillFont.rounded(.headline)
            content.textProperties.color = Still.label
            content.textProperties.numberOfLines = 0
            content.textProperties.adjustsFontForContentSizeCategory = true
            content.secondaryTextProperties.font = .preferredFont(forTextStyle: .subheadline)
            content.secondaryTextProperties.color = Still.labelSecondary
            content.secondaryTextProperties.numberOfLines = 0
            content.secondaryTextProperties.adjustsFontForContentSizeCategory = true
            cell.contentConfiguration = content
            cell.accessories = pair.1 == nil ? [.checkmark()] : []
            cell.backgroundConfiguration = StillList.cellBackground()
        }

        switchRegistration = .init { [weak self] cell, _, _ in
            guard let self else { return }
            var content = UIListContentConfiguration.cell()
            content.text = "Quiet sound"
            content.textProperties.font = .preferredFont(forTextStyle: .body)
            content.textProperties.color = Still.label
            content.textProperties.numberOfLines = 0
            content.textProperties.adjustsFontForContentSizeCategory = true
            cell.contentConfiguration = content
            let toggle = UISwitch()
            toggle.isOn = self.switchOn
            toggle.addAction(UIAction { [weak self, weak toggle] _ in
                guard let self, let toggle else { return }
                StillHaptics.touch(0.5)
                self.switchOn = toggle.isOn
            }, for: .valueChanged)
            cell.accessories = [.customView(configuration: .init(customView: toggle, placement: .trailing(),
                                                                 reservedLayoutWidth: .actual,
                                                                 maintainsFixedSize: true))]
            cell.backgroundConfiguration = StillList.cellBackground()
        }

        sliderRegistration = .init { [weak self] cell, _, _ in
            guard let self else { return }
            cell.contentConfiguration = nil
            cell.accessories = []
            cell.backgroundConfiguration = StillList.cellBackground()
            let slider = cell.contentView.subviews.compactMap { $0 as? UISlider }.first ?? {
                let s = UISlider()
                s.accessibilityLabel = "Sample slider"
                s.addAction(UIAction { [weak self, weak s] _ in
                    guard let self, let s else { return }
                    self.sliderValue = s.value
                }, for: .valueChanged)
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
            slider.value = self.sliderValue
        }

        stepperRegistration = .init { [weak self] cell, _, _ in
            guard let self else { return }
            var content = UIListContentConfiguration.cell()
            content.text = "Steps: \(self.stepperValue)"
            content.textProperties.font = .preferredFont(forTextStyle: .body)
            content.textProperties.color = Still.label
            content.textProperties.numberOfLines = 0
            content.textProperties.adjustsFontForContentSizeCategory = true
            cell.contentConfiguration = content
            let stepper = UIStepper()
            stepper.minimumValue = 1
            stepper.maximumValue = 10
            stepper.value = Double(self.stepperValue)
            stepper.addAction(UIAction { [weak self, weak stepper] _ in
                guard let self, let stepper else { return }
                StillHaptics.tick()
                self.stepperValue = Int(stepper.value.rounded())
                self.collectionView.reconfigureItems(at: [IndexPath(item: 2, section: Section.controls.rawValue)])
            }, for: .valueChanged)
            cell.accessories = [.customView(configuration: .init(customView: stepper, placement: .trailing(),
                                                                 reservedLayoutWidth: .actual,
                                                                 maintainsFixedSize: true))]
            cell.backgroundConfiguration = StillList.cellBackground()
        }

        destructiveRegistration = .init { cell, _, title in
            var content = UIListContentConfiguration.cell()
            content.text = title
            content.textProperties.font = .preferredFont(forTextStyle: .body)
            content.textProperties.color = Still.destructive
            content.textProperties.numberOfLines = 0
            content.textProperties.adjustsFontForContentSizeCategory = true
            cell.contentConfiguration = content
            cell.accessories = []
            cell.backgroundConfiguration = StillList.cellBackground()
            cell.accessibilityTraits = [.button]
        }

        headerRegistration = .init(elementKind: UICollectionView.elementKindSectionHeader) { header, _, indexPath in
            var content = UIListContentConfiguration.groupedHeader()
            switch Section(rawValue: indexPath.section) {
            case .standard: content.text = "Inset-grouped rows"
            case .controls: content.text = "System controls"
            case .destructive: content.text = "Destructive action"
            case .none: content.text = nil
            }
            content.textProperties.color = Still.labelSecondary
            header.contentConfiguration = content
        }
    }

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        Section.allCases.count
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch Section(rawValue: section) {
        case .standard: 2
        case .controls: 3
        case .destructive: 1
        case .none: 0
        }
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        switch Section(rawValue: indexPath.section) {
        case .standard:
            let item = indexPath.item == 0
                ? ("Selected item", nil as String?)
                : ("Subtitle row", "Surfaces separate by ground step, never borders or shadows.")
            return collectionView.dequeueConfiguredReusableCell(using: textRegistration, for: indexPath, item: item)
        case .controls:
            switch indexPath.item {
            case 0: return collectionView.dequeueConfiguredReusableCell(using: switchRegistration, for: indexPath, item: ())
            case 1: return collectionView.dequeueConfiguredReusableCell(using: sliderRegistration, for: indexPath, item: ())
            default: return collectionView.dequeueConfiguredReusableCell(using: stepperRegistration, for: indexPath, item: ())
            }
        case .destructive:
            return collectionView.dequeueConfiguredReusableCell(using: destructiveRegistration, for: indexPath,
                                                                item: "Reset saved data")
        case .none:
            return UICollectionViewCell()
        }
    }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String,
                        at indexPath: IndexPath) -> UICollectionReusableView {
        collectionView.dequeueConfiguredReusableSupplementary(using: headerRegistration, for: indexPath)
    }

    func collectionView(_ collectionView: UICollectionView, shouldHighlightItemAt indexPath: IndexPath) -> Bool {
        Section(rawValue: indexPath.section) == .destructive
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard Section(rawValue: indexPath.section) == .destructive else { return }
        let alert = UIAlertController(title: "Reset saved data?", message: "System alerts stay unstyled.", preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Reset", style: .destructive))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let popover = alert.popoverPresentationController, let cell = collectionView.cellForItem(at: indexPath) {
            popover.sourceView = cell
            popover.sourceRect = cell.bounds
        }
        present(alert, animated: true)
    }
}
