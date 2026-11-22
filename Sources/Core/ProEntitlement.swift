import Combine
import Foundation
import StoreKit

/// 功能开关：全 App 唯一来源。
///
/// 当前版本**全部功能免费**，`isPro` 恒为 true，不做任何拦截。
/// 保留这层抽象是为了以后要重新加付费时，只需要改这里和 `unlock/revoke` 的实现，
/// 不用回头改各个页面。
@MainActor
final class ProEntitlement: ObservableObject {
    static let shared = ProEntitlement()

    static let productID = "com.trainledger.app.pro.lifetime"

    /// 恒为 true：本版本不限制任何功能。
    @Published private(set) var isPro: Bool = true

    private init() {}

    /// 保留接口：购买成功后调用（当前无效果）。
    func unlock() {
        isPro = true
    }

    /// 保留接口：退款/撤销时调用。本版本不做锁定，所以是空实现。
    func revoke() {}

    /// 保留接口：启动时按 StoreKit 校准。本版本不需要，直接返回。
    func refreshFromStore() async {}
}
