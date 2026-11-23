# -*- coding: utf-8 -*-
"""静态审查：死状态、未被引用的私有成员、可疑的重复声明。

不能替代编译器，但能发现「功能写了却接不上」这类逻辑缺口。
"""
import re
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DIRS = [ROOT / "Sources", ROOT / "Shared", ROOT / "Targets"]


def files():
    for base in DIRS:
        if base.exists():
            yield from base.rglob("*.swift")


problems = []

for path in files():
    text = path.read_text(encoding="utf-8")
    rel = path.relative_to(ROOT)
    lines = text.splitlines()

    # 1. 声明了但从未被写入/绑定的 @State
    for match in re.finditer(r"@State private var (\w+)\s*=", text):
        name = match.group(1)
        uses = len(re.findall(rf"\b{name}\b", text))
        # 声明处 1 次；正常至少还有读取或写入
        writes = len(re.findall(rf"(?<![=!<>])\b{name}\s*=(?!=)", text))
        bindings = len(re.findall(rf"\${name}\b", text))
        if uses <= 1:
            problems.append(f"{rel}: @State {name} 声明后从未使用")
        elif writes == 0 and bindings == 0:
            problems.append(f"{rel}: @State {name} 只读不写，可能缺少触发入口")

    # 2. 私有方法从未被引用（含 .onAppear(perform: name) 这种引用方式）
    for match in re.finditer(r"private func (\w+)\(", text):
        name = match.group(1)
        if len(re.findall(rf"\b{name}\b", text)) <= 1:
            problems.append(f"{rel}: private func {name}() 从未被引用")

    # 3. body 里引用了某个视图属性，但文件内没有声明（删块时最容易踩）
    body_match = re.search(r"var body: some View \{", text)
    if body_match:
        depth = 0
        end = len(text)
        for i in range(body_match.end() - 1, len(text)):
            if text[i] == "{":
                depth += 1
            elif text[i] == "}":
                depth -= 1
                if depth == 0:
                    end = i
                    break
        body_text = text[body_match.end():end]
        for line in body_text.splitlines():
            name = line.strip()
            if re.fullmatch(r"[a-z][A-Za-z0-9]*", name):
                if not re.search(rf"(private )?(var|let|func) {name}\b", text):
                    problems.append(f"{rel}: body 引用了 {name}，但文件中没有声明")

    # 4. 同一**类型作用域**内重复的 private var
    #    （不同 struct 各有 exercises 是正常的，只有同一类型里重复才算问题）
    scopes = []
    for match in re.finditer(r"(?:^|\n)\s*(?:private\s+)?(?:struct|final class|class|enum)\s+(\w+)[^{]*\{", text):
        name = match.group(1)
        depth, i, end = 0, match.end() - 1, len(text)
        while i < len(text):
            if text[i] == "{":
                depth += 1
            elif text[i] == "}":
                depth -= 1
                if depth == 0:
                    end = i
                    break
            i += 1
        scopes.append((name, match.end(), end))

    declared = defaultdict(list)
    for match in re.finditer(r"private var (\w+):", text):
        position = match.start()
        owner = "file"
        for type_name, start, end in scopes:
            if start <= position <= end:
                owner = type_name
                break
        declared[(owner, match.group(1))].append(position)

    for (owner, name), positions in declared.items():
        if len(positions) > 1:
            problems.append(f"{rel}: {owner} 里 private var {name} 重复声明 {len(positions)} 次")

if problems:
    print("审查发现：")
    for p in problems:
        print(" -", p)
    print(f"\n共 {len(problems)} 条")
    sys.exit(1)

print("静态审查通过：无死状态、无未引用私有方法、无重复声明")
