# StillKit

The shared look and feel for the Still series: small, calm, free iOS apps and toys. No ads, no tracking, no accounts. Ever.

StillKit is a thin layer over UIKit: colour roles from one muted palette, SF Pro Rounded for display text, capsule buttons, continuous corners, a calm spring and soft haptics. Games and toys show nothing but the game, and get the series menu: opened by a two-finger tap, with the game modes (and each mode's settings), the current mode's actions and the app's credits. Undo is a shake of the device, and a quiet hint teaches both when a game begins (`StillMenu`, `addStillTap(fingers:)`, `addStillUndo(action:)`, `StillHintView`).

## Add it to an app

1. In Xcode: **File → Add Package Dependencies…**
2. Paste `https://github.com/contention/StillKit`, choose **Up to Next Major Version**, and add the **StillKit** library to the app target.
3. In the scene delegate:

```swift
import StillKit

let window = UIWindow(windowScene: windowScene)
StillAppearance.apply(to: window)
```

4. Set the asset catalog's AccentColor to #4B6E68 (Any) and #99B59D (Dark).

Then use roles everywhere: `view.backgroundColor = Still.background`, `label.font = StillFont.rounded(.title2)`, `UIButton(configuration: .stillPrimary("Begin"))`.

## Adopting it in an existing app with an agent

Point the agent at `AGENTS.md` and ask it to start with pass 0. It works in passes and stops for review after each.

## Docs

- `docs/brand.md`: the rules (colour roles, type, shape, motion, voice).
- `docs/uikit.md`: how StillKit layers over UIKit, and what it leaves alone.

## Releasing

Put the new version in `VERSION` (for example `0.1.0`) in the same commit as the changes it ships, and push to main. The release workflow builds the package, then creates the tag and a GitHub release. Tags have no `v` prefix.

## Requirements

iOS 17+. Liquid Glass aware on iOS 26.
