import UIKit
import StillKit

/// Displays every `StillFont` display style, numeral variant and plain text style at the
/// active Dynamic Type size.
@MainActor
final class TypographyViewController: UIViewController, UICollectionViewDataSource {
    private struct Sample {
        let title: String
        let specimen: String
        let font: UIFont
    }

    private struct SectionGroup {
        let header: String
        let items: [Sample]
    }

    private var groups: [SectionGroup] = []
    private var collectionView: UICollectionView!
    private var cellRegistration: UICollectionView.CellRegistration<UICollectionViewListCell, Sample>!
    private var headerRegistration: UICollectionView.SupplementaryRegistration<UICollectionViewListCell>!

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Typography"
        view.backgroundColor = Still.groupedBackground
        rebuildGroups()

        var config = StillList.insetGrouped()
        config.headerMode = .supplementary
        let layout = UICollectionViewCompositionalLayout.list(using: config)

        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = Still.groupedBackground
        collectionView.allowsSelection = false
        collectionView.dataSource = self
        view.addSubview(collectionView)
        registerViews()

        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (vc: TypographyViewController, _) in
            vc.rebuildGroups()
            vc.collectionView.reloadData()
        }
    }

    private func rebuildGroups() {
        let category = traitCollection.preferredContentSizeCategory.rawValue
        groups = [
            SectionGroup(header: "Active size category: \(category)", items: [
                Sample(title: "StillFont.rounded(.largeTitle)", specimen: "Large title", font: StillFont.rounded(.largeTitle)),
                Sample(title: "StillFont.rounded(.title1)", specimen: "Title 1", font: StillFont.rounded(.title1)),
                Sample(title: "StillFont.rounded(.title2)", specimen: "Title 2", font: StillFont.rounded(.title2)),
                Sample(title: "StillFont.rounded(.title3)", specimen: "Title 3", font: StillFont.rounded(.title3)),
                Sample(title: "StillFont.rounded(.headline)", specimen: "Rounded headline", font: StillFont.rounded(.headline)),
            ]),
            SectionGroup(header: "Numerals (monospaced digits)", items: [
                Sample(title: "StillFont.numeral(weight: .medium)", specimen: "0428", font: StillFont.numeral(size: 44, weight: .medium)),
                Sample(title: "StillFont.numeral(weight: .light)", specimen: "12:00", font: StillFont.numeral(size: 44, weight: .light)),
            ]),
            SectionGroup(header: "Reading styles (SF Pro)", items: [
                Sample(title: "StillFont.text(.headline)", specimen: "Headline reading style", font: StillFont.text(.headline)),
                Sample(title: "StillFont.text(.body)", specimen: "Body copy scales cleanly with Dynamic Type.", font: StillFont.text(.body)),
                Sample(title: "StillFont.text(.callout)", specimen: "Callout style for gentle emphasis.", font: StillFont.text(.callout)),
                Sample(title: "StillFont.text(.subheadline)", specimen: "Subheadline for descriptions.", font: StillFont.text(.subheadline)),
                Sample(title: "StillFont.text(.footnote)", specimen: "Footnote for quiet notes and credits.", font: StillFont.text(.footnote)),
                Sample(title: "StillFont.text(.caption1)", specimen: "Caption 1 label", font: StillFont.text(.caption1)),
                Sample(title: "StillFont.text(.caption2)", specimen: "Caption 2 label", font: StillFont.text(.caption2)),
            ]),
        ]
    }

    private func registerViews() {
        cellRegistration = .init { cell, _, sample in
            var content = UIListContentConfiguration.subtitleCell()
            content.text = sample.specimen
            content.secondaryText = "\(sample.title) - \(Int(sample.font.pointSize.rounded()))pt"
            content.textProperties.font = sample.font
            content.textProperties.color = Still.label
            content.textProperties.numberOfLines = 0
            content.textProperties.adjustsFontForContentSizeCategory = true
            content.secondaryTextProperties.font = .preferredFont(forTextStyle: .footnote)
            content.secondaryTextProperties.color = Still.labelSecondary
            content.secondaryTextProperties.numberOfLines = 0
            content.secondaryTextProperties.adjustsFontForContentSizeCategory = true
            content.textToSecondaryTextVerticalPadding = StillSpace.s1
            cell.contentConfiguration = content
            cell.backgroundConfiguration = StillList.cellBackground()
        }

        headerRegistration = .init(elementKind: UICollectionView.elementKindSectionHeader) { [weak self] header, _, indexPath in
            guard let self else { return }
            var content = UIListContentConfiguration.groupedHeader()
            content.text = self.groups[indexPath.section].header
            content.textProperties.color = Still.labelSecondary
            header.contentConfiguration = content
        }
    }

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        groups.count
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        groups[section].items.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath,
                                                     item: groups[indexPath.section].items[indexPath.item])
    }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String,
                        at indexPath: IndexPath) -> UICollectionReusableView {
        collectionView.dequeueConfiguredReusableSupplementary(using: headerRegistration, for: indexPath)
    }
}
