import ActivityKit
import Foundation

/// 训练中的锁屏 / 灵动岛实时活动。只在用户开始训练后存在，结束即清除。
@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()

    private var activity: Activity<WorkoutActivityAttributes>?

    var isSupported: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    func start(sessionID: String, state: WorkoutActivityAttributes.ContentState) {
        guard isSupported, activity == nil else { return }
        let attributes = WorkoutActivityAttributes(sessionID: sessionID, startedAt: .now)
        activity = try? Activity.request(
            attributes: attributes,
            content: ActivityContent(state: state, staleDate: nil)
        )
    }

    func update(_ state: WorkoutActivityAttributes.ContentState) {
        guard let activity else { return }
        Task {
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
    }

    func end() {
        guard let activity else { return }
        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        self.activity = nil
    }
}
