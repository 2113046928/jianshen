import Combine
import Foundation
import StoreKit

/// Pro 权益状态：全 App 唯一来源，持久化在 UserDefaults，启动时按 StoreKit 校准。
///
/// DEBUG 构建默认解锁，方便开发与截图；Release 才会真正拦。
@MainActor
final class ProEntitlement: ObservableObject {
    static let shared = ProEntitlement()

    static let productID = "com.trainledger.app.pro.lifetime"
    private static let storageKey = "pro.entitlement.unlocked"

    @Published private(set) var isPro: Bool

    private let defaults: UserDefaults

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        #if DEBUG
        self.isPro = true
        #else
        self.isPro = defaults.bool(forKey: Self.storageKey)
        #endif
    }

    /// 购买或恢复成功后调用
    func unlock() {
        isPro = true
        defaults.set(true, forKey: Self.storageKey)
    }

    /// 退款、撤销或换账号后调用。DEBUG 下忽略，避免开发机没有商品时被锁住。
    func revoke() {
        #if DEBUG
        return
        #else
        isPro = false
        defaults.set(false, forKey: Self.storageKey)
        #endif
    }

    /// 启动时按当前有效交易校准一次；DEBUG 不覆盖本地开关
    func refreshFromStore() async {
        #if DEBUG
        return
        #else
        var entitled = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  transaction.productID == Self.productID,
                  transaction.revocationDate == nil else { continue }
            entitled = true
        }
        entitled ? unlock() : revoke()
        #endif
    }
}
