#!/usr/bin/env bash
# 推送前的本地预检：所有不依赖 Xcode 的检查一次跑完。
#
#   ./scripts/preflight.sh
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
PYTHON="${PYTHON:-python3}"
FAILED=0

run() {
  local label="$1"; shift
  printf "── %-22s" "$label"
  if "$@" >/tmp/preflight.out 2>&1; then
    echo "通过"
  else
    echo "失败"
    tail -25 /tmp/preflight.out | sed 's/^/     /'
    FAILED=1
  fi
}

run "配重规则"        "$PYTHON" spec/test_engine.py
run "营养算法"        "$PYTHON" spec/test_nutrition.py
run "体脂公式"        "$PYTHON" spec/bodyfat.py
run "动作库与计划包"   "$PYTHON" spec/validate_assets.py
run "工程结构"        "$PYTHON" spec/validate_project.py
run "框架 import"     "$PYTHON" spec/check_imports.py
run "符号引用"        "$PYTHON" spec/lint_swift.py
run "成员访问"        "$PYTHON" spec/lint_members.py
run "闭包参数"        "$PYTHON" spec/lint_closures.py
run "死代码与重复"     "$PYTHON" spec/review_swift.py
run "中英文案对齐"     "$PYTHON" scripts/extract_strings.py --check

echo
if [[ $FAILED -eq 0 ]]; then
  echo "预检通过，可以推送。"
  echo "推送后到 GitHub Actions 看「iOS」和「Build IPA」两个 workflow。"
else
  echo "预检有失败项，先修再推。"
fi
exit $FAILED
