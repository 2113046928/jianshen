# -*- coding: utf-8 -*-
"""生成 Xcode 工程。

    python3 scripts/gen_project.py              # 包含 watchOS target
    WITH_WATCH=0 python3 scripts/gen_project.py # 剔除 watchOS target（构建兜底）
"""
import os
import shutil
import subprocess
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "project.yml"
OUT = ROOT / "project.generated.yml"


def main() -> int:
    spec = yaml.safe_load(SRC.read_text(encoding="utf-8"))
    with_watch = os.environ.get("WITH_WATCH", "1") != "0"

    if not with_watch:
        spec["targets"].pop("TrainLedgerWatch", None)
        deps = spec["targets"]["TrainLedger"].get("dependencies", [])
        spec["targets"]["TrainLedger"]["dependencies"] = [
            d for d in deps if d.get("target") != "TrainLedgerWatch"
        ]

    OUT.write_text(
        yaml.safe_dump(spec, allow_unicode=True, sort_keys=False),
        encoding="utf-8",
    )
    print("targets:", ", ".join(spec["targets"]))

    if shutil.which("xcodegen") is None:
        print(
            "未找到 xcodegen。已生成 project.generated.yml，"
            "在 macOS 上执行：xcodegen generate --spec project.generated.yml"
        )
        return 0

    return subprocess.call(["xcodegen", "generate", "--spec", str(OUT)])


if __name__ == "__main__":
    sys.exit(main())
