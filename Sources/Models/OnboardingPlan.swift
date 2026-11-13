import Foundation

// MARK: - 建档问题

enum TrainingGoal: String, CaseIterable, Identifiable {
    case buildMuscle, loseFat, getStronger, generalFitness

    var id: String { rawValue }

    var title: String {
        switch self {
        case .buildMuscle: return "增肌"
        case .loseFat: return "减脂"
        case .getStronger: return "力量"
        case .generalFitness: return "保持健康"
        }
    }

    var subtitle: String {
        switch self {
        case .buildMuscle: return "容量驱动，体重缓慢上升"
        case .loseFat: return "守住力量，制造热量缺口"
        case .getStronger: return "冲大重量，次数偏低"
        case .generalFitness: return "规律训练，不追极限"
        }
    }

    var phase: Phase {
        switch self {
        case .buildMuscle: return .bulk
        case .loseFat: return .cut
        case .getStronger, .generalFitness: return .maintain
        }
    }
}

enum EquipmentAccess: String, CaseIterable, Identifiable {
    case commercialGym, homeDumbbell, bodyweightOnly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .commercialGym: return "健身房"
        case .homeDumbbell: return "家里有哑铃"
        case .bodyweightOnly: return "只有自重"
        }
    }

    var subtitle: String {
        switch self {
        case .commercialGym: return "杠铃、器械、绳索都有"
        case .homeDumbbell: return "一对哑铃 + 可调节凳"
        case .bodyweightOnly: return "弹力带、单杠"
        }
    }
}

enum ExperienceLevel: String, CaseIterable, Identifiable {
    case beginner, intermediate, advanced

    var id: String { rawValue }

    var title: String {
        switch self {
        case .beginner: return "刚开始"
        case .intermediate: return "半年到两年"
        case .advanced: return "两年以上"
        }
    }
}

struct OnboardingAnswers: Equatable {
    var goal: TrainingGoal = .buildMuscle
    var daysPerWeek: Int = 3
    var equipment: EquipmentAccess = .commercialGym
    var experience: ExperienceLevel = .beginner
    var bodyweight: Double = 70
}

struct OnboardingPlan: Equatable {
    var phase: Phase
    var weeklyGoal: Int
    var programID: String
    var programName: String
    var headline: String
    var detail: String
}

/// 五个问题 -> 阶段、每周目标、训练模板。
/// 规则刻意保守：新手与器械受限的人一律先进全身训练，避免一上来就排 5 分化。
enum OnboardingPlanner {

    static func plan(for answers: OnboardingAnswers) -> OnboardingPlan {
        let days = min(max(answers.daysPerWeek, 2), 6)
        let phase = answers.goal.phase

        var programID: String
        switch answers.equipment {
        case .homeDumbbell, .bodyweightOnly:
            programID = "home"
        case .commercialGym:
            if days <= 3 {
                programID = "fullBody"
            } else if days == 4 {
                programID = "upperLower"
            } else {
                programID = "ppl"
            }
            if answers.experience == .beginner && days <= 4 {
                programID = "fullBody"
            }
        }

        let template = ProgramTemplates.template(id: programID)
        let headline = "\(phase.title) · 每周 \(days) 练"
        let detail: String
        switch answers.equipment {
        case .homeDumbbell:
            detail = "用哑铃做全身训练，每次 40 分钟左右。重量可以慢慢加，动作标准优先。"
        case .bodyweightOnly:
            detail = "自重为主，靠次数和组间休息控制强度。第一周先把动作做标准。"
        case .commercialGym:
            detail = "\(template.name)：\(template.subtitle)。先跑满 4 周，再考虑调整。"
        }

        return OnboardingPlan(
            phase: phase,
            weeklyGoal: days,
            programID: programID,
            programName: template.name,
            headline: headline,
            detail: detail
        )
    }
}
