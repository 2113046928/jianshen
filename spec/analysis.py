# -*- coding: utf-8 -*-
"""
容量分析 / 1RM 估算 / 周报聚合的可运行参考实现。

对应 iOS 工程 Core/VolumeAnalyzer.swift、Core/StrengthEstimate.swift、Core/WeeklyReport.swift。
"""
from __future__ import annotations

from dataclasses import dataclass
from enum import Enum
from typing import Optional

# (下限, 上限) 单位为「有效组 / 周」，参考一般增肌人群的 MEV-MAV 区间简化值
MUSCLE_TARGETS = {
    "chest": (10, 20),
    "back": (10, 22),
    "legs": (12, 22),
    "shoulders": (8, 16),
    "arms": (6, 14),
    "core": (4, 12),
}

MUSCLE_NAMES = {
    "chest": "胸",
    "back": "背",
    "legs": "腿",
    "shoulders": "肩",
    "arms": "手臂",
    "core": "核心",
}


class VolumeStatus(str, Enum):
    UNDER = "under"
    IN_RANGE = "inRange"
    OVER = "over"


@dataclass(frozen=True)
class MuscleVolume:
    muscle: str
    sets: float
    low: float
    high: float
    status: VolumeStatus


@dataclass(frozen=True)
class LoggedSet:
    exercise_id: str
    muscle_primary: tuple
    muscle_secondary: tuple
    weight: float
    reps: int
    set_type: str = "normal"


def analyze_volume(sets, weeks: float = 1.0):
    """有效组：主动肌 1.0，协同肌 0.5；热身不计。"""
    totals = {m: 0.0 for m in MUSCLE_TARGETS}
    for s in sets:
        if s.set_type == "warmup":
            continue
        for m in s.muscle_primary:
            if m in totals:
                totals[m] += 1.0
        for m in s.muscle_secondary:
            if m in totals:
                totals[m] += 0.5
    result = []
    for muscle, value in totals.items():
        low, high = MUSCLE_TARGETS[muscle]
        low_w, high_w = low / weeks, high / weeks
        volume = value / weeks
        if volume < low_w:
            status = VolumeStatus.UNDER
        elif volume > high_w:
            status = VolumeStatus.OVER
        else:
            status = VolumeStatus.IN_RANGE
        result.append(MuscleVolume(muscle, round(volume, 2), low_w, high_w, status))
    return result


def epley_1rm(weight: float, reps: int) -> float:
    """Epley 公式；1 次时直接返回重量。"""
    if reps <= 1:
        return weight
    return weight * (1 + reps / 30.0)


# 相对体重倍数：达到该值即进入对应等级（入门 -> 初级 -> 中级 -> 高级 -> 精英）
LIFT_TIERS = {
    "bench": (0.75, 1.0, 1.25, 1.5),
    "squat": (1.0, 1.25, 1.5, 1.75),
    "deadlift": (1.25, 1.5, 1.75, 2.0),
    "press": (0.5, 0.65, 0.85, 1.0),
}

TIER_NAMES = ("入门", "初级", "中级", "高级", "精英")


def strength_tier(one_rm: float, bodyweight: float, lift_class: str) -> Optional[str]:
    if bodyweight <= 0 or lift_class not in LIFT_TIERS:
        return None
    ratio = one_rm / bodyweight
    level = 0
    for threshold in LIFT_TIERS[lift_class]:
        if ratio >= threshold:
            level += 1
    return TIER_NAMES[level]


@dataclass(frozen=True)
class WeeklyStats:
    session_count: int
    total_sets: int
    total_volume_kg: float
    pr_count: int
    muscle_volumes: list
    adherence: float


def weekly_stats(sessions, planned_sessions: int = 3) -> WeeklyStats:
    total_sets = 0
    volume = 0.0
    pr = 0
    logged = []
    # PR 的判定基准是「本次训练之前」的最佳成绩，同一次训练内不重复计 PR
    best_e1rm = {}
    for s in sessions:
        baseline = dict(best_e1rm)
        session_best = {}
        for ws in s.sets:
            if ws.set_type == "warmup":
                continue
            total_sets += 1
            volume += ws.weight * ws.reps
            logged.append(ws)
            estimate = epley_1rm(ws.weight, ws.reps)
            previous = baseline.get(ws.exercise_id)
            if previous is not None and ws.set_type == "normal" and estimate > previous:
                pr += 1
            if estimate > session_best.get(ws.exercise_id, 0.0):
                session_best[ws.exercise_id] = estimate
        for exercise_id, estimate in session_best.items():
            if estimate > best_e1rm.get(exercise_id, 0.0):
                best_e1rm[exercise_id] = estimate
    adherence = min(session_count_ratio(len(sessions), planned_sessions), 1.0)
    return WeeklyStats(
        session_count=len(sessions),
        total_sets=total_sets,
        total_volume_kg=round(volume, 1),
        pr_count=pr,
        muscle_volumes=analyze_volume(logged),
        adherence=round(adherence, 3),
    )


def session_count_ratio(actual: int, planned: int) -> float:
    if planned <= 0:
        return 0.0
    return actual / planned


