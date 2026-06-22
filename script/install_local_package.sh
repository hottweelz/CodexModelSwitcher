#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_SOURCE="${1:-$SCRIPT_DIR/CodexModelSwitcher.app}"
TARGET_DIR="${TARGET_DIR:-/Applications}"
TARGET_APP="$TARGET_DIR/CodexModelSwitcher.app"

if [[ ! -d "$APP_SOURCE" ]]; then
  echo "error: app bundle not found at $APP_SOURCE" >&2
  echo "usage: ./install.sh [path/to/CodexModelSwitcher.app]" >&2
  exit 1
fi

if [[ ! -d "$TARGET_DIR" ]]; then
  echo "error: target directory does not exist: $TARGET_DIR" >&2
  exit 1
fi

SUDO=()
if [[ ! -w "$TARGET_DIR" ]]; then
  SUDO=(sudo)
fi

echo "Stopping any running CodexModelSwitcher instance..."
pkill -x CodexModelSwitcher >/dev/null 2>&1 || true

if command -v xattr >/dev/null 2>&1; then
  xattr -dr com.apple.quarantine "$APP_SOURCE" >/dev/null 2>&1 || true
fi

echo "Installing to $TARGET_APP..."
"${SUDO[@]}" rm -rf "$TARGET_APP"
"${SUDO[@]}" /usr/bin/ditto "$APP_SOURCE" "$TARGET_APP"

if command -v xattr >/dev/null 2>&1; then
  "${SUDO[@]}" xattr -dr com.apple.quarantine "$TARGET_APP" >/dev/null 2>&1 || true
fi

echo "Launching CodexModelSwitcher..."
/usr/bin/open -n "$TARGET_APP"

echo "Installed. Look for Codex Profiles in the macOS menu bar."
