import Foundation

extension LiftClass {
    /// 每个大项只用一个锚点动作，保证 1RM 可比（不同器械的估算值不可比）
    var anchorExerciseID: String {
        switch self {
        case .bench: return "barbell-bench-press"
        case .squat: return "back-squat"
        case .deadlift: return "deadlift"
        case .press: return "overhead-press"
        }
    }
}

/// 一次训练的单项最佳 e1RM 采样
struct RetentionSample: Equatable {
    var date: Date
    var exerciseID: String
    var oneRepMax: Double
}

enum RetentionStatus: String {
    case kept, watch, risk, unknown

    var title: String {
        switch self {
        case .kept: return "保持"
        case .watch: return "留意"
        case .risk: return "掉力量"
        case .unknown: return "无数据"
        }
    }
}

struct LiftRetention: Identifiable, Equatable {
    var lift: LiftClass
    var baseline: Double?
    var current: Double?

    var id: String { lift.rawValue }

    var ratio: Double? {
        guard let baseline, let current, baseline > 0 else { return nil }
        return current / baseline
    }

    var delta: Double? {
        guard let baseline, let current else { return nil }
        return current - baseline
    }

    var status: RetentionStatus {
        guard let ratio else { return .unknown }
        if ratio >= 0.97 { return .kept }
        if ratio >= 0.90 { return .watch }
        return .risk
    }
}

/// 减脂期的核心问题：掉的是脂肪还是肌肉？
/// 用「阶段开始前的最佳 e1RM」对比「阶段内的最佳 e1RM」，得到力量保持率。
enum RetentionAnalyzer {

    /// 从训练记录里抽出锚点动作的最佳 e1RM（每次训练一条）
    static func samples(from sessions: [TrainingSession]) -> [RetentionSample] {
        let anchors = Set(LiftClass.allCases.map(\.anchorExerciseID))
        var result: [RetentionSample] = []

        for session in sessions where session.isFinished {
            for item in session.orderedExercises {
                guard let exercise = item.exercise,
                      anchors.contains(exercise.id) else { continue }
                let sets = item.orderedSets
                    .filter { $0.isCompleted && $0.setType != .warmup && $0.weight > 0 && $0.reps > 0 }
                    .map { SetSnapshot(weight: $0.weight, reps: $0.reps) }
                guard let best = StrengthEstimate.bestEstimate(from: sets) else { continue }
                result.append(
                    RetentionSample(
                        date: session.startedAt,
                        exerciseID: exercise.id,
                        oneRepMax: best.oneRepMax
                    )
                )
            }
        }
        return result
    }

    static func analyze(samples: [RetentionSample], phaseStart: Date) -> [LiftRetention] {
        LiftClass.allCases.map { lift in
            let id = lift.anchorExerciseID
            let relevant = samples.filter { $0.exerciseID == id }
            let baseline = relevant
                .filter { $0.date < phaseStart }
                .map(\.oneRepMax)
                .max()
            let current = relevant
                .filter { $0.date >= phaseStart }
                .map(\.oneRepMax)
                .max()
            return LiftRetention(lift: lift, baseline: baseline, current: current)
        }
    }

    /// 有数据的项的平均保持率；没有数据返回 nil
    static func overall(_ retentions: [LiftRetention]) -> Double? {
        let values = retentions.compactMap(\.ratio)
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }
}
