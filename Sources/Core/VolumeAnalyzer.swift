import Foundation

/// 训练中一条已完成的组（带肌群归属），用于容量分析
struct LoggedSet: Equatable {
    var exerciseID: String
    var primary: [MuscleGroup]
    var secondary: [MuscleGroup]
    var weight: Double
    var reps: Int
    var setType: SetType

    init(
        exerciseID: String,
        primary: [MuscleGroup],
        secondary: [MuscleGroup] = [],
        weight: Double,
        reps: Int,
        setType: SetType = .normal
    ) {
        self.exerciseID = exerciseID
        self.primary = primary
        self.secondary = secondary
        self.weight = weight
        self.reps = reps
        self.setType = setType
    }
}

struct MuscleVolume: Identifiable, Equatable {
    var muscle: MuscleGroup
    var sets: Double
    var status: VolumeStatus

    var id: String { muscle.rawValue }
    var low: Double { muscle.weeklyLow }
    var high: Double { muscle.weeklyHigh }

    /// 0...1，用于画容量条
    var progress: Double {
        guard high > 0 else { return 0 }
        return min(sets / high, 1)
    }
}

enum VolumeAnalyzer {

    /// 有效组：主动肌算 1 组，协同肌算 0.5 组，热身不计。
    static func analyze(sets: [LoggedSet], weeks: Double = 1) -> [MuscleVolume] {
        let divisor = max(weeks, 0.01)
        var totals: [MuscleGroup: Double] = [:]
        for muscle in MuscleGroup.allCases { totals[muscle] = 0 }

        for set in sets where set.setType != .warmup {
            for muscle in set.primary { totals[muscle, default: 0] += 1 }
            for muscle in set.secondary { totals[muscle, default: 0] += 0.5 }
        }

        return MuscleGroup.allCases.map { muscle in
            let volume = (totals[muscle] ?? 0) / divisor
            let low = muscle.weeklyLow / divisor
            let high = muscle.weeklyHigh / divisor
            let status: VolumeStatus
            if volume < low {
                status = .under
            } else if volume > high {
                status = .over
            } else {
                status = .inRange
            }
            return MuscleVolume(muscle: muscle, sets: (volume * 10).rounded() / 10, status: status)
        }
    }

    /// 最需要补的肌群（不足且差距最大）
    static func weakest(_ volumes: [MuscleVolume]) -> MuscleVolume? {
        volumes
            .filter { $0.status == .under }
            .max { ($0.low - $0.sets) < ($1.low - $1.sets) }
    }
}
