import UIKit

// MARK: - Taps

/// A tap with several fingers. The series uses one: a two-finger tap opens the menu. A
/// mode's settings live in the menu, and undo is a shake (`addStillUndo(action:)`).
///
/// It recognises alongside the app's own gestures and never cancels their touches, so a drag
/// or a flick under one finger carries on. A tap with more fingers than it asks for fails it,
/// so a three-finger tap never counts as a two-finger one.
///
/// VoiceOver keeps multi-finger taps for itself, so the host also exposes "Open menu" and
/// "Undo" as accessibility custom actions and maps the magic tap to opening the menu.
@MainActor
final class StillTapGesture: UITapGestureRecognizer, UIGestureRecognizerDelegate {
    private let action: @MainActor () -> Void

    init(fingers: Int, action: @escaping @MainActor () -> Void) {
        self.action = action
        super.init(target: nil, action: nil)
        addTarget(self, action: #selector(recognized))
        numberOfTouchesRequired = fingers
        cancelsTouchesInView = false
        delegate = self
    }

    @objc private func recognized() { action() }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        true
    }
}

extension UIView {
    /// Calls `action` when `fingers` fingers tap this view. Internal to `StillGameHost`.
    @MainActor
    @discardableResult
    func addStillTap(fingers: Int, action: @escaping @MainActor () -> Void) -> StillTapGesture {
        let gesture = StillTapGesture(fingers: fingers, action: action)
        addGestureRecognizer(gesture)
        return gesture
    }
}

// MARK: - Hints

/// The quiet pebble that teaches the series gestures. Internal to `StillGameHost`.
@MainActor
final class StillHintView: UIView {
    /// How long after `playGameHint` the message fades in.
    static let delay: TimeInterval = 3
    /// How long the menu-only hint stays.
    static let duration: TimeInterval = 3
    /// How long the game hint stays when it also teaches undo: two sentences take longer to read.
    static let longDuration: TimeInterval = 4.5

    private let label = UILabel()
    private var sequence: Task<Void, Never>?

    override init(frame: CGRect) {
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

    deinit {
        sequence?.cancel()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // A capsule while it is one line; continuous corners if large text wraps it.
        stillCorners(min(bounds.height / 2, StillRadius.lg))
    }

    /// The line that teaches the series gestures when a game begins.
    static func gameMessage(canUndo: Bool) -> String {
        let menu = StillSeriesCopy.hintMenu
        guard canUndo, StillShakeToUndo.isAvailable else { return menu }
        return menu + " " + StillSeriesCopy.hintUndo
    }

    /// Teaches the series gestures as a game begins. Does nothing while VoiceOver is running.
    func playGameHint(canUndo: Bool) {
        stop(animated: false)
        guard !UIAccessibility.isVoiceOverRunning else { return }

        let teachesUndo = canUndo && StillShakeToUndo.isAvailable
        let message = Self.gameMessage(canUndo: canUndo)
        let holding = teachesUndo ? Self.longDuration : Self.duration

        sequence = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: .seconds(Self.delay))
                guard let self, !Task.isCancelled else { return }
                self.label.text = message
                StillMotion.animate { self.alpha = 1 }
            } catch {
                return
            }

            do {
                try await Task.sleep(for: .seconds(holding))
                guard let self, !Task.isCancelled else { return }
                StillMotion.animate { self.alpha = 0 }
                self.sequence = nil
            } catch {
                // Stopped.
            }
        }
    }

    @objc private func menuWillOpen() {
        guard sequence != nil else { return }
        stop()
    }

    /// Ends the sequence: call when the gesture is used, or the screen changes.
    func stop(animated: Bool = true) {
        sequence?.cancel()
        sequence = nil
        if animated {
            StillMotion.animate { self.alpha = 0 }
        } else {
            alpha = 0
        }
    }

    /// A hint view at the bottom centre of `view`, above the safe area, as a toy shows it.
    static func pinned(to view: UIView) -> StillHintView {
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

// MARK: - Shake to undo

/// Undo by shaking the device, wired internally by `StillGameHost`.
@MainActor
final class StillShakeToUndo: UIView {
    /// Whether a shake undoes. Set from the current mode.
    var isEnabled = true

    /// Whether the person allows shake to undo (Settings > Accessibility > Touch > Shake to
    /// Undo). When false, the host offers undo on the current mode's row in the menu instead.
    static var isAvailable: Bool { UIAccessibility.isShakeToUndoEnabled }

    private let action: @MainActor () -> Void

    init(action: @escaping @MainActor () -> Void) {
        self.action = action
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        accessibilityElementsHidden = true

        // Presenting something can take first responder away; take it back once the game is
        // in front again.
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(listen),
                           name: UIApplication.didBecomeActiveNotification, object: nil)
        center.addObserver(self, selector: #selector(listen), name: .stillMenuDidClose, object: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override var canBecomeFirstResponder: Bool { true }

    override func willMove(toWindow newWindow: UIWindow?) {
        if newWindow == nil && isFirstResponder {
            resignFirstResponder()
        }
        super.willMove(toWindow: newWindow)
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        listen()
    }

    @objc private func listen() {
        guard window != nil, !isFirstResponder, !isCovered else { return }
        becomeFirstResponder()
    }

    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        guard motion == .motionShake else {
            super.motionEnded(motion, with: event)
            return
        }
        // Not passed on: the shake is ours, so the system's undo alert never appears.
        guard isEnabled, Self.isAvailable, window != nil, !isCovered else { return }
        action()
    }

    /// Whether something is presented over this view, such as the menu.
    private var isCovered: Bool {
        var top = window?.rootViewController
        while let presented = top?.presentedViewController, !presented.isBeingDismissed {
            top = presented
        }
        guard let top else { return false }
        return !isDescendant(of: top.view)
    }
}

extension UIView {
    /// Calls `action` when the device is shaken while this view is on screen.
    @MainActor
    @discardableResult
    func addStillUndo(action: @escaping @MainActor () -> Void) -> StillShakeToUndo {
        let undo = StillShakeToUndo(action: action)
        addSubview(undo)
        return undo
    }
}

// MARK: - Internal layout helpers

extension UIView {
    @MainActor
    func pinToEdges(of container: UIView) {
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            leadingAnchor.constraint(equalTo: container.leadingAnchor),
            trailingAnchor.constraint(equalTo: container.trailingAnchor),
            topAnchor.constraint(equalTo: container.topAnchor),
            bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
    }
}

extension UICollectionViewListCell {
    /// Reuses an existing custom subview of type `V` pinned to `contentView.layoutMarginsGuide`,
    /// clearing any list content configuration and applying `StillList.cellBackground()`.
    @MainActor
    func stillHostedView<V: UIView>(make: () -> V) -> V {
        contentConfiguration = nil
        accessories = []
        backgroundConfiguration = StillList.cellBackground()
        if let existing = contentView.subviews.first(where: { $0 is V }) as? V {
            return existing
        }
        let hosted = make()
        hosted.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(hosted)
        let margins = contentView.layoutMarginsGuide
        NSLayoutConstraint.activate([
            hosted.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
            hosted.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
            hosted.topAnchor.constraint(equalTo: margins.topAnchor),
            hosted.bottomAnchor.constraint(equalTo: margins.bottomAnchor),
        ])
        return hosted
    }
}
