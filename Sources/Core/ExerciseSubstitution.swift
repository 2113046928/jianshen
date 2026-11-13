import Foundation

/// 动作替换：器械被占、器械不在、某个动作做不了时，按「同动作模式 + 同器械 + 同主动肌」打分。
enum ExerciseSubstitution {

    /// 候选动作至少要有的分数，低于这个值宁可返回空，也不要瞎推荐
    static let minimumScore: Double = 4.0

    static func score(_ candidate: Exercise, against base: Exercise) -> Double {
        var score = 0.0

        if candidate.pattern == base.pattern {
            score += 4
        }
        if candidate.equipment == base.equipment {
            score += 2
        }
        if candidate.isCompound == base.isCompound {
            score += 1.5
        }

        let shared = Set(candidate.primaryRaw).intersection(Set(base.primaryRaw)).count
        score += Double(shared) * 0.5

        return score
    }

    static func alternatives(
        for base: Exercise,
        in catalog: [Exercise],
        limit: Int = 4
    ) -> [Exercise] {
        catalog
            .filter { $0.id != base.id }
            .map { (exercise: $0, score: score($0, against: base)) }
            .filter { $0.score >= minimumScore }
            .sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score > rhs.score }
                return lhs.exercise.sortIndex < rhs.exercise.sortIndex
            }
            .prefix(limit)
            .map(\.exercise)
    }

    /// 只保留某种器械的替代动作（比如出差只能用哑铃）
    static func alternatives(
        for base: Exercise,
        in catalog: [Exercise],
        equipment: Equipment,
        limit: Int = 4
    ) -> [Exercise] {
        alternatives(for: base, in: catalog.filter { $0.equipment == equipment }, limit: limit)
    }
}
