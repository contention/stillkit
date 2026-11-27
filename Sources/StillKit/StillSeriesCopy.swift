import Foundation

/// Localised series copy and shell strings, loaded from StillKit's resource bundle.
enum StillSeriesCopy {
    static var seriesSectionTitle: String { localized("series.section.title") }
    static var seriesPromise: String { localized("series.promise") }
    static var seriesPrivacy: String { localized("series.privacy") }
    static var seriesMoreApps: String { localized("series.moreApps") }
    static var gestureMenu: String { localized("series.gesture.menu") }
    static var gestureUndoShake: String { localized("series.gesture.undoShake") }
    static var gestureUndoMenu: String { localized("series.gesture.undoMenu") }

    static var hintMenu: String { localized("shell.hint.menu") }
    static var hintUndo: String { localized("shell.hint.undo") }
    static var modesHeader: String { localized("shell.menu.modesHeader") }
    static var howToPlayHeader: String { localized("shell.menu.howToPlayHeader") }
    static var openMenu: String { localized("shell.action.openMenu") }
    static var undo: String { localized("shell.action.undo") }
    static var settings: String { localized("shell.action.settings") }
    static var newGame: String { localized("shell.action.newGame") }
    static var clearBoard: String { localized("shell.action.clearBoard") }
    static var cancel: String { localized("shell.action.cancel") }

    static func localized(_ key: String) -> String {
        NSLocalizedString(key, bundle: .module, comment: "")
    }
}
