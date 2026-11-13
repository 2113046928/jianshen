# -*- coding: utf-8 -*-
"""验证营养算法，并输出 Swift XCTest 需要的期望值。"""
import json

from nutrition import (
    Activity, BodyProfile, Phase, Sex,
    bmr, tdee, plan, meal_split, weekly_adjustment,
)

CASES = []

# 标准案例：30 岁男性 180cm 80kg，中等活动
male = BodyProfile(Sex.MALE, 30, 180, 80, Activity.MODERATE)
female = BodyProfile(Sex.FEMALE, 28, 165, 60, Activity.LIGHT)

b = bmr(male)
assert b == 10 * 80 + 6.25 * 180 - 5 * 30 + 5, b
assert b == 1780.0, b
print("BMR 男:", b, " TDEE:", tdee(male))
assert tdee(male) == 2759.0, tdee(male)

b_f = bmr(female)
assert b_f == 10 * 60 + 6.25 * 165 - 5 * 28 - 161, b_f
print("BMR 女:", b_f, " TDEE:", tdee(female))

# 减脂方案
cut = plan(male, Phase.CUT)
print("减脂:", cut)
assert cut.bmr == 1780.0
assert cut.targets.calories == round(2759.0 * 0.82, 1)
assert cut.targets.protein_g == 176.0          # 2.2 g/kg × 80
assert cut.targets.fat_g == 72.0               # 0.9 × 80
expected_carbs = (cut.targets.calories - 176 * 4 - 72 * 9) / 4
assert cut.targets.carbs_g == round(expected_carbs, 1)

# 宏量热量应等于目标热量（±1 千卡）
kcal = cut.targets.protein_g * 4 + cut.targets.fat_g * 9 + cut.targets.carbs_g * 4
assert abs(kcal - cut.targets.calories) < 1.0, (kcal, cut.targets.calories)
print("宏量回算:", round(kcal, 1), "vs", cut.targets.calories)

# 增肌方案
bulk = plan(male, Phase.BULK)
assert bulk.targets.calories == round(2759.0 * 1.10, 1)
assert bulk.targets.protein_g == 144.0          # 1.8 × 80
print("增肌:", bulk.targets)

# 维持
maint = plan(male, Phase.MAINTAIN)
assert maint.targets.calories == 2759.0

# 极端案例：低体重减脂，缺口不得低于 BMR
tiny = BodyProfile(Sex.FEMALE, 45, 150, 42, Activity.SEDENTARY)
p = plan(tiny, Phase.CUT)
assert p.targets.calories >= p.bmr, (p.targets.calories, p.bmr)
print("小体重减脂:", p.targets.calories, "BMR:", p.bmr)

CASES.append({
    "name": "male_cut",
    "bmr": cut.bmr, "tdee": cut.tdee,
    "calories": cut.targets.calories,
    "protein": cut.targets.protein_g,
    "fat": cut.targets.fat_g,
    "carbs": cut.targets.carbs_g,
})
CASES.append({
    "name": "male_bulk",
    "bmr": bulk.bmr, "tdee": bulk.tdee,
    "calories": bulk.targets.calories,
    "protein": bulk.targets.protein_g,
    "fat": bulk.targets.fat_g,
    "carbs": bulk.targets.carbs_g,
})
CASES.append({
    "name": "female_light",
    "bmr": round(b_f, 1), "tdee": round(b_f * 1.375, 1),
    "calories": round(b_f * 1.375, 1),
    "protein": round(1.8 * 60, 1),
    "fat": round(0.9 * 60, 1),
    "carbs": None,
})

# 餐次分配
three = meal_split(2400, 3)
four = meal_split(2400, 4)
assert sum(three) == 2400, three
assert abs(sum(four) - 2400) < 1.0, four
print("餐次:", three, four)

# 每周调整
r = weekly_adjustment(-0.006, Phase.CUT)
assert r[0] == "hold", r
assert weekly_adjustment(-0.001, Phase.CUT)[0] == "reduce"
assert weekly_adjustment(-0.02, Phase.CUT)[0] == "increase"
assert weekly_adjustment(0.003, Phase.BULK)[0] == "hold"
assert weekly_adjustment(0.0, Phase.BULK)[0] == "increase"
assert weekly_adjustment(0.01, Phase.BULK)[0] == "reduce"
assert weekly_adjustment(0.02, Phase.MAINTAIN)[0] == "adjust"
print("每周调整规则通过")

with open("nutrition_fixtures.json", "w", encoding="utf-8") as f:
    json.dump(CASES, f, ensure_ascii=False, indent=2)
print("全部通过，fixtures 已写入")
