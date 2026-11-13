#!/usr/bin/env bash
# 在模拟器上跑单元测试。
#   ./scripts/test.sh                 # 默认 iPhone 15
#   SIM="iPhone 16 Pro" ./scripts/test.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

SIM="${SIM:-iPhone 15}"
OS="${OS:-latest}"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "缺少 xcodegen，先执行：brew install xcodegen" >&2
  exit 1
fi

python3 scripts/gen_project.py

xcodebuild test \
  -project TrainLedger.xcodeproj \
  -scheme TrainLedger \
  -destination "platform=iOS Simulator,name=$SIM,OS=$OS" \
  CODE_SIGNING_ALLOWED=NO
