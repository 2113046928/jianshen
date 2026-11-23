# -*- coding: utf-8 -*-
"""检查「`}` 之后直接跟 `.modifier`」的断裂修饰符链。

真实事故：把一段 Text 替换成 if/else 后，原来的 .font()/.foregroundStyle()
留在了 if 表达式后面，Swift 报
"instance member 'font' cannot be used on type 'View'"。
"""
import re
import sys
from pathlib import Path

ROOT = Path(r"D:\ios-soft\健身\TrainLedger")
FILES = [
    p for base in (ROOT / "Sources", ROOT / "Shared", ROOT / "Targets", ROOT / "Tests")
    if base.exists() for p in base.rglob("*.swift")
]

problems = []
for path in FILES:
    lines = path.read_text(encoding="utf-8").splitlines()
    for index, line in enumerate(lines):
        stripped = line.strip()
        if not stripped.startswith("."):
            continue
        # 往上找最近的非空行
        previous = index - 1
        while previous >= 0 and not lines[previous].strip():
            previous -= 1
        if previous < 0:
            continue
        previous_stripped = lines[previous].strip()
        # 正常写法里，修饰符与包的 } 同缩进；挂错位置时通常更深一级
        if previous_stripped in ("}", "})") and len(line) - len(line.lstrip()) != len(lines[previous]) - len(lines[previous].lstrip()):
            problems.append(
                f"{path.relative_to(ROOT)}:{index + 1}  `}}` 之后直接跟 `{stripped}`，"
                f"修饰符可能挂到了 if/闭包表达式上"
            )

if problems:
    print("可疑的断裂修饰符：")
    for p in problems:
        print(" -", p)
    sys.exit(1)

print("修饰符链检查通过")
