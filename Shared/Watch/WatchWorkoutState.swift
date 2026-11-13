import Foundation

/// 手机与手表之间同步的最小状态。App 与 Watch App 共用。
struct WatchWorkoutState: Codable, Equatable {
    var exerciseName: String
    var setNumber: Int
    var totalSets: Int
    var weight: Double
    var reps: Int
    var isActive: Bool

    static let idle = WatchWorkoutState(
        exerciseName: "在手机上开始训练",
        setNumber: 1,
        totalSets: 3,
        weight: 0,
        reps: 0,
        isActive: false
    )
}
