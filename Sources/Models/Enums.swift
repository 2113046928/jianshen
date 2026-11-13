import SwiftUI

// MARK: - 肌群

enum MuscleGroup: String, CaseIterable, Codable, Identifiable {
    case chest, back, legs, shoulders, arms, core

    var id: String { rawValue }

    var title: String {
        switch self {
        case .chest: return "胸"
        case .back: return "背"
        case .legs: return "腿"
        case .shoulders: return "肩"
        case .arms: return "手臂"
        case .core: return "核心"
        }
    }

    /// 每周有效组下限 / 上限（MEV–MAV 简化值）
    var weeklyLow: Double {
        switch self {
        case .chest: return 10
        case .back: return 10
        case .legs: return 12
        case .shoulders: return 8
        case .arms: return 6
        case .core: return 4
        }
    }

    var weeklyHigh: Double {
        switch self {
        case .chest: return 20
        case .back: return 22
        case .legs: return 22
        case .shoulders: return 16
        case .arms: return 14
        case .core: return 12
        }
    }

    var tint: Color {
        switch self {
        case .chest: return Color(red: 0.90, green: 0.32, blue: 0.24)
        case .back: return Color(red: 0.20, green: 0.45, blue: 0.85)
        case .legs: return Color(red: 0.18, green: 0.60, blue: 0.44)
        case .shoulders: return Color(red: 0.85, green: 0.55, blue: 0.15)
        case .arms: return Color(red: 0.55, green: 0.36, blue: 0.80)
        case .core: return Color(red: 0.40, green: 0.45, blue: 0.50)
        }
    }
}

// MARK: - 动作模式

enum MovementPattern: String, Codable, CaseIterable {
    case horizontalPush, verticalPush, horizontalPull, verticalPull
    case squat, hinge, lunge, arm, core

    var title: String {
        switch self {
        case .horizontalPush: return "水平推"
        case .verticalPush: return "垂直推"
        case .horizontalPull: return "水平拉"
        case .verticalPull: return "垂直拉"
        case .squat: return "蹲"
        case .hinge: return "髋铰链"
        case .lunge: return "单腿"
        case .arm: return "手臂"
        case .core: return "核心"
        }
    }
}

// MARK: - 器械

enum Equipment: String, Codable, CaseIterable, Identifiable {
    case barbell, dumbbell, machine, cable, bodyweight, kettlebell, band

    var id: String { rawValue }

    var title: String {
        switch self {
        case .barbell: return "杠铃"
        case .dumbbell: return "哑铃"
        case .machine: return "固定器械"
        case .cable: return "绳索"
        case .bodyweight: return "自重"
        case .kettlebell: return "壶铃"
        case .band: return "弹力带"
        }
    }

    var symbol: String {
        switch self {
        case .barbell: return "figure.strengthtraining.traditional"
        case .dumbbell: return "dumbbell.fill"
        case .machine: return "gearshape.2.fill"
        case .cable: return "cable.connector"
        case .bodyweight: return "figure.gymnastics"
        case .kettlebell: return "figure.cross.training"
        case .band: return "link"
        }
    }
}

// MARK: - 组类型

enum SetType: String, Codable, CaseIterable, Identifiable {
    case warmup, normal, drop, failure

    var id: String { rawValue }

    var title: String {
        switch self {
        case .warmup: return "热身"
        case .normal: return "正式"
        case .drop: return "递减"
        case .failure: return "力竭"
        }
    }
}

// MARK: - 训练阶段

enum Phase: String, Codable, CaseIterable, Identifiable {
    case bulk, cut, maintain

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bulk: return "增肌期"
        case .cut: return "减脂期"
        case .maintain: return "维持期"
        }
    }

    var summary: String {
        switch self {
        case .bulk: return "容量驱动，热量小幅盈余，目标是把训练容量推上去"
        case .cut: return "维持强度不掉重量，热量缺口，重点是力量保持率"
        case .maintain: return "强度与容量交替，热量平衡，保持节奏"
        }
    }

    var weeklyCardio: String {
        switch self {
        case .bulk: return "有氧 1–2 次"
        case .cut: return "有氧 3–4 次"
        case .maintain: return "有氧 2 次"
        }
    }
}

// MARK: - 容量状态

enum VolumeStatus: String {
    case under, inRange, over

    var title: String {
        switch self {
        case .under: return "不足"
        case .inRange: return "达标"
        case .over: return "过量"
        }
    }

    var tint: Color {
        switch self {
        case .under: return Color(red: 0.85, green: 0.55, blue: 0.15)
        case .inRange: return Color(red: 0.18, green: 0.60, blue: 0.44)
        case .over: return Color(red: 0.90, green: 0.32, blue: 0.24)
        }
    }
}

// MARK: - 配重建议的置信度

enum Confidence: String {
    case calibrate, increase, hold, reduce

    var title: String {
        switch self {
        case .calibrate: return "校准"
        case .increase: return "加重"
        case .hold: return "保持"
        case .reduce: return "减重"
        }
    }

    var symbol: String {
        switch self {
        case .calibrate: return "target"
        case .increase: return "arrow.up.right"
        case .hold: return "equal"
        case .reduce: return "arrow.down.right"
        }
    }

    var tint: Color {
        switch self {
        case .calibrate: return Color(red: 0.40, green: 0.45, blue: 0.50)
        case .increase: return Color(red: 0.18, green: 0.60, blue: 0.44)
        case .hold: return Color(red: 0.35, green: 0.40, blue: 0.45)
        case .reduce: return Color(red: 0.90, green: 0.32, blue: 0.24)
        }
    }
}

// MARK: - 力量等级

enum LiftClass: String, Codable, CaseIterable, Identifiable {
    case bench, squat, deadlift, press

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bench: return "卧推"
        case .squat: return "深蹲"
        case .deadlift: return "硬拉"
        case .press: return "推举"
        }
    }

    /// 达到该倍数即进入下一等级：入门 → 初级 → 中级 → 高级 → 精英
    var thresholds: [Double] {
        switch self {
        case .bench: return [0.75, 1.0, 1.25, 1.5]
        case .squat: return [1.0, 1.25, 1.5, 1.75]
        case .deadlift: return [1.25, 1.5, 1.75, 2.0]
        case .press: return [0.5, 0.65, 0.85, 1.0]
        }
    }
}

enum StrengthTier: String, CaseIterable {
    case beginner = "入门"
    case novice = "初级"
    case intermediate = "中级"
    case advanced = "高级"
    case elite = "精英"
}
