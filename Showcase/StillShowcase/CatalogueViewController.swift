import UIKit
import StillKit

/// Root screen of the StillShowcase app: launches the sample game and lists every
/// visual primitive catalogue screen.
@MainActor
final class CatalogueViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {
    private enum Section: Int, CaseIterable {
        case game
        case primitives
    }

    private struct Entry {
        let title: String
        let detail: String
        let symbol: String
        let makeDestination: @MainActor () -> UIViewController
    }

    private lazy var entries: [Entry] = [
        Entry(title: "Colours & contrast",
              detail: "Every Still role and live WCAG contrast ratios.",
              symbol: "paintpalette",
              makeDestination: { ColoursViewController() }),
        Entry(title: "Typography",
              detail: "SF Pro Rounded display styles, numerals and Dynamic Type.",
              symbol: "textformat",
              makeDestination: { TypographyViewController() }),
        Entry(title: "Buttons",
              detail: "Primary, secondary and plain capsules, enabled and disabled.",
              symbol: "capsule",
              makeDestination: { ButtonsViewController() }),
        Entry(title: "Shape & spacing",
              detail: "Continuous corners, counter pebbles and the 8pt rhythm.",
              symbol: "square.on.circle",
              makeDestination: { ShapeSpaceViewController() }),
        Entry(title: "Lists",
              detail: "Inset-grouped lists, system controls and destructive actions.",
              symbol: "list.bullet.rectangle",
              makeDestination: { ListsViewController() }),
        Entry(title: "Motion",
              detail: "The bounce-free house spring and Reduce Motion crossfade.",
              symbol: "wind",
              makeDestination: { MotionViewController() }),
        Entry(title: "Haptics",
              detail: "Touch, snap, tick and a draggable piece that snaps into place.",
              symbol: "hand.tap",
              makeDestination: { HapticsViewController() }),
    ]

    private var collectionView: UICollectionView!
    private var gameLaunchRegistration: UICollectionView.CellRegistration<UICollectionViewListCell, Void>!
    private var entryRegistration: UICollectionView.CellRegistration<UICollectionViewListCell, Entry>!
    private var headerRegistration: UICollectionView.SupplementaryRegistration<UICollectionViewListCell>!
    private var footerRegistration: UICollectionView.SupplementaryRegistration<UICollectionViewListCell>!

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "StillKit"
        view.backgroundColor = Still.groupedBackground

        let layout = UICollectionViewCompositionalLayout { sectionIndex, environment in
            var config = StillList.insetGrouped()
            config.headerMode = .supplementary
            config.footerMode = sectionIndex == Section.game.rawValue ? .supplementary : .none
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

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    private func registerViews() {
        gameLaunchRegistration = .init { [weak self] cell, _, _ in
            cell.contentConfiguration = nil
            cell.accessories = []
            cell.backgroundConfiguration = StillList.cellBackground()
            let container = cell.contentView.subviews.compactMap { $0 as? UIStackView }.first ?? {
                let stack = UIStackView()
                stack.axis = .vertical
                stack.spacing = StillSpace.s3
                stack.translatesAutoresizingMaskIntoConstraints = false

                let summary = UILabel()
                summary.text = "Three blank modes (Drift, Trace with undo, Garden with all four setting kinds) plus the cold-launch splash carry-over."
                summary.font = .preferredFont(forTextStyle: .subheadline)
                summary.textColor = Still.labelSecondary
                summary.numberOfLines = 0
                summary.adjustsFontForContentSizeCategory = true

                let button = UIButton(configuration: .stillPrimary("Launch sample game"))
                button.addAction(UIAction { [weak self] _ in
                    self?.launchSampleGame()
                }, for: .primaryActionTriggered)

                stack.addArrangedSubview(summary)
                stack.addArrangedSubview(button)
                cell.contentView.addSubview(stack)
                let margins = cell.contentView.layoutMarginsGuide
                NSLayoutConstraint.activate([
                    stack.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
                    stack.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
                    stack.topAnchor.constraint(equalTo: margins.topAnchor, constant: StillSpace.s1),
                    stack.bottomAnchor.constraint(equalTo: margins.bottomAnchor, constant: -StillSpace.s1),
                ])
                return stack
            }()
            _ = container
        }

        entryRegistration = .init { cell, _, entry in
            var content = UIListContentConfiguration.subtitleCell()
            content.text = entry.title
            content.secondaryText = entry.detail
            content.image = UIImage(systemName: entry.symbol)
            content.imageProperties.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .body)
            content.textProperties.font = StillFont.rounded(.headline)
            content.textProperties.color = Still.label
            content.textProperties.numberOfLines = 0
            content.textProperties.adjustsFontForContentSizeCategory = true
            content.secondaryTextProperties.font = .preferredFont(forTextStyle: .subheadline)
            content.secondaryTextProperties.color = Still.labelSecondary
            content.secondaryTextProperties.numberOfLines = 0
            content.secondaryTextProperties.adjustsFontForContentSizeCategory = true
            content.textToSecondaryTextVerticalPadding = StillSpace.s1
            cell.contentConfiguration = content
            cell.accessories = [.disclosureIndicator()]
            cell.backgroundConfiguration = StillList.cellBackground()
        }

        headerRegistration = .init(elementKind: UICollectionView.elementKindSectionHeader) { header, _, indexPath in
            var content = UIListContentConfiguration.groupedHeader()
            content.text = Section(rawValue: indexPath.section) == .game ? "Game shell" : "Catalogue"
            content.textProperties.color = Still.labelSecondary
            header.contentConfiguration = content
        }

        footerRegistration = .init(elementKind: UICollectionView.elementKindSectionFooter) { footer, _, _ in
            var content = UIListContentConfiguration.groupedFooter()
            content.text = "Tap with two fingers inside the game to open the series menu. Swipe from the left edge to return to the catalogue."
            content.textProperties.color = Still.labelSecondary
            footer.contentConfiguration = content
        }
    }

    private func launchSampleGame() {
        let hostVC = StillGameHost.makeViewController(for: StillSampleGame())
        navigationController?.setNavigationBarHidden(true, animated: true)
        navigationController?.pushViewController(hostVC, animated: true)
    }

    // MARK: Data source

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        Section.allCases.count
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        Section(rawValue: section) == .game ? 1 : entries.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if Section(rawValue: indexPath.section) == .game {
            return collectionView.dequeueConfiguredReusableCell(using: gameLaunchRegistration, for: indexPath, item: ())
        }
        return collectionView.dequeueConfiguredReusableCell(using: entryRegistration, for: indexPath,
                                                            item: entries[indexPath.item])
    }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String,
                        at indexPath: IndexPath) -> UICollectionReusableView {
        if kind == UICollectionView.elementKindSectionFooter {
            return collectionView.dequeueConfiguredReusableSupplementary(using: footerRegistration, for: indexPath)
        }
        return collectionView.dequeueConfiguredReusableSupplementary(using: headerRegistration, for: indexPath)
    }

    // MARK: Selection

    func collectionView(_ collectionView: UICollectionView, shouldHighlightItemAt indexPath: IndexPath) -> Bool {
        Section(rawValue: indexPath.section) == .primitives
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard Section(rawValue: indexPath.section) == .primitives else { return }
        navigationController?.pushViewController(entries[indexPath.item].makeDestination(), animated: true)
    }
}
