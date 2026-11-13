import Foundation

enum StrengthEstimate {

    /// Epley 公式；1 次时直接返回重量
    static func oneRepMax(weight: Double, reps: Int) -> Double {
        guard weight > 0 else { return 0 }
        if reps <= 1 { return weight }
        return weight * (1 + Double(reps) / 30)
    }

    /// 相对体重力量等级
    static func tier(oneRepMax: Double, bodyweight: Double, lift: LiftClass) -> StrengthTier? {
        guard bodyweight > 0, oneRepMax > 0 else { return nil }
        let ratio = oneRepMax / bodyweight
        var level = 0
        for threshold in lift.thresholds where ratio >= threshold {
            level += 1
        }
        let tiers = StrengthTier.allCases
        return tiers[min(level, tiers.count - 1)]
    }

    /// 1RM 的展示文案，例如 "102.5kg（高级，1.28 倍体重）"
    static func summary(oneRepMax: Double, bodyweight: Double, lift: LiftClass) -> String {
        guard bodyweight > 0 else { return "\(LoadPrescription.kg(oneRepMax))kg" }
        let ratio = oneRepMax / bodyweight
        let ratioText = String(format: "%.2f", ratio)
        guard let tier = tier(oneRepMax: oneRepMax, bodyweight: bodyweight, lift: lift) else {
            return "\(LoadPrescription.kg(oneRepMax))kg"
        }
        return "\(LoadPrescription.kg(oneRepMax))kg（\(tier.rawValue)，\(ratioText) 倍体重）"
    }

    /// 从一组最好成绩里估算 1RM
    static func bestEstimate(from sets: [SetSnapshot]) -> (oneRepMax: Double, source: SetSnapshot)? {
        let candidates = sets
            .filter { $0.setType != .warmup && $0.reps > 0 && $0.weight > 0 }
            .map { (oneRepMax: oneRepMax(weight: $0.weight, reps: $0.reps), source: $0) }
        return candidates.max { $0.oneRepMax < $1.oneRepMax }
    }
}
