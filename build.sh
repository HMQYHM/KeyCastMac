#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
APP_NAME="键映"
DIST="dist/$APP_NAME.app"
BIN=".build/release/KeyCast"

echo "==> swift build"
swift build -c release

echo "==> assembling .app"
rm -rf "$DIST"
mkdir -p "$DIST/Contents/MacOS" "$DIST/Contents/Resources"
cp "$BIN" "$DIST/Contents/MacOS/KeyCast"
cp "Info.plist" "$DIST/Contents/Info.plist"

echo "==> codesign"
if security find-identity -v -p codesigning 2>/dev/null | grep -q "PA Keystroke Dev"; then
  codesign --force --timestamp=none --sign "PA Keystroke Dev" "$DIST"
else
  codesign --force --timestamp=none --sign - "$DIST"
fi

echo "==> done: $DIST"
