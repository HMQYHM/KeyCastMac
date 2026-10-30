#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
APP="键映.app"
SRC="dist/$APP"
DEST="/Applications/$APP"

if [ ! -d "$SRC" ]; then
  echo "未找到 $SRC，请先运行 ./build.sh"
  exit 1
fi

echo "==> 退出正在运行的 键映"
osascript -e 'tell application "键映" to quit' 2>/dev/null || true
pkill -x KeyCast 2>/dev/null || true
sleep 1

echo "==> 安装 / 覆盖到 $DEST"
rm -rf "$DEST"
ditto "$SRC" "$DEST"

echo "==> 重新打开"
open "$DEST"
echo "完成：已安装到 $DEST"
