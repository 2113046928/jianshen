import Combine
import Foundation
import WatchConnectivity

/// 手表端的连接管理。
///
/// 刻意**不用** `@MainActor`：`WCSessionDelegate` 是 ObjC 协议，
/// 在 main-actor 隔离的类上实现容易出现隔离面不匹配、进而报
/// "does not conform to protocol 'WCSessionDelegate'"。
/// 这里让类保持非隔离，所有 UI 状态更新显式切回主线程，行为等价且更稳。
final class WatchSessionManager: NSObject, ObservableObject, WCSessionDelegate {

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
            apply { $0.hint = "手机不在身边，无法记录" }
            return
        }
        WCSession.default.sendMessage(
            ["action": "completeSet"],
            replyHandler: { [weak self] reply in
                let ok = reply["ok"] as? Bool == true
                self?.apply { $0.hint = ok ? "已记录" : "记录失败" }
            },
            errorHandler: { [weak self] error in
                let text = error.localizedDescription
                self?.apply { $0.hint = text }
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

    /// 统一切回主线程改发布属性
    private func apply(_ change: @escaping (WatchSessionManager) -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            change(self)
        }
    }

    // MARK: - WCSessionDelegate

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        let reachable = session.isReachable
        apply { $0.isReachable = reachable }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        apply { $0.isReachable = reachable }
    }

    func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        guard let data = applicationContext["state"] as? Data,
              let decoded = try? JSONDecoder().decode(WatchWorkoutState.self, from: data) else {
            return
        }
        apply {
            $0.state = decoded
            $0.hint = nil
        }
    }
}
