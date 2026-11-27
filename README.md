# StillKit

The shared look, feel and game shell for the Still series: small, calm, free iOS apps and toys. No ads, no tracking, no accounts. Ever.

StillKit provides two layers:

1. **The game shell (`StillGameHost`)**: owns the window, cold-launch splash and carry-over transition, mode switching, series menu, declarative mode settings screens, `UserDefaults` persistence, two-finger tap, shake to undo, gesture hints, VoiceOver wiring and shared series copy. A Still game writes only its splash and its game modes (`StillGame`, `StillSplash`, `StillGameMode`, `StillSetting`).
2. **Visual primitives**: semantic colour roles (`Still.*`), SF Pro Rounded display type (`StillFont`), capsule button presets, continuous corners (`StillRadius`), spacing (`StillSpace`), inset-grouped lists (`StillList`), bounce-free motion (`StillMotion`) and soft haptics (`StillHaptics`). Used inside game views and by non-game Still apps.

## Starting a new game app

Run the setup script against a fresh iOS app `.xcodeproj` (iOS 17 or later) from any terminal or VS Code with SweetPad, without opening Xcode:

```bash
scripts/new-app.sh /path/to/MyGame/MyGame.xcodeproj
```

The script builds and runs `Tools/still-setup/`, which parses the `.xcodeproj` directly:

- Checks the deployment target is iOS 17.0 or later.
- Adds the StillKit package dependency (`https://github.com/contention/StillKit`, Up to Next Major) and links it to the app target.
- Copies the starter game from `templates/game/` (`<App>Game.swift`, `<App>Splash.swift`, blank modes, one-line `SceneDelegate.swift`, `AccentColor`, `LaunchBackground` on `Still.canvas`, `Info.plist`, `CLAUDE.md`). Supports both Xcode 16+ synchronized folders and classic `PBXGroup` projects.
- Removes untouched Xcode template `ViewController.swift` and `Main.storyboard` files.
- Builds for `generic/platform=iOS Simulator` to confirm everything compiles.

Pass `--files-only` when migrating an existing app that already depends on StillKit.

## Minimal app entry point

```swift
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

## Running the showcase on a device

`Showcase/StillShowcase.xcodeproj` references StillKit by local path so it always builds against the working tree. It includes catalogue screens for every public primitive (with live WCAG contrast ratios, Dynamic Type sizes, buttons, corners, spacing, lists, motion and haptics) plus the sample game built directly from `templates/game/`.

To install on a physical iPhone with a personal team:

1. Copy `Showcase/Config/Local.xcconfig.example` to `Showcase/Config/Local.xcconfig` and fill in your `DEVELOPMENT_TEAM` (and optional `PRODUCT_BUNDLE_IDENTIFIER`).
2. Open `Showcase/StillShowcase.xcodeproj` in Xcode (or build from VS Code with SweetPad), select your iPhone and run.

## Non-game apps

Non-game apps continue to use the public visual primitives directly with `StillAppearance.apply(to: window)` in their scene delegate and `AccentColor` set to `#4B6E68` (Any) and `#99B59D` (Dark).

## Docs

- `docs/brand.md`: the rules (colour roles, type, shape, motion, splash, series copy, voice).
- `docs/uikit.md`: building games with `StillGameHost` and layering primitives over UIKit.
- `AGENTS.md`: instructions for agents starting a new app, adopting StillKit in an existing app, or changing StillKit itself.

## Releasing

Put the new version in `VERSION` (for example `0.6.0`) in the same commit as the changes it ships, and push to `main`. The release workflow builds the package, then creates the tag and a GitHub release. Tags have no `v` prefix.

## Requirements

iOS 17+. Liquid Glass aware on iOS 26.
