import Foundation

// MARK: - 输入

enum Sex: String, CaseIterable, Identifiable {
    case male, female

    var id: String { rawValue }

    var title: String {
        switch self {
        case .male: return "男"
        case .female: return "女"
        }
    }
}

enum ActivityLevel: String, CaseIterable, Identifiable {
    case sedentary, light, moderate, active, veryActive

    var id: String { rawValue }

    /// 日常活动系数（不含训练本身——训练量由训练计划决定，不重复计入）
    var factor: Double {
        switch self {
        case .sedentary: return 1.2
        case .light: return 1.375
        case .moderate: return 1.55
        case .active: return 1.725
        case .veryActive: return 1.9
        }
    }

    var title: String {
        switch self {
        case .sedentary: return "久坐"
        case .light: return "轻度活动"
        case .moderate: return "中等活动"
        case .active: return "高活动"
        case .veryActive: return "极高活动"
        }
    }

    var detail: String {
        switch self {
        case .sedentary: return "办公室为主，每天走路不到 5000 步"
        case .light: return "偶尔走动，5000–8000 步"
        case .moderate: return "经常站立或走动，8000–12000 步"
        case .active: return "体力工作或每天通勤 + 训练"
        case .veryActive: return "重体力劳动或一天两练"
        }
    }
}

struct BodyProfile: Equatable {
    var sex: Sex
    var age: Int
    var heightCM: Double
    var weightKG: Double
    var activity: ActivityLevel
}

// MARK: - 输出

struct MacroTargets: Equatable {
    var calories: Double
    var proteinG: Double
    var fatG: Double
    var carbsG: Double
    var proteinPerKg: Double

    /// 用 4/9/4 回算热量，用于自检
    var caloriesFromMacros: Double {
        proteinG * 4 + fatG * 9 + carbsG * 4
    }
}

struct NutritionPlan: Equatable {
    var bmr: Double
    var tdee: Double
    var targets: MacroTargets
    var notes: [String]
}

enum NutritionAdjustment: String {
    case hold, increase, reduce, adjust

    var title: String {
        switch self {
        case .hold: return "保持"
        case .increase: return "加 150 千卡"
        case .reduce: return "减 150 千卡"
        case .adjust: return "先稳定结构"
        }
    }
}

/// 营养目标计算。与 _spec/nutrition.py 为同一套公式，XCTest 用同一批期望值。
enum NutritionEngine {

    /// Mifflin-St Jeor
    static func bmr(_ profile: BodyProfile) -> Double {
        let base = 10 * profile.weightKG
            + 6.25 * profile.heightCM
            - 5 * Double(profile.age)
        return base + (profile.sex == .male ? 5 : -161)
    }

    static func tdee(_ profile: BodyProfile) -> Double {
        bmr(profile) * profile.activity.factor
    }

    static func plan(for profile: BodyProfile, phase: Phase) -> NutritionPlan {
        let base = bmr(profile)
        let maintenance = base * profile.activity.factor

        var target = maintenance * phaseAdjustment(phase)

        // 缺口不超过 20%，并且绝不低于基础代谢
        if phase == .cut {
            target = max(target, maintenance * 0.80)
        }
        target = max(target, base)

        let protein = proteinPerKg(phase) * profile.weightKG
        let fat = 0.9 * profile.weightKG
        let remaining = target - protein * 4 - fat * 9
        let carbs = max(remaining, 0) / 4

        var notes: [String] = []
        if phase == .cut, carbs < 1.5 * profile.weightKG {
            notes.append("碳水偏低，先把缺口收到 15% 左右，再考虑加有氧。")
        }
        if phase == .bulk, target - maintenance > maintenance * 0.12 {
            notes.append("盈余偏大，脂肪增长会明显，建议控制在 10% 以内。")
        }
        if profile.activity == .sedentary, phase == .cut {
            notes.append("久坐 + 减脂时优先加日常步数，比加有氧更不容易影响恢复。")
        }

        return NutritionPlan(
            bmr: round1(base),
            tdee: round1(maintenance),
            targets: MacroTargets(
                calories: round1(target),
                proteinG: round1(protein),
                fatG: round1(fat),
                carbsG: round1(carbs),
                proteinPerKg: round1(protein / profile.weightKG * 100) / 100
            ),
            notes: notes
        )
    }

    /// 三餐 / 三餐 + 加餐的热量分配
    static func mealSplit(calories: Double, meals: Int) -> [Double] {
        let ratios: [Double]
        switch meals {
        case 4: ratios = [0.28, 0.32, 0.30, 0.10]
        case 5: ratios = [0.24, 0.28, 0.26, 0.12, 0.10]
        default: ratios = [0.33, 0.34, 0.33]
        }
        return ratios.map { round1(calories * $0) }
    }

    /// 每周体重变化百分比 -> 该不该动热量。先看趋势，再动数字。
    static func weeklyAdjustment(
        weeklyChangePercent: Double,
        phase: Phase
    ) -> (action: NutritionAdjustment, advice: String) {
        switch phase {
        case .cut:
            if weeklyChangePercent > -0.003 {
                return (.reduce, "两周几乎没动，先减 150 千卡或每天多走 2000 步。")
            }
            if weeklyChangePercent < -0.012 {
                return (.increase, "掉得过快，加回 150 千卡，优先补碳水。")
            }
            return (.hold, "速度合适，保持不变。")

        case .bulk:
            if weeklyChangePercent < 0.001 {
                return (.increase, "两周没涨，加 150 千卡。")
            }
            if weeklyChangePercent > 0.006 {
                return (.reduce, "涨得过快，减 150 千卡，避免脂肪堆积。")
            }
            return (.hold, "速度合适，保持不变。")

        case .maintain:
            if abs(weeklyChangePercent) > 0.008 {
                return (.adjust, "波动偏大，先稳定饮食结构再看体重。")
            }
            return (.hold, "维持期保持稳定即可。")
        }
    }

    // MARK: - 内部

    private static func phaseAdjustment(_ phase: Phase) -> Double {
        switch phase {
        case .bulk: return 1.10
        case .cut: return 0.82
        case .maintain: return 1.0
        }
    }

    private static func proteinPerKg(_ phase: Phase) -> Double {
        switch phase {
        case .bulk: return 1.8
        case .cut: return 2.2
        case .maintain: return 1.8
        }
    }

    private static func round1(_ value: Double) -> Double {
        (value * 10).rounded() / 10
    }
}
