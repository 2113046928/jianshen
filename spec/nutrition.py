# -*- coding: utf-8 -*-
"""
营养算法的可运行参考实现（executable spec）。

与 iOS 侧 Core/NutritionEngine.swift 同一套公式，XCTest 用本文件产出的期望值。
公式来源：Mifflin-St Jeor 基础代谢；活动系数取通行值；宏量按 g/kg 体重分配。
"""
from __future__ import annotations

from dataclasses import dataclass
from enum import Enum


class Sex(str, Enum):
    MALE = "male"
    FEMALE = "female"


class Activity(str, Enum):
    SEDENTARY = "sedentary"
    LIGHT = "light"
    MODERATE = "moderate"
    ACTIVE = "active"
    VERY_ACTIVE = "veryActive"

    @property
    def factor(self) -> float:
        return {
            "sedentary": 1.2,
            "light": 1.375,
            "moderate": 1.55,
            "active": 1.725,
            "veryActive": 1.9,
        }[self.value]


class Phase(str, Enum):
    BULK = "bulk"
    CUT = "cut"
    MAINTAIN = "maintain"


@dataclass(frozen=True)
class BodyProfile:
    sex: Sex
    age: int
    height_cm: float
    weight_kg: float
    activity: Activity


@dataclass(frozen=True)
class MacroTargets:
    calories: float
    protein_g: float
    fat_g: float
    carbs_g: float
    protein_per_kg: float


@dataclass(frozen=True)
class NutritionPlan:
    bmr: float
    tdee: float
    targets: MacroTargets
    notes: list


# 目标热量系数：增肌小幅盈余，减脂温和缺口（都不超过 20%）
PHASE_ADJUST = {"bulk": 1.10, "cut": 0.82, "maintain": 1.0}

# 蛋白质 g/kg：减脂期提高以保肌
PROTEIN_PER_KG = {"bulk": 1.8, "cut": 2.2, "maintain": 1.8}

FAT_PER_KG = 0.9
MIN_PROTEIN_PER_KG = 1.6
MIN_FAT_PER_KG = 0.6
MAX_DEFICIT = 0.20


def bmr(profile: BodyProfile) -> float:
    base = 10 * profile.weight_kg + 6.25 * profile.height_cm - 5 * profile.age
    return base + (5 if profile.sex == Sex.MALE else -161)


def tdee(profile: BodyProfile) -> float:
    return bmr(profile) * profile.activity.factor


def plan(profile: BodyProfile, phase: Phase) -> NutritionPlan:
    base = bmr(profile)
    maintenance = base * profile.activity.factor

    target = maintenance * PHASE_ADJUST[phase.value]

    # 缺口不超过 20%，且不低于基础代谢——低于 BMR 的方案不可持续
    floor = base
    if phase == Phase.CUT:
        target = max(target, maintenance * (1 - MAX_DEFICIT))
    target = max(target, floor)

    protein_g = PROTEIN_PER_KG[phase.value] * profile.weight_kg
    fat_g = FAT_PER_KG * profile.weight_kg

    remaining = target - protein_g * 4 - fat_g * 9
    carbs_g = max(remaining, 0) / 4

    notes = []
    if phase == Phase.CUT and carbs_g < 1.5 * profile.weight_kg:
        notes.append("碳水偏低，先把缺口收到 15% 左右，再考虑加有氧。")
    if phase == Phase.BULK and target - maintenance > maintenance * 0.12:
        notes.append("盈余偏大，脂肪增长会明显，建议控制在 10% 以内。")
    if profile.activity == Activity.SEDENTARY and phase == Phase.CUT:
        notes.append("久坐 + 减脂时优先加日常步数，比加有氧更不容易影响恢复。")
    if protein_g / profile.weight_kg < MIN_PROTEIN_PER_KG:
        notes.append("蛋白质低于 1.6g/kg，建议补足。")

    return NutritionPlan(
        bmr=round(base, 1),
        tdee=round(maintenance, 1),
        targets=MacroTargets(
            calories=round(target, 1),
            protein_g=round(protein_g, 1),
            fat_g=round(fat_g, 1),
            carbs_g=round(carbs_g, 1),
            protein_per_kg=round(protein_g / profile.weight_kg, 2),
        ),
        notes=notes,
    )


def meal_split(calories: float, meals: int = 4) -> list:
    """三餐 + 一次加餐的比例；返回每餐千卡。"""
    ratios = {3: [0.33, 0.34, 0.33], 4: [0.28, 0.32, 0.30, 0.10]}
    parts = ratios.get(meals, ratios[3])
    return [round(calories * r, 1) for r in parts]


def weekly_adjustment(weekly_change_pct: float, phase: Phase) -> tuple:
    """
    每周体重变化百分比 -> (动作, 提示)
    专业做法是不改方案改执行：先看两周趋势，再动热量。
    """
    if phase == Phase.CUT:
        if weekly_change_pct > -0.003:
            return ("reduce", "两周几乎没动，先减 150 千卡或每天多走 2000 步。")
        if weekly_change_pct < -0.012:
            return ("increase", "掉得过快，加回 150 千卡，优先补碳水。")
        return ("hold", "速度合适，保持不变。")

    if phase == Phase.BULK:
        if weekly_change_pct < 0.001:
            return ("increase", "两周没涨，加 150 千卡。")
        if weekly_change_pct > 0.006:
            return ("reduce", "涨得过快，减 150 千卡，避免脂肪堆积。")
        return ("hold", "速度合适，保持不变。")

    if abs(weekly_change_pct) > 0.008:
        return ("adjust", "波动偏大，先稳定饮食结构再看体重。")
    return ("hold", "维持期保持稳定即可。")
