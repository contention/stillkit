## Still series

This app is part of the Still series and uses the StillKit package
(https://github.com/contention/StillKit). Its AGENTS.md has the full rules,
the adoption playbook and the colour mapping; docs/brand.md and docs/uikit.md
explain why. Read them before changing any UI.

- Colours: `Still.*` roles only. No hex, no UIColor literals, no .white/.black, no UIKit system colours. Never `StillPalette` in a view.
- Type: `StillFont.rounded` for display text and numbers, `preferredFont(forTextStyle:)` for everything else. Dynamic Type always.
- Buttons: `.stillPrimary` / `.stillSecondary` / `.stillPlain`. Capsules. One primary per screen.
- Corners: `stillCorners(_:)` with `StillRadius`. Motion: `StillMotion`. Haptics: `StillHaptics` (`touch` for contact, `snap` for a dragged piece finding its place, `tick` for control detents).
- iOS 26: no custom navigation bar, tab bar or toolbar backgrounds or tints.
- Actions: a screen's actions go in the system navigation bar or toolbar, not custom floating buttons. Words, not symbols, when a symbol would mislead (`plus` means making something to keep).
- Game modes show the game and nothing else: no buttons, bars, labels or settings controls. Everything else is in the series menu (`StillMenu`, opened by a two-finger tap): switching mode, the mode's actions, and its settings (the settings button on its row, `.choice(…, settings:)`). Undo is a device shake (`addStillUndo(action:)`), never a button. Each mode's settings, and the mode last played, persist between launches in `UserDefaults`, on the device only. When a game begins, `StillHintView.playGameHint(canUndo:)` teaches the tap and, where the mode supports undo, the shake.
- Never restyle alerts, menus, keyboards, system sheet chrome or destructive red. Never set `overrideUserInterfaceStyle`.
