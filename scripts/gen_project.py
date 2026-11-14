# -*- coding: utf-8 -*-
"""生成 Xcode 工程。

    python3 scripts/gen_project.py              # 含 watchOS
    WITH_WATCH=0 python3 scripts/gen_project.py # 剔除 watchOS（不需要 PyYAML）

默认路径不引入任何第三方依赖——CI runner 上没有装 PyYAML。
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


def strip_watch(text: str) -> str:
    """从 project.yml 文本里删掉 TrainLedgerWatch target 及其依赖。"""
    # 1) 整个 target 块：从 "  TrainLedgerWatch:" 到下一个同级 key
    lines = text.splitlines()
    out: list[str] = []
    skipping = False
    for line in lines:
        if re.match(r"^  TrainLedgerWatch:", line):
            skipping = True
            continue
        if skipping:
            if re.match(r"^  \S", line):   # 下一个同级 target
                skipping = False
            else:
                continue
        out.append(line)

    # 2) 主 target 里对 watch 的依赖块
    result: list[str] = []
    skipping = False
    for line in out:
        if re.match(r"^\s+- target: TrainLedgerWatch\s*$", line):
            skipping = True
            continue
        if skipping:
            if re.match(r"^\s{4}- ", line) or re.match(r"^\s{0,2}\S", line):
                skipping = False
            else:
                continue
        result.append(line)

    return "\n".join(result) + "\n"


def generate(spec_path: Path) -> int:
    if shutil.which("xcodegen") is None:
        print(
            f"未找到 xcodegen。装好后执行：xcodegen generate --spec {spec_path.name}",
            file=sys.stderr,
        )
        return 2
    return subprocess.call(["xcodegen", "generate", "--spec", str(spec_path)])


def main() -> int:
    if os.environ.get("WITH_WATCH", "1") != "0":
        print("targets: 使用 project.yml（含 watchOS）")
        return generate(SRC)

    stripped = strip_watch(SRC.read_text(encoding="utf-8"))
    if "TrainLedgerWatch" in stripped:
        print("剔除 watch 失败：还能找到 TrainLedgerWatch", file=sys.stderr)
        return 2
    OUT.write_text(stripped, encoding="utf-8")
    print("targets: 已剔除 watchOS")
    return generate(OUT)


if __name__ == "__main__":
    sys.exit(main())
