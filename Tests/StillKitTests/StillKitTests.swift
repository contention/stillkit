import XCTest
import UIKit
@testable import StillKit

@MainActor
final class StillKitTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var store: StillSettingsStore!

    override func setUp() {
        super.setUp()
        suiteName = "StillKitTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        store = StillSettingsStore(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        store = nil
        super.tearDown()
    }

    // MARK: - Series copy

    func testSeriesCopyKeysResolve() {
        let keys = [
            "series.section.title",
            "series.promise",
            "series.privacy",
            "series.moreApps",
            "series.gesture.menu",
            "series.gesture.undoShake",
            "series.gesture.undoMenu",
            "shell.hint.menu",
            "shell.hint.undo",
            "shell.menu.modesHeader",
            "shell.menu.howToPlayHeader",
            "shell.action.openMenu",
            "shell.action.undo",
            "shell.action.settings",
            "shell.action.newGame",
            "shell.action.clearBoard",
            "shell.action.cancel",
        ]
        for key in keys {
            let value = StillSeriesCopy.localized(key)
            XCTAssertFalse(value.isEmpty, "Missing value for \(key)")
            XCTAssertNotEqual(value, key, "Key \(key) was not found in Localizable.strings")
        }
    }

    // MARK: - Settings persistence and clamping

    func testSettingsDefaultsAndPersistence() {
        let settings: [StillSetting] = [
            .toggle("Sound", key: "sound", default: true),
            .choice("Speed", key: "speed", options: ["Slow", "Calm", "Brisk"], default: "Calm"),
            .stepper("Pebbles", key: "pebbles", range: 3...12, default: 6),
            .slider("Drift", key: "drift", range: 0...1, default: 0.4),
            .slider("Balls", key: "balls", range: 2...100, step: 1, default: 20),
        ]
        let reader = StillSettingsReader(modeID: "garden", settings: settings, store: store)

        XCTAssertTrue(reader.bool("sound"))
        XCTAssertEqual(reader.string("speed"), "Calm")
        XCTAssertEqual(reader.int("pebbles"), 6)
        XCTAssertEqual(reader.double("drift"), 0.4, accuracy: 1e-6)
        XCTAssertEqual(reader.int("balls"), 20)

        store.setBool(false, key: "sound", modeID: "garden")
        store.setString("Brisk", key: "speed", modeID: "garden")
        store.setInt(99, key: "pebbles", modeID: "garden")
        store.setDouble(1.8, key: "drift", modeID: "garden")
        store.setDouble(14.6, key: "balls", modeID: "garden")

        XCTAssertFalse(reader.bool("sound"))
        XCTAssertEqual(reader.string("speed"), "Brisk")
        XCTAssertEqual(reader.int("pebbles"), 12) // clamped to upper bound
        XCTAssertEqual(reader.double("drift"), 1.0, accuracy: 1e-6) // clamped
        XCTAssertEqual(reader.int("balls"), 15) // snapped to step 1

        // Invalid choice falls back to default
        store.setString("Invalid", key: "speed", modeID: "garden")
        XCTAssertEqual(reader.string("speed"), "Calm")
    }

    // MARK: - One-time storage migration

    func testStorageMigrationCopiesOnceAndDoesNotOverwrite() {
        defaults.set("oldMode", forKey: "selectedMode")
        defaults.set(25, forKey: "Diffusion.ballCount")
        defaults.set(false, forKey: "legacy.sound")
        defaults.set("Slow", forKey: "legacy.speed")
        defaults.set(0.75, forKey: "legacy.drift")

        let migration = StillStorageMigration(store: store)
        migration.migrateSelectedMode(fromLegacyKey: "selectedMode") { legacy in
            legacy == "oldMode" ? "diffusion" : legacy
        }
        migration.migrateInt(fromLegacyKey: "Diffusion.ballCount", toMode: "diffusion", settingKey: "ballCount")
        migration.migrateBool(fromLegacyKey: "legacy.sound", toMode: "garden", settingKey: "sound")
        migration.migrateString(fromLegacyKey: "legacy.speed", toMode: "garden", settingKey: "speed")
        migration.migrateDouble(fromLegacyKey: "legacy.drift", toMode: "garden", settingKey: "drift")

        XCTAssertEqual(store.selectedModeID, "diffusion")
        XCTAssertNil(defaults.object(forKey: "selectedMode"))
        XCTAssertNil(defaults.object(forKey: "Diffusion.ballCount"))

        let diffusionReader = StillSettingsReader(
            modeID: "diffusion",
            settings: [.slider("Balls", key: "ballCount", range: 2...100, step: 1, default: 20)],
            store: store
        )
        XCTAssertEqual(diffusionReader.int("ballCount"), 25)

        // Running migration again with a different legacy value must not overwrite existing StillKit state.
        defaults.set("otherMode", forKey: "selectedMode")
        migration.migrateSelectedMode(fromLegacyKey: "selectedMode")
        XCTAssertEqual(store.selectedModeID, "diffusion")
    }

    // MARK: - Debug view-tree auditor

    func testAuditorAcceptsCleanGameView() {
        let root = UIView()
        let piece = UIView()
        piece.backgroundColor = Still.pieceStrong
        piece.stillCorners(StillRadius.lg)
        root.addSubview(piece)

        let violations = StillGameViewAuditor.audit(viewTree: root, modeID: "clean")
        XCTAssertTrue(violations.isEmpty, "Expected no violations, got: \(violations)")
    }

    func testAuditorFlagsForbiddenViewsAndOverrides() {
        let cases: [(String, UIView)] = [
            ("UIButton", UIButton(type: .system)),
            ("UINavigationBar", UINavigationBar()),
            ("UIToolbar", UIToolbar()),
            ("UITabBar", UITabBar()),
            ("UIVisualEffectView", UIVisualEffectView(effect: UIBlurEffect(style: .regular))),
        ]

        for (name, forbidden) in cases {
            let root = UIView()
            let container = UIView()
            container.addSubview(forbidden)
            root.addSubview(container)

            let violations = StillGameViewAuditor.audit(viewTree: root, modeID: "test")
            XCTAssertFalse(violations.isEmpty, "Expected violation for \(name)")
            XCTAssertTrue(violations.contains { $0.contains(name) }, "Violation should mention \(name)")
        }

        let styled = UIView()
        styled.overrideUserInterfaceStyle = .dark
        let styleViolations = StillGameViewAuditor.audit(viewTree: styled, modeID: "styled")
        XCTAssertEqual(styleViolations.count, 1)
        XCTAssertTrue(styleViolations[0].contains("overrideUserInterfaceStyle"))
    }

    // MARK: - Slider snapping and formatting

    func testSliderSnappingAndFormatting() {
        let stepped = StillSetting.slider("Balls", key: "balls", range: 2...10, step: 2, default: 4)
        XCTAssertEqual(stepped.snappedSliderValue(3.1), 4, accuracy: 1e-9)
        XCTAssertEqual(stepped.snappedSliderValue(15), 10, accuracy: 1e-9)
        XCTAssertEqual(stepped.snappedSliderValue(-5), 2, accuracy: 1e-9)
        XCTAssertEqual(stepped.formattedSliderValue(4), "4")

        let continuous = StillSetting.slider("Scale", key: "scale", range: 0.5...1.5, default: 1.0)
        XCTAssertEqual(continuous.formattedSliderValue(1.25), "1.25")

        let custom = StillSetting.slider("Zoom", key: "zoom", range: 0...1, default: 0.5) {
            "\(Int(($0 * 100).rounded()))%"
        }
        XCTAssertEqual(custom.formattedSliderValue(0.75), "75%")
    }

    // MARK: - Host lifecycle, mode switching and memory cleanup

    func testHostRestoresMigratedModeSwitchesCleanlyAndDeallocates() {
        defaults.set("beta", forKey: "legacy.mode")

        final class AlphaMode: StillGameMode {
            static let id = "alpha"
            let title = "Alpha"
            var beginCount = 0
            var endCount = 0
            func makeGameView(context: StillModeContext) -> UIView { UIView() }
            func begin() { beginCount += 1 }
            func end() { endCount += 1 }
        }

        final class BetaMode: StillGameMode {
            static let id = "beta"
            let title = "Beta"
            var beginCount = 0
            var endCount = 0
            func makeGameView(context: StillModeContext) -> UIView { UIView() }
            func begin() { beginCount += 1 }
            func end() { endCount += 1 }
        }

        final class TestGame: StillGame {
            let name = "TestGame"
            let about = "Test"
            let modes: [any StillGameMode]
            init(modes: [any StillGameMode]) { self.modes = modes }
            func migrateStorage(using migration: StillStorageMigration) {
                migration.migrateSelectedMode(fromLegacyKey: "legacy.mode")
            }
        }

        let alpha = AlphaMode()
        let beta = BetaMode()
        weak var weakHost: StillGameHostViewController?

        autoreleasepool {
            let host = StillGameHostViewController(game: TestGame(modes: [alpha, beta]), store: store)
            weakHost = host
            host.loadViewIfNeeded()

            // Migration ran before restoring, so beta is mounted initially.
            XCTAssertEqual(host.currentMode?.modeID, "beta")
            XCTAssertEqual(store.selectedModeID, "beta")

            // Switching to the already-active mode is a no-op.
            XCTAssertFalse(host.prepareModeSwitch(to: beta))

            // Switching to alpha ends beta, persists alpha, mounts and begins alpha.
            XCTAssertTrue(host.prepareModeSwitch(to: alpha))
            XCTAssertEqual(beta.endCount, 1)
            XCTAssertEqual(alpha.beginCount, 1)
            XCTAssertEqual(host.currentMode?.modeID, "alpha")
            XCTAssertEqual(store.selectedModeID, "alpha")
        }

        // Host must not be retained by gesture closures, mode contexts, or subviews.
        XCTAssertNil(weakHost, "StillGameHostViewController leaked after release")
    }
}
