# StillKit: instructions for agents

StillKit is the shared visual identity for the Still series: small, calm, free iOS apps and toys with no ads, no tracking and no accounts. It is a thin layer over UIKit. Apple's controls, layouts and behaviours stay; StillKit supplies colour roles, fonts, one-time appearance setup, button presets, list styling, motion, haptics, and the series menu for games and toys.

Two jobs come here. Most often you will be **adopting StillKit in an existing app** (the playbook below). Sometimes you will be **changing StillKit itself** (last section).

Read `docs/brand.md` (the rules) and `docs/uikit.md` (how the layering works) before either job. If you are working in an app repo and cannot see those files, read them from https://github.com/contention/StillKit.

---

## The rules, short form

These are what every app must end up following. Copy them into the app's `CLAUDE.md` in pass 0.

- **Colours: `Still.*` roles only.** No hex, no `UIColor(red:…)`, no `.white` or `.black`, no UIKit system colours (`.systemBackground`, `.label`, `.systemBlue`…). Never use `StillPalette` in a view.
- **The window tint is the only accent.** Do not set `tintColor` on individual views unless restoring the inherited value.
- **Type:** display text and numbers in `StillFont.rounded(_:)` / `StillFont.numeral()`; everything else `UIFont.preferredFont(forTextStyle:)`. No fixed sizes. `adjustsFontForContentSizeCategory = true` on every label.
- **Buttons:** `.stillPrimary`, `.stillSecondary`, `.stillPlain`. Capsules. One primary per screen.
- **Shape:** `stillCorners(_:)` with `StillRadius` values (continuous corners). No borders or shadows to separate surfaces; use the step between `groupedBackground` and `groupedSurface`.
- **Motion:** `StillMotion.animate`. No bounce, no flashing.
- **Haptics:** `StillHaptics.touch()` for contact, `.snap()` for a dragged piece finding its place, `.tick()` for control detents. Never heavy or rigid.
- **iOS 26:** no custom backgrounds or tints on navigation bars, tab bars or toolbars. Liquid Glass picks up the ground.
- **Actions:** a screen's actions go in the system navigation bar or toolbar, not custom floating buttons. A full-screen game or toy puts them in the series menu: `StillMenu`, opened by a two-finger tap (`addStillTap(fingers:)`), taught by `StillHintView`, and offered to VoiceOver as actions. Use a word, not a symbol, when the symbol would mislead.
- **Leave alone:** alerts, action sheets, menus, share sheet, keyboards, system sheet chrome, and Apple's red for destructive actions.
- **Follow the system appearance.** Never set `overrideUserInterfaceStyle`.

---

## Adopting StillKit in an existing app

Work in passes. **After each pass: build, summarise the diff, list anything you were unsure of, and stop for the person to review on a device before starting the next.** Never combine passes. Never change layout, behaviour, copy or game logic unless the pass says so.

### Pass 0: set up

1. Check the app's deployment target is iOS 17 or later. If not, stop and ask.
2. Confirm the StillKit package is added to the app target (File → Add Package Dependencies, `https://github.com/contention/StillKit`, Up to Next Major). If it is not, add it yourself: either ask the person to do it in Xcode, or edit the `.xcodeproj` directly (an `XCRemoteSwiftPackageReference` with `upToNextMajorVersion`, an `XCSwiftPackageProductDependency` for `StillKit`, and the product in the app target's `packageProductDependencies` and Frameworks build phase), then resolve packages and build to confirm.
3. Copy `templates/app-CLAUDE.md` from this package into the app's `CLAUDE.md` (append if one exists).
4. Build. Stop.

### Pass 1: wire up

1. In the scene delegate (or wherever the window is created), call `StillAppearance.apply(to: window)` before `makeKeyAndVisible()`.
2. Set the asset catalog's **AccentColor**: Any appearance #4B6E68, Dark appearance #99B59D.
3. Remove any existing global appearance code (`UINavigationBar.appearance()`, `UITabBar.appearance()`, window tint) that now conflicts. List what you removed.
4. Build. Stop.

### Pass 2: grounds, text and colours

1. Inventory first. Run:

   ```
   grep -rnE 'UIColor\(|Color\(|\.system(Background|GroupedBackground|Blue|Green|Red|Orange|Gray[0-9]?|Fill)|secondarySystem|tertiarySystem|\.(label|secondaryLabel|tertiaryLabel|placeholderText|separator|white|black)\b|#colorLiteral|named:' --include='*.swift' . | grep -v 'Still\.'
   ```

   (The final filter drops lines that already use Still roles.)

   Also list colours set in storyboards and XIBs.
2. Present a table: file, line, current value, proposed role. Use the mapping below. **Wait for approval before changing anything.** Where the mapping says "ask", ask.
3. Apply the approved mapping. Make sure every plain screen sets `view.backgroundColor = Still.background` and every settings-style list uses `Still.groupedBackground`.
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
2. Propose the nearest text style for each (17 → `.body`, 15 → `.subheadline`, 13 → `.footnote`…). Titles, level names, counters and timers go rounded. Wait for approval.
3. Apply, set `adjustsFontForContentSizeCategory = true`, and check nothing truncates at the largest accessibility size (fix with `numberOfLines = 0` or stack-axis changes, and list them).
4. Build. Stop.

### Pass 4: controls and lists

1. Buttons: move to `.stillPrimary` / `.stillSecondary` / `.stillPlain`. If a screen has more than one primary, ask which stays primary.
2. Lists: `UICollectionView` lists use `StillList.insetGrouped()` and `StillList.cellBackground()`. Leave `UITableView`s structurally as they are; set their background, cell background and separator colours from roles. Do not convert table views to collection views unless asked.
3. Remove custom bar backgrounds, bar button tints and blur views added to bars.
4. Build. Stop.

### Pass 5: shape, motion, haptics

1. `layer.cornerRadius` → `stillCorners(_:)` with the nearest `StillRadius` value; capsules for anything button-like.
2. Remove borders and shadows used to separate surfaces. Keep `shadow-lift` only on things being dragged (see `docs/uikit.md`).
3. `UIView.animate(withDuration:)` used for UI transitions → `StillMotion.animate`. Leave game physics and frame-driven animation alone; list them.
4. Haptics → `StillHaptics.touch()` for contact, `.snap()` for a dragged piece snapping into place, `.tick()` for control detents. Call `StillHaptics.prepare()` when a drag begins. Remove `.heavy`, `.rigid` and repeated notification haptics.
5. Build. Stop.

### Pass 6: series signatures

1. Check the app icon follows the template in `docs/brand.md` (Night ground, one Mist glyph, at most one Sage or Moss accent). Report; do not draw icons.
2. Build. Stop.

### Done when

- [ ] The pass 2 and pass 3 inventory commands return nothing except approved exceptions (list them).
- [ ] Every screen checked in light and dark mode.
- [ ] Largest accessibility text size: nothing truncated or overlapping.
- [ ] Reduce Motion on: no movement beyond crossfades; ambient loops stopped.
- [ ] VoiceOver: every game piece and custom control has a label.
- [ ] No `overrideUserInterfaceStyle`, no bar backgrounds on iOS 26.

Report the checklist with each item ticked or explained.

---

## Changing StillKit itself

- Keep every public API source-compatible within a major version. Adding is fine; renaming or removing is a major version.
- A change to a colour value must keep the contrast pairs in `docs/brand.md` at 4.5:1 for text (3:1 for `labelTertiary`, large text and non-text marks) in both modes. Check and state the ratios.
- Update `docs/` in the same commit as the code.
- Build for an iOS Simulator destination (`xcodebuild -scheme StillKit -destination 'generic/platform=iOS Simulator' build`). `swift build` on macOS will fail because the target imports UIKit.
- Suggest the version bump (patch for fixes, minor for additions, major for breaking changes; before 1.0, breaking changes bump the minor). Once the person agrees, write it to `VERSION`. A push to main that changes `VERSION` builds, tags and releases it (`.github/workflows/release.yml`). Never create tags or releases by hand.
