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
    """删掉 `- target: X` 及其后续更深缩进的行。

    结束条件按缩进算：只要下一行的缩进 <= `- target` 的缩进，就不再属于这一项。
    之前用固定空格数判断，会把紧跟其后的 `info:` / `settings:` 块一起吞掉。
    """
    out, skipping, base_indent = [], False, 0
    for line in lines:
        m = re.match(rf"^(\s*)- target: {name}\s*$", line)
        if m:
            base_indent = len(m.group(1))
            skipping = True
            continue
        if skipping:
            if not line.strip():
                continue
            indent = len(line) - len(line.lstrip())
            if indent > base_indent:
                continue
            skipping = False
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


def _drop_empty_keys(lines):
    """删掉已经没有子项的 `dependencies:` 之类的空 key。

    xcodegen 要求 dependencies 是数组；如果把它下面的项全删光却留下 `dependencies:`，
    解析会报 "Incorrect type, expected Array<Any> found"。
    """
    out = []
    for i, line in enumerate(lines):
        if re.match(r"^\s+dependencies:\s*$", line):
            indent = len(line) - len(line.lstrip())
            nxt = next((l for l in lines[i + 1 :] if l.strip()), None)
            if nxt is None or (len(nxt) - len(nxt.lstrip())) <= indent:
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
    lines = _drop_empty_keys(lines)
    return "\n".join(lines) + "\n"


def generate(spec_path: Path) -> int:
    if shutil.which("xcodegen") is None:
        print(
            f"未找到 xcodegen。装好后执行：xcodegen generate --spec {spec_path.name}",
            file=sys.stderr,
        )
        return 2
    code = subprocess.call(["xcodegen", "generate", "--spec", str(spec_path)])
    if code != 0:
        # xcodegen 的报错只说 key，不给行号；把 spec 打出来，CI 日志里才能对照。
        print(f"--- xcodegen 失败，以下是 {spec_path.name} 全文 ---", file=sys.stderr)
        for index, line in enumerate(spec_path.read_text(encoding="utf-8").splitlines(), 1):
            print(f"{index:4} | {line}", file=sys.stderr)
        print("--- 结束 ---", file=sys.stderr)
    return code


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
