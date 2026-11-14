# -*- coding: utf-8 -*-
"""生成 Xcode 工程。

    python3 scripts/gen_project.py              # 含 watchOS，不依赖 PyYAML
    WITH_WATCH=0 python3 scripts/gen_project.py # 剔除 watchOS，需要 PyYAML

默认路径刻意不引入额外依赖——CI runner 上没有装 PyYAML。
"""
import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "project.yml"
OUT = ROOT / "project.generated.yml"


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

    try:
        import yaml
    except ImportError:
        print(
            "剔除 watchOS 需要 PyYAML：python3 -m pip install pyyaml\n"
            "默认路径不需要它，CI 走的是默认路径。",
            file=sys.stderr,
        )
        return 2

    spec = yaml.safe_load(SRC.read_text(encoding="utf-8"))
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
    return generate(OUT)


if __name__ == "__main__":
    sys.exit(main())
