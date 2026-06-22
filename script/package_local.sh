#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCHEME="${SCHEME:-CodexModelSwitcher}"
CONFIGURATION="${CONFIGURATION:-Release}"
DERIVED_DATA="$ROOT_DIR/.build/xcode-derived"
DIST_DIR="$ROOT_DIR/dist"
PACKAGE_NAME="CodexModelSwitcher-local"
PACKAGE_DIR="$DIST_DIR/$PACKAGE_NAME"
ZIP_PATH="$DIST_DIR/$PACKAGE_NAME-macos.zip"
APP_NAME="CodexModelSwitcher.app"
APP_SOURCE="$DERIVED_DATA/Build/Products/$CONFIGURATION/$APP_NAME"

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "error: xcodebuild was not found. Build the package on a Mac with Xcode installed." >&2
  exit 1
fi

rm -rf "$PACKAGE_DIR" "$ZIP_PATH" "$ZIP_PATH.sha256"
mkdir -p "$PACKAGE_DIR"

echo "Building $APP_NAME ($CONFIGURATION)..."
XCODEBUILD_FLAGS=()
if [[ "${VERBOSE:-0}" != "1" ]]; then
  XCODEBUILD_FLAGS+=("-quiet")
fi

xcodebuild "${XCODEBUILD_FLAGS[@]}" \
  -project "$ROOT_DIR/CodexModelSwitcher.xcodeproj" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination "generic/platform=macOS" \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY=- \
  DEVELOPMENT_TEAM= \
  ONLY_ACTIVE_ARCH=NO \
  build

if [[ ! -d "$APP_SOURCE" ]]; then
  echo "error: expected app was not built at $APP_SOURCE" >&2
  exit 1
fi

echo "Assembling local package..."
/usr/bin/ditto "$APP_SOURCE" "$PACKAGE_DIR/$APP_NAME"
/usr/bin/ditto "$ROOT_DIR/script/install_local_package.sh" "$PACKAGE_DIR/install.sh"
chmod +x "$PACKAGE_DIR/install.sh"

cat > "$PACKAGE_DIR/README.txt" <<'README'
Codex Model Switcher local package

This package installs the already-built app onto a Mac without Xcode.

Install:

  ./install.sh

Notes:

- This is a private local package, not a notarized public distribution.
- The app manages local Codex profile config only; it does not include account secrets.
- macOS may ask for permission to install into /Applications.
- To make bare terminal launches like `codex` follow profile switches, open the
  app and click the terminal icon once. Then open a new terminal window, or run
  `source ~/.zshrc` once.
README

(
  cd "$DIST_DIR"
  /usr/bin/ditto -c -k --sequesterRsrc --keepParent "$PACKAGE_NAME" "$ZIP_PATH"
)

shasum -a 256 "$ZIP_PATH" > "$ZIP_PATH.sha256"

echo
echo "Package created:"
echo "  $ZIP_PATH"
echo "  $ZIP_PATH.sha256"
echo
echo "On another Mac:"
echo "  unzip $(basename "$ZIP_PATH")"
echo "  cd $PACKAGE_NAME"
echo "  ./install.sh"
