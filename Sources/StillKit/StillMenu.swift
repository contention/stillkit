import UIKit

// MARK: - The menu
//
// A game or toy's screen shows the game and nothing else: no buttons, bars or labels. So
// the series gives it one menu, opened by a two-finger tap: the app's logo in the navigation
// bar, a line about the app, an inset-grouped list (game modes, the current one with its
// actions on its row, each with its settings if it has any, then how to play), and the
// version and credits at the foot. See docs/uikit.md, step 6.

/// The series menu. Describe it, then call `present(from:)`.
///
/// ```swift
/// let menu = StillMenu(
///     title: "minibalism",
///     logo: LogoView(pointSize: 24),
///     about: "No points. No aims. Just a tiny space to bounce, breathe, and be.",
///     sections: [
///         .init("Game mode", items: modes.map { mode in
///             .choice(mode.name, detail: mode.summary, isSelected: mode == current,
///                     actions: mode == current ? [.init("New game") { game.reset() }] : [],
///                     settings: mode.hasSettings ? { ModeSettingsViewController(mode) } : nil) {
///                 switchTo(mode)
///             }
///         })
///     ],
///     footer: [StillMenu.version(of: "minibalism"), "A contention product."]
/// )
/// menu.present(from: viewController)
/// ```
///
/// The menu is a snapshot: build it each time it opens, so it shows the app as it is then.
/// Choosing a row closes the menu first and runs the row's action once it has gone, so the
/// action's effect (a new mode, a cleared board) is seen rather than hidden behind the sheet.
public struct StillMenu {
    /// The app's name. VoiceOver reads it as the menu's title; the logo is shown instead.
    public var title: String
    /// Shown in the navigation bar in place of the title, about 24pt tall.
    public var logo: UIView?
    /// A line or two about the app, centred above the list, in the series voice.
    public var about: String?
    public var sections: [Section]
    /// Lines centred below the list in footnote type: the version, credits. Markdown links
    /// (`[Coolors](https://coolors.co)`) can be tapped.
    public var footer: [String]

    public init(title: String, logo: UIView? = nil, about: String? = nil,
                sections: [Section] = [], footer: [String] = []) {
        self.title = title
        self.logo = logo
        self.about = about
        self.sections = sections
        self.footer = footer
    }

    /// A group of rows on one surface, with an optional header above and footer below.
    public struct Section {
        public var header: String?
        public var footer: String?
        public var items: [Item]

        public init(_ header: String? = nil, footer: String? = nil, items: [Item]) {
            self.header = header
            self.footer = footer
            self.items = items
        }
    }

    /// One row.
    public struct Item {
        enum Kind {
            case choice(detail: String?, isSelected: Bool, actions: [RowAction],
                        settings: (@MainActor () -> UIViewController)?)
            case action(role: Role, confirmation: Confirmation?)
            case text
        }

        let title: String
        let kind: Kind
        let handler: (@MainActor () -> Void)?

        /// One of a set to choose between, such as a game mode: its name in rounded type,
        /// what it is beneath, and a checkmark when it is the current one.
        ///
        /// Give the current mode its `actions` ("New game", undo, "Clear the board"). They
        /// are buttons on its row, before the checkmark; each closes the menu and then acts
        /// on the mode's game. Tapping the rest of the row still chooses the mode.
        ///
        /// Give a mode with its own settings a `settings` closure. The row then shows a
        /// settings button: tapping the row still chooses the mode, and tapping the button
        /// pushes the closure's view controller onto the menu, titled with the mode's name
        /// unless it has a title of its own. The mode is not switched. Build the settings
        /// screen like any other list (`Still.groupedBackground`, `StillList`), and apply
        /// changes as they are made: there is no Save.
        public static func choice(_ title: String, detail: String? = nil, isSelected: Bool,
                                  actions: [RowAction] = [],
                                  settings: (@MainActor () -> UIViewController)? = nil,
                                  action: @escaping @MainActor () -> Void) -> Item {
            Item(title: title,
                 kind: .choice(detail: detail, isSelected: isSelected, actions: actions, settings: settings),
                 handler: action)
        }

        /// Something to do, in tint text: "New game", "Clear the board". With a
        /// `confirmation`, the system asks first, for actions that lose progress.
        public static func action(_ title: String, role: Role = .normal, confirmation: Confirmation? = nil,
                                  action: @escaping @MainActor () -> Void) -> Item {
            Item(title: title, kind: .action(role: role, confirmation: confirmation), handler: action)
        }

        /// Text to read, such as how to play. Not selectable.
        public static func text(_ text: String) -> Item {
            Item(title: text, kind: .text, handler: nil)
        }
    }

    /// A button on a `.choice` row: something to do to that mode's game.
    ///
    /// With a `symbol`, it is drawn as that SF Symbol, and its title is what VoiceOver reads.
    /// Without one, it is drawn as its title in tint text. Use a word when a symbol would
    /// mislead (docs/brand.md): a new round is "New game", never a plus or circular arrows.
    public struct RowAction {
        public var title: String
        /// An SF Symbol name, such as "arrow.uturn.backward" for undo.
        public var symbol: String?
        /// The question asked first, for an action that loses progress.
        public var confirmation: Confirmation?
        let handler: @MainActor () -> Void

        public init(_ title: String, symbol: String? = nil, confirmation: Confirmation? = nil,
                    action: @escaping @MainActor () -> Void) {
            self.title = title
            self.symbol = symbol
            self.confirmation = confirmation
            self.handler = action
        }
    }

    /// How an action row is drawn.
    public enum Role {
        /// Tint text.
        case normal
        /// Apple's red, for an action that destroys something kept, such as a saved drawing.
        /// Starting a new round is not one: give it a `Confirmation` instead.
        case destructive
    }

    /// The question asked before an action that loses progress. Shown as a system action sheet.
    public struct Confirmation {
        public var title: String
        public var message: String?
        public var confirm: String
        public var cancel: String
        /// Whether confirming loses something, so the confirm button is Apple's red. Usually
        /// true: that is why the question is asked.
        public var isDestructive: Bool

        public init(_ title: String, message: String? = nil, confirm: String, cancel: String = "Cancel",
                    isDestructive: Bool = true) {
            self.title = title
            self.message = message
            self.confirm = confirm
            self.cancel = cancel
            self.isDestructive = isDestructive
        }
    }

    /// Presents the menu as a sheet from `presenter`. Returns `false`, doing nothing, if
    /// `presenter` is already presenting something (the menu, say).
    @MainActor
    @discardableResult
    public func present(from presenter: UIViewController) -> Bool {
        guard presenter.presentedViewController == nil else { return false }
        let root = StillMenuViewController(menu: self)
        let navigation = UINavigationController(rootViewController: root)
        if let sheet = navigation.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
        // Told when the sheet is swiped away, so the game knows the menu has gone.
        navigation.presentationController?.delegate = root
        NotificationCenter.default.post(name: .stillMenuWillOpen, object: nil)
        presenter.present(navigation, animated: true)
        return true
    }

    /// "name 1.0 (12)", from the bundle's version and build, for the footer.
    public static func version(of name: String, bundle: Bundle = .main) -> String {
        let info = bundle.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        guard let build = info?["CFBundleVersion"] as? String else { return "\(name) \(version)" }
        return "\(name) \(version) (\(build))"
    }
}

// MARK: - The menu's screen

@MainActor
final class StillMenuViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate,
    UIAdaptivePresentationControllerDelegate {
    private static let aboutKind = "StillMenu.about"
    private static let creditsKind = "StillMenu.credits"

    private let menu: StillMenu
    private let sections: [StillMenu.Section]
    private var collectionView: UICollectionView!
    private var cellRegistration: UICollectionView.CellRegistration<UICollectionViewListCell, StillMenu.Item>!
    private var headerRegistration: UICollectionView.SupplementaryRegistration<UICollectionViewListCell>!
    private var footerRegistration: UICollectionView.SupplementaryRegistration<UICollectionViewListCell>!
    private var aboutRegistration: UICollectionView.SupplementaryRegistration<StillMenuTextView>!
    private var creditsRegistration: UICollectionView.SupplementaryRegistration<StillMenuTextView>!

    init(menu: StillMenu) {
        self.menu = menu
        // An empty section would still draw its header and an empty surface.
        self.sections = menu.sections.filter { !$0.items.isEmpty }
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Still.groupedBackground
        title = menu.title
        if let logo = menu.logo {
            navigationItem.titleView = logo
        }

        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: makeLayout())
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = Still.groupedBackground
        collectionView.dataSource = self
        collectionView.delegate = self
        view.addSubview(collectionView)
        registerViews()
    }

    private func makeLayout() -> UICollectionViewLayout {
        let configuration = UICollectionViewCompositionalLayoutConfiguration()
        var boundaries: [NSCollectionLayoutBoundarySupplementaryItem] = []
        let estimated = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(60))
        if menu.about != nil {
            boundaries.append(.init(layoutSize: estimated, elementKind: Self.aboutKind, alignment: .top))
        }
        if !menu.footer.isEmpty {
            boundaries.append(.init(layoutSize: estimated, elementKind: Self.creditsKind, alignment: .bottom))
        }
        configuration.boundarySupplementaryItems = boundaries

        let sections = sections
        return UICollectionViewCompositionalLayout(sectionProvider: { index, environment in
            var list = StillList.insetGrouped()
            list.headerMode = sections[index].header == nil ? .none : .supplementary
            list.footerMode = sections[index].footer == nil ? .none : .supplementary
            return .list(using: list, layoutEnvironment: environment)
        }, configuration: configuration)
    }

    private func registerViews() {
        let sections = sections

        // In a section where any choice has settings, every choice row keeps room for the
        // settings button, so the checkmarks line up. Where any choice has settings or row
        // actions, every choice row draws the same checkmark, for the same reason.
        func sectionIndices(where test: @escaping (StillMenu.Item.Kind) -> Bool) -> Set<Int> {
            Set(sections.indices.filter { index in sections[index].items.contains { test($0.kind) } })
        }
        let settingsSections = sectionIndices { kind in
            if case .choice(_, _, _, .some) = kind { return true }
            return false
        }
        let accessorySections = sectionIndices { kind in
            if case .choice(_, _, let actions, let settings) = kind { return !actions.isEmpty || settings != nil }
            return false
        }

        cellRegistration = .init { [weak self] cell, indexPath, item in
            cell.accessibilityCustomActions = nil
            switch item.kind {
            case .choice(let detail, let isSelected, let actions, let settings):
                var content = UIListContentConfiguration.subtitleCell()
                content.text = item.title
                content.secondaryText = detail
                content.textProperties.font = StillFont.rounded(.headline)
                content.textProperties.color = Still.label
                content.secondaryTextProperties.font = .preferredFont(forTextStyle: .subheadline)
                content.secondaryTextProperties.color = Still.labelSecondary
                content.textToSecondaryTextVerticalPadding = 4
                content.textProperties.adjustsFontForContentSizeCategory = true
                content.secondaryTextProperties.adjustsFontForContentSizeCategory = true
                cell.contentConfiguration = content
                cell.accessibilityTraits = isSelected ? [.button, .selected] : [.button]

                guard accessorySections.contains(indexPath.section) else {
                    cell.accessories = isSelected ? [.checkmark()] : []
                    break
                }
                var open: (@MainActor () -> Void)?
                if let settings {
                    open = { self?.showSettings(settings(), for: item.title) }
                }
                let accessory = StillMenuChoiceAccessory(
                    isSelected: isSelected, title: item.title, actions: actions,
                    run: { action, source in self?.run(action.handler, confirmation: action.confirmation, from: source) },
                    showsSettingsColumn: settingsSections.contains(indexPath.section),
                    openSettings: open, traits: cell.traitCollection)
                cell.accessories = [.customView(configuration: .init(
                    customView: accessory, placement: .trailing(displayed: .always), maintainsFixedSize: true))]
                // VoiceOver reads the row as one element, so its buttons are offered as actions.
                var custom = zip(actions, accessory.actionButtons).map { action, button in
                    UIAccessibilityCustomAction(name: action.title) { _ in
                        self?.run(action.handler, confirmation: action.confirmation, from: button)
                        return true
                    }
                }
                if let open {
                    custom.append(UIAccessibilityCustomAction(name: "Settings") { _ in
                        open()
                        return true
                    })
                }
                cell.accessibilityCustomActions = custom.isEmpty ? nil : custom

            case .action(let role, _):
                var content = UIListContentConfiguration.cell()
                content.text = item.title
                content.textProperties.font = .preferredFont(forTextStyle: .body)
                content.textProperties.color = role == .destructive ? Still.destructive : Still.tint
                content.textProperties.adjustsFontForContentSizeCategory = true
                cell.contentConfiguration = content
                cell.accessories = []
                cell.accessibilityTraits = [.button]

            case .text:
                var content = UIListContentConfiguration.cell()
                content.text = item.title
                content.textProperties.font = .preferredFont(forTextStyle: .subheadline)
                content.textProperties.color = Still.label
                content.textProperties.adjustsFontForContentSizeCategory = true
                cell.contentConfiguration = content
                cell.accessories = []
                cell.accessibilityTraits = [.staticText]
            }
            cell.backgroundConfiguration = StillList.cellBackground()
        }

        headerRegistration = .init(elementKind: UICollectionView.elementKindSectionHeader) { header, _, indexPath in
            var content = UIListContentConfiguration.groupedHeader()
            content.text = sections[indexPath.section].header
            content.textProperties.color = Still.labelSecondary
            header.contentConfiguration = content
        }
        footerRegistration = .init(elementKind: UICollectionView.elementKindSectionFooter) { footer, _, indexPath in
            var content = UIListContentConfiguration.groupedFooter()
            content.text = sections[indexPath.section].footer
            content.textProperties.color = Still.labelSecondary
            footer.contentConfiguration = content
        }

        let about = menu.about ?? ""
        aboutRegistration = .init(elementKind: Self.aboutKind) { view, _, _ in
            view.configure(text: about, style: .subheadline, color: Still.label,
                           insets: UIEdgeInsets(top: 20, left: 20, bottom: 8, right: 20))
        }
        let credits = menu.footer.joined(separator: "\n")
        creditsRegistration = .init(elementKind: Self.creditsKind) { view, _, _ in
            view.configure(text: credits, style: .footnote, color: Still.labelSecondary,
                           insets: UIEdgeInsets(top: 12, left: 20, bottom: 24, right: 20))
        }
    }

    // MARK: Data source

    func numberOfSections(in collectionView: UICollectionView) -> Int { sections.count }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        sections[section].items.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath,
                                                     item: sections[indexPath.section].items[indexPath.item])
    }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String,
                        at indexPath: IndexPath) -> UICollectionReusableView {
        switch kind {
        case Self.aboutKind:
            collectionView.dequeueConfiguredReusableSupplementary(using: aboutRegistration, for: indexPath)
        case Self.creditsKind:
            collectionView.dequeueConfiguredReusableSupplementary(using: creditsRegistration, for: indexPath)
        case UICollectionView.elementKindSectionFooter:
            collectionView.dequeueConfiguredReusableSupplementary(using: footerRegistration, for: indexPath)
        default:
            collectionView.dequeueConfiguredReusableSupplementary(using: headerRegistration, for: indexPath)
        }
    }

    // MARK: Selection

    func collectionView(_ collectionView: UICollectionView, shouldHighlightItemAt indexPath: IndexPath) -> Bool {
        sections[indexPath.section].items[indexPath.item].handler != nil
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        let item = sections[indexPath.section].items[indexPath.item]
        guard let handler = item.handler else { return }

        var confirmation: StillMenu.Confirmation?
        if case .action(_, let asked) = item.kind { confirmation = asked }
        run(handler, confirmation: confirmation, from: collectionView.cellForItem(at: indexPath))
    }

    /// Asks first when there is a confirmation, then closes the menu and acts.
    private func run(_ handler: @escaping @MainActor () -> Void, confirmation: StillMenu.Confirmation?,
                     from source: UIView?) {
        guard let confirmation else {
            close(then: handler)
            return
        }
        let alert = UIAlertController(title: confirmation.title, message: confirmation.message,
                                      preferredStyle: .actionSheet)
        let style: UIAlertAction.Style = confirmation.isDestructive ? .destructive : .default
        alert.addAction(UIAlertAction(title: confirmation.confirm, style: style) { [weak self] _ in
            self?.close(then: handler)
        })
        alert.addAction(UIAlertAction(title: confirmation.cancel, style: .cancel))
        // On iPad the action sheet points at the row or button it asks about.
        if let popover = alert.popoverPresentationController, let source {
            popover.sourceView = source
            popover.sourceRect = source.bounds
        }
        present(alert, animated: true)
    }

    /// Closes the menu, then acts, so the action's effect is seen.
    private func close(then handler: @escaping @MainActor () -> Void) {
        guard let presenter = presentingViewController else {
            handler()
            return
        }
        presenter.dismiss(animated: true) {
            NotificationCenter.default.post(name: .stillMenuDidClose, object: nil)
            handler()
        }
    }

    /// Pushes a mode's settings onto the menu.
    private func showSettings(_ settings: UIViewController, for title: String) {
        if settings.title == nil && settings.navigationItem.title == nil {
            settings.title = title
        }
        navigationController?.pushViewController(settings, animated: true)
    }

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        NotificationCenter.default.post(name: .stillMenuDidClose, object: nil)
    }
}

/// The trailing end of a choice row in a section with row actions or settings: the row's
/// action buttons, then the checkmark (kept in place but invisible on rows that are not
/// current, so checkmarks line up), then, in a section with settings, the settings button
/// (likewise kept in place on modes without settings).
final class StillMenuChoiceAccessory: UIView {
    private static let buttonSide: CGFloat = 44

    private let checkmark = UIImageView()
    private let button = UIButton(configuration: .plain())
    /// One per row action, in order. The popover anchor for a confirmation.
    private(set) var actionButtons: [UIButton] = []

    init(isSelected: Bool, title: String, actions: [StillMenu.RowAction],
         run: @escaping @MainActor (StillMenu.RowAction, UIView) -> Void,
         showsSettingsColumn: Bool, openSettings: (@MainActor () -> Void)?, traits: UITraitCollection) {
        super.init(frame: .zero)
        let font = UIFont.preferredFont(forTextStyle: .body, compatibleWith: traits)
        let symbols = UIImage.SymbolConfiguration(font: font)

        // Drawn in the inherited tint: they are things to tap.
        actionButtons = actions.map { action in
            var configuration = UIButton.Configuration.plain()
            if let symbol = action.symbol {
                configuration.image = UIImage(systemName: symbol)
                configuration.preferredSymbolConfigurationForImage = symbols
                configuration.contentInsets = .zero
            } else {
                configuration.title = action.title
                configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                    var outgoing = incoming
                    outgoing.font = font
                    return outgoing
                }
                configuration.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: StillSpace.s2,
                                                                      bottom: 0, trailing: StillSpace.s2)
            }
            let actionButton = UIButton(configuration: configuration)
            actionButton.accessibilityLabel = action.title
            actionButton.addAction(UIAction { [weak actionButton] _ in
                guard let actionButton else { return }
                run(action, actionButton)
            }, for: .primaryActionTriggered)
            addSubview(actionButton)
            return actionButton
        }

        checkmark.image = UIImage(systemName: "checkmark",
                                  withConfiguration: symbols.applying(UIImage.SymbolConfiguration(weight: .semibold)))
        checkmark.contentMode = .center
        checkmark.alpha = isSelected ? 1 : 0
        checkmark.isAccessibilityElement = false
        addSubview(checkmark)

        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(systemName: "gearshape")
        // Drawn in the inherited tint: it is something to tap.
        configuration.preferredSymbolConfigurationForImage = symbols
        configuration.contentInsets = .zero
        button.configuration = configuration
        button.accessibilityLabel = "\(title) settings"
        if let openSettings {
            button.addAction(UIAction { _ in openSettings() }, for: .primaryActionTriggered)
        } else {
            button.alpha = 0
            button.isUserInteractionEnabled = false
            button.isAccessibilityElement = false
        }
        button.isHidden = !showsSettingsColumn
        addSubview(button)

        // Each button a full 44pt target, laid out leading to trailing.
        let checkSize = checkmark.intrinsicContentSize
        let height = max(Self.buttonSide, checkSize.height)
        var x: CGFloat = 0
        for actionButton in actionButtons {
            let width = max(Self.buttonSide, actionButton.intrinsicContentSize.width)
            actionButton.frame = CGRect(x: x, y: (height - Self.buttonSide) / 2, width: width, height: Self.buttonSide)
            x += width
        }
        if !actionButtons.isEmpty { x += StillSpace.s1 }
        checkmark.frame = CGRect(x: x, y: (height - checkSize.height) / 2,
                                 width: checkSize.width, height: checkSize.height)
        x += checkSize.width
        if showsSettingsColumn {
            x += StillSpace.s1
            // The gear sits at the centre of its target.
            button.frame = CGRect(x: x, y: (height - Self.buttonSide) / 2,
                                  width: Self.buttonSide, height: Self.buttonSide)
            x += Self.buttonSide
        }
        frame.size = CGSize(width: x, height: height)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override var intrinsicContentSize: CGSize { frame.size }
}

/// Centred text above or below the menu's list. A text view rather than a label, so links in
/// the credits can be tapped.
final class StillMenuTextView: UICollectionReusableView {
    private let textView = UITextView()
    private var insetConstraints: [NSLayoutConstraint] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.adjustsFontForContentSizeCategory = true
        textView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(textView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func configure(text: String, style: UIFont.TextStyle, color: UIColor, insets: UIEdgeInsets) {
        let font = UIFont.preferredFont(forTextStyle: style)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color, .paragraphStyle: paragraph]

        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        let parsed = (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
        let string = NSMutableAttributedString(parsed)
        string.addAttributes(attributes, range: NSRange(location: 0, length: string.length))
        textView.attributedText = string
        textView.linkTextAttributes = [.foregroundColor: Still.tint, .underlineStyle: NSUnderlineStyle.single.rawValue]

        NSLayoutConstraint.deactivate(insetConstraints)
        insetConstraints = [
            textView.topAnchor.constraint(equalTo: topAnchor, constant: insets.top),
            textView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: insets.left),
            textView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -insets.right),
            textView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -insets.bottom),
        ]
        NSLayoutConstraint.activate(insetConstraints)
    }
}

// MARK: - Taps

/// A tap with several fingers. The series uses one: a two-finger tap opens the menu. A
/// mode's settings live in the menu, and undo is a shake (`addStillUndo(action:)`).
///
/// It recognises alongside the app's own gestures and never cancels their touches, so a drag
/// or a flick under one finger carries on. A tap with more fingers than it asks for fails it,
/// so a three-finger tap never counts as a two-finger one.
///
/// VoiceOver keeps multi-finger taps for itself, so give VoiceOver the same things as
/// accessibility custom actions ("Open menu", and `StillShakeToUndo.accessibilityAction`), and
/// the magic tap (a two-finger double tap) for opening the menu.
@MainActor
public final class StillTapGesture: UITapGestureRecognizer, UIGestureRecognizerDelegate {
    private let action: @MainActor () -> Void

    public init(fingers: Int, action: @escaping @MainActor () -> Void) {
        self.action = action
        super.init(target: nil, action: nil)
        addTarget(self, action: #selector(recognized))
        numberOfTouchesRequired = fingers
        cancelsTouchesInView = false
        delegate = self
    }

    @objc private func recognized() { action() }

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                                  shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        true
    }
}

public extension UIView {
    /// Calls `action` when `fingers` fingers tap this view. See `StillTapGesture`.
    @MainActor
    @discardableResult
    func addStillTap(fingers: Int, action: @escaping @MainActor () -> Void) -> StillTapGesture {
        let gesture = StillTapGesture(fingers: fingers, action: action)
        addGestureRecognizer(gesture)
        return gesture
    }
}

// MARK: - Hints

/// The quiet pebble that teaches the series gestures. It fades in after a pause, shows its
/// message, and fades away. It never takes touches and VoiceOver skips it (VoiceOver users
/// get the gestures as actions instead). It is the one thing besides the game that a game
/// screen may show, and only for a moment.
///
/// When a game begins (on launch, and after switching mode), call `playGameHint(canUndo:)`:
/// "A two-finger tap opens the menu.", with "Shake your device to undo." added when the mode
/// supports undo. Opening the menu stops it. Place the view where it covers nothing being
/// played with, or use `pinned(to:)` for the bottom of the screen.
@MainActor
public final class StillHintView: UIView {
    /// How long after `play(_:)` the first message fades in.
    public static let delay: TimeInterval = 3
    /// How long each message stays.
    public static let duration: TimeInterval = 3
    /// How long the game hint stays when it also teaches undo: two sentences take longer to read.
    public static let longDuration: TimeInterval = 4.5
    /// The pause between messages.
    public static let gap: TimeInterval = 0.4

    private let label = UILabel()
    private var sequence: Task<Void, Never>?

    public override init(frame: CGRect) {
        super.init(frame: frame)
        // A moment worth noticing, so the soft tint pebble (docs/brand.md, Shape).
        backgroundColor = Still.tintSoft
        alpha = 0
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        accessibilityElementsHidden = true

        label.font = .preferredFont(forTextStyle: .footnote)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = Still.onTintSoft
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        // The menu teaches itself once it is open.
        NotificationCenter.default.addObserver(self, selector: #selector(menuWillOpen),
                                               name: .stillMenuWillOpen, object: nil)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: topAnchor, constant: StillSpace.s2),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -StillSpace.s2),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: StillSpace.s4),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -StillSpace.s4),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    public override func layoutSubviews() {
        super.layoutSubviews()
        // A capsule while it is one line; continuous corners if large text wraps it.
        stillCorners(min(bounds.height / 2, StillRadius.lg))
    }

    /// The line that teaches the series gestures when a game begins: "A two-finger tap opens
    /// the menu.", plus "Shake your device to undo." when `canUndo` is true and the person
    /// allows shake to undo.
    public static func gameMessage(canUndo: Bool) -> String {
        let menu = "A two-finger tap opens the menu."
        guard canUndo, StillShakeToUndo.isAvailable else { return menu }
        return menu + " Shake your device to undo."
    }

    /// Teaches the series gestures as a game begins: after a pause, `gameMessage(canUndo:)`
    /// fades in, stays, and fades away. Call it on launch and after switching mode, with
    /// whether the new mode supports undo. Replaces anything already playing.
    public func playGameHint(canUndo: Bool) {
        let teachesUndo = canUndo && StillShakeToUndo.isAvailable
        play([Self.gameMessage(canUndo: canUndo)], holding: teachesUndo ? Self.longDuration : Self.duration)
    }

    /// Shows each message in turn, after a pause. Replaces any sequence already playing.
    /// Does nothing while VoiceOver is running.
    public func play(_ messages: [String]) {
        play(messages, holding: Self.duration)
    }

    private func play(_ messages: [String], holding: TimeInterval) {
        stop(animated: false)
        guard !messages.isEmpty, !UIAccessibility.isVoiceOverRunning else { return }
        sequence = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(Self.delay))
                for message in messages {
                    guard let self else { return }
                    self.label.text = message
                    StillMotion.animate { self.alpha = 1 }
                    try await Task.sleep(for: .seconds(holding))
                    StillMotion.animate { self.alpha = 0 }
                    try await Task.sleep(for: .seconds(Self.gap))
                }
            } catch {
                // Stopped.
            }
        }
    }

    @objc private func menuWillOpen() {
        guard sequence != nil else { return }
        stop()
    }

    /// Ends the sequence: call when the gesture is used, or the screen changes. Opening the
    /// menu calls it for you.
    public func stop(animated: Bool = true) {
        sequence?.cancel()
        sequence = nil
        if animated {
            StillMotion.animate { self.alpha = 0 }
        } else {
            alpha = 0
        }
    }

    /// A hint view at the bottom centre of `view`, above the safe area, as a toy shows it.
    public static func pinned(to view: UIView) -> StillHintView {
        let hint = StillHintView()
        hint.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hint)
        NSLayoutConstraint.activate([
            hint.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            hint.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -StillSpace.s6),
            hint.widthAnchor.constraint(lessThanOrEqualToConstant: 300),
            hint.leadingAnchor.constraint(greaterThanOrEqualTo: view.layoutMarginsGuide.leadingAnchor),
            hint.trailingAnchor.constraint(lessThanOrEqualTo: view.layoutMarginsGuide.trailingAnchor),
        ])
        return hint
    }
}
