import Foundation

/// 根据上周各肌群的有效组，决定下周每个动作加减几组。
struct VolumeAdjustment: Identifiable, Equatable {
    var muscle: MuscleGroup
    /// +1 加一组、-1 减一组、0 不动
    var delta: Int
    var reason: String

    var id: String { muscle.rawValue }
}

enum VolumeProgression {

    /// 差 2 组以上才加，超 3 组以上才减——避免每周来回抖
    static let addThreshold: Double = 2
    static let reduceThreshold: Double = 3

    static func adjustments(volumes: [MuscleVolume]) -> [VolumeAdjustment] {
        volumes.compactMap { volume in
            let gap = volume.low - volume.sets
            let excess = volume.sets - volume.high

            if gap >= addThreshold {
                return VolumeAdjustment(
                    muscle: volume.muscle,
                    delta: 1,
                    reason: "\(volume.muscle.title)还差 \(Fmt.kg(gap)) 个有效组，下周每个相关动作加 1 组。"
                )
            }

            if excess >= reduceThreshold {
                return VolumeAdjustment(
                    muscle: volume.muscle,
                    delta: -1,
                    reason: "\(volume.muscle.title)超出上限 \(Fmt.kg(excess)) 组，下周先从相关动作各减 1 组。"
                )
            }

            return nil
        }
    }

    /// 某个动作因为容量缺口该加几组
    static func extraSets(for exercise: Exercise, adjustments: [VolumeAdjustment]) -> Int {
        let muscles = Set(exercise.primaryRaw)
        let positive = adjustments.contains { $0.delta > 0 && muscles.contains($0.muscle.rawValue) }
        return positive ? 1 : 0
    }

    /// 某个动作因为容量过量该减几组
    static func reducedSets(for exercise: Exercise, adjustments: [VolumeAdjustment]) -> Int {
        let muscles = Set(exercise.primaryRaw)
        let negative = adjustments.contains { $0.delta < 0 && muscles.contains($0.muscle.rawValue) }
        return negative ? 1 : 0
    }
}
