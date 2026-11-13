# -*- coding: utf-8 -*-
"""
配重规则的可运行参考实现（executable spec）。

它与 iOS 工程里的 Swift 版本 Core/LoadPrescription.swift 是同一套规则；
Swift 侧 XCTest 的期望值直接由本文件生成，保证两端行为一致。

规则（双进阶 double progression）：
1. 没有历史 -> 校准：不给重量，让用户自选第一组。
2. 顶组次数达到区间上限，且平均 RPE <= 8.5 -> 加一个最小递增（increase）。
3. 顶组次数低于区间下限：
   - 连续两次都没达标 -> 减一个递增（reduce）
   - 否则 -> 保持重量，目标 +1 次（hold）
4. 次数在区间内：
   - 平均 RPE <= 7.0 且已超下限 1 次 -> 跳一级加重量（increase）
   - 否则 -> 保持重量，目标 +1 次（hold）
"""
from __future__ import annotations

from dataclasses import dataclass
from enum import Enum
from statistics import mean
from typing import Optional


class SetType(str, Enum):
    WARMUP = "warmup"
    NORMAL = "normal"
    DROP = "drop"
    FAILURE = "failure"


class Confidence(str, Enum):
    CALIBRATE = "calibrate"
    INCREASE = "increase"
    HOLD = "hold"
    REDUCE = "reduce"


@dataclass(frozen=True)
class SetRecord:
    weight: float
    reps: int
    rpe: Optional[float] = None
    set_type: SetType = SetType.NORMAL


@dataclass(frozen=True)
class SessionRecord:
    date: str
    sets: list


@dataclass(frozen=True)
class Prescription:
    weight: Optional[float]
    target_reps_low: int
    target_reps_high: int
    confidence: Confidence
    rationale: str
    conservative: Optional[float]
    aggressive: Optional[float]


def _round_half(value: float) -> float:
    """对齐到 0.5kg 的配重片最小刻度。"""
    return round(value * 2) / 2


def _working(sets):
    return [s for s in sets if s.set_type != SetType.WARMUP]


def _top_stats(sets):
    top_weight = max(s.weight for s in sets)
    at_top = [s for s in sets if abs(s.weight - top_weight) < 0.01]
    reps = max(s.reps for s in at_top)
    rpes = [s.rpe for s in at_top if s.rpe is not None]
    return top_weight, reps, (mean(rpes) if rpes else None)


def _consecutive_failures(history, target_low):
    count = 0
    for session in reversed(history):
        working = _working(session.sets)
        if not working:
            continue
        _, reps, _ = _top_stats(working)
        if reps < target_low:
            count += 1
        else:
            break
    return count


def propose(
    history,
    increment: float,
    target_low: int,
    target_high: int,
) -> Prescription:
    """history 按时间升序；返回下一次该练多重。"""
    sessions = [s for s in history if _working(s.sets)]
    if not sessions:
        return Prescription(
            weight=None,
            target_reps_low=target_low,
            target_reps_high=target_high,
            confidence=Confidence.CALIBRATE,
            rationale="第一次练这个动作，先用能标准完成 %d 次的重量做校准。" % target_low,
            conservative=None,
            aggressive=None,
        )

    last = sessions[-1]
    working = _working(last.sets)
    top, reps, rpe = _top_stats(working)
    failures = _consecutive_failures(sessions, target_low)

    if reps >= target_high and (rpe is None or rpe <= 8.5):
        new = _round_half(top + increment)
        return Prescription(
            weight=new,
            target_reps_low=target_low,
            target_reps_high=target_high,
            confidence=Confidence.INCREASE,
            rationale="上次 %gkg 做到 %d 次%s，已达上限，加 %gkg。"
            % (top, reps, "" if rpe is None else "（RPE %g）" % rpe, increment),
            conservative=top,
            aggressive=_round_half(top + increment * 2),
        )

    if reps < target_low:
        if failures >= 2:
            new = max(_round_half(top - increment), increment)
            return Prescription(
                weight=new,
                target_reps_low=target_low,
                target_reps_high=target_high,
                confidence=Confidence.REDUCE,
                rationale="连续 %d 次没做到 %d 次，减 %gkg 重建动作质量。" % (failures, target_low, increment),
                conservative=max(_round_half(top - increment * 2), increment),
                aggressive=top,
            )
        return Prescription(
            weight=top,
            target_reps_low=target_low,
            target_reps_high=target_high,
            confidence=Confidence.HOLD,
            rationale="上次 %gkg 只做到 %d 次，先不加重量，目标做到 %d 次。" % (top, reps, reps + 1),
            conservative=top,
            aggressive=_round_half(top + increment),
        )

    if rpe is not None and rpe <= 7.0 and reps >= target_low + 1:
        new = _round_half(top + increment)
        return Prescription(
            weight=new,
            target_reps_low=target_low,
            target_reps_high=target_high,
            confidence=Confidence.INCREASE,
            rationale="上次 %gkg 做到 %d 次但 RPE 只有 %g，明显偏轻，直接加 %gkg。"
            % (top, reps, rpe, increment),
            conservative=top,
            aggressive=_round_half(top + increment * 2),
        )

    return Prescription(
        weight=top,
        target_reps_low=target_low,
        target_reps_high=target_high,
        confidence=Confidence.HOLD,
        rationale="目标先做到 %d 次，再加重。" % (target_high),
        conservative=top,
        aggressive=_round_half(top + increment),
    )
