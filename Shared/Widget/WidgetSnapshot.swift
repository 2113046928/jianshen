import Foundation

/// 桌面小组件需要的快照。小组件进程不打开 SwiftData，只读这份由 App 写入的小数据。
struct WidgetSnapshot: Codable, Equatable {
    var dayName: String
    var focus: String
    var exerciseNames: [String]
    var weekCompleted: Int
    var weeklyGoal: Int
    var updatedAt: Date

    static let placeholder = WidgetSnapshot(
        dayName: "推日",
        focus: "胸 · 肩 · 三头",
        exerciseNames: ["杠铃卧推", "上斜哑铃卧推", "站姿杠铃推举"],
        weekCompleted: 2,
        weeklyGoal: 4,
        updatedAt: .now
    )
}

enum WidgetStore {
    static let appGroup = "group.com.trainledger.shared"
    static let key = "home.plan.snapshot"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroup) ?? .standard
    }

    static func save(_ snapshot: WidgetSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: key)
    }

    static func load() -> WidgetSnapshot? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }
}
