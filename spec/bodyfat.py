# -*- coding: utf-8 -*-
"""体脂率估算的可运行参考实现：Deurenberg 与 US Navy 围度法。"""
import math


def bmi(weight_kg: float, height_cm: float) -> float:
    h = height_cm / 100
    return weight_kg / (h * h)


def deurenberg(weight_kg: float, height_cm: float, age: int, male: bool) -> float:
    """Deurenberg 1991：由 BMI 与年龄回归，误差约 ±4-5%。"""
    b = bmi(weight_kg, height_cm)
    return 1.20 * b + 0.23 * age - 10.8 * (1 if male else 0) - 5.4


def navy(weight_kg: float, height_cm: float, waist: float, neck: float,
         hip: float = 0.0, male: bool = True) -> float | None:
    """US Navy 围度法，单位 cm；男性只需腰/颈，女性需要腰/臀/颈。"""
    if male:
        if waist <= neck:
            return None
        denom = (1.0324
                 - 0.19077 * math.log10(waist - neck)
                 + 0.15456 * math.log10(height_cm))
    else:
        if hip <= 0 or waist + hip <= neck:
            return None
        denom = (1.29579
                 - 0.35004 * math.log10(waist + hip - neck)
                 + 0.22100 * math.log10(height_cm))
    return 495 / denom - 450


def lean_mass(weight_kg: float, body_fat_pct: float) -> float:
    return weight_kg * (1 - body_fat_pct / 100)


def ffmi(lean_kg: float, height_cm: float) -> float:
    h = height_cm / 100
    return lean_kg / (h * h)


def target_weight(lean_kg: float, target_bf: float) -> float:
    return lean_kg / (1 - target_bf / 100)


# ---------------- 校验 ----------------
m = dict(weight_kg=80, height_cm=180, age=30, male=True)
b = bmi(80, 180)
d = deurenberg(80, 180, 30, True)
n = navy(80, 180, 85, 38, male=True)
print(f"男性 180cm/80kg/30y")
print(f"  BMI        = {b:.2f}")
print(f"  Deurenberg = {d:.1f}%")
print(f"  Navy(85/38)= {n:.1f}%")

lean_n = lean_mass(80, n)
print(f"  瘦体重      = {lean_n:.1f} kg")
print(f"  FFMI       = {ffmi(lean_n, 180):.1f}")
print(f"  目标 12% 体重 = {target_weight(lean_n, 12):.1f} kg")

f = dict(weight_kg=60, height_cm=165, age=28, male=False)
bf = bmi(60, 165)
df = deurenberg(60, 165, 28, False)
nf = navy(60, 165, waist=72, neck=32, hip=95, male=False)
print(f"\n女性 165cm/60kg/28y")
print(f"  BMI        = {bf:.2f}")
print(f"  Deurenberg = {df:.1f}%")
print(f"  Navy(72/95/32) = {nf:.1f}%")

# 边界：腰围小于颈围应返回 None
assert navy(80, 180, 38, 40, male=True) is None
assert navy(60, 165, 70, 32, hip=0, male=False) is None
print("\n边界用例通过")

# 分类
def category(pct: float, male: bool) -> str:
    if male:
        if pct < 6: return "偏低"
        if pct < 14: return "运动员"
        if pct < 18: return "健壮"
        if pct < 25: return "正常"
        if pct < 30: return "偏高"
        return "肥胖"
    if pct < 14: return "偏低"
    if pct < 21: return "运动员"
    if pct < 25: return "健壮"
    if pct < 32: return "正常"
    if pct < 38: return "偏高"
    return "肥胖"

print("男 16.1% ->", category(16.1, True))
print("女 24.0% ->", category(24.0, False))

import json
json.dump({
    "male": {"bmi": round(b, 2), "deurenberg": round(d, 1), "navy": round(n, 1),
             "lean": round(lean_n, 1), "ffmi": round(ffmi(lean_n, 180), 1),
             "target12": round(target_weight(lean_n, 12), 1)},
    "female": {"bmi": round(bf, 2), "deurenberg": round(df, 1), "navy": round(nf, 1)},
}, open("bodycomp_fixtures.json", "w"), ensure_ascii=False, indent=2)
print("\nfixtures 已写入")
