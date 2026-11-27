import UIKit

// MARK: - Game definition

/// A Still game or toy hosted by `StillGameHost`.
///
/// An app conforms to `StillGame` once and hands it to `StillGameHost.launch(_:in:)`.
/// StillKit owns the window, splash layout and carry-over transition, mode switching,
/// series menu, settings screens, persistence, gestures, shake to undo, hints and
/// VoiceOver wiring. The app writes only its splash and its game modes.
@MainActor
public protocol StillGame {
    /// The app's name. Shown on the splash, read by VoiceOver for the menu title,
    /// and placed in the footer's version line.
    var name: String { get }

    /// Optional logo shown in the series menu's navigation bar (about 24pt tall).
    var logo: UIView? { get }

    /// A line or two about the app, centred above the menu's list.
    var about: String { get }

    /// Optional lines shown in the menu's "How to play" section before the series
    /// gesture notes.
    var howToPlay: [String] { get }

    /// Footer lines shown below the app's version line (for example, author and credits).
    /// Inline markdown links are tappable.
    var credits: [String] { get }

    /// Whether the status bar is hidden while playing. Defaults to `false`.
    var prefersStatusBarHidden: Bool { get }

    /// Builds the cold-launch splash: an optional logo view and an optional element
    /// inside it that carries over into the restored game mode.
    func makeSplash() -> StillSplash

    /// The game's modes in menu order. The first mode is used on first launch.
    var modes: [any StillGameMode] { get }

    /// Optional one-time migration from legacy `UserDefaults` keys into StillKit's
    /// storage, called before the host restores the selected mode and settings.
    func migrateStorage(using migration: StillStorageMigration)
}

public extension StillGame {
    var logo: UIView? { nil }
    var howToPlay: [String] { [] }
    var credits: [String] { [] }
    var prefersStatusBarHidden: Bool { false }
    func makeSplash() -> StillSplash { StillSplash() }
    func migrateStorage(using migration: StillStorageMigration) {}
}

// MARK: - Game mode

/// One playable mode of a `StillGame`.
///
/// A mode owns a single full-screen `UIView` containing its game elements and nothing else:
/// no buttons, bars, toolbars, tab bars, visual effect views or appearance overrides.
@MainActor
public protocol StillGameMode: AnyObject {
    /// Stable identifier used to persist the selected mode and its settings in `UserDefaults`.
    /// Keep this value stable across releases so saved choices survive updates.
    static var id: String { get }

    /// The mode's name in the series menu.
    var title: String { get }

    /// A short description shown beneath the mode's name in the series menu.
    var detail: String? { get }

    /// Whether this mode supports undo. Controls whether the game hint teaches shake to undo
    /// and whether VoiceOver offers the Undo action.
    var supportsUndo: Bool { get }

    /// Whether there is currently a move to undo. Defaults to `supportsUndo`.
    /// Shaking and the menu's fallback Undo row button act only when both `supportsUndo`
    /// and `canUndo` are `true`.
    var canUndo: Bool { get }

    /// Row actions shown as symbol buttons on this mode's row when it is the current mode
    /// (for example `.newGame` or `.clear`). Evaluated fresh each time the menu opens;
    /// omit any action that currently has nothing to act on.
    var actions: [StillModeAction] { get }

    /// Declarative settings for this mode. The host builds the settings screen, applies
    /// changes live and persists them on the device.
    var settings: [StillSetting] { get }

    /// Optional mode-specific how-to-play lines shown when this mode is active.
    var howToPlay: [String] { get }

    /// Screen edges where a swipe should reach the game before system gestures
    /// (for example `.bottom` for a control near the home indicator). Defaults to `[]`.
    var deferredSystemGestureEdges: UIRectEdge { get }

    /// Builds the mode's game view. Must contain game elements only.
    func makeGameView(context: StillModeContext) -> UIView

    /// Where the splash's carried element should land in `gameView`, given its starting frame
    /// converted into `gameView` coordinates. Return `nil` to fade the element out with the
    /// rest of the splash.
    func splashLanding(in gameView: UIView, carriedFrame: CGRect) -> StillSplashLanding?

    /// Called when this mode becomes active and ready for play (after the splash finishes on
    /// cold launch, or right after switching modes). The host plays the game hint alongside this.
    func begin()

    /// Called when the host switches away from this mode.
    func end()

    /// Called immediately when one of this mode's settings changes in the menu.
    func settingDidChange(key: String, context: StillModeContext)

    /// Called on device shake (or via VoiceOver or the menu's fallback Undo button) when
    /// `supportsUndo` and `canUndo` are `true`.
    func undo()
}

public extension StillGameMode {
    var detail: String? { nil }
    var supportsUndo: Bool { false }
    var canUndo: Bool { supportsUndo }
    var actions: [StillModeAction] { [] }
    var settings: [StillSetting] { [] }
    var howToPlay: [String] { [] }
    var deferredSystemGestureEdges: UIRectEdge { [] }
    func splashLanding(in gameView: UIView, carriedFrame: CGRect) -> StillSplashLanding? { nil }
    func end() {}
    func settingDidChange(key: String, context: StillModeContext) {}
    func undo() {}
}

extension StillGameMode {
    var modeID: String { Self.id }
}

// MARK: - Mode context

/// Read-only context handed to a `StillGameMode` by the host.
///
/// Gives a mode access to its persisted settings without exposing any view controller
/// or presentation APIs.
@MainActor
public final class StillModeContext {
    /// Reads this mode's persisted setting values, falling back to their declared defaults.
    public let settings: StillSettingsReader

    private let onDeferredEdgesChanged: @MainActor () -> Void

    init(settings: StillSettingsReader, onDeferredEdgesChanged: @escaping @MainActor () -> Void = {}) {
        self.settings = settings
        self.onDeferredEdgesChanged = onDeferredEdgesChanged
    }

    /// Tells the host to re-read `deferredSystemGestureEdges` for the current mode.
    public func setNeedsUpdateOfDeferredSystemGestureEdges() {
        onDeferredEdgesChanged()
    }
}

// MARK: - Mode actions and confirmation

/// A symbol action shown on the current mode's row in the series menu.
///
/// Symbols are fixed across the series (docs/brand.md): starting over, whether a new round
/// or clearing the board, always uses `arrow.clockwise`. Undo (`arrow.uturn.backward`) is
/// added automatically by the host when Shake to Undo is turned off in system settings.
@MainActor
public struct StillModeAction {
    public var title: String
    public var confirmation: StillConfirmation?
    let symbol: String
    let handler: @MainActor () -> Void

    private init(title: String, symbol: String, confirmation: StillConfirmation?,
                 handler: @escaping @MainActor () -> Void) {
        self.title = title
        self.symbol = symbol
        self.confirmation = confirmation
        self.handler = handler
    }

    /// Starts a new round of the mode. Drawn with `arrow.clockwise`.
    public static func newGame(title: String? = nil, confirmation: StillConfirmation? = nil,
                               action: @escaping @MainActor () -> Void) -> StillModeAction {
        StillModeAction(title: title ?? StillSeriesCopy.newGame,
                        symbol: "arrow.clockwise",
                        confirmation: confirmation,
                        handler: action)
    }

    /// Clears the board or canvas. Drawn with `arrow.clockwise`.
    public static func clear(title: String? = nil, confirmation: StillConfirmation? = nil,
                             action: @escaping @MainActor () -> Void) -> StillModeAction {
        StillModeAction(title: title ?? StillSeriesCopy.clearBoard,
                        symbol: "arrow.clockwise",
                        confirmation: confirmation,
                        handler: action)
    }
}

/// The confirmation sheet presented before a destructive or progress-losing action runs.
public struct StillConfirmation: Sendable {
    public var title: String
    public var message: String?
    public var confirm: String
    public var cancel: String
    public var isDestructive: Bool

    public init(_ title: String, message: String? = nil, confirm: String,
                cancel: String? = nil, isDestructive: Bool = true) {
        self.title = title
        self.message = message
        self.confirm = confirm
        self.cancel = cancel ?? StillSeriesCopy.cancel
        self.isDestructive = isDestructive
    }
}

// MARK: - Splash

/// The cold-launch splash configuration returned by `StillGame.makeSplash()`.
///
/// StillKit lays out the logo and app name on `Still.canvas` (name in `StillFont.rounded`),
/// holds briefly, and then carries `carriedView` into the restored game mode's landing place
/// while the rest of the splash fades away. Under Reduce Motion, the splash crossfades without
/// movement.
@MainActor
public struct StillSplash {
    /// Optional logo view centred on `Still.canvas`.
    public var logo: UIView?

    /// Whether StillKit renders `game.name` beneath `logo` in `StillFont.rounded(.largeTitle)`.
    /// Defaults to `true`. Set to `false` when `logo` itself is the app's wordmark.
    /// VoiceOver always announces `game.name`.
    public var showsName: Bool

    /// An optional element (typically a subview of `logo`, or `logo` itself) that moves from
    /// its place on the splash to the restored mode's landing frame while the rest of the
    /// splash fades away.
    public var carriedView: UIView?

    public init(logo: UIView? = nil, showsName: Bool = true, carriedView: UIView? = nil) {
        self.logo = logo
        self.showsName = showsName
        self.carriedView = carriedView
    }
}

/// Where the splash's carried element lands inside a mode's game view.
@MainActor
public struct StillSplashLanding {
    /// Destination frame in the game view's coordinate space.
    public var targetFrame: CGRect

    /// Optional view in the game view that the carried element becomes. Hidden while the
    /// carried element is in flight and revealed when it arrives.
    public weak var targetView: UIView?

    /// Called when the carried element arrives at `targetFrame` (or just before the crossfade
    /// under Reduce Motion). Receives the carried view so the mode can adopt it or reveal its
    /// own game piece.
    public var onArrival: (@MainActor (_ carriedView: UIView) -> Void)?

    /// Lands the carried element at `targetFrame` (in the game view's coordinates).
    public init(frame targetFrame: CGRect, onArrival: (@MainActor (_ carriedView: UIView) -> Void)? = nil) {
        self.targetFrame = targetFrame
        self.targetView = nil
        self.onArrival = onArrival
    }

    /// Lands the carried element directly onto `targetView` inside `gameView`.
    /// StillKit converts `targetView`'s bounds into `gameView`, hides `targetView` while the
    /// carried element is in flight, and restores it on arrival.
    public init(onto targetView: UIView, in gameView: UIView,
                onArrival: (@MainActor (_ carriedView: UIView) -> Void)? = nil) {
        self.targetFrame = targetView.convert(targetView.bounds, to: gameView)
        self.targetView = targetView
        self.onArrival = onArrival
    }
}
