# -*- coding: utf-8 -*-
"""生成 Xcode 工程。

    python3 scripts/gen_project.py              # 完整工程（含 watch / widget）
    WITH_WATCH=0 python3 scripts/gen_project.py # CI 精简模式，不需要 PyYAML

CI 精简模式会剔除：
  * TrainLedgerWatch target 及其依赖
  * TrainLedgerWidgets 嵌入依赖
  * 各 target 的 entitlements

原因：禁用签名时 ValidateEmbeddedBinary 会去读主 app 的 Info.plist 而失败，
entitlements 在未签名包里也不生效。完整工程请在 Mac 上带签名构建。
"""
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "project.yml"
OUT = ROOT / "project.generated.yml"


def _drop_target_block(lines, name):
    out, skipping = [], False
    for line in lines:
        if re.match(rf"^  {name}:", line):
            skipping = True
            continue
        if skipping:
            if re.match(r"^  \S", line):
                skipping = False
            else:
                continue
        out.append(line)
    return out


def _drop_dependency(lines, name):
    out, skipping = [], False
    for line in lines:
        if re.match(rf"^\s+- target: {name}\s*$", line):
            skipping = True
            continue
        if skipping:
            if re.match(r"^\s{4}- ", line) or re.match(r"^\s{0,2}\S", line):
                skipping = False
            else:
                continue
        out.append(line)
    return out


def _drop_entitlements(lines):
    out, skipping = [], False
    for line in lines:
        if re.match(r"^\s+entitlements:\s*$", line):
            skipping = True
            continue
        if skipping:
            if re.match(r"^\s{0,4}\S", line):
                skipping = False
            else:
                continue
        out.append(line)
    return out


def strip_for_ci(text: str, watch: bool, widget: bool, entitlements: bool) -> str:
    lines = text.splitlines()
    if watch:
        lines = _drop_target_block(lines, "TrainLedgerWatch")
        lines = _drop_dependency(lines, "TrainLedgerWatch")
    if widget:
        lines = _drop_dependency(lines, "TrainLedgerWidgets")
    if entitlements:
        lines = _drop_entitlements(lines)
    return "\n".join(lines) + "\n"


def generate(spec_path: Path) -> int:
    if shutil.which("xcodegen") is None:
        print(
            f"未找到 xcodegen。装好后执行：xcodegen generate --spec {spec_path.name}",
            file=sys.stderr,
        )
        return 2
    return subprocess.call(["xcodegen", "generate", "--spec", str(spec_path)])


def main() -> int:
    # 三个独立的裁剪开关，默认全保留（本地开发用完整工程）
    drop_watch = os.environ.get("WITH_WATCH", "1") == "0"
    drop_widget = os.environ.get("WITH_WIDGET", "1") == "0"
    drop_entitlements = os.environ.get("WITH_ENTITLEMENTS", "1") == "0"

    if not (drop_watch or drop_widget or drop_entitlements):
        print("targets: 使用 project.yml（完整工程）")
        return generate(SRC)

    stripped = strip_for_ci(
        SRC.read_text(encoding="utf-8"),
        watch=drop_watch,
        widget=drop_widget,
        entitlements=drop_entitlements,
    )

    problems = []
    if drop_watch and "TrainLedgerWatch" in stripped:
        problems.append("仍包含 watch target")
    if drop_widget and "target: TrainLedgerWidgets" in stripped:
        problems.append("仍嵌入 widget")
    if drop_entitlements and "entitlements:" in stripped:
        problems.append("仍包含 entitlements")
    if problems:
        print(f"裁剪失败：{problems}", file=sys.stderr)
        return 2

    OUT.write_text(stripped, encoding="utf-8")
    kept = [
        name
        for name, dropped in [
            ("watch", drop_watch),
            ("widget", drop_widget),
            ("entitlements", drop_entitlements),
        ]
        if dropped
    ]
    print(f"targets: 已裁剪 {', '.join(kept)}")
    return generate(OUT)


if __name__ == "__main__":
    sys.exit(main())
