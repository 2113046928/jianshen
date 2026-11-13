# -*- coding: utf-8 -*-
"""用边界用例验证配重与容量规则，并输出 Swift XCTest 要用的期望值。"""
import json

from engine import SetRecord, SessionRecord, SetType, propose, Confidence
from analysis import (
    LoggedSet, analyze_volume, epley_1rm, strength_tier, weekly_stats,
    VolumeStatus, weekly_stats as ws,
)

CASES = []


def case(name, history, inc, low, high, expect):
    p = propose(history, inc, low, high)
    CASES.append({
        "name": name,
        "expect_weight": p.weight,
        "expect_confidence": p.confidence.value,
        "expect_conservative": p.conservative,
        "expect_aggressive": p.aggressive,
    })
    return p


def S(w, r, rpe=None, t=SetType.NORMAL):
    return SetRecord(weight=w, reps=r, rpe=rpe, set_type=t)


def sess(*sets):
    return SessionRecord(date="2026-01-01", sets=list(sets))


# 1. 无历史 -> 校准
p = case("首次", [], 2.5, 8, 12, ("calibrate", None))
assert p.weight is None and p.confidence == Confidence.CALIBRATE

# 2. 12 次 @8 -> 加重
p = case("达上限且不吃力", [sess(S(100, 12, 8))], 2.5, 8, 12, ("increase", 102.5))
assert p.weight == 102.5, p.weight
assert p.conservative == 100 and p.aggressive == 105

# 3. 12 次 @9.5 -> 保持
p = case("达上限但接近力竭", [sess(S(100, 12, 9.5))], 2.5, 8, 12, ("hold", 100))
assert p.weight == 100

# 4. 首次掉组 -> 保持
p = case("首次未达标", [sess(S(100, 6, 9))], 2.5, 8, 12, ("hold", 100))
assert p.weight == 100

# 5. 连续两次未达标 -> 减重
p = case("连续两次未达标", [sess(S(100, 6, 9)), sess(S(100, 5, 9.5))], 2.5, 8, 12, ("reduce", 97.5))
assert p.weight == 97.5

# 6. 区间内但 RPE 很低 -> 跳一级
p = case("轻得不合理", [sess(S(100, 9, 6.5))], 2.5, 8, 12, ("increase", 102.5))
assert p.weight == 102.5

# 7. 区间内正常 -> 保持
p = case("区间内", [sess(S(100, 9, 8))], 2.5, 8, 12, ("hold", 100))
assert p.weight == 100

# 8. 热身组不参与判断
p = case("忽略热身", [sess(S(60, 10, None, SetType.WARMUP), S(100, 12, 8))], 2.5, 8, 12, ("increase", 102.5))
assert p.weight == 102.5

# 9. 减重不越过最小配重
p = case("减重下限", [sess(S(2.5, 3, 9)), sess(S(2.5, 2, 10))], 2.5, 8, 12, ("reduce", 2.5))
assert p.weight == 2.5

# 10. 无 RPE 数据也要能判断
p = case("无RPE达上限", [sess(S(100, 12, None))], 2.5, 8, 12, ("increase", 102.5))
assert p.weight == 102.5

print("配重用例全部通过：", len(CASES))

# ---- 容量 ----
CHEST = ("chest",)
TRI = ("arms",)
sets = [
    LoggedSet("bench", CHEST, TRI, 80, 8),
    LoggedSet("bench", CHEST, TRI, 80, 8),
    LoggedSet("bench", CHEST, TRI, 80, 8),
    LoggedSet("bench", CHEST, TRI, 80, 8),
    LoggedSet("bench", CHEST, TRI, 80, 8),
    LoggedSet("bench", CHEST, TRI, 80, 8),
    LoggedSet("bench", CHEST, TRI, 80, 8),
    LoggedSet("bench", CHEST, TRI, 80, 8),
]
vols = analyze_volume(sets)
chest = next(v for v in vols if v.muscle == "chest")
print("胸 有效组:", chest.sets, chest.status.value)
assert chest.sets == 8.0 and chest.status == VolumeStatus.UNDER
arms = next(v for v in vols if v.muscle == "arms")
print("手臂 有效组:", arms.sets, arms.status.value)
assert arms.sets == 4.0

# 热身不计入
warm = analyze_volume(sets + [LoggedSet("bench", CHEST, TRI, 40, 15, "warmup")])
assert next(v for v in warm if v.muscle == "chest").sets == 8.0

# ---- 1RM ----
assert round(epley_1rm(100, 1), 2) == 100
assert round(epley_1rm(100, 5), 2) == 116.67
assert round(epley_1rm(80, 10), 2) == 106.67
print("1RM: 100x5 =", round(epley_1rm(100, 5), 2))

assert strength_tier(100, 80, "bench") == "高级"     # 1.25 倍体重
assert strength_tier(60, 80, "bench") == "初级"      # 0.75 倍体重
assert strength_tier(120, 80, "bench") == "精英"     # 1.5 倍体重
assert strength_tier(180, 80, "squat") == "精英"     # 2.25 倍体重
assert strength_tier(90, 0, "bench") is None
print("力量等级映射正常")

# ---- 周报 ----
class P:
    def __init__(self, sets):
        self.sets = sets


def LS(w, r, t="normal", prim=CHEST, sec=TRI):
    return LoggedSet("bench", prim, sec, w, r, t)


sessions = [
    P([LS(80, 8), LS(80, 8), LS(80, 9), LS(90, 5)]),
    P([LS(80, 8), LS(90, 6), LS(40, 15, "warmup")]),
]
stats = weekly_stats(sessions, planned_sessions=3)
print("周报: 场次", stats.session_count, "组数", stats.total_sets,
      "容量", stats.total_volume_kg, "PR", stats.pr_count, "完成率", stats.adherence)
assert stats.session_count == 2
assert stats.total_sets == 6            # 热身不计
assert stats.total_volume_kg == 3630.0  # 2450 + 640 + 540
assert stats.pr_count == 1              # 只有 90x6 超过此前最佳 e1RM
assert stats.adherence == 0.667
print("容量/1RM/周报用例全部通过")

with open("fixtures.json", "w", encoding="utf-8") as f:
    json.dump(CASES, f, ensure_ascii=False, indent=2)
print("fixtures 已写入 fixtures.json")


