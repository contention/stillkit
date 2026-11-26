import UIKit

// MARK: - Game host entry point

/// Launches and hosts a `StillGame`.
///
/// An app calls `StillGameHost.launch(MyGame(), in: windowScene)` once in its scene delegate.
/// StillKit creates the window, applies `StillAppearance`, runs the cold-launch splash,
/// hosts each game mode on `Still.canvas`, manages the series menu, settings screens,
/// persistence, gestures, shake to undo, hints and VoiceOver.
@MainActor
public enum StillGameHost {
    /// Creates the window, applies `StillAppearance`, installs the game host as its root
    /// view controller, and makes the window key and visible.
    @discardableResult
    public static func launch(_ game: any StillGame, in windowScene: UIWindowScene) -> UIWindow {
        let window = UIWindow(windowScene: windowScene)
        StillAppearance.apply(to: window)
        window.rootViewController = makeViewController(for: game)
        window.makeKeyAndVisible()
        return window
    }

    /// Builds the game host view controller for embedding (for example, launching a sample
    /// game from a catalogue). Apps should call `launch(_:in:)` from their scene delegate.
    public static func makeViewController(for game: any StillGame) -> UIViewController {
        StillGameHostViewController(game: game, store: StillSettingsStore())
    }
}

// MARK: - Splash timings (internal)

enum StillSplashTiming {
    /// Splash logo and name fade-in duration (normal motion).
    static let fadeIn: TimeInterval = 0.4
    /// Splash fade-in and crossfade duration under Reduce Motion.
    static let reduceMotionFade: TimeInterval = 0.3
    /// Calm pause showing the app name and logo before carrying into the game.
    static let hold: TimeInterval = 1.2
    /// Backdrop and non-carried splash elements fade-out duration during carry.
    static let backdropFadeOut: TimeInterval = 0.4
    /// Spring duration (bounce 0) for the carried element gliding to its landing frame.
    static let carrySpring: TimeInterval = 0.6
}

// MARK: - Debug view-tree auditor (internal)

enum StillGameViewAuditor {
    /// Inspects a mode's view tree and hosting window for forbidden UIKit chrome or
    /// appearance overrides. Returns human-readable violation descriptions (empty when clean).
    @MainActor
    static func audit(viewTree root: UIView, window: UIWindow? = nil, modeID: String) -> [String] {
        var violations: [String] = []

        if let window, window.overrideUserInterfaceStyle != .unspecified {
            violations.append("StillKit [\(modeID)]: window.overrideUserInterfaceStyle must remain .unspecified.")
        }

        func walk(_ view: UIView) {
            if view is UIButton {
                violations.append("StillKit [\(modeID)]: mode view tree must not contain UIButton (\(type(of: view))).")
            }
            if view is UINavigationBar {
                violations.append("StillKit [\(modeID)]: mode view tree must not contain UINavigationBar.")
            }
            if view is UIToolbar {
                violations.append("StillKit [\(modeID)]: mode view tree must not contain UIToolbar.")
            }
            if view is UITabBar {
                violations.append("StillKit [\(modeID)]: mode view tree must not contain UITabBar.")
            }
            if view is UIVisualEffectView {
                violations.append("StillKit [\(modeID)]: mode view tree must not contain UIVisualEffectView.")
            }
            if view.overrideUserInterfaceStyle != .unspecified {
                violations.append("StillKit [\(modeID)]: \(type(of: view)) sets overrideUserInterfaceStyle; follow the system appearance.")
            }
            for subview in view.subviews {
                walk(subview)
            }
        }

        walk(root)
        return violations
    }

    @MainActor
    static func assertClean(viewTree root: UIView, window: UIWindow?, modeID: String) {
        #if DEBUG
        let violations = audit(viewTree: root, window: window, modeID: modeID)
        if !violations.isEmpty {
            assertionFailure(violations.joined(separator: "\n"))
        }
        #endif
    }
}

// MARK: - Host view controller (internal)

@MainActor
final class StillGameHostViewController: UIViewController {
    private let game: any StillGame
    private let store: StillSettingsStore
    private let modes: [any StillGameMode]

    private var currentMode: (any StillGameMode)?
    private var currentGameView: UIView?
    private var modeContexts: [String: StillModeContext] = [:]

    private let gameContainer = StillGameContainerView()
    private lazy var hintView = StillHintView.pinned(to: view)
    private var undoView: StillShakeToUndo?

    // Cold-launch splash state
    private var hasPlayedSplash = false
    private var isPlayingSplash = false
    private var splashTask: Task<Void, Never>?
    private var splashBackdrop: UIView?
    private var splashContentStack: UIStackView?
    private var splashData: StillSplash?

    init(game: any StillGame, store: StillSettingsStore) {
        self.game = game
        self.store = store
        self.modes = game.modes
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    deinit {
        splashTask?.cancel()
    }

    override var prefersStatusBarHidden: Bool {
        game.prefersStatusBarHidden
    }

    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge {
        currentMode?.deferredSystemGestureEdges ?? []
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Still.canvas

        // Run any one-time storage migration before reading saved mode or settings.
        game.migrateStorage(using: StillStorageMigration(store: store))

        // Build per-mode contexts.
        for mode in modes {
            let reader = StillSettingsReader(modeID: mode.modeID, settings: mode.settings, store: store)
            modeContexts[mode.modeID] = StillModeContext(settings: reader) { [weak self] in
                self?.setNeedsUpdateOfScreenEdgesDeferringSystemGestures()
            }
        }

        // Full-screen container for the active mode's view.
        gameContainer.backgroundColor = Still.canvas
        gameContainer.translatesAutoresizingMaskIntoConstraints = false
        gameContainer.onMagicTap = { [weak self] in self?.openMenu() ?? false }
        view.addSubview(gameContainer)
        NSLayoutConstraint.activate([
            gameContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            gameContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            gameContainer.topAnchor.constraint(equalTo: view.topAnchor),
            gameContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        // Two-finger tap opens the series menu.
        view.addStillTap(fingers: 2) { [weak self] in
            self?.openMenu()
        }

        // Shake to undo calls the active mode when it supports undo and has something to undo.
        undoView = view.addStillUndo { [weak self] in
            self?.performUndo()
        }

        // Ensure hint sits above the game container.
        _ = hintView

        // Restore the previously selected mode, or fall back to the first mode.
        let restored = restoredMode()
        if let restored {
            mountMode(restored, animated: false, startImmediately: false)
        }

        // Prepare the cold-launch splash over the mounted game view.
        installSplash()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !hasPlayedSplash else { return }
        hasPlayedSplash = true
        playSplash()
    }

    override func accessibilityPerformMagicTap() -> Bool {
        openMenu()
    }

    // MARK: - Mode lifecycle

    private func restoredMode() -> (any StillGameMode)? {
        if let savedID = store.selectedModeID,
           let match = modes.first(where: { $0.modeID == savedID }) {
            return match
        }
        return modes.first
    }

    private func context(for mode: any StillGameMode) -> StillModeContext {
        if let existing = modeContexts[mode.modeID] {
            return existing
        }
        let reader = StillSettingsReader(modeID: mode.modeID, settings: mode.settings, store: store)
        let created = StillModeContext(settings: reader) { [weak self] in
            self?.setNeedsUpdateOfScreenEdgesDeferringSystemGestures()
        }
        modeContexts[mode.modeID] = created
        return created
    }

    /// Swaps the active mode immediately behind the dismissing menu sheet so the previous
    /// mode never flashes as the sheet slides away.
    private func prepareModeSwitch(to nextMode: any StillGameMode) -> Bool {
        guard currentMode?.modeID != nextMode.modeID else { return false }
        currentMode?.end()
        store.selectedModeID = nextMode.modeID
        mountMode(nextMode, animated: false, startImmediately: false)
        nextMode.begin()
        return true
    }

    /// Runs once the menu sheet has finished dismissing after a mode switch.
    private func completeModeSwitch(to nextMode: any StillGameMode) {
        hintView.playGameHint(canUndo: nextMode.supportsUndo)
        if let gameView = currentGameView {
            UIAccessibility.post(notification: .screenChanged, argument: gameView)
        }
    }

    private func mountMode(_ mode: any StillGameMode, animated: Bool, startImmediately: Bool) {
        let previousView = currentGameView
        let ctx = context(for: mode)
        let nextView = mode.makeGameView(context: ctx)
        nextView.translatesAutoresizingMaskIntoConstraints = false

        gameContainer.addSubview(nextView)
        NSLayoutConstraint.activate([
            nextView.leadingAnchor.constraint(equalTo: gameContainer.leadingAnchor),
            nextView.trailingAnchor.constraint(equalTo: gameContainer.trailingAnchor),
            nextView.topAnchor.constraint(equalTo: gameContainer.topAnchor),
            nextView.bottomAnchor.constraint(equalTo: gameContainer.bottomAnchor),
        ])

        currentMode = mode
        currentGameView = nextView
        undoView?.isEnabled = mode.supportsUndo
        setNeedsUpdateOfScreenEdgesDeferringSystemGestures()
        updateVoiceOverActions(for: mode, gameView: nextView)

        view.layoutIfNeeded()
        StillGameViewAuditor.assertClean(viewTree: nextView, window: view.window, modeID: mode.modeID)

        if animated, let previousView {
            nextView.alpha = 0
            StillMotion.animate({
                nextView.alpha = 1
                previousView.alpha = 0
            }, completion: { _ in
                previousView.removeFromSuperview()
            })
        } else {
            previousView?.removeFromSuperview()
        }

        if startImmediately {
            mode.begin()
            hintView.playGameHint(canUndo: mode.supportsUndo)
            UIAccessibility.post(notification: .screenChanged, argument: nextView)
        }
    }

    private func updateVoiceOverActions(for mode: any StillGameMode, gameView: UIView) {
        var hostActions: [UIAccessibilityCustomAction] = [
            UIAccessibilityCustomAction(name: StillSeriesCopy.openMenu) { [weak self] _ in
                self?.openMenu() ?? false
            }
        ]
        if mode.supportsUndo {
            hostActions.append(UIAccessibilityCustomAction(name: StillSeriesCopy.undo) { [weak self] _ in
                self?.performUndo() ?? false
            })
        }

        gameContainer.accessibilityCustomActions = hostActions

        // Preserve any mode-supplied custom actions on the game view itself while appending ours.
        let existing = (gameView.accessibilityCustomActions ?? []).filter { action in
            action.name != StillSeriesCopy.openMenu && action.name != StillSeriesCopy.undo
        }
        gameView.accessibilityCustomActions = existing + hostActions

        // If a mode's root game view has no label and no accessible children, make it an element
        // so VoiceOver can focus it and reach the host's actions.
        if !gameView.isAccessibilityElement && !hasAccessibleDescendant(in: gameView) {
            gameView.isAccessibilityElement = true
            if gameView.accessibilityLabel == nil {
                gameView.accessibilityLabel = "\(game.name), \(mode.title)"
            }
        }
    }

    private func hasAccessibleDescendant(in view: UIView) -> Bool {
        for subview in view.subviews {
            if subview.isAccessibilityElement || hasAccessibleDescendant(in: subview) {
                return true
            }
        }
        return false
    }

    @discardableResult
    private func performUndo() -> Bool {
        guard !isPlayingSplash, let mode = currentMode, mode.supportsUndo, mode.canUndo else {
            return false
        }
        mode.undo()
        return true
    }

    // MARK: - Cold-launch splash

    private func installSplash() {
        let splash = game.makeSplash()
        self.splashData = splash
        isPlayingSplash = true

        let backdrop = UIView()
        backdrop.backgroundColor = Still.canvas
        backdrop.translatesAutoresizingMaskIntoConstraints = false
        backdrop.isAccessibilityElement = true
        backdrop.accessibilityLabel = game.name
        backdrop.accessibilityTraits = .header
        backdrop.accessibilityViewIsModal = true
        view.addSubview(backdrop)
        NSLayoutConstraint.activate([
            backdrop.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backdrop.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backdrop.topAnchor.constraint(equalTo: view.topAnchor),
            backdrop.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = StillSpace.s4
        stack.alpha = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        backdrop.addSubview(stack)

        if let logo = splash.logo {
            logo.translatesAutoresizingMaskIntoConstraints = false
            stack.addArrangedSubview(logo)
        }

        if splash.showsName {
            let nameLabel = UILabel()
            nameLabel.text = game.name
            nameLabel.font = StillFont.rounded(.largeTitle, weight: .semibold)
            nameLabel.textColor = Still.label
            nameLabel.textAlignment = .center
            nameLabel.numberOfLines = 0
            nameLabel.adjustsFontForContentSizeCategory = true
            stack.addArrangedSubview(nameLabel)
        }

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: backdrop.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: backdrop.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: backdrop.layoutMarginsGuide.leadingAnchor,
                                           constant: StillSpace.s4),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: backdrop.layoutMarginsGuide.trailingAnchor,
                                            constant: -StillSpace.s4),
        ])

        self.splashBackdrop = backdrop
        self.splashContentStack = stack
    }

    private func playSplash() {
        guard let backdrop = splashBackdrop, let contentStack = splashContentStack else {
            finishSplash()
            return
        }

        UIAccessibility.post(notification: .screenChanged, argument: backdrop)

        splashTask = Task { @MainActor [weak self] in
            guard let self else { return }

            let fadeIn = UIAccessibility.isReduceMotionEnabled
                ? StillSplashTiming.reduceMotionFade
                : StillSplashTiming.fadeIn

            await withCheckedContinuation { continuation in
                UIView.animate(withDuration: fadeIn, delay: 0, options: [.curveEaseInOut], animations: {
                    contentStack.alpha = 1
                }, completion: { _ in
                    continuation.resume()
                })
            }

            do {
                try await Task.sleep(for: .seconds(StillSplashTiming.hold))
            } catch {
                return
            }

            guard !Task.isCancelled else { return }
            self.transitionSplashToGame()
        }
    }

    private func transitionSplashToGame() {
        guard let backdrop = splashBackdrop else {
            finishSplash()
            return
        }

        view.layoutIfNeeded()

        let carriedView = splashData?.carriedView
        let gameView = currentGameView
        let mode = currentMode

        var landing: StillSplashLanding?
        var startFrameInHost: CGRect = .zero

        if let carriedView, let gameView, let mode {
            startFrameInHost = carriedView.convert(carriedView.bounds, to: view)
            let startFrameInGame = carriedView.convert(carriedView.bounds, to: gameView)
            landing = mode.splashLanding(in: gameView, carriedFrame: startFrameInGame)
        }

        let canCarry = !UIAccessibility.isReduceMotionEnabled
            && carriedView != nil
            && landing != nil
            && gameView != nil
            && startFrameInHost.width > 0
            && startFrameInHost.height > 0

        if canCarry, let carriedView, let landing, let gameView {
            // Detach the carried element onto the host view so the rest of the splash can fade.
            carriedView.removeFromSuperview()
            carriedView.translatesAutoresizingMaskIntoConstraints = true
            carriedView.frame = startFrameInHost
            view.addSubview(carriedView)

            landing.targetView?.alpha = 0
            let targetFrameInHost = gameView.convert(landing.targetFrame, to: view)
            let scaleX = targetFrameInHost.width / startFrameInHost.width
            let scaleY = targetFrameInHost.height / startFrameInHost.height

            UIView.animate(withDuration: StillSplashTiming.backdropFadeOut, delay: 0, options: [.curveEaseOut]) {
                backdrop.alpha = 0
            }

            UIView.animate(springDuration: StillSplashTiming.carrySpring, bounce: 0, animations: {
                carriedView.center = CGPoint(x: targetFrameInHost.midX, y: targetFrameInHost.midY)
                carriedView.transform = CGAffineTransform(scaleX: scaleX, y: scaleY)
            }, completion: { [weak self] _ in
                guard let self else { return }
                landing.targetView?.alpha = 1
                landing.onArrival?(carriedView)
                if carriedView.superview === self.view {
                    carriedView.removeFromSuperview()
                }
                backdrop.removeFromSuperview()
                self.splashBackdrop = nil
                self.splashContentStack = nil
                self.splashData = nil
                self.finishSplash()
            })
        } else {
            // Reduce Motion, or no landing place: plain crossfade with no movement.
            if let carriedView {
                landing?.onArrival?(carriedView)
            }
            StillMotion.animate({
                backdrop.alpha = 0
            }, completion: { [weak self] _ in
                guard let self else { return }
                backdrop.removeFromSuperview()
                self.splashBackdrop = nil
                self.splashContentStack = nil
                self.splashData = nil
                self.finishSplash()
            })
        }
    }

    private func finishSplash() {
        isPlayingSplash = false
        guard let mode = currentMode, let gameView = currentGameView else { return }
        StillGameViewAuditor.assertClean(viewTree: gameView, window: view.window, modeID: mode.modeID)
        mode.begin()
        hintView.playGameHint(canUndo: mode.supportsUndo)
        UIAccessibility.post(notification: .screenChanged, argument: gameView)
    }

    // MARK: - Series menu

    @discardableResult
    private func openMenu() -> Bool {
        guard !isPlayingSplash, presentedViewController == nil else { return false }

        if let mode = currentMode, let gameView = currentGameView {
            StillGameViewAuditor.assertClean(viewTree: gameView, window: view.window, modeID: mode.modeID)
        }

        let menu = buildMenu()
        return menu.present(from: self)
    }

    private func makeModeMenuItem(_ mode: any StillGameMode, activeID: String?) -> StillMenu.Item {
        let isSelected = (mode.modeID == activeID)

        var rowActions: [StillMenu.RowAction] = []
        if isSelected {
            if mode.supportsUndo && mode.canUndo && !StillShakeToUndo.isAvailable {
                rowActions.append(StillMenu.RowAction(StillSeriesCopy.undo, symbol: "arrow.uturn.backward") { [weak self] in
                    _ = self?.performUndo()
                })
            }
            for action in mode.actions {
                let confirmation: StillMenu.Confirmation? = action.confirmation.map {
                    StillMenu.Confirmation($0.title, message: $0.message, confirm: $0.confirm,
                                           cancel: $0.cancel, isDestructive: $0.isDestructive)
                }
                rowActions.append(StillMenu.RowAction(action.title, symbol: action.symbol,
                                                      confirmation: confirmation, action: action.handler))
            }
        }

        let settingsBuilder: (@MainActor () -> UIViewController)?
        if mode.settings.isEmpty {
            settingsBuilder = nil
        } else {
            settingsBuilder = { [weak self] in
                guard let self else { return UIViewController() }
                let ctx = self.context(for: mode)
                return StillModeSettingsViewController(title: mode.title, modeID: mode.modeID,
                                                       settings: mode.settings, store: self.store) { key in
                    mode.settingDidChange(key: key, context: ctx)
                }
            }
        }

        var switched = false
        return StillMenu.Item.choice(mode.title, detail: mode.detail, isSelected: isSelected,
                                     actions: rowActions, settings: settingsBuilder,
                                     beforeClose: { [weak self] in
            switched = self?.prepareModeSwitch(to: mode) ?? false
        }) { [weak self] in
            if switched {
                self?.completeModeSwitch(to: mode)
            }
        }
    }

    private func buildMenu() -> StillMenu {
        let activeID = currentMode?.modeID

        // Section 1: Game modes.
        let modeItems = modes.map { makeModeMenuItem($0, activeID: activeID) }

        // Section 2: How to play (mode lines + app lines + series gesture notes).
        var howToPlayItems: [StillMenu.Item] = []
        if let mode = currentMode {
            howToPlayItems.append(contentsOf: mode.howToPlay.map { .text($0) })
        }
        howToPlayItems.append(contentsOf: game.howToPlay.map { .text($0) })
        howToPlayItems.append(.text(StillSeriesCopy.gestureMenu))
        if currentMode?.supportsUndo == true {
            let undoNote = StillShakeToUndo.isAvailable
                ? StillSeriesCopy.gestureUndoShake
                : StillSeriesCopy.gestureUndoMenu
            howToPlayItems.append(.text(undoNote))
        }

        // Section 3: Shared series section (fixed order, cannot be removed or reordered).
        let seriesItems: [StillMenu.Item] = [
            .text(StillSeriesCopy.seriesPromise),
            .text(StillSeriesCopy.seriesPrivacy),
            .disabled(StillSeriesCopy.seriesMoreApps),
        ]

        let sections: [StillMenu.Section] = [
            StillMenu.Section(StillSeriesCopy.modesHeader, items: modeItems),
            StillMenu.Section(StillSeriesCopy.howToPlayHeader, items: howToPlayItems),
            StillMenu.Section(StillSeriesCopy.seriesSectionTitle, items: seriesItems),
        ]

        let footer = [StillMenu.version(of: game.name)] + game.credits

        return StillMenu(title: game.name, logo: game.logo, about: game.about,
                         sections: sections, footer: footer)
    }
}

// MARK: - Container view for VoiceOver magic tap

@MainActor
private final class StillGameContainerView: UIView {
    var onMagicTap: (@MainActor () -> Bool)?

    override func accessibilityPerformMagicTap() -> Bool {
        onMagicTap?() ?? false
    }
}
