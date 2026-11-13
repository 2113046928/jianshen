import Combine
import Foundation
import WatchConnectivity

/// 手机侧的手表桥接：把手上的「完成本组」回传到当前训练。
@MainActor
final class WatchBridge: NSObject, ObservableObject {
    static let shared = WatchBridge()

    /// 手表点了「完成本组」
    var onCompleteSet: (() -> Void)?

    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    var isReachable: Bool {
        WCSession.isSupported() && WCSession.default.isReachable
    }

    /// 把当前训练状态推给手表（手表未安装/未配对时静默失败）
    func push(_ state: WatchWorkoutState) {
        guard WCSession.isSupported(),
              WCSession.default.activationState == .activated,
              let data = try? JSONEncoder().encode(state) else { return }
        try? WCSession.default.updateApplicationContext(["state": data])
    }
}

extension WatchBridge: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        guard message["action"] as? String == "completeSet" else {
            replyHandler(["ok": false])
            return
        }
        Task { @MainActor in
            self.onCompleteSet?()
        }
        replyHandler(["ok": true])
    }
}
