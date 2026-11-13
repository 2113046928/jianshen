import Foundation

/// 所有需要拼接数字/名称的文案集中在这里。
///
/// 为什么不直接在 View 里写 `Text("第 \(n) 组")`：那样 SwiftUI 会生成
/// 形如 "第 %lld 组" 的隐式 key，既不可控也不好翻译。统一走 `String(format:)` 后，
/// key 在 .strings 里是显式的，类型也由这里的函数签名固定住。
enum L10n {

    // MARK: - 通用

    static func setCount(_ sets: String) -> String {
        String(format: String(localized: "%@ 组"), sets)
    }

    static func percent(_ value: Int) -> String {
        String(format: String(localized: "%lld%%"), value)
    }

    static func progressPercent(_ value: Int) -> String {
        String(format: String(localized: "已处理 %lld%%"), value)
    }

    // MARK: - 今天

    static func phaseProgram(phase: String, program: String) -> String {
        String(format: String(localized: "%@ · %@"), phase, program)
    }

    static func weekProgress(done: Int, goal: Int) -> String {
        String(format: String(localized: "本周 %lld/%lld"), done, goal)
    }

    static func sessionIndex(_ index: Int) -> String {
        String(format: String(localized: "第 %lld 练"), index)
    }

    static func repRange(low: Int, high: Int) -> String {
        String(format: String(localized: "%lld–%lld 次"), low, high)
    }

    static func weakestMuscle(muscle: String, gap: String) -> String {
        String(format: String(localized: "最需要补：%@，还差 %@ 组"), muscle, gap)
    }

    // MARK: - 训练中

    static func repRangeWithRest(low: Int, high: Int, rest: Int) -> String {
        String(format: String(localized: "%lld–%lld 次 · 休息 %lld 秒"), low, high, rest)
    }

    static func suggestedLoad(_ kilograms: String) -> String {
        String(format: String(localized: "建议 %@ kg"), kilograms)
    }

    // MARK: - 记录

    static func sessionSummary(sets: Int, volume: String, phase: String) -> String {
        String(format: String(localized: "%lld 组 · %@ · %@"), sets, volume, phase)
    }

    // MARK: - 周报

    static func reportSubtitle(phase: String, goal: Int) -> String {
        String(format: String(localized: "每周目标 %lld 练 · %@"), goal, phase)
    }

    // MARK: - 阶段

    static func weekNumber(_ weeks: Int) -> String {
        String(format: String(localized: "第 %lld 周"), weeks)
    }

    // MARK: - 建档

    static func stepProgress(current: Int, total: Int) -> String {
        String(format: String(localized: "第 %lld / %lld 步"), current, total)
    }

    // MARK: - 计划包

    static func packMeta(weeks: Int, days: Int, coach: String) -> String {
        String(format: String(localized: "%lld 周 · %lld 个训练日 · %@"), weeks, days, coach)
    }

    static func unlockedCount(_ count: Int) -> String {
        String(format: String(localized: "%lld 个已解锁"), count)
    }

    // MARK: - 设置

    static func weeklyGoalValue(_ goal: Int) -> String {
        String(format: String(localized: "%lld 练"), goal)
    }

    static func templateOption(name: String, days: Int) -> String {
        String(format: String(localized: "%@ · %lld 天"), name, days)
    }

    static func backupNote(kept: Int) -> String {
        String(
            format: String(
                localized: "数据只保存在这台设备。每次完成训练会自动备份一份，最多保留 3 份（当前 %lld 份）。删 App 会同时删除数据，换机前请先导出。"
            ),
            kept
        )
    }

    // MARK: - 手表

    static func watchSetProgress(current: Int, total: Int) -> String {
        String(format: String(localized: "第 %lld/%lld 组"), current, total)
    }

    // MARK: - 小组件

    static func widgetProgress(done: Int, goal: Int) -> String {
        String(format: String(localized: "%lld/%lld"), done, goal)
    }

    static func widgetExercise(_ name: String) -> String {
        String(format: String(localized: "· %@"), name)
    }

    static func completedSets(_ count: Int) -> String {
        String(format: String(localized: "已完成 %lld 组"), count)
    }

    static func targetLoad(kilograms: String, reps: Int) -> String {
        String(format: String(localized: "目标 %@kg × %lld"), kilograms, reps)
    }

    static func liveSetLine(set: Int, total: Int, kilograms: String, reps: Int) -> String {
        String(format: String(localized: "第 %lld/%lld 组 · %@kg × %lld"), set, total, kilograms, reps)
    }
    // MARK: - 无障碍

    static func rpeLabel(_ value: String) -> String {
        String(format: String(localized: "RPE %@"), value)
    }

    static func volumeAccessibility(
        muscle: String,
        sets: String,
        low: String,
        high: String,
        status: String
    ) -> String {
        String(
            format: String(localized: "%@，每周 %@ 个有效组，目标 %@ 到 %@ 组，%@"),
            muscle, sets, low, high, status
        )
    }

    static func setAccessibility(warmup: Bool, index: Int, completed: Bool) -> String {
        switch (warmup, completed) {
        case (true, true):
            return String(localized: "热身组，已完成，点按取消")
        case (true, false):
            return String(localized: "热身组，点按标记完成")
        case (false, true):
            return String(format: String(localized: "第 %lld 组，已完成，点按取消"), index)
        case (false, false):
            return String(format: String(localized: "第 %lld 组，点按标记完成"), index)
        }
    }
    // MARK: - 营养

    static func bmrLine(bmr: String, tdee: String) -> String {
        String(format: String(localized: "BMR %@ · 维持 %@"), bmr, tdee)
    }

    static func proteinQualityNote(perKg: String, kcal: String) -> String {
        String(format: String(localized: "每公斤体重 %@g 蛋白 · 用 4/9/4 回算 %@ 千卡"), perKg, kcal)
    }

    static func proteinPerMealNote(_ grams: String) -> String {
        String(format: String(localized: "每餐约 %@g 蛋白"), grams)
    }

    static func proteinApprox(_ grams: String) -> String {
        String(format: String(localized: "≈ %@g 蛋白"), grams)
    }

    static func weeklyChangePart(_ percent: String) -> String {
        String(format: String(localized: "周变化 %@%%"), percent)
    }

    static func mealIndex(_ index: Int) -> String {
        String(format: String(localized: "第 %lld 餐"), index)
    }
}
