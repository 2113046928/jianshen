#!/usr/bin/env bash
# 一键跑完所有本机可执行的校验（不需要 Xcode）。
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SPEC="$ROOT/spec"
PYTHON="${PYTHON:-python3}"
FAILED=0

run() {
  local label="$1"; shift
  echo "── $label"
  if "$@" >/tmp/verify.out 2>&1; then
    tail -2 /tmp/verify.out
  else
    echo "失败："
    tail -20 /tmp/verify.out
    FAILED=1
  fi
}

[[ -d "$SPEC" ]] && run "配重规则" "$PYTHON" "$SPEC/test_engine.py"
[[ -d "$SPEC" ]] && run "资产与计划包" "$PYTHON" "$SPEC/validate_assets.py"
[[ -d "$SPEC" ]] && run "工程结构" "$PYTHON" "$SPEC/validate_project.py"
[[ -d "$SPEC" ]] && run "import 检查" "$PYTHON" "$SPEC/check_imports.py"
run "中英文案对齐" "$PYTHON" "$ROOT/scripts/extract_strings.py" --check

echo
if [[ $FAILED -eq 0 ]]; then
  echo "全部通过"
else
  echo "有失败项，见上面输出"
fi
exit $FAILED
