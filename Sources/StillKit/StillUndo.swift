import UIKit

// MARK: - Shake to undo
//
// A game or toy's screen shows nothing but the game, so undo cannot be a button. It is a
// gesture, the same in every app in the series: shake the device. See docs/uikit.md, step 6.

/// Undo by shaking the device, for a game or toy whose current mode can take a move back.
///
/// Add it once to the game's root view, and turn it on and off as the mode changes:
///
/// ```swift
/// undo = view.addStillUndo { [weak self] in self?.game.undo() }
/// undo.isEnabled = mode.supportsUndo
/// ```
///
/// It listens only while its view is in a window and nothing is presented over it, so a
/// shake while the menu is open does nothing. It takes no touches, draws nothing and is
/// hidden from VoiceOver.
///
/// It follows the person's Shake to Undo setting (Settings > Accessibility > Touch). When
/// that is off (`isAvailable` is false), shaking does nothing, the game hint leaves undo out,
/// and the app offers "Undo" in the menu instead. VoiceOver users get `accessibilityAction`.
///
/// To listen for shakes it becomes first responder. Do not use it on a screen with text
/// fields, and do not also register undo with UIKit's `undoManager` on the same screen, or
/// the system's own shake-to-undo alert can appear as well.
@MainActor
public final class StillShakeToUndo: UIView {
    /// Whether a shake undoes. Set it from the current mode, and to false when there is
    /// nothing to undo, so a shake at the start of a round does nothing.
    public var isEnabled = true

    /// Whether the person allows shake to undo (Settings > Accessibility > Touch > Shake to
    /// Undo). When false, offer undo in the menu instead.
    public static var isAvailable: Bool { UIAccessibility.isShakeToUndoEnabled }

    private let action: @MainActor () -> Void

    public init(action: @escaping @MainActor () -> Void) {
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

    /// "Undo", for the game view's `accessibilityCustomActions`. Include it only while the
    /// current mode supports undo.
    public var accessibilityAction: UIAccessibilityCustomAction {
        UIAccessibilityCustomAction(name: "Undo") { [weak self] _ in
            guard let self, self.isEnabled else { return false }
            self.action()
            return true
        }
    }

    public override var canBecomeFirstResponder: Bool { true }

    public override func didMoveToWindow() {
        super.didMoveToWindow()
        listen()
    }

    @objc private func listen() {
        guard window != nil, !isFirstResponder, !isCovered else { return }
        becomeFirstResponder()
    }

    public override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
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

public extension UIView {
    /// Calls `action` when the device is shaken while this view is on screen. See
    /// `StillShakeToUndo`.
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
