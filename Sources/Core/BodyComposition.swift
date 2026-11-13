import Foundation

/// 体脂率分类（参考 ACE 的体脂区间，按性别分开）
enum BodyFatCategory: String, CaseIterable {
    case low, athletic, fit, average, high, obese

    var title: String {
        switch self {
        case .low: return "偏低"
        case .athletic: return "运动员"
        case .fit: return "健壮"
        case .average: return "正常"
        case .high: return "偏高"
        case .obese: return "肥胖"
        }
    }
}

/// 身体成分估算。
///
/// 两条路线：
/// - Deurenberg：只要有身高、体重、年龄、性别，误差约 ±4–5%
/// - US Navy 围度法：多量腰围（女性加臀围）和颈围，误差约 ±3%
///
/// 都不是"测量"，是估算。绝对值参考意义有限，趋势才有意义。
enum BodyComposition {

    // MARK: - 基础

    static func bmi(weightKG: Double, heightCM: Double) -> Double {
        guard heightCM > 0 else { return 0 }
        let meters = heightCM / 100
        return weightKG / (meters * meters)
    }

    /// Deurenberg 1991：1.20×BMI + 0.23×年龄 − 10.8×性别 − 5.4（男=1，女=0）
    static func deurenberg(
        weightKG: Double,
        heightCM: Double,
        age: Int,
        sex: Sex
    ) -> Double {
        let index = bmi(weightKG: weightKG, heightCM: heightCM)
        let sexTerm = sex == .male ? 1.0 : 0.0
        let value = 1.20 * index + 0.23 * Double(age) - 10.8 * sexTerm - 5.4
        return max(2, min(value, 60))
    }

    /// US Navy 围度法（公制，单位 cm）
    static func navy(
        waistCM: Double,
        neckCM: Double,
        hipCM: Double?,
        heightCM: Double,
        sex: Sex
    ) -> Double? {
        guard waistCM > 0, neckCM > 0, heightCM > 0 else { return nil }

        let denominator: Double
        if sex == .male {
            let circumference = waistCM - neckCM
            guard circumference > 0 else { return nil }
            denominator = 1.0324
                - 0.19077 * log10(circumference)
                + 0.15456 * log10(heightCM)
        } else {
            guard let hipCM, hipCM > 0 else { return nil }
            let circumference = waistCM + hipCM - neckCM
            guard circumference > 0 else { return nil }
            denominator = 1.29579
                - 0.35004 * log10(circumference)
                + 0.22100 * log10(heightCM)
        }

        guard denominator > 0 else { return nil }
        let percent = 495 / denominator - 450
        return max(2, min(percent, 60))
    }

    // MARK: - 衍生指标

    static func leanMass(weightKG: Double, bodyFatPercent: Double) -> Double {
        weightKG * (1 - bodyFatPercent / 100)
    }

    static func fatMass(weightKG: Double, bodyFatPercent: Double) -> Double {
        weightKG * bodyFatPercent / 100
    }

    /// 去脂体重指数：瘦体重 / 身高²，健美人群常用 20–25
    static func ffmi(leanKG: Double, heightCM: Double) -> Double {
        guard heightCM > 0 else { return 0 }
        let meters = heightCM / 100
        return leanKG / (meters * meters)
    }

    /// 身高归一化后的 FFMI（超过 180cm 时补偿），便于横向比较
    static func normalizedFFMI(leanKG: Double, heightCM: Double) -> Double {
        guard heightCM > 0 else { return 0 }
        let meters = heightCM / 100
        let raw = ffmi(leanKG: leanKG, heightCM: heightCM)
        return raw + 6.1 * (1.8 - meters)
    }

    /// 想达到某个体脂率时的体重（假设瘦体重不变）
    static func targetWeight(leanKG: Double, targetBodyFatPercent: Double) -> Double? {
        guard targetBodyFatPercent < 100 else { return nil }
        return leanKG / (1 - targetBodyFatPercent / 100)
    }

    // MARK: - 分类

    static func category(bodyFatPercent: Double, sex: Sex) -> BodyFatCategory {
        if sex == .male {
            switch bodyFatPercent {
            case ..<6: return .low
            case ..<14: return .athletic
            case ..<18: return .fit
            case ..<25: return .average
            case ..<30: return .high
            default: return .obese
            }
        }
        switch bodyFatPercent {
        case ..<14: return .low
        case ..<21: return .athletic
        case ..<25: return .fit
        case ..<32: return .average
        case ..<38: return .high
        default: return .obese
        }
    }

    /// 展示用的健康区间
    static func healthyRange(sex: Sex) -> ClosedRange<Double> {
        sex == .male ? 10...20 : 18...28
    }
}
