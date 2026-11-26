import UIKit
import StillKit

/// Displays every `Still.*` semantic role alongside live WCAG 2.1 contrast ratios for
/// the text and foreground pairs defined in docs/brand.md.
@MainActor
final class ColoursViewController: UIViewController, UICollectionViewDataSource {
    private enum Section: Int, CaseIterable {
        case contrastPairs
        case accent
        case grounds
        case textAndLines
        case play
    }

    private struct RoleItem {
        let name: String
        let role: UIColor
        let note: String
    }

    private struct ContrastPair {
        let name: String
        let foreground: UIColor
        let background: UIColor
        let minimumRatio: Double
    }

    private let contrastPairs: [ContrastPair] = [
        ContrastPair(name: "label on background", foreground: Still.label, background: Still.background, minimumRatio: 4.5),
        ContrastPair(name: "label on groupedSurface", foreground: Still.label, background: Still.groupedSurface, minimumRatio: 4.5),
        ContrastPair(name: "labelSecondary on background", foreground: Still.labelSecondary, background: Still.background, minimumRatio: 4.5),
        ContrastPair(name: "labelSecondary on groupedSurface", foreground: Still.labelSecondary, background: Still.groupedSurface, minimumRatio: 4.5),
        ContrastPair(name: "labelTertiary on background", foreground: Still.labelTertiary, background: Still.background, minimumRatio: 3.0),
        ContrastPair(name: "tint on background", foreground: Still.tint, background: Still.background, minimumRatio: 4.5),
        ContrastPair(name: "tint on groupedSurface", foreground: Still.tint, background: Still.groupedSurface, minimumRatio: 4.5),
        ContrastPair(name: "onTint on tint", foreground: Still.onTint, background: Still.tint, minimumRatio: 4.5),
        ContrastPair(name: "onTintSoft on tintSoft", foreground: Still.onTintSoft, background: Still.tintSoft, minimumRatio: 4.5),
        ContrastPair(name: "pieceStrong on canvas", foreground: Still.pieceStrong, background: Still.canvas, minimumRatio: 3.0),
    ]

    private let roleGroups: [[RoleItem]] = [
        [
            RoleItem(name: "Still.tint", role: Still.tint, note: "Window accent"),
            RoleItem(name: "Still.onTint", role: Still.onTint, note: "Text on primary buttons"),
            RoleItem(name: "Still.tintSoft", role: Still.tintSoft, note: "Secondary button and hint ground"),
            RoleItem(name: "Still.onTintSoft", role: Still.onTintSoft, note: "Text on soft tint"),
        ],
        [
            RoleItem(name: "Still.background", role: Still.background, note: "Plain screen ground"),
            RoleItem(name: "Still.backgroundSecondary", role: Still.backgroundSecondary, note: "Secondary ground"),
            RoleItem(name: "Still.backgroundTertiary", role: Still.backgroundTertiary, note: "Tertiary ground"),
            RoleItem(name: "Still.groupedBackground", role: Still.groupedBackground, note: "Inset-grouped list ground"),
            RoleItem(name: "Still.groupedSurface", role: Still.groupedSurface, note: "Grouped list cell surface"),
        ],
        [
            RoleItem(name: "Still.label", role: Still.label, note: "Primary text"),
            RoleItem(name: "Still.labelSecondary", role: Still.labelSecondary, note: "Secondary text"),
            RoleItem(name: "Still.labelTertiary", role: Still.labelTertiary, note: "Placeholders and disabled rows"),
            RoleItem(name: "Still.separator", role: Still.separator, note: "Hairlines and dividers"),
            RoleItem(name: "Still.fill", role: Still.fill, note: "Control tracks and fills"),
            RoleItem(name: "Still.destructive", role: Still.destructive, note: "Apple red for destructive actions"),
        ],
        [
            RoleItem(name: "Still.canvas", role: Still.canvas, note: "Pure Mist / Night game canvas"),
            RoleItem(name: "Still.pieceStrong", role: Still.pieceStrong, note: "Primary game piece"),
            RoleItem(name: "Still.pieceMid", role: Still.pieceMid, note: "Secondary game piece"),
            RoleItem(name: "Still.pieceAmbient", role: Still.pieceAmbient, note: "Quiet ambient game element"),
        ],
    ]

    private var collectionView: UICollectionView!
    private var contrastRegistration: UICollectionView.CellRegistration<UICollectionViewListCell, ContrastPair>!
    private var roleRegistration: UICollectionView.CellRegistration<UICollectionViewListCell, RoleItem>!
    private var headerRegistration: UICollectionView.SupplementaryRegistration<UICollectionViewListCell>!

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Colours & contrast"
        view.backgroundColor = Still.groupedBackground

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

        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (vc: ColoursViewController, _) in
            vc.collectionView.reloadData()
        }
    }

    private func registerViews() {
        contrastRegistration = .init { [weak self] cell, _, pair in
            guard let self else { return }
            let fg = pair.foreground.resolvedColor(with: self.traitCollection)
            let bg = pair.background.resolvedColor(with: self.traitCollection)
            let ratio = Self.contrastRatio(fg, bg)
            let passes = ratio >= pair.minimumRatio
            let threshold = String(format: "%.1f:1", pair.minimumRatio)
            let ratioText = String(format: "%.2f:1", ratio)

            var content = UIListContentConfiguration.subtitleCell()
            content.text = pair.name
            content.secondaryText = "\(ratioText) (target \(threshold)) - \(passes ? "Pass" : "Check")"
            content.textProperties.font = .preferredFont(forTextStyle: .body)
            content.textProperties.color = Still.label
            content.textProperties.numberOfLines = 0
            content.textProperties.adjustsFontForContentSizeCategory = true
            content.secondaryTextProperties.font = StillFont.rounded(.footnote, weight: .medium)
            content.secondaryTextProperties.color = Still.labelSecondary
            content.secondaryTextProperties.numberOfLines = 0
            content.secondaryTextProperties.adjustsFontForContentSizeCategory = true
            cell.contentConfiguration = content

            let chip = ContrastSampleChip(foreground: pair.foreground, background: pair.background)
            cell.accessories = [.customView(configuration: .init(customView: chip, placement: .trailing(),
                                                                 reservedLayoutWidth: .actual,
                                                                 maintainsFixedSize: true))]
            cell.backgroundConfiguration = StillList.cellBackground()
        }

        roleRegistration = .init { [weak self] cell, _, item in
            guard let self else { return }
            let resolved = item.role.resolvedColor(with: self.traitCollection)
            var content = UIListContentConfiguration.subtitleCell()
            content.text = item.name
            content.secondaryText = "\(item.note) (\(Self.hexString(for: resolved)))"
            content.textProperties.font = StillFont.rounded(.headline)
            content.textProperties.color = Still.label
            content.textProperties.numberOfLines = 0
            content.textProperties.adjustsFontForContentSizeCategory = true
            content.secondaryTextProperties.font = .preferredFont(forTextStyle: .footnote)
            content.secondaryTextProperties.color = Still.labelSecondary
            content.secondaryTextProperties.numberOfLines = 0
            content.secondaryTextProperties.adjustsFontForContentSizeCategory = true
            cell.contentConfiguration = content

            let swatch = SwatchView(color: item.role)
            cell.accessories = [.customView(configuration: .init(customView: swatch, placement: .leading(),
                                                                 reservedLayoutWidth: .actual,
                                                                 maintainsFixedSize: true))]
            cell.backgroundConfiguration = StillList.cellBackground()
        }

        headerRegistration = .init(elementKind: UICollectionView.elementKindSectionHeader) { header, _, indexPath in
            var content = UIListContentConfiguration.groupedHeader()
            switch Section(rawValue: indexPath.section) {
            case .contrastPairs: content.text = "Live contrast ratios"
            case .accent: content.text = "Accent roles"
            case .grounds: content.text = "Ground roles"
            case .textAndLines: content.text = "Text and line roles"
            case .play: content.text = "Play roles"
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
        if section == Section.contrastPairs.rawValue {
            return contrastPairs.count
        }
        return roleGroups[section - 1].count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if indexPath.section == Section.contrastPairs.rawValue {
            return collectionView.dequeueConfiguredReusableCell(using: contrastRegistration, for: indexPath,
                                                                item: contrastPairs[indexPath.item])
        }
        return collectionView.dequeueConfiguredReusableCell(using: roleRegistration, for: indexPath,
                                                            item: roleGroups[indexPath.section - 1][indexPath.item])
    }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String,
                        at indexPath: IndexPath) -> UICollectionReusableView {
        collectionView.dequeueConfiguredReusableSupplementary(using: headerRegistration, for: indexPath)
    }

    // MARK: WCAG 2.1 contrast calculation

    private static func relativeLuminance(of color: UIColor) -> Double {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)

        func linear(_ channel: CGFloat) -> Double {
            let c = Double(min(max(channel, 0), 1))
            return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
    }

    private static func contrastRatio(_ a: UIColor, _ b: UIColor) -> Double {
        let la = relativeLuminance(of: a)
        let lb = relativeLuminance(of: b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    private static func hexString(for color: UIColor) -> String {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(round(r * 255)), Int(round(g * 255)), Int(round(b * 255)))
    }
}

@MainActor
private final class SwatchView: UIView {
    init(color: UIColor) {
        super.init(frame: CGRect(x: 0, y: 0, width: 32, height: 32))
        backgroundColor = color
        stillCorners(StillRadius.sm)
        layer.borderWidth = 0.5
        updateBorder()
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: SwatchView, _) in
            view.updateBorder()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override var intrinsicContentSize: CGSize { CGSize(width: 32, height: 32) }

    private func updateBorder() {
        layer.borderColor = Still.separator.resolvedColor(with: traitCollection).cgColor
    }
}

@MainActor
private final class ContrastSampleChip: UIView {
    init(foreground: UIColor, background: UIColor) {
        super.init(frame: CGRect(x: 0, y: 0, width: 44, height: 28))
        backgroundColor = background
        stillCorners(StillRadius.sm)
        let label = UILabel(frame: bounds)
        label.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        label.text = "Aa"
        label.textAlignment = .center
        label.font = StillFont.rounded(.subheadline, weight: .semibold)
        label.textColor = foreground
        addSubview(label)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override var intrinsicContentSize: CGSize { CGSize(width: 44, height: 28) }
}
