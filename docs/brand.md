# Still, the brand book

Still is the shared identity for a series of small, calm iOS apps and toys. Free, no ads, no tracking, no accounts, ever. It is a thin skin over UIKit, not a replacement for it: Apple's controls, layouts and behaviours stay; the palette, one typeface twist, one shape rule and a shared game shell make every app recognisably part of the set.

## The idea in one line

**Colour the room, not the furniture.** Put the palette into the grounds your content sits on and into the single UIKit tint. Leave the system bars, alerts, menus and keyboards as Apple draws them. Since iOS 26, navigation bars, tab bars and toolbars are Liquid Glass that floats over your content and takes its colour from what is behind it, so a Mist or Night ground tints the glass for free. Custom bar backgrounds fight the glass; Apple's guidance is to remove them.

## Principles

- **UIKit first, skin second.** If a system control does the job, use it and let the tokens style it. Build a custom element only when the toy needs it.
- **Diluted for UI, neat for play.** App chrome uses the palette diluted (`mist-50`, `mist-100`, `night-900`). Games and toys use it neat: the canvas is pure `mist` or `night`, pieces are pure palette colours.
- **One signal at a time.** One tinted action per screen. No badges, red dots, streaks, timers counting down, or celebratory bursts.
- **Never ask for anything.** No sign-up, no rating prompts, no notification permission unless the toy truly needs it, and then only when the person taps the feature.
- **Quiet by default.** Sound off until switched on; haptics soft; motion slow.

## Colour

Five palette colours, five derived steps, and semantic roles that map one-to-one onto UIKit's semantic colours. Views use roles only, never raw palette names.

| Role token | Replaces in UIKit | Light | Dark |
| --- | --- | --- | --- |
| `tint` | `tintColor` (window) | `moss-ink` | `sage-lift` |
| `on-tint` | text on `.filled()` buttons | `mist-50` | `night` |
| `tint-soft` / `on-tint-soft` | `.tinted()` buttons | `mist-100` / `moss-ink` | #3f5053 / `mist-100` |
| `background` | `systemBackground` | `mist-50` | `night-900` |
| `background-secondary` | `secondarySystemBackground` | `mist-100` | `night` |
| `background-tertiary` | `tertiarySystemBackground` | `mist` | `slate` |
| `grouped-background` | `systemGroupedBackground` | `mist-100` | `night-900` |
| `grouped-surface` | `secondarySystemGroupedBackground` | `mist-50` | `night` |
| `label` | `label` | `night` | `mist-100` |
| `label-secondary` | `secondaryLabel` | #536969 | #b3bcb2 |
| `label-tertiary` | `tertiaryLabel`, `placeholderText` | #74878a | #7c8886 |
| `separator` | `separator` | `mist` | #40565b |
| `fill` | `systemFill` | `mist` | `slate` |
| `destructive` | `systemRed` (unchanged) | #ff3b30 | #ff453a |

Rules:

- Set `tint` once on the window. Everything tappable in your content inherits it. Never set `tintColor` per view to a palette colour.
- Never use pure white or pure black. Light grounds are `mist-50` and `mist-100`; dark grounds are `night-900` and `night`.
- Text is `label`, `label-secondary` or `on-tint`. Never set text in `sage` or `moss`: both miss 4.5:1 on light grounds. That is why the tint is `moss-ink` (Moss deepened a touch) in light mode and `sage-lift` (Sage lifted a touch) in dark mode. They look like the palette and pass.
- Tint text never sits on `background-tertiary` or `slate`.
- `destructive` stays Apple's red. It is the one colour outside the palette, on purpose: it means danger everywhere on iOS.
- Follow the system appearance. Never force light or dark with `overrideUserInterfaceStyle`.

Every text pair above holds 4.5:1 in both modes (`label-tertiary` is placeholder-only at 3:1). Live contrast ratios for every pair appear in `Showcase/StillShowcase.xcodeproj`.

## Type

SF Pro, the system font, with Dynamic Type. The series signature is **SF Pro Rounded for display text and numbers**: large titles, sheet titles, level names and game counters are rounded; everything you read is plain SF Pro.

- Use UIKit text styles, never fixed sizes: `large-title`, `title-1`, `title-2`, `title-3` in the rounded design; `headline`, `body`, `callout`, `subheadline`, `footnote`, `caption` in the default design.
- Display weights are a step lighter than Apple's defaults (semibold, medium). Calm reads lighter.
- Game counters use `numeral`: rounded, medium, monospaced digits. A score is glanced at mid-move, so it needs the weight to read at once; light is for big numbers you look at rather than glance at, like a clock.
- Set `adjustsFontForContentSizeCategory = true` on every label. Test at the largest accessibility size.
- Sentence case everywhere, including titles and buttons.

## Shape

- **Every corner is continuous** (`layer.cornerCurve = .continuous`). Squircles, not rounded rectangles: it is what makes custom elements sit naturally next to Apple's.
- **Every button is a capsule** (`configuration.cornerStyle = .capsule`), whether filled, tinted or plain-with-background. Pebbles, not tiles.
- Radii: `radius-sm` 8, `radius-md` 12, `radius-lg` 20, `radius-xl` 32, `radius-pill` for capsules. Nested shapes are concentric: inner radius = outer radius minus the padding between them.
- Separate surfaces by a step in ground colour (`grouped-background` to `grouped-surface`), not by borders or shadows.
- Shadows: only `shadow-lift`, only on something being touched or dragged.
- **Counters sit on pebbles**: a label and a number on a capsule at least 44pt tall, label in `label-secondary`, number in rounded `title-3`. The pebble's ground says how loud it is: `background-secondary` for a counter that is always there (a best score), `tint-soft` for a moment worth noticing (a best just beaten), filled `tint` for the one thing happening right now. Never more than one filled pebble at a time.

## Spacing

An 8-point rhythm with a 4-point half step: `space-1` 4, `space-2` 8, `space-3` 12, `space-4` 16, `space-5` 20, `space-6` 24, `space-8` 32, `space-12` 48. Use the view's `layoutMargins` and `readableContentGuide` for outer margins so iPad and landscape behave; use the tokens inside custom elements. Be generous: when in doubt, more space.

## Motion

- Springs with no visible overshoot: `UIView.animate(springDuration: 0.5, bounce: 0)` (iOS 17+), or damping 0.9 and up. Nothing bounces for attention.
- Durations 0.35 to 0.6s for UI; ambient loops (breathing, drifting) slower than 4 seconds per cycle.
- No flashing, no strobing, no shaking the screen to alert, no confetti. (Shaking the device to undo is a gesture, not motion on screen.)
- With Reduce Motion on, replace movement with a 0.3s crossfade and stop ambient loops.

## Haptics and sound

- Haptics: `UIImpactFeedbackGenerator(style: .soft)` at intensity 0.7 to 0.9 (default 0.85) for contact (`touch`); `.light` at about 0.7 for a dragged piece snapping into place (`snap`); `UISelectionFeedbackGenerator` for detents in controls (`tick`). The selection haptic is too faint to feel under a moving finger, so never use it for a snap. Never `.heavy` or `.rigid`. `.success` notification feedback at most once per session, for finishing something.
- Sound: off by default. When on, use `AVAudioSession` category `.ambient`, so the Ring/Silent switch mutes it and the person's music keeps playing.

## Iconography

- SF Symbols only in UI, at the weight of the text beside them, rendering mode `.hierarchical`, coloured by `tint` or `label-secondary`. No multicolour symbols.
- Use a word instead of a symbol when the symbol would mislead. `plus` means making something you keep, so it is wrong for a new round of a game; counterclockwise arrows read as undo. In a list or a bar, a new round is "New game", in words.
- The one place that is always symbols is a mode's row in the series menu: words there crowd the mode's name and look like a second list. So each action has one symbol across the series, chosen not to mislead: starting over, whether a new round or clearing the board, is `arrow.clockwise` (turning forward, so never undo), and undo is `arrow.uturn.backward`. A mode offers one way to start over, so the symbol never means two things on one row. A new action gets its symbol added here before it is used.
- Actions live in the system navigation bar or toolbar, drawn as the system draws them, not in custom floating buttons. A full-screen game or toy, which has no bars and shows nothing but the game, puts them in the series menu instead (below).
- App icons share one template: `night` ground, a single simple glyph in `mist`, at most one accent in `sage` or `moss`. Provide the dark and tinted variants iOS asks for; the dark variant uses `night-900`.
- No emoji in UI.

## Splash

Every Still game opens the same way on cold launch (never when returning from the background):

- The launch screen hands over seamlessly on `Still.canvas` (`LaunchBackground`: Mist in light mode, Night in dark mode).
- StillKit centres the app's logo and name (in `StillFont.rounded(.largeTitle)`) on `Still.canvas`, fades them in calmly, and holds briefly.
- One element of the splash (a piece of the logo, or another view the app chooses) carries over into the restored game mode: it moves smoothly with a bounce-free spring to its landing spot in the game while the rest of the splash fades away, and becomes part of that game.
- Under Reduce Motion, the splash crossfades without movement (0.3s).
- A mode with no landing place still works: the carried element fades away with the rest of the splash.
- VoiceOver announces the app name while the splash is up, then moves focus to the game view when the splash ends.

## Game screens, the menu and series copy

**A game shows the game and nothing else.** Every mode of a full-screen game or toy shows only its game elements: no buttons, bars, labels, settings controls or floating glass. The quiet hint pebble is the one exception, and only for a moment.

Everything else is owned by `StillGameHost` and lives in one menu, opened the same way in every app: **a two-finger tap**. The menu has a fixed layout across the series:

1. **Header**: the app's logo in the navigation bar (with the app name set for VoiceOver) and a line or two about the app centred above the list.
2. **Game modes**: every mode in order, the current one ticked, its actions as symbol buttons on its row (`.newGame` / `.clear`), and a settings button on each mode that declares settings.
3. **How to play**: the current mode's and app's instructions, followed by StillKit's localisable gesture notes.
4. **Series section**: StillKit's shared localisable promise ("no ads, no tracking, no accounts"), privacy line (settings stay on the device) and "More Still apps" row (disabled until it has a destination). Apps cannot remove or reorder this section.
5. **Footer**: the app's version and credits centred in footnote type.

All shared series copy lives in one localisable file in StillKit (`Sources/StillKit/Resources/en.lproj/Localizable.strings`), so updating the series copy is a single package bump.

- **Undo is a shake.** A mode that can take a move back undoes on a shake of the device, never with a button. If the person has turned Shake to Undo off, the host automatically offers an undo button on the current mode's row instead.
- **Mode settings are declarative.** A mode lists its `[StillSetting]` values (toggle, choice, stepper, slider) and the host builds the settings screen, applies changes live (no Save), and persists them.
- **Nothing is forgotten.** Both the selected game mode and every mode's settings are kept on the device in `UserDefaults`, never synced or sent anywhere.
- **The hint teaches the gestures.** When a game begins, the host fades in a quiet pebble with the tap note (and the shake note when the mode supports undo and the person allows it), then fades it away.
- **VoiceOver users get the same things as actions**: open menu, undo, each mode's row buttons and its settings, plus the magic tap to open the menu.

`StillGameHost`, `StillGame`, `StillGameMode`, `StillSetting` and `StillSplash` build it; see `docs/uikit.md`.

## Voice

- Plain, short, warm, second person. "Tap anywhere to begin." not "Let's get started!"
- No exclamation marks, no streaks, no scores you can lose, no urgency ("Don't miss...", "Hurry").
- Say less. A toy with one hint line is better than a tutorial.

## Recognisability checklist

A new app belongs to the series when it has all five:

1. Grounds are `mist-50`/`mist-100` or `night-900`/`night`, never white or black; toys use the neat `canvas`.
2. The window tint is `tint`.
3. Display text and numbers are SF Pro Rounded.
4. Buttons are capsules; corners are continuous.
5. The app icon follows the template.

## Accessibility

- Contrast as above, in both modes.
- Support Dynamic Type, VoiceOver (every interactive game piece gets an `accessibilityLabel` and, where it moves, an adjustable trait), Reduce Motion and Increase Contrast.
- Never carry meaning by colour alone: game pieces differ in lightness (`piece-strong`, `piece-mid`) and in shape.

## Building it

`docs/uikit.md` explains how StillKit layers this over UIKit and how `StillGameHost` works. The code is `Sources/StillKit/`. To start a new app or adopt StillKit in an existing app, follow `AGENTS.md`.
