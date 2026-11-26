# Layering over UIKit

How to put Still on top of UIKit without rebuilding UIKit. The code is `Sources/StillKit/StillKit.swift`; this page explains what it does and why.

## The three layers

1. **Roles.** One file defines semantic colours (`Still.tint`, `Still.background`, `Still.label`…) as dynamic `UIColor`s that resolve per light and dark mode, plus `StillFont.rounded(_:)` for display text. Views only ever name roles. Changing the palette later is a one-file edit.
2. **Global appearance.** Called once per window, before it shows. Sets the window tint, navigation titles and the few controls that do not inherit tint in every state. This is where 80% of the identity comes from, in about forty lines.
3. **Custom elements.** Toys, canvases, sheets, and the series menu, shake to undo and hint (step 6). Built from the same roles, the radius and spacing tokens, the house spring and soft haptics, so they sit next to UIKit's controls without looking foreign.

All three layers ship in this package. Apps add it with Swift Package Manager and `import StillKit`.

## Step 1: set it up once

```swift
// SceneDelegate.swift
func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
           options connectionOptions: UIScene.ConnectionOptions) {
    guard let windowScene = scene as? UIWindowScene else { return }
    let window = UIWindow(windowScene: windowScene)
    StillAppearance.apply(to: window)
    window.rootViewController = RootViewController()
    window.makeKeyAndVisible()
    self.window = window
}
```

Also set the asset catalog's **AccentColor** to the same two values as `tint` (#4b6e68 light, #99b59d dark). That colours the few places that read the accent before your code runs, and keeps storyboards and previews in sync.

## Step 2: grounds on every screen

UIKit's `systemBackground` and friends cannot be redefined globally, so each screen sets its ground from a role. Make it automatic with a base class or a one-liner:

```swift
override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = Still.background          // plain screens
    // or Still.groupedBackground for settings-style lists
}
```

Lists: use `UICollectionView` with `StillList.insetGrouped()` for the layout and `StillList.cellBackground()` in the cell registration.

## Step 3: what to customise, and what to leave alone

| Element | Do | Leave alone |
| --- | --- | --- |
| Window | `tintColor = Still.tint` | `overrideUserInterfaceStyle` (follow the system) |
| Navigation bar | Title fonts (rounded) and colour | Backgrounds on iOS 26 (Liquid Glass picks up your ground); bar button colours |
| Tab bar | Nothing on iOS 26: selected items follow the tint | Backgrounds, item colours |
| Buttons | `.stillPrimary`, `.stillSecondary`, `.stillPlain`: capsules | System `.glass()` buttons on iOS 26 if you use them: let them be glass |
| Switch, slider, progress, page control | Tint and track colours (in `apply`) | Thumb shapes, sizes |
| Segmented control | Nothing: selected segment follows the ground | Custom fonts |
| Lists | Grounds, cell background, separator colour | Cell layout, accessories, swipe actions |
| Alerts, action sheets, context menus, share sheet, keyboard | Nothing | Everything. These are the system speaking. |
| Destructive actions | `role: .destructive` (Apple's red) | Never recolour red into the palette |
| SF Symbols | `.hierarchical` rendering, tint or `labelSecondary` | Multicolour, custom-drawn replacements |

## Step 4: on iOS 26 and Liquid Glass

Navigation bars, toolbars and tab bars float above content as glass, and Apple's own guidance (TN3106) is to stop putting custom backgrounds on them. That suits a calm identity: the glass takes on the Mist or Night ground underneath, and bar buttons draw in neutral glass rather than shouting in the accent. So on iOS 26:

- Do not set bar backgrounds or bar button tint colours. `StillAppearance` sets titles only.
- If one bar action must be prominent (a single Done), use the system's prominent bar button style, which takes the window tint.
- Put a screen's actions in the bar as system bar buttons rather than custom floating buttons. Unrelated actions get their own glass: separate them with a fixed space (`UIBarButtonItem.fixedSpace(_:)`, or `ToolbarSpacer(.fixed)` in SwiftUI). A full-screen game or toy has no bars and no floating controls: its actions go in the series menu (step 6).
- For your own floating controls on screens that are not a game or toy's modes, use the system glass effect (`UIGlassEffect`) rather than a custom blur, untinted or tinted with `Still.tint` at most. A game's modes have none.
- On iOS 18 and earlier the same file draws opaque bars in `Still.background` with no hairline, so the apps look like the same family on older phones.

## Step 5: custom elements

- Colours: roles only. Toys use `Still.canvas`, `pieceStrong`, `pieceMid`, `pieceAmbient`.
- Corners: `view.stillCorners(StillRadius.xl)` (continuous). Buttons: capsules.
- Type: `StillFont.rounded(.title2)`, `StillFont.numeral()`. Set `adjustsFontForContentSizeCategory = true`.
- Motion: `StillMotion.animate { … }` (bounce 0; crossfade under Reduce Motion).
- Haptics: `StillHaptics.touch()` on contact, `StillHaptics.snap()` as a dragged piece snaps into place, `StillHaptics.tick()` on control detents. Call `StillHaptics.prepare()` when a drag begins so the first snap is on time.
- Depth: a piece being dragged gets the `shadow-lift` look (Night at 16% opacity, 24pt blur, 8pt down in light; black at 36% in dark). Nothing at rest casts a shadow.
- Accessibility: every piece gets an `accessibilityLabel`; draggable pieces get `.adjustable` with increment and decrement.

## Step 6: game screens, the menu, undo and hints

A game or toy runs full screen, and each of its modes (the versions of the game) shows **the game and nothing else**: no buttons, bars, toolbars, labels, settings controls or floating glass. Everything you might do besides play lives in one place, the series menu, opened the same way in every app. The code is `Sources/StillKit/StillMenu.swift` and `Sources/StillKit/StillUndo.swift`.

- **A two-finger tap opens the menu.** `view.addStillTap(fingers: 2) { … }` adds a tap that recognises alongside the toy's own gestures and never cancels their touches, so a drag or flick carries on. Put it on the screen's root view. It is the series' only multi-finger tap.
- **The menu** is `StillMenu`, presented with `menu.present(from: viewController)`. It is a navigation sheet at full height with the grabber: the app's logo in the bar (the title stays set, for VoiceOver), a line or two about the app centred above the list, inset-grouped sections built with `StillList`, and the version and credits centred in footnote type at the foot. Rows are `.choice` (a game mode: rounded headline, a line about it, the system checkmark on the current one), `.action` (tint text; give it a `Confirmation` if it loses progress, and the system asks first) and `.text` (how to play). Build the menu each time it opens, so it shows the app as it is. Choosing a row closes the menu, then runs the row's action, so its effect is seen.
- **Switching mode** is choosing its row. The new mode starts with its game elements and nothing else.
- **A mode's settings** are reached from its row. Pass `settings:` to `.choice` and the row gets a settings button (a gear) beside the checkmark. Tapping the row still chooses the mode; tapping the gear pushes the settings screen you return onto the menu, titled with the mode's name, without switching mode. Build it as an ordinary list (`Still.groupedBackground`, `StillList.insetGrouped()`, system switches, steppers and pickers), apply each change as it is made, and give it no Save or Done: the back button and closing the menu are enough. In a section where any mode has settings, every row keeps room for the gear, so the checkmarks line up.
- **Shake to undo.** A mode that can take a move back gets undo from a shake of the device, never a button. `view.addStillUndo { … }` returns a `StillShakeToUndo`; set its `isEnabled` from the current mode (and to false when there is nothing to undo). It acts only while nothing is presented over the game, so shaking with the menu open does nothing. It follows the person's Shake to Undo setting (Settings › Accessibility › Touch): when `StillShakeToUndo.isAvailable` is false, put an "Undo" action in the menu's section for the current mode instead. Don't register UIKit `undoManager` actions on a game screen, or the system's own shake alert can appear too.
- **The hint teaches the gestures.** When a game begins (on launch, and after switching mode), call `hint.playGameHint(canUndo:)` on a `StillHintView`. A few seconds in, a soft tint pebble fades in with "A two-finger tap opens the menu.", adding "Shake your device to undo." when the mode supports undo and the person allows it, then fades away. Opening the menu stops it. It is the only thing besides the game that a mode may show, and only for a moment. Use `StillHintView.pinned(to:)` for the bottom of the screen, or place it where it covers nothing being played with.
- **VoiceOver** keeps multi-finger taps for itself. Give the game's view the same things as accessibility custom actions ("Open menu", and `undo.accessibilityAction` while the mode supports undo), and open the menu on the magic tap (`accessibilityPerformMagicTap`). The menu's settings button is also offered as a "Settings" action on its row. `StillHintView` stays silent while VoiceOver runs.

```swift
lazy var hint = StillHintView.pinned(to: view)
lazy var undo = view.addStillUndo { [weak self] in self?.game.undo() }

override func viewDidLoad() {
    super.viewDidLoad()
    view.addStillTap(fingers: 2) { [weak self] in self?.showMenu() }
    start(current)
}

func start(_ mode: Mode) {
    current = mode
    undo.isEnabled = mode.supportsUndo
    hint.playGameHint(canUndo: mode.supportsUndo)
    // …lay out the mode's game elements, and nothing else.
}

func showMenu() {
    var actions: [StillMenu.Item] = [.action("New game") { [weak self] in self?.game.reset() }]
    if current.supportsUndo && !StillShakeToUndo.isAvailable {
        actions.insert(.action("Undo") { [weak self] in self?.game.undo() }, at: 0)
    }
    StillMenu(
        title: "minibalism",
        logo: LogoView(pointSize: 24),
        about: "No points. No leaderboards. No aims.",
        sections: [
            .init("Game mode", items: modes.map { mode in
                .choice(mode.name, detail: mode.summary, isSelected: mode == current,
                        settings: mode.hasSettings ? { ModeSettingsViewController(mode) } : nil) { [weak self] in
                    self?.start(mode)
                }
            }),
            .init(current.name, items: actions),
        ],
        footer: [StillMenu.version(of: "minibalism"), "A contention product."]
    ).present(from: self)
}
```

SwiftUI apps present the menu from their window's root view controller and add the tap and the shake to its view.

## Asset catalog or code?

Code (the Swift file) is one file to share, diff and review, which suits a series. The asset catalog route (a colour set per role with Any, Dark and High Contrast appearances) is better if you want Interface Builder and SwiftUI previews to see the colours by name, and it gives Increase Contrast variants without code. Either is fine; pick one and do not mix them.
