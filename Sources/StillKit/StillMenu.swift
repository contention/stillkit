import UIKit

// MARK: - The menu
//
// A full-screen game or toy has no bars to hold its actions, so the series gives it one
// menu, opened by a two-finger tap: the app's logo in the navigation bar, a line about the
// app, an inset-grouped list (game modes, then the current mode's actions and how to play
// it), and the version and credits at the foot. See docs/uikit.md, step 6.

/// The series menu. Describe it, then call `present(from:)`.
///
/// ```swift
/// let menu = StillMenu(
///     title: "minibalism",
///     logo: LogoView(pointSize: 24),
///     about: "No points. No aims. Just a tiny space to bounce, breathe, and be.",
///     sections: [
///         .init("Game mode", items: modes.map { mode in
///             .choice(mode.name, detail: mode.summary, isSelected: mode == current) { switchTo(mode) }
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
            case choice(detail: String?, isSelected: Bool)
            case action(role: Role, confirmation: Confirmation?)
            case text
        }

        let title: String
        let kind: Kind
        let handler: (@MainActor () -> Void)?

        /// One of a set to choose between, such as a game mode: its name in rounded type,
        /// what it is beneath, and a checkmark when it is the current one.
        public static func choice(_ title: String, detail: String? = nil, isSelected: Bool,
                                  action: @escaping @MainActor () -> Void) -> Item {
            Item(title: title, kind: .choice(detail: detail, isSelected: isSelected), handler: action)
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
        let navigation = UINavigationController(rootViewController: StillMenuViewController(menu: self))
        if let sheet = navigation.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
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
final class StillMenuViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {
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
        cellRegistration = .init { cell, _, item in
            switch item.kind {
            case .choice(let detail, let isSelected):
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
                cell.accessories = isSelected ? [.checkmark()] : []
                cell.accessibilityTraits = isSelected ? [.button, .selected] : [.button]

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

        let sections = sections
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

        if case .action(_, let confirmation?) = item.kind {
            let alert = UIAlertController(title: confirmation.title, message: confirmation.message,
                                          preferredStyle: .actionSheet)
            let style: UIAlertAction.Style = confirmation.isDestructive ? .destructive : .default
            alert.addAction(UIAlertAction(title: confirmation.confirm, style: style) { [weak self] _ in
                self?.close(then: handler)
            })
            alert.addAction(UIAlertAction(title: confirmation.cancel, style: .cancel))
            // On iPad the action sheet points at the row it asks about.
            if let popover = alert.popoverPresentationController, let cell = collectionView.cellForItem(at: indexPath) {
                popover.sourceView = cell
                popover.sourceRect = cell.bounds
            }
            present(alert, animated: true)
        } else {
            close(then: handler)
        }
    }

    /// Closes the menu, then acts, so the action's effect is seen.
    private func close(then handler: @escaping @MainActor () -> Void) {
        guard let presenter = presentingViewController else {
            handler()
            return
        }
        presenter.dismiss(animated: true) { handler() }
    }
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

/// A tap with several fingers, for the series' gestures: two fingers open the menu, three
/// do the current mode's own thing (its settings, or undo).
///
/// It recognises alongside the app's own gestures and never cancels their touches, so a drag
/// or a flick under one finger carries on. A tap with more fingers than it asks for fails it,
/// so a three-finger tap never counts as a two-finger one.
///
/// VoiceOver keeps multi-finger taps for itself, so give VoiceOver the same things as
/// accessibility custom actions ("Open menu"), and the magic tap (a two-finger double tap) for
/// opening the menu.
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

/// The quiet pebble that teaches a gesture: "Two-finger tap for the menu". It fades in after
/// a pause, shows each message in turn, and fades away. It never takes touches and VoiceOver
/// skips it (VoiceOver users get the gestures as actions instead).
///
/// Show hints until the gesture has been used once, then stop. Place the view where it covers
/// nothing being played with, or use `pinned(to:)` for the bottom of a toy's screen.
@MainActor
public final class StillHintView: UIView {
    /// How long after `play(_:)` the first message fades in.
    public static let delay: TimeInterval = 3
    /// How long each message stays.
    public static let duration: TimeInterval = 3
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

    /// Shows each message in turn, after a pause. Replaces any sequence already playing.
    /// Does nothing while VoiceOver is running.
    public func play(_ messages: [String]) {
        stop(animated: false)
        guard !messages.isEmpty, !UIAccessibility.isVoiceOverRunning else { return }
        sequence = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(Self.delay))
                for message in messages {
                    guard let self else { return }
                    self.label.text = message
                    StillMotion.animate { self.alpha = 1 }
                    try await Task.sleep(for: .seconds(Self.duration))
                    StillMotion.animate { self.alpha = 0 }
                    try await Task.sleep(for: .seconds(Self.gap))
                }
            } catch {
                // Stopped.
            }
        }
    }

    /// Ends the sequence: call when the gesture is used, or the screen changes.
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
