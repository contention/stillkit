# StillKit: instructions for agents

StillKit is the shared visual identity and game shell for the Still series: small, calm, free iOS apps and toys with no ads, no tracking and no accounts. It is a thin layer over UIKit. For games and toys, `StillGameHost` owns the entire shell (window setup, cold-launch splash and carry-over animation, mode switching, series menu, declarative settings screens, persistence, two-finger tap, shake to undo, hints, VoiceOver and shared series copy). Apps write only their splash and their game modes.

Three jobs come here: **starting a new app**, **adopting StillKit in an existing app**, or **changing StillKit itself**.

Read `docs/brand.md` (the rules) and `docs/uikit.md` (how the layering and `StillGameHost` work) before any job. If you are working in an app repo and cannot see those files, read them from https://github.com/contention/StillKit.

---

## The rules, short form

These are what every app must end up following. `scripts/new-app.sh` copies them into the app's `CLAUDE.md`.

- **Colours: `Still.*` roles only.** No hex, no `UIColor(red:...)`, no `.white` or `.black`, no UIKit system colours (`.systemBackground`, `.label`, `.systemBlue`...). Never use `StillPalette` in a view.
- **The window tint is the only accent.** Do not set `tintColor` on individual views unless restoring the inherited value.
- **Type:** display text and numbers in `StillFont.rounded(_:)` / `StillFont.numeral()`; everything else `UIFont.preferredFont(forTextStyle:)`. No fixed sizes. `adjustsFontForContentSizeCategory = true` on every label.
- **Buttons:** `.stillPrimary`, `.stillSecondary`, `.stillPlain`. Capsules. One primary per screen. (Never inside a game mode.)
- **Shape:** `stillCorners(_:)` with `StillRadius` values (continuous corners). No borders or shadows to separate surfaces; use the step between `groupedBackground` and `groupedSurface`.
- **Motion:** `StillMotion.animate`. No bounce, no flashing.
- **Haptics:** `StillHaptics.touch()` for contact, `.snap()` for a dragged piece finding its place, `.tick()` for control detents. Never heavy or rigid.
- **iOS 26:** no custom backgrounds or tints on navigation bars, tab bars or toolbars. Liquid Glass picks up the ground.
- **Game shell:** games launch with `StillGameHost.launch(MyGame(), in: windowScene)`. An app writes only its `StillGame`, `StillSplash` and `StillGameMode`s. Never rebuild a menu, settings screen, tap gesture, shake-to-undo handler, hint view or mode-persistence store by hand.
- **Game modes show the game and nothing else.** `makeGameView(context:)` returns a `UIView` containing game elements only: no `UIButton`, `UINavigationBar`, `UIToolbar`, `UITabBar`, `UIVisualEffectView` or `overrideUserInterfaceStyle`. Debug builds assert this.
- **Settings are declarative.** Modes list `[StillSetting]` (`.toggle`, `.choice`, `.stepper`, `.slider`) and read values from `context.settings`. No custom settings view controllers.
- **Splash:** supply logo and optional carried view in `StillSplash`, and return a `StillSplashLanding` per mode. StillKit owns layout, timing, animation, Reduce Motion fallback and VoiceOver focus.
- **Leave alone:** alerts, action sheets, menus, share sheet, keyboards, system sheet chrome, and Apple's red for destructive actions.
- **Follow the system appearance.** Never set `overrideUserInterfaceStyle`.

---

## Starting a new app

1. Create a fresh iOS App project (iOS 17.0+ deployment target).
2. Run the setup tool from StillKit (works from any terminal or VS Code / SweetPad without opening Xcode):

   ```bash
   scripts/new-app.sh /path/to/MyGame/MyGame.xcodeproj
   ```

   This verifies the iOS 17+ target, links StillKit via Swift Package Manager, copies the starter files from `templates/game/` (game definition, splash, starter modes, one-line `SceneDelegate`, `AccentColor`, `LaunchBackground` on `Still.canvas`, `Info.plist`, `CLAUDE.md`), removes untouched Xcode template `ViewController.swift` and `Main.storyboard`, and verifies the simulator build.
3. Build only the app's splash (`<App>Splash.swift`) and game modes (`Modes/*.swift`). Do not write shell code, settings screens, menu code, gesture recognizers for the menu/undo, or `UserDefaults` code for modes/settings.
4. Build for `generic/platform=iOS Simulator` and verify the "Done when" checklist below on a device.

---

## Adopting StillKit in an existing app

Work in passes. **After each pass: build, summarise the diff, list anything you were unsure of, and stop for the person to review on a device before starting the next.** Never combine passes. Never change layout, behaviour, copy or game logic unless the pass says so.

### Pass 0: set up

1. Check the app's deployment target is iOS 17 or later. If not, stop and ask.
2. Confirm the StillKit package is added to the app target (`https://github.com/contention/StillKit`, Up to Next Major). For a fresh setup, run `scripts/new-app.sh /path/to/App.xcodeproj`. If StillKit is already added, run `scripts/new-app.sh --files-only --skip-build /path/to/App.xcodeproj` when ready to adopt the host (pass 1 / pass 6).
3. Copy `templates/app-CLAUDE.md` into the app's `CLAUDE.md` (append if one exists).
4. Build. Stop.

### Pass 1: wire up (or adopt `StillGameHost` for games)

- **For non-game apps:** call `StillAppearance.apply(to: window)` in the scene delegate before `makeKeyAndVisible()`, set **AccentColor** (#4B6E68 Any, #99B59D Dark), and remove conflicting global appearance code.
- **For games:** prepare the inventory before changing storage or layout (see Pass 6 below). Once approved, launch via `StillGameHost.launch(MyGame(), in: windowScene)`, which handles `StillAppearance.apply(to:)` automatically, and set **AccentColor** (#4B6E68 Any, #99B59D Dark) and **LaunchBackground** (#CAD2C5 Any, #2F3E46 Dark).
- Build. Stop.

### Pass 2: grounds, text and colours

1. Inventory first. Run:

   ```
   grep -rnE 'UIColor\(|Color\(|\.system(Background|GroupedBackground|Blue|Green|Red|Orange|Gray[0-9]?|Fill)|secondarySystem|tertiarySystem|\.(label|secondaryLabel|tertiaryLabel|placeholderText|separator|white|black)\b|#colorLiteral|named:' --include='*.swift' . | grep -v 'Still\.'
   ```

   Also list colours set in storyboards and XIBs.
2. Present a table: file, line, current value, proposed role. Use the mapping below. **Wait for approval before changing anything.** Where the mapping says "ask", ask.
3. Apply the approved mapping. Make sure every plain screen sets `view.backgroundColor = Still.background`, every settings-style list uses `Still.groupedBackground`, and every game mode uses `Still.canvas`.
4. Build. Stop.

| Found | Replace with |
| --- | --- |
| `.systemBackground` | `Still.background` |
| `.secondarySystemBackground` | `Still.backgroundSecondary` |
| `.tertiarySystemBackground` | `Still.backgroundTertiary` |
| `.systemGroupedBackground` | `Still.groupedBackground` |
| `.secondarySystemGroupedBackground` | `Still.groupedSurface` |
| `.label` | `Still.label` |
| `.secondaryLabel` | `Still.labelSecondary` |
| `.tertiaryLabel`, `.quaternaryLabel`, `.placeholderText` | `Still.labelTertiary` |
| `.separator`, `.opaqueSeparator` | `Still.separator` |
| `.systemFill` family, grey tracks | `Still.fill` |
| `.systemBlue`, custom accent, `.tintColor` | delete and inherit, or `Still.tint` |
| `.systemRed` on a destructive action | keep (`role: .destructive` where possible) |
| `.white`, `.black`, `.systemGray*`, hex, other system colours | ask |
| Colours on a game or toy screen | `Still.canvas`, `pieceStrong`, `pieceMid`, `pieceAmbient`: ask which |

SwiftUI views inside the app: wrap roles as `Color(uiColor: Still.tint)`.

### Pass 3: type

1. Inventory `UIFont.systemFont(ofSize:`, `UIFont(name:`, `.boldSystemFont`, `Font.system(size:` and labels without `adjustsFontForContentSizeCategory`.
2. Propose the nearest text style for each (17 -> `.body`, 15 -> `.subheadline`, 13 -> `.footnote`...). Titles, level names, counters and timers go rounded. Wait for approval.
3. Apply, set `adjustsFontForContentSizeCategory = true`, and check nothing truncates at the largest accessibility size (fix with `numberOfLines = 0` or stack-axis changes, and list them).
4. Build. Stop.

### Pass 4: controls and lists

1. Buttons (non-game screens): move to `.stillPrimary` / `.stillSecondary` / `.stillPlain`. If a screen has more than one primary, ask which stays primary.
2. Lists: `UICollectionView` lists use `StillList.insetGrouped()` and `StillList.cellBackground()`. Leave `UITableView`s structurally as they are; set their background, cell background and separator colours from roles. Do not convert table views to collection views unless asked.
3. Remove custom bar backgrounds, bar button tints and blur views added to bars.
4. Build. Stop.

### Pass 5: shape, motion, haptics

1. `layer.cornerRadius` -> `stillCorners(_:)` with the nearest `StillRadius` value; capsules for anything button-like.
2. Remove borders and shadows used to separate surfaces. Keep `shadow-lift` only on things being dragged (see `docs/uikit.md`).
3. `UIView.animate(withDuration:)` used for UI transitions -> `StillMotion.animate`. Leave game physics and frame-driven animation alone; list them.
4. Haptics -> `StillHaptics.touch()` for contact, `.snap()` for a dragged piece snapping into place, `.tick()` for control detents. Call `StillHaptics.prepare()` when a drag begins. Remove `.heavy`, `.rigid` and repeated notification haptics.
5. Build. Stop.

### Pass 6: adopt `StillGameHost` and series signatures

1. Check the app icon follows the template in `docs/brand.md` (Night ground, one Mist glyph, at most one Sage or Moss accent). Report; do not draw icons.
2. **Inventory first, change nothing.** List every mode, anything each mode shows besides its game elements, its settings and every `UserDefaults` key or other storage used today, its menu and gesture code, its splash or launch behaviour, and its logo. Propose:
   - how each mode maps onto `StillGameMode`,
   - each setting's `StillSetting` kind (`.toggle`, `.choice`, `.stepper`, `.slider`),
   - which element of the logo or splash carries over (`StillSplash`) and where it lands in each mode (`StillSplashLanding`),
   - and a one-time migration (`StillGame.migrateStorage(using:)`) from legacy storage keys into StillKit's keys so saved modes and settings survive updating from an older build.

   **Wait for approval**, since this changes layout, behaviour and storage.
3. Apply the approved plan:
   - Move each mode's game view and logic into a `StillGameMode` returning a plain `UIView`.
   - Convert hand-built settings screens to `[StillSetting]` and read values from `context.settings`.
   - Write the `StillGame` conformance, `StillSplash`, and one-time `migrateStorage(using:)`.
   - Launch with `StillGameHost.launch(MyGame(), in: windowScene)`.
   - Delete the app's own menu code, settings view controllers, tap/undo gesture plumbing, hint view, mode/settings persistence, VoiceOver menu wiring and any root view controller replaced by `StillGameHost`.
4. Build. Stop.

### Done when

- [ ] The pass 2 and pass 3 inventory commands return nothing except approved exceptions (list them).
- [ ] Every screen checked in light and dark mode.
- [ ] Largest accessibility text size: nothing truncated or overlapping.
- [ ] Reduce Motion on: no movement beyond crossfades; ambient loops stopped; splash crossfades without movement.
- [ ] VoiceOver: splash announces app name then focuses the game; every interactive game piece has a label; the host's "Open menu" (and "Undo" where supported) actions and magic tap work.
- [ ] Every game mode shows only its game elements (debug assertions pass with zero violations); cold-launch splash carries over and does not replay on return from background; two-finger tap opens the menu; shake undoes where supported (and the Undo row appears when Shake to Undo is off); hint plays when a game begins; selected mode and all settings survive quitting, relaunching and updating from an older build.
- [ ] No `overrideUserInterfaceStyle`, no bar backgrounds on iOS 26.

Report the checklist with each item ticked or explained.

---

## Changing StillKit itself

- Keep every public API source-compatible within a major version (before 1.0, breaking changes bump the minor version).
- Shell plumbing (`StillMenu`, `StillTapGesture`, `StillHintView`, `StillShakeToUndo`) stays internal so games can only get their shell from `StillGameHost`.
- A change to a colour value must keep the contrast pairs in `docs/brand.md` at 4.5:1 for text (3:1 for `labelTertiary`, large text and non-text marks) in both modes. Check and state the ratios (and verify in `Showcase/StillShowcase.xcodeproj`).
- Keep `Showcase/StillShowcase.xcodeproj`, `templates/game/`, `Tools/still-setup/` and `scripts/new-app.sh` in sync with any public API change. The sample game in `Showcase` compiles the files in `templates/game/Game/` directly.
- Update `docs/` and `templates/app-CLAUDE.md` in the same branch as the code.
- Verify all targets before opening a PR:
  - `xcodebuild -scheme StillKit -destination 'generic/platform=iOS Simulator' build`
  - `xcodebuild -scheme StillKit -destination 'platform=iOS Simulator,name=...' test`
  - `xcodebuild -project Showcase/StillShowcase.xcodeproj -scheme StillShowcase -destination 'generic/platform=iOS Simulator' build`
  - `bash scripts/test-setup.sh`
- `swift build` on macOS will fail for the root StillKit package because it imports UIKit; use `xcodebuild`. (`Tools/still-setup` is its own macOS Swift package.)
- Suggest the version bump (patch for fixes, minor for additions, major for breaking changes; before 1.0, breaking changes bump the minor). Once the person agrees, write it to `VERSION`. A push to `main` that changes `VERSION` builds, tags and releases it (`.github/workflows/release.yml`). Never create tags or releases by hand.
