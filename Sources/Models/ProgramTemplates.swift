import Foundation

struct ProgramDay: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var focus: String
    var exerciseIDs: [String]
}

struct ProgramTemplate: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var subtitle: String
    var days: [ProgramDay]
}

enum ProgramTemplates {

    static let ppl = ProgramTemplate(
        id: "ppl",
        name: "推拉腿",
        subtitle: "每周 3–6 练，最通用的增肌结构",
        days: [
            ProgramDay(
                id: "push",
                name: "推日",
                focus: "胸 · 肩 · 三头",
                exerciseIDs: [
                    "barbell-bench-press",
                    "incline-dumbbell-press",
                    "overhead-press",
                    "lateral-raise",
                    "triceps-pushdown",
                    "cable-fly"
                ]
            ),
            ProgramDay(
                id: "pull",
                name: "拉日",
                focus: "背 · 二头",
                exerciseIDs: [
                    "deadlift",
                    "pull-up",
                    "barbell-row",
                    "lat-pulldown",
                    "face-pull",
                    "barbell-curl"
                ]
            ),
            ProgramDay(
                id: "legs",
                name: "腿日",
                focus: "股四 · 股二 · 臀",
                exerciseIDs: [
                    "back-squat",
                    "romanian-deadlift",
                    "leg-press",
                    "leg-curl",
                    "standing-calf-raise",
                    "hanging-leg-raise"
                ]
            )
        ]
    )

    static let upperLower = ProgramTemplate(
        id: "upperLower",
        name: "上下肢",
        subtitle: "每周 4 练，时间紧时最省事",
        days: [
            ProgramDay(
                id: "upper",
                name: "上肢",
                focus: "胸 · 背 · 肩 · 手臂",
                exerciseIDs: [
                    "barbell-bench-press",
                    "barbell-row",
                    "overhead-press",
                    "lat-pulldown",
                    "dumbbell-curl",
                    "triceps-pushdown"
                ]
            ),
            ProgramDay(
                id: "lower",
                name: "下肢",
                focus: "腿 · 臀 · 核心",
                exerciseIDs: [
                    "back-squat",
                    "romanian-deadlift",
                    "leg-press",
                    "leg-curl",
                    "standing-calf-raise",
                    "cable-crunch"
                ]
            )
        ]
    )

    static let fullBody = ProgramTemplate(
        id: "fullBody",
        name: "全身",
        subtitle: "每周 3 练，新手与回归期首选",
        days: [
            ProgramDay(
                id: "fullA",
                name: "全身 A",
                focus: "蹲 · 推 · 拉",
                exerciseIDs: [
                    "back-squat",
                    "barbell-bench-press",
                    "barbell-row",
                    "lateral-raise",
                    "barbell-curl"
                ]
            ),
            ProgramDay(
                id: "fullB",
                name: "全身 B",
                focus: "髋铰链 · 推 · 拉",
                exerciseIDs: [
                    "deadlift",
                    "overhead-press",
                    "lat-pulldown",
                    "leg-press",
                    "hanging-leg-raise"
                ]
            )
        ]
    )

    static let home = ProgramTemplate(
        id: "home",
        name: "居家哑铃",
        subtitle: "一对哑铃 + 自重，每次 40 分钟",
        days: [
            ProgramDay(
                id: "homeA",
                name: "居家 A",
                focus: "腿 · 推 · 拉",
                exerciseIDs: [
                    "goblet-squat",
                    "dumbbell-bench-press",
                    "dumbbell-row",
                    "lateral-raise",
                    "ab-wheel"
                ]
            ),
            ProgramDay(
                id: "homeB",
                name: "居家 B",
                focus: "单腿 · 肩 · 手臂",
                exerciseIDs: [
                    "bulgarian-split-squat",
                    "dumbbell-shoulder-press",
                    "push-up",
                    "hammer-curl",
                    "russian-twist"
                ]
            )
        ]
    )

    static let all: [ProgramTemplate] = [ppl, upperLower, fullBody, home]

    static func template(id: String) -> ProgramTemplate {
        all.first { $0.id == id } ?? ppl
    }
}
