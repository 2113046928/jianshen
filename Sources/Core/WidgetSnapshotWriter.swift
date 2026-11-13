import Foundation
import WidgetKit

/// 把「今天练什么」写进 App Group，供桌面小组件读取。
/// 小组件不打开 SwiftData：扩展进程只读这一份小快照，启动更快、也不会和主库抢锁。
@MainActor
enum WidgetSnapshotWriter {

    static func update(
        dayName: String,
        focus: String,
        exerciseNames: [String],
        weekCompleted: Int,
        weeklyGoal: Int
    ) {
        let snapshot = WidgetSnapshot(
            dayName: dayName,
            focus: focus,
            exerciseNames: exerciseNames,
            weekCompleted: weekCompleted,
            weeklyGoal: weeklyGoal,
            updatedAt: .now
        )
        WidgetStore.save(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
