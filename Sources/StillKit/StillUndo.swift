import UIKit

// MARK: - Shake to undo
//
// A game or toy's screen shows nothing but the game, so undo cannot be a button. It is a
// gesture, the same in every app in the series: shake the device. See docs/uikit.md, step 6.

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

    /// "Undo", for the game view's `accessibilityCustomActions`.
    var accessibilityAction: UIAccessibilityCustomAction {
        UIAccessibilityCustomAction(name: StillSeriesCopy.undo) { [weak self] _ in
            guard let self, self.isEnabled else { return false }
            self.action()
            return true
        }
    }

    override var canBecomeFirstResponder: Bool { true }

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

extension Notification.Name {
    /// Posted as the series menu is presented.
    static let stillMenuWillOpen = Notification.Name("StillKit.menuWillOpen")
    /// Posted once the series menu has gone, however it was closed.
    static let stillMenuDidClose = Notification.Name("StillKit.menuDidClose")
}
