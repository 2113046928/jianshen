# -*- coding: utf-8 -*-
"""没有编译器时的符号级自查：Theme/Fmt/L10n 的成员是否都存在、修饰器是否定义。

不能替代编译，但能抓住「改了组件却漏改引用」这类最常见的错。
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCES = ROOT / "Sources"
SHARED = ROOT / "Shared"
TARGETS = ROOT / "Targets"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def swift_files(*dirs: Path):
    for base in dirs:
        if base.exists():
            yield from base.rglob("*.swift")


theme_text = read(SOURCES / "Design/Theme.swift")
l10n_text = read(SHARED / "L10n/L10n.swift")
components_text = read(SOURCES / "Design/Components.swift")

# Theme 与 Fmt 都在 Theme.swift 里
theme_members = set(re.findall(r"static (?:let|var|func) (\w+)", theme_text))
l10n_members = set(re.findall(r"static func (\w+)\(", l10n_text))
modifiers = set(re.findall(r"^\s{4}func (\w+)\(\) -> some View", theme_text, re.M))

problems = []

for path in swift_files(SOURCES, SHARED, TARGETS):
    if path.name in {"Theme.swift"}:
        continue
    text = read(path)
    rel = path.relative_to(ROOT)

    for name in set(re.findall(r"\bTheme\.(\w+)", text)):
        if name not in theme_members:
            problems.append(f"{rel}: Theme.{name} 不存在")

    for name in set(re.findall(r"\bFmt\.(\w+)", text)):
        if name not in theme_members:
            problems.append(f"{rel}: Fmt.{name} 不存在")

    for name in set(re.findall(r"\bL10n\.(\w+)\(", text)):
        if name not in l10n_members:
            problems.append(f"{rel}: L10n.{name}() 未定义")

    for name in set(re.findall(r"\.(card|darkCard|hairline)\(\)", text)):
        if name not in modifiers:
            problems.append(f"{rel}: .{name}() 修饰器未定义")

# 已知被删除但仍被引用的标识符
removed = ["averageSetsText", "toReportSession"]
for token in removed:
    for path in swift_files(SOURCES, SHARED, TARGETS):
        if token in read(path):
            problems.append(f"{path.relative_to(ROOT)}: 仍引用已删除的 {token}")

# 每个 #Preview 需要 PreviewData
for path in swift_files(SOURCES):
    text = read(path)
    if "#Preview" in text and "PreviewData.container" in text:
        if "enum PreviewData" not in read(SOURCES / "App/RootTabView.swift"):
            problems.append("RootTabView.swift 缺少 PreviewData")

if problems:
    print("发现问题：")
    for p in problems:
        print(" -", p)
    sys.exit(1)

print("符号自查通过")
print(f"Theme/Fmt 成员 {len(theme_members)} 个 · L10n {len(l10n_members)} 个 · 修饰器 {sorted(modifiers)}")
