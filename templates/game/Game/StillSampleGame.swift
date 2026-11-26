import UIKit
import StillKit

/// The app's `StillGame` definition.
///
/// StillKit owns the window, splash layout and transition, mode switching, series menu,
/// settings screens, persistence, gestures, shake to undo, hints and VoiceOver.
@MainActor
final class StillSampleGame: StillGame {
    let name = "StillSample"

    var logo: UIView? {
        StillSampleLogoView(size: 24)
    }

    let about = "A quiet sample game showing how StillKit hosts modes, settings, undo and splash carry-over."

    let howToPlay = [
        "Move or tap the pebble on the canvas.",
    ]

    let credits = [
        "Built with StillKit.",
    ]

    let modes: [any StillGameMode] = [
        PlainMode(),
        UndoMode(),
        SettingsMode(),
    ]

    func makeSplash() -> StillSplash {
        StillSampleSplash.make()
    }
}
