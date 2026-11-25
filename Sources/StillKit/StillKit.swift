//  StillKit.swift
//  The Still identity layered over UIKit. Part of the StillKit package.
//  Imported by every app in the Still series.
//
//  Three layers, in this order:
//    1. Roles      - semantic colours and fonts (Still, StillFont)
//    2. Appearance - applied once per window (StillAppearance.apply)
//    3. Presets    - button configurations and helpers for custom elements
//
//  Views use roles only. Never reach for StillPalette in a view.

import UIKit

// MARK: - 1. Palette (raw values, used only to build roles)

public enum StillPalette {
    public static let mist      = UIColor(stillHex: 0xCAD2C5)
    public static let sage      = UIColor(stillHex: 0x84A98C)
    public static let moss      = UIColor(stillHex: 0x52796F)
    public static let slate     = UIColor(stillHex: 0x354F52)
    public static let night     = UIColor(stillHex: 0x2F3E46)

    // Derived steps
    public static let mist50    = UIColor(stillHex: 0xF7F8F6) // Mist 15% over white
    public static let mist100   = UIColor(stillHex: 0xE4E8E2) // Mist 50% over white
    public static let mossInk   = UIColor(stillHex: 0x4B6E68) // Moss toward Slate: light-mode tint
    public static let sageLift  = UIColor(stillHex: 0x99B59D) // Sage toward Mist: dark-mode tint
    public static let night900  = UIColor(stillHex: 0x263238) // Night toward black: dark page
}

// MARK: - 1. Roles (what views use)

public enum Still {
    // Accent
    public static let tint               = dynamic(StillPalette.mossInk, StillPalette.sageLift)
    public static let onTint             = dynamic(StillPalette.mist50, StillPalette.night)
    public static let tintSoft           = dynamic(StillPalette.mist100, UIColor(stillHex: 0x3F5053))
    public static let onTintSoft         = dynamic(StillPalette.mossInk, StillPalette.mist100)

    // Grounds
    public static let background          = dynamic(StillPalette.mist50, StillPalette.night900)
    public static let backgroundSecondary = dynamic(StillPalette.mist100, StillPalette.night)
    public static let backgroundTertiary  = dynamic(StillPalette.mist, StillPalette.slate)
    public static let groupedBackground   = dynamic(StillPalette.mist100, StillPalette.night900)
    public static let groupedSurface      = dynamic(StillPalette.mist50, StillPalette.night)

    // Text and lines
    public static let label          = dynamic(StillPalette.night, StillPalette.mist100)
    public static let labelSecondary = dynamic(UIColor(stillHex: 0x536969), UIColor(stillHex: 0xB3BCB2))
    public static let labelTertiary  = dynamic(UIColor(stillHex: 0x74878A), UIColor(stillHex: 0x7C8886))
    public static let separator      = dynamic(StillPalette.mist, UIColor(stillHex: 0x40565B))
    public static let fill           = dynamic(StillPalette.mist, StillPalette.slate)
    public static let destructive    = UIColor.systemRed // unchanged, on purpose

    // Play (the palette neat)
    public static let canvas       = dynamic(StillPalette.mist, StillPalette.night)
    public static let pieceStrong  = dynamic(StillPalette.night, StillPalette.mist)
    public static let pieceMid     = dynamic(StillPalette.moss, StillPalette.sage)
    public static let pieceAmbient = dynamic(StillPalette.sage, StillPalette.moss)

    /// A colour that resolves per appearance. Add an Increase Contrast branch
    /// here (traits.accessibilityContrast == .high) if you want one.
    private static func dynamic(_ light: UIColor, _ dark: UIColor) -> UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        }
    }
}

// MARK: - 1. Type

public enum StillFont {
    /// A Dynamic Type text style in SF Pro Rounded. Use for display text and numbers.
    public static func rounded(_ style: UIFont.TextStyle,
                               weight: UIFont.Weight = .semibold) -> UIFont {
        let size = defaultPointSize(for: style)
        let system = UIFont.systemFont(ofSize: size, weight: weight)
        let font = system.fontDescriptor.withDesign(.rounded)
            .map { UIFont(descriptor: $0, size: size) } ?? system
        return UIFontMetrics(forTextStyle: style).scaledFont(for: font)
    }

    /// Game counters and timers: rounded, monospaced digits.
    ///
    /// Medium by default, so a score reads at a glance in the middle of play. Pass `.light`
    /// for a large number you look at rather than glance at, such as a clock face.
    public static func numeral(size: CGFloat = 64, weight: UIFont.Weight = .medium) -> UIFont {
        let system = UIFont.monospacedDigitSystemFont(ofSize: size, weight: weight)
        let font = system.fontDescriptor.withDesign(.rounded)
            .map { UIFont(descriptor: $0, size: size) } ?? system
        return UIFontMetrics(forTextStyle: .largeTitle).scaledFont(for: font)
    }

    /// Plain SF Pro text styles: just use UIFont.preferredFont(forTextStyle:).
    public static func text(_ style: UIFont.TextStyle) -> UIFont {
        UIFont.preferredFont(forTextStyle: style)
    }

    private static func defaultPointSize(for style: UIFont.TextStyle) -> CGFloat {
        let traits = UITraitCollection(preferredContentSizeCategory: .large)
        return UIFontDescriptor.preferredFontDescriptor(withTextStyle: style,
                                                        compatibleWith: traits).pointSize
    }
}

// MARK: - 2. Appearance (call once per window, before it becomes visible)

public enum StillAppearance {
    @MainActor
    public static func apply(to window: UIWindow) {
        // The one global colour decision. Everything tappable inherits it.
        window.tintColor = Still.tint
        window.backgroundColor = Still.background

        // Navigation bar: rounded titles in label colour.
        func titled(_ nav: UINavigationBarAppearance) -> UINavigationBarAppearance {
            nav.titleTextAttributes = [
                .foregroundColor: Still.label,
                .font: StillFont.rounded(.headline, weight: .semibold)
            ]
            nav.largeTitleTextAttributes = [
                .foregroundColor: Still.label,
                .font: StillFont.rounded(.largeTitle, weight: .semibold)
            ]
            return nav
        }

        if #available(iOS 26.0, *) {
            // Liquid Glass: no custom bar backgrounds. The glass picks up
            // Still.background behind it. Titles only; scrollEdgeAppearance
            // stays nil so the system scroll-edge effect keeps working.
            let nav = UINavigationBarAppearance()
            nav.configureWithDefaultBackground()
            UINavigationBar.appearance().standardAppearance = titled(nav)
            UINavigationBar.appearance().compactAppearance = titled(nav)
        } else {
            // iOS 18 and earlier: a quiet opaque bar in the ground colour, no hairline.
            let nav = UINavigationBarAppearance()
            nav.configureWithOpaqueBackground()
            nav.backgroundColor = Still.background
            nav.shadowColor = .clear
            let edge = UINavigationBarAppearance()
            edge.configureWithTransparentBackground()
            UINavigationBar.appearance().standardAppearance = titled(nav)
            UINavigationBar.appearance().compactAppearance = titled(nav)
            UINavigationBar.appearance().scrollEdgeAppearance = titled(edge)

            let tab = UITabBarAppearance()
            tab.configureWithOpaqueBackground()
            tab.backgroundColor = Still.background
            tab.shadowColor = Still.separator
            UITabBar.appearance().standardAppearance = tab
            UITabBar.appearance().scrollEdgeAppearance = tab
        }

        // Controls that do not inherit the window tint in every state.
        UISwitch.appearance().onTintColor = Still.tint
        UISlider.appearance().minimumTrackTintColor = Still.tint
        UISlider.appearance().maximumTrackTintColor = Still.fill
        UIProgressView.appearance().progressTintColor = Still.tint
        UIProgressView.appearance().trackTintColor = Still.fill
        UIPageControl.appearance().currentPageIndicatorTintColor = Still.tint
        UIPageControl.appearance().pageIndicatorTintColor = Still.fill

        // Lists are styled where they are made: see StillList below.
    }
}

// MARK: - 3. Presets

public extension UIButton.Configuration {
    /// The one primary action on a screen.
    static func stillPrimary(_ title: String) -> UIButton.Configuration {
        var c = UIButton.Configuration.filled()
        c.title = title
        c.baseBackgroundColor = Still.tint
        c.baseForegroundColor = Still.onTint
        c.cornerStyle = .capsule
        c.buttonSize = .large
        c.titleTextAttributesTransformer = .still(.headline)
        return c
    }

    /// Secondary actions.
    static func stillSecondary(_ title: String) -> UIButton.Configuration {
        var c = UIButton.Configuration.filled()
        c.title = title
        c.baseBackgroundColor = Still.tintSoft
        c.baseForegroundColor = Still.onTintSoft
        c.cornerStyle = .capsule
        c.buttonSize = .large
        c.titleTextAttributesTransformer = .still(.body)
        return c
    }

    /// Low-emphasis actions: tint text, no fill.
    static func stillPlain(_ title: String) -> UIButton.Configuration {
        var c = UIButton.Configuration.plain()
        c.title = title
        c.baseForegroundColor = Still.tint
        c.cornerStyle = .capsule
        return c
    }
}

public extension UIConfigurationTextAttributesTransformer {
    static func still(_ style: UIFont.TextStyle) -> UIConfigurationTextAttributesTransformer {
        UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = UIFont.preferredFont(forTextStyle: style)
            return outgoing
        }
    }
}

public extension UIView {
    /// Continuous (squircle) corners. Use for every custom rounded shape.
    func stillCorners(_ radius: CGFloat) {
        layer.cornerRadius = radius
        layer.cornerCurve = .continuous
    }
}

public enum StillList {
    /// An inset-grouped collection-view list in Still colours.
    @MainActor
    public static func insetGrouped() -> UICollectionLayoutListConfiguration {
        var config = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        config.backgroundColor = Still.groupedBackground
        config.separatorConfiguration.color = Still.separator
        return config
    }

    /// Cell background for list cells: call from the cell registration.
    @MainActor
    public static func cellBackground() -> UIBackgroundConfiguration {
        var bg: UIBackgroundConfiguration
        if #available(iOS 18.0, *) {
            bg = .listCell()
        } else {
            bg = .listGroupedCell()
        }
        bg.backgroundColor = Still.groupedSurface
        return bg
    }
}

public enum StillRadius {
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 12
    public static let lg: CGFloat = 20
    public static let xl: CGFloat = 32
}

public enum StillSpace {
    public static let s1: CGFloat = 4
    public static let s2: CGFloat = 8
    public static let s3: CGFloat = 12
    public static let s4: CGFloat = 16
    public static let s5: CGFloat = 20
    public static let s6: CGFloat = 24
    public static let s8: CGFloat = 32
    public static let s12: CGFloat = 48
}

public enum StillMotion {
    /// The house spring: no visible overshoot.
    @MainActor
    public static func animate(_ animations: @escaping () -> Void,
                               completion: ((Bool) -> Void)? = nil) {
        if UIAccessibility.isReduceMotionEnabled {
            UIView.animate(withDuration: 0.3, animations: animations, completion: completion)
        } else {
            UIView.animate(springDuration: 0.5, bounce: 0,
                           animations: animations, completion: completion)
        }
    }
}

public enum StillHaptics {
    @MainActor private static let soft = UIImpactFeedbackGenerator(style: .soft)
    @MainActor private static let light = UIImpactFeedbackGenerator(style: .light)
    @MainActor private static let selection = UISelectionFeedbackGenerator()

    /// Readies the haptic engine so the first haptic plays on time. Call when an interaction
    /// begins, such as a drag starting. Each haptic below also readies the next one.
    @MainActor public static func prepare() {
        soft.prepare()
        light.prepare()
        selection.prepare()
    }

    /// Contact: a piece lands, a toggle settles.
    @MainActor public static func touch(_ intensity: CGFloat = 0.6) {
        soft.impactOccurred(intensity: intensity)
        soft.prepare()
    }

    /// A snap: a dragged piece finds a spot where it fits. A short, crisp tap that feels
    /// different from `touch()`, so snapping and landing never blur together. Use this, not
    /// `tick()`, for anything under a moving finger: the selection haptic is too faint there.
    @MainActor public static func snap(_ intensity: CGFloat = 0.7) {
        light.impactOccurred(intensity: intensity)
        light.prepare()
    }

    /// Detents in controls: a picker passes a step, a stepper changes. The faintest haptic.
    @MainActor public static func tick() {
        selection.selectionChanged()
        selection.prepare()
    }
}

// MARK: - Helpers

public extension UIColor {
    convenience init(stillHex hex: UInt32, alpha: CGFloat = 1) {
        self.init(red:   CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue:  CGFloat(hex & 0xFF) / 255,
                  alpha: alpha)
    }
}
