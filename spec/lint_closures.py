# -*- coding: utf-8 -*-
"""扫描「闭包有参数却没用」的写法（Swift 6 会直接报错，见 SettingsView / WatchSessionManager）。"""
import re
import sys
from pathlib import Path

ROOT = Path(r"D:\ios-soft\健身\TrainLedger")
FILES = [
    p for base in (ROOT / "Sources", ROOT / "Shared", ROOT / "Targets", ROOT / "Tests")
    if base.exists() for p in base.rglob("*.swift")
]

HIGHER_ORDER = r"\.(map|filter|first|last|contains|compactMap|allSatisfy|sorted|max|min|forEach|drop|prefix|reduce)\s*\(\s*(where:)?\s*\{"
PATTERN = re.compile(HIGHER_ORDER + "?")


def balanced(text: str, start: int) -> str:
    depth, i = 0, start
    while i < len(text):
        if text[i] == "{":
            depth += 1
        elif text[i] == "}":
            depth -= 1
            if depth == 0:
                return text[start + 1 : i]
        i += 1
    return text[start + 1 :]


problems = []
for path in FILES:
    text = path.read_text(encoding="utf-8")
    for m in re.finditer(r"\.(map|filter|first|last|contains|compactMap|allSatisfy|sorted|max|min|forEach|drop|prefix)\s*(\(\s*where:)?\s*\{", text):
        body = balanced(text, m.end() - 1)
        # `if let x = arr.first {` / `guard let x = arr.first {` 里的 first 是属性
        line_start = text.rfind("\n", 0, m.start()) + 1
        if "if let" in text[line_start : m.start()] or "guard let" in text[line_start : m.start()]:
            continue
        # 只检查写在同一行的单表达式闭包：
        # 多行的 `{` 往往其实是 if/guard 的条件块，误报率高。
        if "\n" in body.strip():
            continue
        # 有显式参数（xxx in / (a, b) in）或用到了 $0/$1 都算正常
        if re.search(r"\b(in)\b", body) or "$0" in body or "$1" in body:
            continue
        if re.match(r"\s*(return|let|var|if|guard|for|while|switch)\b", body):
            continue
        line = text[: m.start()].count("\n") + 1
        problems.append(f"{path.relative_to(ROOT)}:{line}  {m.group(1)} 的闭包没有使用参数")

if problems:
    print("可疑闭包：")
    for p in problems:
        print(" -", p)
    sys.exit(1)
print("闭包参数检查通过")
