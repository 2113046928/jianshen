import ActivityKit
import Foundation

/// 训练中的实时活动。App 与 Widget 扩展共用这一份定义。
struct WorkoutActivityAttributes: ActivityAttributes {

    struct ContentState: Codable, Hashable {
        /// 当前动作名
        var exerciseName: String
        /// 第几组（从 1 开始）
        var setNumber: Int
        /// 该动作总组数
        var totalSets: Int
        /// 本次建议重量
        var weight: Double
        /// 目标次数
        var reps: Int
        /// 整场训练已完成组数
        var completedSets: Int
        /// 休息结束时间；nil 表示不在休息
        var restEndsAt: Date?
    }

    var sessionID: String
    var startedAt: Date
}
