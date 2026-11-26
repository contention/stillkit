import Foundation
import PathKit
import XcodeProj

// MARK: - CLI options

struct SetupOptions {
    var projectPath: String = ""
    var filesOnly = false
    var skipBuild = false
    var localPackagePath: String?
    var branch: String?
    var version = "0.6.0"
    var repoRoot: String = ""

    static func parse(_ arguments: [String]) throws -> SetupOptions {
        var options = SetupOptions()
        var index = 1
        while index < arguments.count {
            let arg = arguments[index]
            switch arg {
            case "--files-only":
                options.filesOnly = true
            case "--skip-build":
                options.skipBuild = true
            case "--local-package":
                index += 1
                guard index < arguments.count else { throw SetupError("Missing value for --local-package") }
                options.localPackagePath = arguments[index]
            case "--branch":
                index += 1
                guard index < arguments.count else { throw SetupError("Missing value for --branch") }
                options.branch = arguments[index]
            case "--version":
                index += 1
                guard index < arguments.count else { throw SetupError("Missing value for --version") }
                options.version = arguments[index]
            case "--repo-root":
                index += 1
                guard index < arguments.count else { throw SetupError("Missing value for --repo-root") }
                options.repoRoot = arguments[index]
            case "-h", "--help":
                printUsage()
                exit(0)
            default:
                if arg.hasPrefix("-") {
                    throw SetupError("Unknown flag: \(arg)")
                }
                if options.projectPath.isEmpty {
                    options.projectPath = arg
                } else {
                    throw SetupError("Unexpected extra argument: \(arg)")
                }
            }
            index += 1
        }

        if options.projectPath.isEmpty {
            printUsage()
            throw SetupError("Please pass the path to an .xcodeproj bundle.")
        }
        return options
    }

    static func printUsage() {
        let usage = """
        Usage: still-setup [options] /path/to/MyGame.xcodeproj

        Options:
          --files-only              Skip adding the StillKit package dependency (for migrating existing apps).
          --local-package <path>    Reference StillKit as a local Swift package at <path>.
          --branch <name>           Reference remote StillKit at branch <name> instead of Up to Next Major.
          --version <semver>        Minimum StillKit version for Up to Next Major (default: 0.6.0).
          --repo-root <path>        Path to the StillKit repository root containing templates/.
          --skip-build              Skip the verification xcodebuild step.
          -h, --help                Show this help.
        """
        print(usage)
    }
}

struct SetupError: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}

// MARK: - Main runner

do {
    let options = try SetupOptions.parse(CommandLine.arguments)
    try runSetup(options)
} catch {
    fputs("error: \(error)\n", stderr)
    exit(1)
}

func runSetup(_ options: SetupOptions) throws {
    let fm = FileManager.default
    let projPath = Path(options.projectPath).absolute()
    guard projPath.exists, projPath.extension == "xcodeproj" else {
        throw SetupError("Not a valid .xcodeproj path: \(projPath.string)")
    }

    let repoRoot = try resolveRepoRoot(explicit: options.repoRoot)
    let templateGameDir = repoRoot + "templates" + "game"
    let templateClaudeFile = repoRoot + "templates" + "app-CLAUDE.md"
    guard templateGameDir.exists else {
        throw SetupError("Could not locate templates/game at \(templateGameDir.string)")
    }

    let xcodeproj = try XcodeProj(path: projPath)
    let pbxproj = xcodeproj.pbxproj

    guard let project = try pbxproj.rootProject() else {
        throw SetupError("Project has no root PBXProject object.")
    }

    guard let target = pbxproj.nativeTargets.first(where: { $0.productType == .application }) else {
        throw SetupError("Could not find an iOS application target in \(projPath.lastComponent).")
    }

    let appName = target.name
    let swiftPrefix = sanitizeSwiftIdentifier(appName)
    let projectDir = projPath.parent()

    print("Configuring '\(appName)' (\(projPath.string))...")

    // 1. Verify iOS 17.0+ deployment target.
    try verifyDeploymentTarget(target: target, project: project)

    // 2. Add StillKit package dependency unless --files-only.
    if !options.filesOnly {
        try addStillKitPackage(to: target, project: project, pbxproj: pbxproj,
                               projectDir: projectDir, options: options)
    } else {
        print("Skipping package reference (--files-only).")
    }

    // 3. Determine target source directory and whether it uses Xcode 16+ synchronized folders.
    let syncedGroups = target.fileSystemSynchronizedGroups ?? []
    let usesSynchronizedFolder = !syncedGroups.isEmpty
    let appSourceDir: Path
    let appGroup: PBXGroup?

    if let firstSynced = syncedGroups.first, let relativePath = firstSynced.path {
        appSourceDir = projectDir + relativePath
        appGroup = nil
        print("Detected Xcode 16+ synchronized folder: \(relativePath)")
    } else {
        let candidate = projectDir + appName
        if candidate.exists {
            appSourceDir = candidate
        } else {
            appSourceDir = projectDir
        }
        appGroup = findOrCreateAppGroup(named: appName, in: project, pbxproj: pbxproj,
                                        appSourceDir: appSourceDir, projectDir: projectDir)
        print("Detected classic PBXGroup project layout.")
    }

    // 4. Copy starter files from templates/game/ with app name substitution.
    let copiedSwiftFiles = try copyTemplateFiles(
        from: templateGameDir,
        to: appSourceDir,
        projectDir: projectDir,
        appName: appName,
        swiftPrefix: swiftPrefix,
        filesOnly: options.filesOnly,
        templateClaudeFile: templateClaudeFile
    )

    // 5. Update classic PBXGroup & Sources build phase if not using synchronized folders.
    if !usesSynchronizedFolder, let appGroup {
        try registerClassicSwiftFiles(copiedSwiftFiles, appSourceDir: appSourceDir,
                                      appGroup: appGroup, target: target, pbxproj: pbxproj)
    }

    // 6. Remove untouched Xcode template ViewController.swift and Main.storyboard, and wire LaunchScreen / SceneDelegate.
    try cleanUntouchedTemplateFiles(in: appSourceDir, target: target, pbxproj: pbxproj)
    try configureLaunchScreenAndSceneDelegate(
        target: target,
        pbxproj: pbxproj,
        project: project,
        usesSynchronizedFolder: usesSynchronizedFolder,
        appSourceDir: appSourceDir,
        projectDir: projectDir,
        templateConfigDir: templateGameDir + "Config"
    )

    // Ensure AccentColor and LaunchBackground asset catalog settings exist.
    ensureAssetCatalogBuildSettings(on: target)

    // 7. Save updated .xcodeproj.
    try xcodeproj.write(path: projPath)
    print("Updated \(projPath.lastComponent).")

    // Ensure a shared scheme exists so xcodebuild works without opening Xcode.
    try ensureSharedScheme(projPath: projPath, target: target)

    // 8. Build for iOS Simulator unless --skip-build.
    if !options.skipBuild {
        print("Building '\(appName)' for generic/platform=iOS Simulator...")
        let status = runProcess(
            "/usr/bin/xcodebuild",
            arguments: [
                "-project", projPath.string,
                "-scheme", appName,
                "-destination", "generic/platform=iOS Simulator",
                "build",
            ],
            currentDirectory: projectDir.string
        )
        if status != 0 {
            throw SetupError("xcodebuild failed with exit code \(status).")
        }
        print("Build succeeded.")
    }

    _ = fm
}

// MARK: - Step helpers

func resolveRepoRoot(explicit: String) throws -> Path {
    if !explicit.isEmpty {
        return Path(explicit).absolute()
    }
    // Walk up from executable or current working directory looking for templates/game.
    var candidates: [Path] = [Path.current]
    if let execURL = Bundle.main.executableURL {
        candidates.append(Path(execURL.deletingLastPathComponent().path))
    }
    for start in candidates {
        var cursor = start.absolute()
        for _ in 0..<8 {
            if (cursor + "templates" + "game").exists {
                return cursor
            }
            let parent = cursor.parent()
            if parent == cursor { break }
            cursor = parent
        }
    }
    throw SetupError("Could not locate StillKit repository root. Pass --repo-root <path>.")
}

func sanitizeSwiftIdentifier(_ name: String) -> String {
    let parts = name.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
    let joined = parts.map { part -> String in
        guard let first = part.first else { return "" }
        return String(first).uppercased() + part.dropFirst()
    }.joined()
    if joined.isEmpty { return "StillApp" }
    if let first = joined.first, first.isNumber { return "App" + joined }
    return joined
}

func verifyDeploymentTarget(target: PBXNativeTarget, project: PBXProject) throws {
    let targetConfigs = target.buildConfigurationList?.buildConfigurations ?? []
    let projectConfigs = project.buildConfigurationList?.buildConfigurations ?? []

    var versions: [Double] = []
    for config in targetConfigs {
        if let raw = config.buildSettings["IPHONEOS_DEPLOYMENT_TARGET"] as? String, let val = Double(raw) {
            versions.append(val)
        } else if let raw = config.buildSettings["IPHONEOS_DEPLOYMENT_TARGET"] as? Double {
            versions.append(raw)
        }
    }
    if versions.isEmpty {
        for config in projectConfigs {
            if let raw = config.buildSettings["IPHONEOS_DEPLOYMENT_TARGET"] as? String, let val = Double(raw) {
                versions.append(val)
            } else if let raw = config.buildSettings["IPHONEOS_DEPLOYMENT_TARGET"] as? Double {
                versions.append(raw)
            }
        }
    }

    guard let minimum = versions.min() else {
        throw SetupError("IPHONEOS_DEPLOYMENT_TARGET is not set. StillKit requires iOS 17.0 or later.")
    }
    if minimum < 17.0 {
        throw SetupError("Deployment target is iOS \(minimum). StillKit requires iOS 17.0 or later; update IPHONEOS_DEPLOYMENT_TARGET and re-run.")
    }
    print("Deployment target iOS \(minimum) OK.")
}

func addStillKitPackage(to target: PBXNativeTarget, project: PBXProject, pbxproj: PBXProj,
                        projectDir: Path, options: SetupOptions) throws {
    let alreadyLinked = (target.packageProductDependencies ?? []).contains { $0.productName == "StillKit" }
    if alreadyLinked {
        print("StillKit package dependency is already linked to \(target.name).")
        return
    }

    let productDependency: XCSwiftPackageProductDependency
    if let localPath = options.localPackagePath {
        let relative = relativePath(from: projectDir, to: Path(localPath).absolute())
        let localRef = project.localPackages.first { $0.relativePath == relative } ?? {
            let ref = XCLocalSwiftPackageReference(relativePath: relative)
            pbxproj.add(object: ref)
            project.localPackages.append(ref)
            return ref
        }()
        productDependency = XCSwiftPackageProductDependency(productName: "StillKit")
        // XcodeProj links local package product dependencies via the package reference in project.localPackages
        // (Xcode matches productName against localPackages automatically; setting package = nil is standard for XCLocalSwiftPackageReference in XcodeProj).
        _ = localRef
        print("Added local StillKit package reference (\(relative)).")
    } else {
        let url = "https://github.com/contention/StillKit"
        let requirement: XCRemoteSwiftPackageReference.VersionRequirement = options.branch.map { .branch($0) }
            ?? .upToNextMajorVersion(options.version)
        let remoteRef = project.remotePackages.first { $0.repositoryURL?.lowercased() == url.lowercased() } ?? {
            let ref = XCRemoteSwiftPackageReference(repositoryURL: url, versionRequirement: requirement)
            pbxproj.add(object: ref)
            project.remotePackages.append(ref)
            return ref
        }()
        productDependency = XCSwiftPackageProductDependency(productName: "StillKit", package: remoteRef)
        print("Added remote StillKit package reference (\(url)).")
    }

    pbxproj.add(object: productDependency)
    if target.packageProductDependencies == nil {
        target.packageProductDependencies = []
    }
    target.packageProductDependencies?.append(productDependency)

    let frameworksPhase: PBXFrameworksBuildPhase
    if let existing = try target.frameworksBuildPhase() {
        frameworksPhase = existing
    } else {
        let created = PBXFrameworksBuildPhase()
        pbxproj.add(object: created)
        target.buildPhases.append(created)
        frameworksPhase = created
    }

    let buildFile = PBXBuildFile(product: productDependency)
    pbxproj.add(object: buildFile)
    if frameworksPhase.files == nil {
        frameworksPhase.files = []
    }
    frameworksPhase.files?.append(buildFile)
}

func relativePath(from base: Path, to destination: Path) -> String {
    let baseParts = base.normalize().components
    let destParts = destination.normalize().components
    var common = 0
    while common < baseParts.count && common < destParts.count && baseParts[common] == destParts[common] {
        common += 1
    }
    let ups = Array(repeating: "..", count: baseParts.count - common)
    let remainder = destParts[common...]
    let result = (ups + remainder).joined(separator: "/")
    return result.isEmpty ? "." : result
}

func findOrCreateAppGroup(named appName: String, in project: PBXProject, pbxproj: PBXProj,
                          appSourceDir: Path, projectDir: Path) -> PBXGroup {
    if let mainGroup = project.mainGroup {
        if let existing = mainGroup.children.compactMap({ $0 as? PBXGroup }).first(where: { $0.path == appName || $0.name == appName }) {
            return existing
        }
        if appSourceDir == projectDir {
            return mainGroup
        }
        let created = PBXGroup(children: [], sourceTree: .group, name: appName, path: appName)
        pbxproj.add(object: created)
        mainGroup.children.append(created)
        return created
    }
    let fallback = PBXGroup(children: [], sourceTree: .group)
    pbxproj.add(object: fallback)
    return fallback
}

func copyTemplateFiles(
    from templateGameDir: Path,
    to appSourceDir: Path,
    projectDir: Path,
    appName: String,
    swiftPrefix: String,
    filesOnly: Bool,
    templateClaudeFile: Path
) throws -> [Path] {
    let fm = FileManager.default
    var writtenSwiftFiles: [Path] = []

    func substitute(_ source: String) -> String {
        source
            .replacingOccurrences(of: "StillSampleGame", with: "\(swiftPrefix)Game")
            .replacingOccurrences(of: "StillSampleSplash", with: "\(swiftPrefix)Splash")
            .replacingOccurrences(of: "StillSampleLogoView", with: "\(swiftPrefix)LogoView")
            .replacingOccurrences(of: "\"StillSample\"", with: "\"\(appName)\"")
    }

    // Copy Game/ sources (skip in --files-only if the app already has game files? No, in --files-only
    // we still copy the template files unless a file with that exact name already exists, or copy SceneDelegate/assets/CLAUDE.md).
    let gameDir = appSourceDir + "Game"
    let modesDir = gameDir + "Modes"
    try fm.createDirectory(atPath: modesDir.string, withIntermediateDirectories: true)

    let templateFiles: [(source: Path, dest: Path)] = [
        (templateGameDir + "Game" + "StillSampleGame.swift", gameDir + "\(swiftPrefix)Game.swift"),
        (templateGameDir + "Game" + "StillSampleSplash.swift", gameDir + "\(swiftPrefix)Splash.swift"),
        (templateGameDir + "Game" + "Modes" + "PlainMode.swift", modesDir + "PlainMode.swift"),
        (templateGameDir + "Game" + "Modes" + "UndoMode.swift", modesDir + "UndoMode.swift"),
        (templateGameDir + "Game" + "Modes" + "SettingsMode.swift", modesDir + "SettingsMode.swift"),
    ]

    for entry in templateFiles {
        if filesOnly && entry.dest.exists { continue }
        let raw = try String(contentsOfFile: entry.source.string, encoding: .utf8)
        let content = substitute(raw)
        try content.write(toFile: entry.dest.string, atomically: true, encoding: .utf8)
        writtenSwiftFiles.append(entry.dest)
        print("Wrote \(entry.dest.lastComponent)")
    }

    // SceneDelegate.swift & AppDelegate.swift under App/ (matching the canonical Still layout).
    let appDir = appSourceDir + "App"
    try fm.createDirectory(atPath: appDir.string, withIntermediateDirectories: true)

    let rootScene = appSourceDir + "SceneDelegate.swift"
    let nestedScene = appDir + "SceneDelegate.swift"
    let sceneDest = rootScene.exists ? rootScene : nestedScene
    let shouldWriteScene: Bool
    if !sceneDest.exists {
        shouldWriteScene = true
    } else {
        let existing = (try? String(contentsOfFile: sceneDest.string, encoding: .utf8)) ?? ""
        shouldWriteScene = existing.contains("Use this method to optionally configure and attach the UIWindow")
    }
    if shouldWriteScene {
        let raw = try String(contentsOfFile: (templateGameDir + "App" + "SceneDelegate.swift").string, encoding: .utf8)
        let destination = nestedScene
        if rootScene.exists && rootScene != destination {
            try fm.removeItem(atPath: rootScene.string)
        }
        try substitute(raw).write(toFile: destination.string, atomically: true, encoding: .utf8)
        writtenSwiftFiles.append(destination)
        print("Wrote App/SceneDelegate.swift")
    }

    // AppDelegate.swift: write only if no @main entry point exists in appSourceDir.
    let appDelegateDest = appDir + "AppDelegate.swift"
    if !appDelegateDest.exists && !directoryContainsMainAttribute(appSourceDir) {
        let raw = try String(contentsOfFile: (templateGameDir + "App" + "AppDelegate.swift").string, encoding: .utf8)
        try raw.write(toFile: appDelegateDest.string, atomically: true, encoding: .utf8)
        writtenSwiftFiles.append(appDelegateDest)
        print("Wrote App/AppDelegate.swift")
    }

    // Assets.xcassets: AccentColor and LaunchBackground (Still.canvas).
    let assetsDir = findAssetsCatalog(in: appSourceDir) ?? (appSourceDir + "Assets.xcassets")
    try fm.createDirectory(atPath: assetsDir.string, withIntermediateDirectories: true)
    let rootContents = assetsDir + "Contents.json"
    if !rootContents.exists {
        try "{\"info\":{\"author\":\"xcode\",\"version\":1}}\n".write(toFile: rootContents.string, atomically: true, encoding: .utf8)
    }

    for colorset in ["AccentColor.colorset", "LaunchBackground.colorset"] {
        let src = templateGameDir + "Assets.xcassets" + colorset + "Contents.json"
        let dstDir = assetsDir + colorset
        try fm.createDirectory(atPath: dstDir.string, withIntermediateDirectories: true)
        let dst = dstDir + "Contents.json"
        let json = try String(contentsOfFile: src.string, encoding: .utf8)
        try json.write(toFile: dst.string, atomically: true, encoding: .utf8)
        print("Updated \(colorset)")
    }

    // CLAUDE.md at project root.
    if templateClaudeFile.exists {
        let claudeDest = projectDir + "CLAUDE.md"
        let templateText = try String(contentsOfFile: templateClaudeFile.string, encoding: .utf8)
        if claudeDest.exists {
            let existing = try String(contentsOfFile: claudeDest.string, encoding: .utf8)
            if !existing.contains("## Still series") {
                try (existing + "\n\n" + templateText).write(toFile: claudeDest.string, atomically: true, encoding: .utf8)
                print("Appended Still rules to CLAUDE.md")
            }
        } else {
            try templateText.write(toFile: claudeDest.string, atomically: true, encoding: .utf8)
            print("Wrote CLAUDE.md")
        }
    }

    return writtenSwiftFiles
}

func directoryContainsMainAttribute(_ dir: Path) -> Bool {
    guard let enumerator = FileManager.default.enumerator(atPath: dir.string) else { return false }
    while let item = enumerator.nextObject() as? String {
        guard item.hasSuffix(".swift") else { continue }
        let full = (dir + item).string
        if let text = try? String(contentsOfFile: full, encoding: .utf8), text.contains("@main") {
            return true
        }
    }
    return false
}

func findAssetsCatalog(in dir: Path) -> Path? {
    let direct = dir + "Assets.xcassets"
    if direct.exists { return direct }
    guard let items = try? dir.children() else { return nil }
    return items.first { $0.extension == "xcassets" }
}

func registerClassicSwiftFiles(_ files: [Path], appSourceDir: Path, appGroup: PBXGroup,
                               target: PBXNativeTarget, pbxproj: PBXProj) throws {
    guard let sourcesPhase = try target.sourcesBuildPhase() else { return }

    for file in files {
        let relComponents = relativePath(from: appSourceDir, to: file).split(separator: "/").map(String.init)
        guard let fileName = relComponents.last else { continue }

        // Walk/create intermediate subgroups.
        var parentGroup = appGroup
        for folder in relComponents.dropLast() {
            if let existing = parentGroup.children.compactMap({ $0 as? PBXGroup }).first(where: { $0.path == folder || $0.name == folder }) {
                parentGroup = existing
            } else {
                let created = PBXGroup(children: [], sourceTree: .group, name: folder, path: folder)
                pbxproj.add(object: created)
                parentGroup.children.append(created)
                parentGroup = created
            }
        }

        let fileRef: PBXFileReference
        if let existing = parentGroup.children.compactMap({ $0 as? PBXFileReference }).first(where: { $0.path == fileName || $0.name == fileName }) {
            fileRef = existing
        } else {
            let created = PBXFileReference(sourceTree: .group, lastKnownFileType: "sourcecode.swift", path: fileName)
            pbxproj.add(object: created)
            parentGroup.children.append(created)
            fileRef = created
        }

        let alreadyInSources = (sourcesPhase.files ?? []).contains { $0.file === fileRef }
        if !alreadyInSources {
            let buildFile = PBXBuildFile(file: fileRef)
            pbxproj.add(object: buildFile)
            sourcesPhase.files?.append(buildFile)
        }
    }
}

func cleanUntouchedTemplateFiles(in appSourceDir: Path, target: PBXNativeTarget, pbxproj: PBXProj) throws {
    let fm = FileManager.default

    // Remove untouched ViewController.swift.
    let vcPath = appSourceDir + "ViewController.swift"
    if vcPath.exists, let text = try? String(contentsOfFile: vcPath.string, encoding: .utf8),
       text.contains("class ViewController: UIViewController"),
       text.contains("Do any additional setup after loading the view") {
        try fm.removeItem(atPath: vcPath.string)
        removeClassicFileReferences(named: "ViewController.swift", target: target, pbxproj: pbxproj)
        print("Removed untouched template ViewController.swift")
    }

    // Remove untouched Main.storyboard (either directly or inside Base.lproj).
    for candidate in [appSourceDir + "Main.storyboard", appSourceDir + "Base.lproj" + "Main.storyboard"] {
        if candidate.exists, let text = try? String(contentsOfFile: candidate.string, encoding: .utf8),
           text.contains("customClass=\"ViewController\"") {
            try fm.removeItem(atPath: candidate.string)
            removeClassicFileReferences(named: "Main.storyboard", target: target, pbxproj: pbxproj)
            print("Removed untouched template Main.storyboard")
        }
    }
}

func removeClassicFileReferences(named fileName: String, target: PBXNativeTarget, pbxproj: PBXProj) {
    let matchingRefs = pbxproj.fileReferences.filter { $0.path == fileName || $0.name == fileName }
    let matchingVariantGroups = pbxproj.variantGroups.filter { $0.name == fileName }

    for phase in target.buildPhases {
        phase.files?.removeAll { buildFile in
            guard let file = buildFile.file else { return false }
            return matchingRefs.contains(where: { $0 === file })
                || matchingVariantGroups.contains(where: { $0 === file })
        }
    }
    for group in pbxproj.groups {
        group.children.removeAll { child in
            matchingRefs.contains(where: { $0 === child })
                || matchingVariantGroups.contains(where: { $0 === child })
        }
    }
    for ref in matchingRefs { pbxproj.delete(object: ref) }
    for vg in matchingVariantGroups { pbxproj.delete(object: vg) }
}

func configureLaunchScreenAndSceneDelegate(
    target: PBXNativeTarget,
    pbxproj: PBXProj,
    project: PBXProject,
    usesSynchronizedFolder: Bool,
    appSourceDir: Path,
    projectDir: Path,
    templateConfigDir: Path
) throws {
    let fm = FileManager.default
    let configs = target.buildConfigurationList?.buildConfigurations ?? []
    let templateInfoPlist = templateConfigDir + "Info.plist"

    // Ensure Config/ exists for Info.plist and xcconfig templates (outside any synced folder).
    let configDir = projectDir + "Config"
    try fm.createDirectory(atPath: configDir.string, withIntermediateDirectories: true)
    for fileName in ["Base.xcconfig", "Local.xcconfig.example"] {
        let src = templateConfigDir + fileName
        let dst = configDir + fileName
        if src.exists && !dst.exists {
            try String(contentsOfFile: src.string, encoding: .utf8)
                .write(toFile: dst.string, atomically: true, encoding: .utf8)
        }
    }

    // Strip storyboard build settings if present.
    for config in configs {
        config.buildSettings.removeValue(forKey: "INFOPLIST_KEY_UIMainStoryboardFile")
        config.buildSettings.removeValue(forKey: "INFOPLIST_KEY_UILaunchStoryboardName")
        config.buildSettings.removeValue(forKey: "INFOPLIST_KEY_UIApplicationSceneManifest_Generation")
    }

    // Locate Info.plist from build settings, or write Config/Info.plist (always outside synced folders).
    let existingInfoPath: Path? = configs.compactMap { config -> Path? in
        guard let raw = config.buildSettings["INFOPLIST_FILE"] as? String, !raw.isEmpty else { return nil }
        return projectDir + raw
    }.first

    let targetInfoPlist: Path
    if let existingInfoPath, existingInfoPath.exists {
        targetInfoPlist = existingInfoPath
    } else {
        targetInfoPlist = configDir + "Info.plist"
        let rel = relativePath(from: projectDir, to: targetInfoPlist)
        for config in configs {
            config.buildSettings["INFOPLIST_FILE"] = rel
            config.buildSettings["GENERATE_INFOPLIST_FILE"] = "NO"
        }
        if !targetInfoPlist.exists {
            let templateContent = try String(contentsOfFile: templateInfoPlist.string, encoding: .utf8)
            try templateContent.write(toFile: targetInfoPlist.string, atomically: true, encoding: .utf8)
            if let mainGroup = project.mainGroup {
                let configGroup = mainGroup.children.compactMap({ $0 as? PBXGroup }).first(where: { $0.path == "Config" || $0.name == "Config" }) ?? {
                    let g = PBXGroup(children: [], sourceTree: .group, name: "Config", path: "Config")
                    pbxproj.add(object: g)
                    mainGroup.children.append(g)
                    return g
                }()
                let ref = PBXFileReference(sourceTree: .group, lastKnownFileType: "text.plist.xml", path: "Info.plist")
                pbxproj.add(object: ref)
                configGroup.children.append(ref)
            }
            print("Wrote Config/Info.plist with LaunchBackground launch screen")
            return
        }
    }

    // Merge UILaunchScreen and SceneDelegate scene manifest into existing Info.plist.
    let data = try Data(contentsOf: URL(fileURLWithPath: targetInfoPlist.string))
    var format = PropertyListSerialization.PropertyListFormat.xml
    guard var plist = try PropertyListSerialization.propertyList(from: data, options: .mutableContainersAndLeaves, format: &format) as? [String: Any] else {
        return
    }

    plist.removeValue(forKey: "UIMainStoryboardFile")
    plist.removeValue(forKey: "UILaunchStoryboardName")
    plist["UILaunchScreen"] = ["UIColorName": "LaunchBackground"]

    if var manifest = plist["UIApplicationSceneManifest"] as? [String: Any],
       var configurations = manifest["UISceneConfigurations"] as? [String: Any],
       var appScenes = configurations["UIWindowSceneSessionRoleApplication"] as? [[String: Any]],
       !appScenes.isEmpty {
        appScenes[0].removeValue(forKey: "UISceneStoryboardFile")
        appScenes[0]["UISceneDelegateClassName"] = "$(PRODUCT_MODULE_NAME).SceneDelegate"
        configurations["UIWindowSceneSessionRoleApplication"] = appScenes
        manifest["UISceneConfigurations"] = configurations
        plist["UIApplicationSceneManifest"] = manifest
    } else {
        plist["UIApplicationSceneManifest"] = [
            "UIApplicationSupportsMultipleScenes": false,
            "UISceneConfigurations": [
                "UIWindowSceneSessionRoleApplication": [
                    [
                        "UISceneConfigurationName": "Default Configuration",
                        "UISceneDelegateClassName": "$(PRODUCT_MODULE_NAME).SceneDelegate",
                    ],
                ],
            ],
        ]
    }

    let updated = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
    try updated.write(to: URL(fileURLWithPath: targetInfoPlist.string))
    print("Updated \(targetInfoPlist.lastComponent) with LaunchBackground and SceneDelegate")
}

func ensureAssetCatalogBuildSettings(on target: PBXNativeTarget) {
    for config in target.buildConfigurationList?.buildConfigurations ?? [] {
        if config.buildSettings["ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME"] == nil {
            config.buildSettings["ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME"] = "AccentColor"
        }
    }
}

func ensureSharedScheme(projPath: Path, target: PBXNativeTarget) throws {
    let schemesDir = projPath + "xcshareddata" + "xcschemes"
    let schemePath = schemesDir + "\(target.name).xcscheme"
    if schemePath.exists { return }

    try FileManager.default.createDirectory(atPath: schemesDir.string, withIntermediateDirectories: true)
    let reference = XCScheme.BuildableReference(
        referencedContainer: "container:\(projPath.lastComponent)",
        blueprint: target,
        buildableName: "\(target.name).app",
        blueprintName: target.name
    )
    let buildEntry = XCScheme.BuildAction.Entry(
        buildableReference: reference,
        buildFor: [.testing, .running, .profiling, .archiving, .analyzing]
    )
    let scheme = XCScheme(
        name: target.name,
        lastUpgradeVersion: "1600",
        version: "1.7",
        buildAction: XCScheme.BuildAction(buildActionEntries: [buildEntry],
                                          parallelizeBuild: true,
                                          buildImplicitDependencies: true),
        launchAction: XCScheme.LaunchAction(
            runnable: XCScheme.BuildableProductRunnable(buildableReference: reference),
            buildConfiguration: "Debug"
        )
    )
    try scheme.write(path: schemePath, override: true)
}

func runProcess(_ launchPath: String, arguments: [String], currentDirectory: String) -> Int32 {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: launchPath)
    process.arguments = arguments
    process.currentDirectoryURL = URL(fileURLWithPath: currentDirectory)
    do {
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus
    } catch {
        fputs("Failed to launch \(launchPath): \(error)\n", stderr)
        return 1
    }
}
