# -*- coding: utf-8 -*-
"""校验动作库 JSON 与训练模板引用的一致性。"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
JSON_PATH = ROOT / "Sources" / "Resources" / "Exercises.json"
PROGRAMS = ROOT / "Sources" / "Models" / "ProgramTemplates.swift"

MUSCLES = {"chest", "back", "legs", "shoulders", "arms", "core"}
PATTERNS = {"horizontalPush", "verticalPush", "horizontalPull", "verticalPull",
            "squat", "hinge", "lunge", "arm", "core"}
EQUIPMENT = {"barbell", "dumbbell", "machine", "cable", "bodyweight", "kettlebell", "band"}
REQUIRED = {"id", "name", "pattern", "primary", "equipment", "isCompound",
            "loadIncrement", "repsLow", "repsHigh"}

errors = []
data = json.loads(JSON_PATH.read_text(encoding="utf-8"))
if not isinstance(data, list):
    errors.append("根节点必须是数组")

ids, names, aliases = set(), set(), {}
for i, item in enumerate(data):
    missing = REQUIRED - set(item)
    if missing:
        errors.append(f"#{i} 缺少字段 {missing}")
        continue
    if item["id"] in ids:
        errors.append(f"id 重复: {item['id']}")
    ids.add(item["id"])
    if item["name"] in names:
        errors.append(f"名称重复: {item['name']}")
    names.add(item["name"])
    for alias in [item["name"]] + item.get("aliases", []):
        key = alias.lower()
        if key in aliases and aliases[key] != item["id"]:
            errors.append(f"别名冲突: {alias} -> {aliases[key]} / {item['id']}")
        aliases[key] = item["id"]
    if item["pattern"] not in PATTERNS:
        errors.append(f"{item['id']} pattern 非法: {item['pattern']}")
    if item["equipment"] not in EQUIPMENT:
        errors.append(f"{item['id']} equipment 非法: {item['equipment']}")
    for m in item["primary"] + item.get("secondary", []):
        if m not in MUSCLES:
            errors.append(f"{item['id']} 肌群非法: {m}")
    if not item["primary"]:
        errors.append(f"{item['id']} 缺少主动肌")
    if item["repsLow"] > item["repsHigh"]:
        errors.append(f"{item['id']} 次数区间反了")
    if item["loadIncrement"] < 0:
        errors.append(f"{item['id']} 递增为负")
    if item["isCompound"] and not item.get("secondary"):
        errors.append(f"{item['id']} 复合动作缺少协同肌")

# 模板引用的 id 必须存在
swift = PROGRAMS.read_text(encoding="utf-8")
referenced = set(re.findall(r'"([a-z][a-z0-9]*(?:-[a-z0-9]+)+)"', swift))
unknown = sorted(r for r in referenced if r not in ids)
for u in unknown:
    errors.append(f"模板引用了不存在的动作: {u}")

# 每个模板每天至少有 4 个动作
days = re.findall(r'exerciseIDs: \[\s*\r?\n(.*?)\]', swift, re.S)
for idx, block in enumerate(days):
    count = len(re.findall(r'"', block)) // 2
    if count < 4:
        errors.append(f"第 {idx + 1} 个训练日动作过少: {count}")

print(f"动作数: {len(data)}")
print(f"有主动肌覆盖的肌群: {sorted({m for i in data for m in i['primary']})}")
print(f"未覆盖肌群: {sorted(MUSCLES - {m for i in data for m in i['primary']})}")
print(f"模板引用唯一 id 数: {len(referenced)}")
print(f"训练日数: {len(days)}")

# 计划包：id/商品号唯一、每天至少 3 个动作、引用的动作必须存在
PACKS = ROOT / "Sources" / "Resources" / "ProgramPacks.json"
if PACKS.exists():
    packs = json.loads(PACKS.read_text(encoding="utf-8"))
    pack_ids, product_ids = set(), set()
    for pack in packs:
        if pack["id"] in pack_ids:
            errors.append(f"计划包 id 重复: {pack['id']}")
        pack_ids.add(pack["id"])
        if pack["productID"] in product_ids:
            errors.append(f"商品号重复: {pack['productID']}")
        product_ids.add(pack["productID"])
        if not pack.get("days"):
            errors.append(f"计划包没有训练日: {pack['id']}")
        for day in pack.get("days", []):
            if len(day.get("exerciseIDs", [])) < 3:
                errors.append(f"{pack['id']}/{day['id']} 动作过少")
            for eid in day.get("exerciseIDs", []):
                if eid not in ids:
                    errors.append(f"{pack['id']} 引用了不存在的动作: {eid}")
    print(f"计划包: {len(packs)} 个，商品号 {len(product_ids)} 个")

if errors:
    print("\n发现问题:")
    for e in errors:
        print(" -", e)
    sys.exit(1)
print("\n校验通过")

