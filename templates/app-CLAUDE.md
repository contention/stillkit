## Still series

This app is part of the Still series and uses the StillKit package
(https://github.com/contention/StillKit). Its AGENTS.md has the full rules,
new-app setup and colour mapping; docs/brand.md and docs/uikit.md explain why.
Read them before changing any UI.

- **Shell:** launch with `StillGameHost.launch(MyGame(), in: windowScene)`. StillKit owns the window, cold-launch splash layout and transition, mode switching, series menu, settings screens, persistence, two-finger tap, shake to undo, hints, VoiceOver wiring and shared series copy. Write only the app's `StillGame`, `StillSplash` and `StillGameMode`s, and nothing else of the shell.
- **Game modes:** `makeGameView(context:)` returns a `UIView` containing game elements only: no `UIButton`, `UINavigationBar`, `UIToolbar`, `UITabBar`, `UIVisualEffectView` or `overrideUserInterfaceStyle`. Debug builds assert this.
- **Settings:** declare mode settings as `[StillSetting]` (`.toggle`, `.choice`, `.stepper`, `.slider`) and read them from `context.settings`. Never build custom settings view controllers or save mode/settings keys in `UserDefaults` by hand.
- **Splash:** return a `StillSplash` (logo and optional carried view) from `makeSplash()`, and return a `StillSplashLanding` from each mode's `splashLanding(in:carriedFrame:)`. StillKit owns timing, animation and Reduce Motion fallback.
- **Colours:** `Still.*` roles only (`Still.canvas`, `pieceStrong`, `pieceMid`, `pieceAmbient` for play; `background`, `groupedBackground`, `label`, `tint` for UI). No hex, no `UIColor` literals, no `.white`/`.black`, no UIKit system colours. Never use `StillPalette` in a view.
- **Type:** `StillFont.rounded` for display text and numbers, `preferredFont(forTextStyle:)` for everything else. Dynamic Type always (`adjustsFontForContentSizeCategory = true`).
- **Shape, motion, haptics:** `stillCorners(_:)` with `StillRadius`; `StillMotion.animate`; `StillHaptics` (`touch` for contact, `snap` for a dragged piece finding its place, `tick` for control detents).
- **iOS 26:** no custom navigation bar, tab bar or toolbar backgrounds or tints.
- **System UI:** never restyle alerts, menus, keyboards, system sheet chrome or destructive red. Never set `overrideUserInterfaceStyle`.
