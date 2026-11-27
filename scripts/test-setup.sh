#!/usr/bin/env bash
set -euo pipefail

# End-to-end smoke test for scripts/new-app.sh and Tools/still-setup.
# Creates freshly generated iOS projects (both classic PBXGroup and Xcode 16+
# synchronized folder), verifies iOS <17 rejection, runs scripts/new-app.sh
# with --local-package, and builds each generated app for iOS Simulator.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/still-setup-test.XXXXXX")"
trap 'rm -rf "$TMP_ROOT"' EXIT

echo "==> 1. Verifying deployment target < 17.0 is rejected"
OLD_DIR="$TMP_ROOT/OldApp"
mkdir -p "$OLD_DIR/OldApp.xcodeproj" "$OLD_DIR/OldApp"
cat > "$OLD_DIR/OldApp.xcodeproj/project.pbxproj" <<'EOF'
// !$*UTF8*$!
{
	archiveVersion = 1;
	classes = {};
	objectVersion = 56;
	objects = {
		B10000010000000000000001 = { isa = PBXGroup; children = (); sourceTree = "<group>"; };
		B20000010000000000000001 = { isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; };
		B30000010000000000000001 = { isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; };
		B40000010000000000000001 = { isa = XCBuildConfiguration; buildSettings = { IPHONEOS_DEPLOYMENT_TARGET = 16.0; SDKROOT = iphoneos; PRODUCT_BUNDLE_IDENTIFIER = com.example.oldapp; }; name = Debug; };
		B50000010000000000000001 = { isa = XCConfigurationList; buildConfigurations = ( B40000010000000000000001 ); defaultConfigurationIsVisible = 0; defaultConfigurationName = Debug; };
		B60000010000000000000001 = { isa = PBXNativeTarget; buildConfigurationList = B50000010000000000000001; buildPhases = ( B20000010000000000000001, B30000010000000000000001 ); buildRules = (); dependencies = (); name = OldApp; productName = OldApp; productType = "com.apple.product-type.application"; };
		B70000010000000000000001 = { isa = PBXProject; buildConfigurationList = B50000010000000000000001; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = ( en ); mainGroup = B10000010000000000000001; targets = ( B60000010000000000000001 ); };
	};
	rootObject = B70000010000000000000001;
}
EOF

if "$REPO_ROOT/scripts/new-app.sh" --skip-build --local-package "$REPO_ROOT" "$OLD_DIR/OldApp.xcodeproj" >/dev/null 2>&1; then
    echo "error: expected iOS 16.0 project to fail deployment target check" >&2
    exit 1
fi
echo "    iOS 16.0 project correctly rejected."

echo "==> 2. Testing classic PBXGroup project (with untouched ViewController + Main.storyboard)"
CLASSIC_DIR="$TMP_ROOT/FreshClassic"
mkdir -p "$CLASSIC_DIR/FreshClassic.xcodeproj" "$CLASSIC_DIR/FreshClassic/Assets.xcassets"
cat > "$CLASSIC_DIR/FreshClassic/Assets.xcassets/Contents.json" <<'EOF'
{ "info": { "author": "xcode", "version": 1 } }
EOF
cat > "$CLASSIC_DIR/FreshClassic/ViewController.swift" <<'EOF'
import UIKit

class ViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }
}
EOF
cat > "$CLASSIC_DIR/FreshClassic/Main.storyboard" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<document type="com.apple.InterfaceBuilder3.CocoaTouch.Storyboard.XIB" version="3.0">
    <scenes>
        <scene sceneID="tne-QT-ifu">
            <objects>
                <viewController id="BYZ-38-t0r" customClass="ViewController" sceneMemberID="viewController"/>
            </objects>
        </scene>
    </scenes>
</document>
EOF
cat > "$CLASSIC_DIR/FreshClassic.xcodeproj/project.pbxproj" <<'EOF'
// !$*UTF8*$!
{
	archiveVersion = 1;
	classes = {};
	objectVersion = 56;
	objects = {
		C10000010000000000000001 /* ViewController.swift in Sources */ = { isa = PBXBuildFile; fileRef = C20000010000000000000001; };
		C10000020000000000000001 /* Assets.xcassets in Resources */ = { isa = PBXBuildFile; fileRef = C20000020000000000000001; };
		C10000030000000000000001 /* Main.storyboard in Resources */ = { isa = PBXBuildFile; fileRef = C20000030000000000000001; };
		C20000010000000000000001 /* ViewController.swift */ = { isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ViewController.swift; sourceTree = "<group>"; };
		C20000020000000000000001 /* Assets.xcassets */ = { isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = "<group>"; };
		C20000030000000000000001 /* Main.storyboard */ = { isa = PBXFileReference; lastKnownFileType = file.storyboard; path = Main.storyboard; sourceTree = "<group>"; };
		C20000040000000000000001 /* FreshClassic.app */ = { isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = FreshClassic.app; sourceTree = BUILT_PRODUCTS_DIR; };
		C30000010000000000000001 = { isa = PBXGroup; children = ( C30000020000000000000001, C30000030000000000000001 ); sourceTree = "<group>"; };
		C30000020000000000000001 /* FreshClassic */ = { isa = PBXGroup; children = ( C20000010000000000000001, C20000020000000000000001, C20000030000000000000001 ); path = FreshClassic; sourceTree = "<group>"; };
		C30000030000000000000001 /* Products */ = { isa = PBXGroup; children = ( C20000040000000000000001 ); name = Products; sourceTree = "<group>"; };
		C40000010000000000000001 /* Sources */ = { isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ( C10000010000000000000001 ); runOnlyForDeploymentPostprocessing = 0; };
		C40000020000000000000001 /* Frameworks */ = { isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; };
		C40000030000000000000001 /* Resources */ = { isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = ( C10000020000000000000001, C10000030000000000000001 ); runOnlyForDeploymentPostprocessing = 0; };
		C50000010000000000000001 /* Debug */ = { isa = XCBuildConfiguration; buildSettings = { ALWAYS_SEARCH_USER_PATHS = NO; IPHONEOS_DEPLOYMENT_TARGET = 17.0; SDKROOT = iphoneos; SWIFT_VERSION = 5.0; }; name = Debug; };
		C50000020000000000000001 /* Debug */ = { isa = XCBuildConfiguration; buildSettings = { CODE_SIGN_STYLE = Automatic; GENERATE_INFOPLIST_FILE = YES; INFOPLIST_KEY_UIMainStoryboardFile = Main; IPHONEOS_DEPLOYMENT_TARGET = 17.0; PRODUCT_BUNDLE_IDENTIFIER = com.example.freshclassic; PRODUCT_NAME = "$(TARGET_NAME)"; SWIFT_VERSION = 5.0; TARGETED_DEVICE_FAMILY = "1,2"; }; name = Debug; };
		C60000010000000000000001 = { isa = XCConfigurationList; buildConfigurations = ( C50000010000000000000001 ); defaultConfigurationIsVisible = 0; defaultConfigurationName = Debug; };
		C60000020000000000000001 = { isa = XCConfigurationList; buildConfigurations = ( C50000020000000000000001 ); defaultConfigurationIsVisible = 0; defaultConfigurationName = Debug; };
		C70000010000000000000001 /* FreshClassic */ = { isa = PBXNativeTarget; buildConfigurationList = C60000020000000000000001; buildPhases = ( C40000010000000000000001, C40000020000000000000001, C40000030000000000000001 ); buildRules = (); dependencies = (); name = FreshClassic; productName = FreshClassic; productReference = C20000040000000000000001; productType = "com.apple.product-type.application"; };
		C80000010000000000000001 = { isa = PBXProject; buildConfigurationList = C60000010000000000000001; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = ( en ); mainGroup = C30000010000000000000001; productRefGroup = C30000030000000000000001; targets = ( C70000010000000000000001 ); };
	};
	rootObject = C80000010000000000000001;
}
EOF

"$REPO_ROOT/scripts/new-app.sh" --local-package "$REPO_ROOT" "$CLASSIC_DIR/FreshClassic.xcodeproj"

test ! -f "$CLASSIC_DIR/FreshClassic/ViewController.swift"
test ! -f "$CLASSIC_DIR/FreshClassic/Main.storyboard"
test -f "$CLASSIC_DIR/Config/Info.plist"
test -f "$CLASSIC_DIR/Config/Base.xcconfig"
test -f "$CLASSIC_DIR/FreshClassic/App/SceneDelegate.swift"
test -f "$CLASSIC_DIR/FreshClassic/Game/FreshClassicGame.swift"
test -f "$CLASSIC_DIR/FreshClassic/Assets.xcassets/AccentColor.colorset/Contents.json"
test -f "$CLASSIC_DIR/FreshClassic/Assets.xcassets/LaunchBackground.colorset/Contents.json"
test -f "$CLASSIC_DIR/CLAUDE.md"

echo "==> 3. Testing Xcode 16+ synchronized folder project"
SYNC_DIR="$TMP_ROOT/FreshSynced"
mkdir -p "$SYNC_DIR/FreshSynced.xcodeproj" "$SYNC_DIR/FreshSynced/Assets.xcassets"
cat > "$SYNC_DIR/FreshSynced/Assets.xcassets/Contents.json" <<'EOF'
{ "info": { "author": "xcode", "version": 1 } }
EOF
cat > "$SYNC_DIR/FreshSynced.xcodeproj/project.pbxproj" <<'EOF'
// !$*UTF8*$!
{
	archiveVersion = 1;
	classes = {};
	objectVersion = 77;
	objects = {
		D20000040000000000000001 /* FreshSynced.app */ = { isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = FreshSynced.app; sourceTree = BUILT_PRODUCTS_DIR; };
		D30000020000000000000001 /* FreshSynced */ = { isa = PBXFileSystemSynchronizedRootGroup; path = FreshSynced; sourceTree = "<group>"; };
		D30000010000000000000001 = { isa = PBXGroup; children = ( D30000020000000000000001, D30000030000000000000001 ); sourceTree = "<group>"; };
		D30000030000000000000001 /* Products */ = { isa = PBXGroup; children = ( D20000040000000000000001 ); name = Products; sourceTree = "<group>"; };
		D40000010000000000000001 /* Sources */ = { isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; };
		D40000020000000000000001 /* Frameworks */ = { isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; };
		D40000030000000000000001 /* Resources */ = { isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; };
		D50000010000000000000001 /* Debug */ = { isa = XCBuildConfiguration; buildSettings = { ALWAYS_SEARCH_USER_PATHS = NO; IPHONEOS_DEPLOYMENT_TARGET = 17.0; SDKROOT = iphoneos; SWIFT_VERSION = 5.0; }; name = Debug; };
		D50000020000000000000001 /* Debug */ = { isa = XCBuildConfiguration; buildSettings = { CODE_SIGN_STYLE = Automatic; GENERATE_INFOPLIST_FILE = YES; IPHONEOS_DEPLOYMENT_TARGET = 17.0; PRODUCT_BUNDLE_IDENTIFIER = com.example.freshsynced; PRODUCT_NAME = "$(TARGET_NAME)"; SWIFT_VERSION = 5.0; TARGETED_DEVICE_FAMILY = "1,2"; }; name = Debug; };
		D60000010000000000000001 = { isa = XCConfigurationList; buildConfigurations = ( D50000010000000000000001 ); defaultConfigurationIsVisible = 0; defaultConfigurationName = Debug; };
		D60000020000000000000001 = { isa = XCConfigurationList; buildConfigurations = ( D50000020000000000000001 ); defaultConfigurationIsVisible = 0; defaultConfigurationName = Debug; };
		D70000010000000000000001 /* FreshSynced */ = { isa = PBXNativeTarget; buildConfigurationList = D60000020000000000000001; buildPhases = ( D40000010000000000000001, D40000020000000000000001, D40000030000000000000001 ); buildRules = (); dependencies = (); fileSystemSynchronizedGroups = ( D30000020000000000000001 ); name = FreshSynced; productName = FreshSynced; productReference = D20000040000000000000001; productType = "com.apple.product-type.application"; };
		D80000010000000000000001 = { isa = PBXProject; buildConfigurationList = D60000010000000000000001; compatibilityVersion = "Xcode 16.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = ( en ); mainGroup = D30000010000000000000001; productRefGroup = D30000030000000000000001; targets = ( D70000010000000000000001 ); };
	};
	rootObject = D80000010000000000000001;
}
EOF

"$REPO_ROOT/scripts/new-app.sh" --local-package "$REPO_ROOT" "$SYNC_DIR/FreshSynced.xcodeproj"

test -f "$SYNC_DIR/FreshSynced/Game/FreshSyncedGame.swift"
test -f "$SYNC_DIR/CLAUDE.md"

echo "==> All setup tool checks passed!"
