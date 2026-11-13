import Combine
import Foundation
import WatchConnectivity

@MainActor
final class WatchSessionManager: NSObject, ObservableObject {
    @Published var state: WatchWorkoutState = .idle
    @Published var hint: String?
    @Published var isReachable = false

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func completeSet() {
        guard WCSession.default.activationState == .activated,
              WCSession.default.isReachable else {
            hint = "手机不在身边，无法记录"
            return
        }
        WCSession.default.sendMessage(
            ["action": "completeSet"],
            replyHandler: { [weak self] reply in
                Task { @MainActor in
                    self?.hint = (reply["ok"] as? Bool == true) ? "已记录" : "记录失败"
                }
            },
            errorHandler: { [weak self] error in
                Task { @MainActor in
                    self?.hint = error.localizedDescription
                }
            }
        )
    }

    func adjust(weight delta: Double) {
        let next = max(0, state.weight + delta)
        state.weight = (next * 2).rounded() / 2
    }

    func adjust(reps delta: Int) {
        state.reps = max(0, state.reps + delta)
    }

    /// 手表上改的数字只影响本组显示，真正写入以手机为准
    func resetToPhone() {
        hint = nil
    }
}

extension WatchSessionManager: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        let reachable = session.isReachable
        Task { @MainActor in
            self.isReachable = reachable
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        Task { @MainActor in
            self.isReachable = reachable
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        guard let data = applicationContext["state"] as? Data,
              let decoded = try? JSONDecoder().decode(WatchWorkoutState.self, from: data) else {
            return
        }
        Task { @MainActor in
            self.state = decoded
            self.hint = nil
        }
    }
}
