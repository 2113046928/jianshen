import Combine
import Foundation
import StoreKit

/// 本地买断。StoreKit 2 的交易签名可在设备上离线验证，不需要自建服务器。
@MainActor
final class PurchaseService: ObservableObject {
    static let productID = "com.trainledger.app.pro.lifetime"

    @Published var product: Product?
    @Published var isPurchased = false
    @Published var message: String?
    @Published var isLoading = false

    var priceText: String {
        guard let product else { return "¥68" }
        return product.displayPrice
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let products = try await Product.products(for: [Self.productID])
            product = products.first
            if product == nil {
                message = "商品尚未在 App Store Connect 配置，当前为演示状态。"
            }
        } catch {
            message = "商品加载失败：\(error.localizedDescription)"
        }
        await refreshEntitlement()
    }

    func purchase() async {
        guard let product else {
            message = "商品尚未配置，无法购买。"
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    isPurchased = true
                    message = "已解锁 Pro。"
                    await transaction.finish()
                case .unverified:
                    message = "交易校验失败，请稍后重试。"
                }
            case .userCancelled:
                break
            case .pending:
                message = "购买等待确认。"
            @unknown default:
                break
            }
        } catch {
            message = "购买失败：\(error.localizedDescription)"
        }
    }

    func refreshEntitlement() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.productID,
               transaction.revocationDate == nil {
                isPurchased = true
            }
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
            await refreshEntitlement()
            message = isPurchased ? "已恢复购买。" : "没有找到可恢复的购买。"
        } catch {
            message = "恢复失败：\(error.localizedDescription)"
        }
    }
}
