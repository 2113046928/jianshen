#!/usr/bin/env bash
# 归档并导出 App Store 包。上传前请确认版本号与 Bundle ID。
#
#   export TEAM_ID=ABCDE12345
#   ./scripts/archive.sh
#
# 产物：build/TrainLedger.xcarchive 与 build/export/TrainLedger.ipa
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

TEAM_ID="${TEAM_ID:-}"
if [[ -z "$TEAM_ID" ]]; then
  echo "缺少 TEAM_ID。先执行：export TEAM_ID=你的10位TeamID" >&2
  exit 1
fi

SCHEME="TrainLedger"
BUILD_DIR="build"
ARCHIVE="$BUILD_DIR/TrainLedger.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "缺少 xcodegen，先执行：brew install xcodegen" >&2
  exit 1
fi

echo "==> 生成工程"
python3 scripts/gen_project.py

rm -rf "$ARCHIVE" "$EXPORT_DIR"
mkdir -p "$BUILD_DIR"

echo "==> 归档"
xcodebuild archive \
  -project TrainLedger.xcodeproj \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  CODE_SIGN_STYLE=Automatic \
  -allowProvisioningUpdates

echo "==> 导出"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist scripts/ExportOptions.plist \
  -allowProvisioningUpdates

echo "==> 完成：$EXPORT_DIR"
ls -lh "$EXPORT_DIR"
