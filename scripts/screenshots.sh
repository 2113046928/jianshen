#!/usr/bin/env bash
# 生成 App Store 截图原始图。需要 macOS + Xcode + 模拟器。
#
#   ./scripts/screenshots.sh
#   DEVICE="iPhone 16 Pro" ./scripts/screenshots.sh
#
# 输出：docs/app-store/raw/*.png，再用 scripts/make_store_frames.py 合成带标题的成品图。
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

DEVICE="${DEVICE:-iPhone 16 Pro Max}"
BUNDLE_ID="com.trainledger.app"
OUT_DIR="docs/app-store/raw"
SCREENS=(today workout report phase history)

mkdir -p "$OUT_DIR"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "缺少 xcodegen，先执行：brew install xcodegen" >&2
  exit 1
fi

echo "==> 生成工程"
python3 scripts/gen_project.py

echo "==> 启动模拟器：$DEVICE"
xcrun simctl boot "$DEVICE" 2>/dev/null || true
open -a Simulator || true

echo "==> 构建"
xcodebuild \
  -project TrainLedger.xcodeproj \
  -scheme TrainLedger \
  -configuration Debug \
  -destination "platform=iOS Simulator,name=$DEVICE" \
  -derivedDataPath build/dd \
  CODE_SIGNING_ALLOWED=NO \
  build | tail -5

APP_PATH="$(find build/dd/Build/Products/Debug-iphonesimulator -maxdepth 1 -name 'TrainLedger.app' | head -1)"
if [[ -z "$APP_PATH" ]]; then
  echo "找不到构建产物" >&2
  exit 1
fi

xcrun simctl install booted "$APP_PATH"

for screen in "${SCREENS[@]}"; do
  echo "==> 截图：$screen"
  xcrun simctl terminate booted "$BUNDLE_ID" 2>/dev/null || true
  # -demoData 写入 4 周演示数据；-screen 决定打开哪个界面
  xcrun simctl launch booted "$BUNDLE_ID" -demoData -screen "$screen" >/dev/null
  sleep 4
  xcrun simctl io booted screenshot "$OUT_DIR/$screen.png"
done

echo "==> 完成：$OUT_DIR"
ls -1 "$OUT_DIR"
