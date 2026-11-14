# -*- coding: utf-8 -*-
"""检查「已知类型的变量访问了该类型没有的成员」——pack.days 这类错误。

忽略协议/编译器合成成员（rawValue、modelContext 等），
同一变量在文件里出现多种类型时跳过，避免作用域误判。
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FILES = [
    p for base in (ROOT / "Sources", ROOT / "Shared", ROOT / "Targets")
    if base.exists() for p in base.rglob("*.swift")
]

SYNTHESIZED = {
    "rawValue", "id", "modelContext", "persistentModelID", "hashValue",
    "description", "debugDescription", "self", "init", "hash", "title",
}

types: dict[str, set[str]] = {}


def block_body(text: str, brace_index: int) -> str:
    depth, i = 0, brace_index
    while i < len(text):
        if text[i] == "{":
            depth += 1
        elif text[i] == "}":
            depth -= 1
            if depth == 0:
                return text[brace_index : i + 1]
        i += 1
    return text[brace_index:]


for path in FILES:
    text = path.read_text(encoding="utf-8")
    for m in re.finditer(r"(?:struct|class|enum|extension)\s+(\w+)[^{]*\{", text):
        body = block_body(text, m.end() - 1)
        types.setdefault(m.group(1), set()).update(
            re.findall(r"(?:var|let|func)\s+(\w+)", body)
        )

problems = []
for path in FILES:
    text = path.read_text(encoding="utf-8")
    rel = path.relative_to(ROOT)

    seen: dict[str, set[str]] = {}
    for m in re.finditer(r"(?:let|var)\s+(\w+)\s*:\s*([A-Z]\w*)", text):
        seen.setdefault(m.group(1), set()).add(m.group(2))
    for m in re.finditer(r"\b(\w+)\s*:\s*([A-Z]\w*)[?,)]", text):
        seen.setdefault(m.group(1), set()).add(m.group(2))

    for var, declared_types in seen.items():
        if len(declared_types) != 1:
            continue  # 同名变量在不同作用域是不同类型，跳过
        type_name = next(iter(declared_types))
        if type_name not in types:
            continue
        for m in re.finditer(rf"\b{var}\.(\w+)", text):
            member = m.group(1)
            if member in types[type_name] or member in SYNTHESIZED:
                continue
            line_no = text[: m.start()].count("\n") + 1
            problems.append(f"{rel}:{line_no}  {var}.{member}  —— {type_name} 没有 {member}")

if problems:
    print("发现的成员访问问题：")
    for p in sorted(set(problems)):
        print(" -", p)
    sys.exit(1)

print("成员访问检查通过")
