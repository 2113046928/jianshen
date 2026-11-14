# -*- coding: utf-8 -*-
"""从 Swift 源码里抽取可本地化的文案，生成 Localizable.strings 骨架。

    python scripts/extract_strings.py            # 打印统计 + 写出 zh-Hans 骨架
    python scripts/extract_strings.py --check    # 只检查 en 与 zh 的 key 是否一致

只抽取纯字面量（不含 \\( 插值）。带插值的句子需要改成格式化字符串才能翻译，
这一版先不处理，脚本会把它们单独列出来。
"""
import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCE_DIRS = [ROOT / "Sources", ROOT / "Targets", ROOT / "Shared"]
RES = ROOT / "Sources" / "Resources"

PATTERNS = [
    r'Text\(\s*"((?:[^"\\]|\\.)*)"',
    r'Label\(\s*"((?:[^"\\]|\\.)*)"',
    r'Button\(\s*"((?:[^"\\]|\\.)*)"',
    r'Section\(\s*"((?:[^"\\]|\\.)*)"',
    r'\.navigationTitle\(\s*"((?:[^"\\]|\\.)*)"',
    r'Pill\(\s*text:\s*"((?:[^"\\]|\\.)*)"',
    r'Picker\(\s*"((?:[^"\\]|\\.)*)"',
    r'configurationDisplayName\(\s*"((?:[^"\\]|\\.)*)"',
    r'\.description\(\s*"((?:[^"\\]|\\.)*)"',
    r'TextField\(\s*"((?:[^"\\]|\\.)*)"',
    r'String\(\s*localized:\s*"((?:[^"\\]|\\.)*)"',
    r'SectionHeader\(\s*title:\s*"((?:[^"\\]|\\.)*)"',
    r'subtitle:\s*"((?:[^"\\]|\\.)*)"',
    r'StatTile\(\s*title:\s*"((?:[^"\\]|\\.)*)"',
    r'\.init\(\s*title:\s*"((?:[^"\\]|\\.)*)"',
    r'PrimaryButton\(\s*title:\s*"((?:[^"\\]|\\.)*)"',
    r'EmptyHint\(\s*text:\s*"((?:[^"\\]|\\.)*)"',
]

SKIP_PREFIX = ("kg", "http")

# 已经作为标识符/日志使用的短词，不进本地化
SKIP_EXACT = {"kg", "RPE", "次", "组", "分"}


def swift_files():
    for base in SOURCE_DIRS:
        if not base.exists():
            continue
        yield from base.rglob("*.swift")


def extract():
    literal, interpolated = set(), set()
    for path in swift_files():
        text = path.read_text(encoding="utf-8")
        # 去掉整行注释，避免把文档注释里的示例文案算进来
        text = "\n".join(
            line for line in text.splitlines()
            if not line.strip().startswith("//")
        )
        for pattern in PATTERNS:
            for match in re.finditer(pattern, text):
                value = match.group(1).strip()
                if not value:
                    continue
                if "\\(" in value:
                    if not (value.startswith('\\(') and value.endswith(')') and value.count('\\(') == 1):
                        interpolated.add(value)
                else:
                    literal.add(value)
    cleaned = {
        v for v in literal
        if v not in SKIP_EXACT and not v.startswith(SKIP_PREFIX) and len(v) > 0
    }
    return sorted(cleaned), sorted(interpolated)


def write_strings(path, keys, include_header=True):
    path.parent.mkdir(parents=True, exist_ok=True)
    lines = []
    if include_header:
        lines.append("/* 由 scripts/extract_strings.py 生成，请勿手改 key */")
    for key in keys:
        escaped = key.replace("\\", "\\\\").replace('"', '\\"')
        lines.append(f'"{escaped}" = "{escaped}";')
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def parse_keys(path):
    if not path.exists():
        return set()
    text = path.read_text(encoding="utf-8")
    return set(re.findall(r'^"((?:[^"\\]|\\.)*)"\s*=', text, re.M))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()

    zh_path = RES / "zh-Hans.lproj" / "Localizable.strings"
    en_path = RES / "en.lproj" / "Localizable.strings"

    if args.check:
        zh, en = parse_keys(zh_path), parse_keys(en_path)
        missing_en = zh - en
        extra_en = en - zh
        print(f"zh keys: {len(zh)}  en keys: {len(en)}")
        if missing_en:
            print(f"缺英文翻译 {len(missing_en)} 条，例如：")
            for k in sorted(missing_en)[:8]:
                print("  -", k)
        if extra_en:
            print(f"英文里多出 {len(extra_en)} 条（中文已删或改名），例如：")
            for k in sorted(extra_en)[:5]:
                print("  +", k)
        return 1 if (missing_en or extra_en) else 0

    literal, interpolated = extract()
    print(f"可本地化字面量: {len(literal)}")
    print(f"含插值、暂不翻译: {len(interpolated)}")

    write_strings(zh_path, literal)
    print("已写出:", zh_path.relative_to(ROOT))

    if interpolated:
        print("\n含插值（需要先改成格式化字符串）：")
        for item in interpolated[:10]:
            print("  ·", item[:60])
    return 0


if __name__ == "__main__":
    sys.exit(main())
