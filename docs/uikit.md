# Layering over UIKit

How StillKit sits over UIKit without rebuilding UIKit. Visual primitives live in `Sources/StillKit/StillKit.swift`; the game shell lives in `Sources/StillKit/StillGame.swift`, `StillSetting.swift` and `StillGameHost.swift`.

## The layers

1. **Roles and primitives.** Semantic colours (`Still.tint`, `Still.background`, `Still.canvas`, `Still.label`...), rounded display type (`StillFont.rounded(_:)`), capsule button presets, continuous corners, spacing tokens, bounce-free motion and soft haptics. Views only ever name roles.
2. **Global appearance.** `StillAppearance.apply(to: window)` sets the window tint, navigation titles and the few controls that do not inherit tint in every state.
3. **The game shell (`StillGameHost`).** For every Still game or toy, StillKit owns the entire shell: window setup, cold-launch splash and carry-over animation, mode switching, series menu, declarative mode settings screens, persistence, two-finger tap, shake to undo, hints, VoiceOver and shared series copy. The shell plumbing (`StillMenu`, `StillTapGesture`, `StillHintView`, `StillShakeToUndo`) is internal to the package so every app shares the exact same shell.

## Building a Still game

A game app writes only its `StillGame`, its `StillSplash` and its `StillGameMode`s.

### 1. Launch the host

```swift
// SceneDelegate.swift
import UIKit
import StillKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        window = StillGameHost.launch(MyGame(), in: windowScene)
    }
}
```

`StillGameHost.launch(_:in:)` creates the window, calls `StillAppearance.apply(to:)`, runs any one-time storage migration, restores the saved mode and settings, plays the cold-launch splash and hosts the active mode full screen on `Still.canvas`.

### 2. Define the game and splash

Conform to `StillGame`:

```swift
@MainActor
final class MyGame: StillGame {
    let name = "MyGame"
    var logo: UIView? { MyLogoView(size: 24) }
    let about = "One quiet line about the game."
    let howToPlay = ["Move pieces gently across the canvas."]
    let credits = ["Made by Your Name."]
    let modes: [any StillGameMode] = [DriftMode(), TraceMode()]

    func makeSplash() -> StillSplash {
        // StillKit centres logo and name on Still.canvas, then carries carriedView
        // into the restored mode's splashLanding(in:carriedFrame:) while the rest fades.
        StillSplash(logo: logoContainer, showsName: true, carriedView: pebbleView)
    }
}
```

Set `showsName: false` on `StillSplash` when `logo` itself is the app's wordmark. VoiceOver always announces `game.name`, then moves focus to the game view when the splash ends. Under Reduce Motion, the splash crossfades without movement. The splash runs on cold launch only, never when returning from the background.

### 3. Build each mode

Each mode conforms to `StillGameMode`:

- `static var id: String`: stable persistence key. Never change it after shipping.
- `makeGameView(context:) -> UIView`: returns a plain `UIView` (not a view controller) containing game elements only. No buttons, bars, toolbars, tab bars, visual effect views or `overrideUserInterfaceStyle`. In debug builds, `StillGameHost` asserts that the view tree contains none of these.
- `splashLanding(in:carriedFrame:) -> StillSplashLanding?`: returns where the splash's carried element lands (`StillSplashLanding(onto: view, in: gameView)` or `StillSplashLanding(frame: rect, onArrival: ...)`). Return `nil` if nothing lands in this mode; the element fades with the rest of the splash.
- `supportsUndo`, `canUndo`, `undo()`: declare undo capability and availability. The host wires device shake to `undo()`, teaches it in the game hint when Shake to Undo is on, adds an Undo row button (`arrow.uturn.backward`) when Shake to Undo is off, and exposes Undo to VoiceOver.
- `actions: [StillModeAction]`: symbol actions on the current mode's row (`.newGame` or `.clear`, both drawn as `arrow.clockwise`). Evaluated fresh each time the menu opens; omit any action with nothing to act on. Pass `StillConfirmation` when confirming loses progress.
- `settings: [StillSetting]`: declarative settings (`.toggle`, `.choice`, `.stepper`, `.slider`). The host builds the inset-grouped settings screen, applies changes live with no Save button, persists them in `UserDefaults` on the device, and calls `settingDidChange(key:context:)`. Modes read values from `context.settings` (`bool`, `string`, `int`, `double`).
- `begin()` and `end()`: lifecycle hooks called when a mode becomes active (after the splash on cold launch, or on mode switch) and when leaving a mode.
- `deferredSystemGestureEdges`: return edges (such as `.bottom`) where a swipe should reach the game before system gestures.

### 4. One-time storage migration

When migrating an existing app onto `StillGameHost`, implement `migrateStorage(using:)` on your `StillGame` to copy legacy `UserDefaults` keys into StillKit's keys once without losing saved modes or settings:

```swift
func migrateStorage(using migration: StillStorageMigration) {
    migration.migrateSelectedMode(fromLegacyKey: "selectedMode")
    migration.migrateInt(fromLegacyKey: "Diffusion.ballCount", toMode: "Diffusion", settingKey: "ballCount")
}
```

### 5. What the host builds in the menu

The menu structure is fixed across the series and rebuilt fresh each time a two-finger tap (or VoiceOver action / magic tap) opens it:

1. Logo and title in the navigation bar, `about` centred above the list.
2. **Game mode** section: every mode in `modes` order, current mode checked, row actions on the current mode (including fallback Undo when Shake to Undo is off), and a settings gear on every mode with non-empty `settings`.
3. **How to play** section: the current mode's `howToPlay`, the game's `howToPlay`, and StillKit's localisable gesture notes.
4. **Series** section: StillKit's shared localisable promise, privacy line and disabled "More Still apps" row.
5. **Footer**: version line (`name version (build)`) followed by `credits`.

## Visual primitives (inside game views and non-game apps)

### Appearance setup for non-game apps

```swift
// SceneDelegate.swift (non-game app)
let window = UIWindow(windowScene: windowScene)
StillAppearance.apply(to: window)
window.rootViewController = RootViewController()
window.makeKeyAndVisible()
self.window = window
```

Set the asset catalog's **AccentColor** to `#4B6E68` (Any) and `#99B59D` (Dark). For games, set **LaunchBackground** to `#CAD2C5` (Any) and `#2F3E46` (Dark), matching `Still.canvas`, and point `UILaunchScreen.UIColorName` at `LaunchBackground`.

### Grounds and lists

```swift
view.backgroundColor = Still.background          // plain screens
// or Still.groupedBackground for settings-style lists
// or Still.canvas for game views
```

Lists use `UICollectionView` with `StillList.insetGrouped()` for the layout and `StillList.cellBackground()` in the cell registration.

### What to customise, and what to leave alone

| Element | Do | Leave alone |
| --- | --- | --- |
| Window | `tintColor = Still.tint` | `overrideUserInterfaceStyle` (follow the system) |
| Navigation bar | Title fonts (rounded) and colour | Backgrounds on iOS 26 (Liquid Glass picks up your ground); bar button colours |
| Tab bar | Nothing on iOS 26: selected items follow the tint | Backgrounds, item colours |
| Buttons | `.stillPrimary`, `.stillSecondary`, `.stillPlain`: capsules | System `.glass()` buttons on iOS 26 if used |
| Switch, slider, progress, page control | Tint and track colours (in `apply`) | Thumb shapes, sizes |
| Segmented control | Nothing: selected segment follows the ground | Custom fonts |
| Lists | Grounds, cell background, separator colour | Cell layout, accessories, swipe actions |
| Alerts, action sheets, context menus, share sheet, keyboard | Nothing | Everything. These are the system speaking. |
| Destructive actions | `role: .destructive` (Apple's red) | Never recolour red into the palette |
| SF Symbols | `.hierarchical` rendering, tint or `labelSecondary` | Multicolour, custom-drawn replacements |

### On iOS 26 and Liquid Glass

Navigation bars, toolbars and tab bars float above content as glass, and Apple's guidance (TN3106) is to remove custom bar backgrounds. `StillAppearance` sets titles only on iOS 26, and falls back to opaque `Still.background` bars with no hairline on iOS 18 and earlier.

### Custom elements inside game views

- Colours: roles only. Toys use `Still.canvas`, `pieceStrong`, `pieceMid`, `pieceAmbient`.
- Corners: `view.stillCorners(StillRadius.xl)` (continuous). Buttons: capsules (only outside game modes).
- Type: `StillFont.rounded(.title2)`, `StillFont.numeral()`. Set `adjustsFontForContentSizeCategory = true`.
- Motion: `StillMotion.animate { ... }` (bounce 0; 0.3s crossfade under Reduce Motion).
- Haptics: `StillHaptics.touch()` on contact, `StillHaptics.snap()` as a dragged piece snaps into place, `StillHaptics.tick()` on control detents. Call `StillHaptics.prepare()` when a drag begins.
- Depth: a piece being dragged gets the `shadow-lift` look. Nothing at rest casts a shadow.
- Accessibility: every interactive game piece gets an `accessibilityLabel`; draggable pieces get `.adjustable` where appropriate.
