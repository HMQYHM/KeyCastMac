#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
./build.sh

APP="键映.app"
DMG="dist/键映.dmg"
STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT

echo "==> 准备 DMG 内容"
cp -R "dist/$APP" "$STAGING/"

rm -f "$DMG"
echo "==> 创建 DMG"
hdiutil create -volname "键映" -srcfolder "$STAGING" -ov -format UDZO "$DMG"

echo "==> 完成：$DMG"
