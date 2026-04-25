#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="UniversalImageCopy"
BUNDLE_ID="${BUNDLE_ID:-com.codex.UniversalImageCopy}"
VERSION="${VERSION:-0.1.0}"
BUILD_DIR="$ROOT_DIR/build"
MODULE_CACHE_DIR="$ROOT_DIR/.build/ModuleCache"

mkdir -p "$MODULE_CACHE_DIR"
export SWIFTPM_MODULECACHE_PATH="$MODULE_CACHE_DIR"
export CLANG_MODULE_CACHE_PATH="$MODULE_CACHE_DIR"

swift build -c release --disable-sandbox --package-path "$ROOT_DIR"

BIN_PATH="$ROOT_DIR/.build/release/$APP_NAME"
if [[ ! -f "$BIN_PATH" ]]; then
  echo "Release binary not found at $BIN_PATH" >&2
  exit 1
fi

APP_DIR="$BUILD_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$BIN_PATH" "$MACOS_DIR/$APP_NAME"

RESOURCE_BUNDLE=$(find "$ROOT_DIR/.build" -path "*/release/*.bundle" -name "*.bundle" -print -quit)
if [[ -n "${RESOURCE_BUNDLE:-}" ]]; then
  cp -R "$RESOURCE_BUNDLE" "$RESOURCES_DIR/"
fi

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>Universal Image Copy</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$VERSION</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSAppleEventsUsageDescription</key>
  <string>Universal Image Copy checks the active Chrome tab to confirm you are in Google Slides before converting copied content automatically.</string>
  <key>NSInputMonitoringUsageDescription</key>
  <string>Universal Image Copy watches for Command-C so it can convert Google Slides clipboard content into real PNG data automatically.</string>
</dict>
</plist>
PLIST

echo "Built $APP_DIR"
