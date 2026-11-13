import Foundation

/// 一组已完成的训练数据（与 SwiftData 解耦的值类型，便于单元测试）
struct SetSnapshot: Equatable {
    var weight: Double
    var reps: Int
    var rpe: Double?
    var setType: SetType

    init(weight: Double, reps: Int, rpe: Double? = nil, setType: SetType = .normal) {
        self.weight = weight
        self.reps = reps
        self.rpe = rpe
        self.setType = setType
    }
}

/// 一次历史训练
struct SessionSnapshot: Equatable {
    var date: Date
    var sets: [SetSnapshot]

    init(date: Date, sets: [SetSnapshot]) {
        self.date = date
        self.sets = sets
    }
}

/// 下一次该练多重的建议
struct Prescription: Equatable {
    /// nil 表示需要先校准（第一次练这个动作）
    var weight: Double?
    var targetReps: ClosedRange<Int>
    var confidence: Confidence
    var rationale: String
    var conservative: Double?
    var aggressive: Double?

    var isCalibration: Bool { weight == nil }
}

/// 双进阶配重规则。与 _spec/engine.py 为同一套规则，XCTest 用同一批用例校验。
enum LoadPrescription {

    static func next(
        history: [SessionSnapshot],
        increment: Double,
        target: ClosedRange<Int>
    ) -> Prescription {
        let sessions = history
            .filter { !workingSets($0.sets).isEmpty }
            .sorted { $0.date < $1.date }

        guard let last = sessions.last else {
            return Prescription(
                weight: nil,
                targetReps: target,
                confidence: .calibrate,
                rationale: "第一次练这个动作，先用能标准完成 \(target.lowerBound) 次的重量做校准。",
                conservative: nil,
                aggressive: nil
            )
        }

        let working = workingSets(last.sets)
        let stats = topStats(working)
        let failures = consecutiveFailures(sessions, targetLow: target.lowerBound)

        // 1. 顶组达到次数上限，且还有余力 -> 加一个最小递增
        if stats.reps >= target.upperBound, stats.rpe == nil || stats.rpe! <= 8.5 {
            let newWeight = roundHalf(stats.weight + increment)
            let rpeText = stats.rpe.map { "（RPE \(kg($0))）" } ?? ""
            return Prescription(
                weight: newWeight,
                targetReps: target,
                confidence: .increase,
                rationale: "上次 \(kg(stats.weight))kg 做到 \(stats.reps) 次\(rpeText)，已达上限，加 \(kg(increment))kg。",
                conservative: stats.weight,
                aggressive: roundHalf(stats.weight + increment * 2)
            )
        }

        // 2. 次数低于下限
        if stats.reps < target.lowerBound {
            if failures >= 2 {
                let newWeight = max(roundHalf(stats.weight - increment), increment)
                return Prescription(
                    weight: newWeight,
                    targetReps: target,
                    confidence: .reduce,
                    rationale: "连续 \(failures) 次没做到 \(target.lowerBound) 次，减 \(kg(increment))kg 重建动作质量。",
                    conservative: max(roundHalf(stats.weight - increment * 2), increment),
                    aggressive: stats.weight
                )
            }
            return Prescription(
                weight: stats.weight,
                targetReps: target,
                confidence: .hold,
                rationale: "上次 \(kg(stats.weight))kg 只做到 \(stats.reps) 次，先不加重量，目标做到 \(stats.reps + 1) 次。",
                conservative: stats.weight,
                aggressive: roundHalf(stats.weight + increment)
            )
        }

        // 3. 次数在上限内，但明显偏轻 -> 跳一级
        if let rpe = stats.rpe, rpe <= 7.0, stats.reps >= target.lowerBound + 1 {
            let newWeight = roundHalf(stats.weight + increment)
            return Prescription(
                weight: newWeight,
                targetReps: target,
                confidence: .increase,
                rationale: "上次 \(kg(stats.weight))kg 做到 \(stats.reps) 次但 RPE 只有 \(kg(rpe))，明显偏轻，直接加 \(kg(increment))kg。",
                conservative: stats.weight,
                aggressive: roundHalf(stats.weight + increment * 2)
            )
        }

        // 4. 正常区间内 -> 保持重量，先把次数做满
        return Prescription(
            weight: stats.weight,
            targetReps: target,
            confidence: .hold,
            rationale: "目标先做到 \(target.upperBound) 次，再加重。",
            conservative: stats.weight,
            aggressive: roundHalf(stats.weight + increment)
        )
    }

    // MARK: - 内部工具

    private static func workingSets(_ sets: [SetSnapshot]) -> [SetSnapshot] {
        sets.filter { $0.setType != .warmup }
    }

    private static func topStats(_ sets: [SetSnapshot]) -> (weight: Double, reps: Int, rpe: Double?) {
        let topWeight = sets.map(\.weight).max() ?? 0
        let atTop = sets.filter { abs($0.weight - topWeight) < 0.01 }
        let reps = atTop.map(\.reps).max() ?? 0
        let rpes = atTop.compactMap(\.rpe)
        let rpe = rpes.isEmpty ? nil : rpes.reduce(0, +) / Double(rpes.count)
        return (topWeight, reps, rpe)
    }

    private static func consecutiveFailures(_ sessions: [SessionSnapshot], targetLow: Int) -> Int {
        var count = 0
        for session in sessions.reversed() {
            let working = workingSets(session.sets)
            if working.isEmpty { continue }
            let stats = topStats(working)
            if stats.reps < targetLow {
                count += 1
            } else {
                break
            }
        }
        return count
    }

    /// 对齐到 0.5kg 的最小配重刻度
    static func roundHalf(_ value: Double) -> Double {
        (value * 2).rounded() / 2
    }

    static func kg(_ value: Double) -> String {
        if value == value.rounded() {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
    }
}
