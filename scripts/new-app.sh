#!/usr/bin/env bash
set -euo pipefail

# Thin wrapper that builds and runs the still-setup Swift CLI from any terminal
# or VS Code / SweetPad without opening Xcode.
#
# Usage:
#   scripts/new-app.sh [--files-only] /path/to/MyGame/MyGame.xcodeproj

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TOOL_DIR="$REPO_ROOT/Tools/still-setup"

swift build --package-path "$TOOL_DIR" -c release --product still-setup >/dev/null
BIN_DIR="$(swift build --package-path "$TOOL_DIR" -c release --show-bin-path)"

exec "$BIN_DIR/still-setup" --repo-root "$REPO_ROOT" "$@"
