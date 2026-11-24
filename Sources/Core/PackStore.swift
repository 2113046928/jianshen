import Combine
import Foundation
import StoreKit
import SwiftData

/// 计划包：每个包一个非消耗型商品，解锁状态存在本机。
@MainActor
final class PackStore: ObservableObject {
    static let shared = PackStore()

    @Published var products: [String: Product] = [:]
    @Published var purchasingID: String?
    @Published var message: String?

    let packs: [ProgramPack] = PackCatalog.bundled

    func loadProducts() async {
        let ids = packs.map(\.productID)
        guard !ids.isEmpty else { return }
        do {
            let result = try await Product.products(for: ids)
            products = result.reduce(into: [String: Product]()) { $0[$1.id] = $1 }
        } catch {
            message = "商品加载失败：\(error.localizedDescription)"
        }
    }

    func price(for pack: ProgramPack) -> String {
        products[pack.productID]?.displayPrice ?? pack.priceHint
    }

    func purchase(
        _ pack: ProgramPack,
        profile: UserProfile?,
        context: ModelContext
    ) async {
        guard let product = products[pack.productID] else {
            message = "商品尚未在 App Store Connect 配置，暂时无法购买。"
            return
        }
        purchasingID = pack.id
        defer { purchasingID = nil }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    unlock(pack, profile: profile, context: context)
                    await transaction.finish()
                    message = "已解锁《\(pack.name)》，已设为当前计划。"
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

    func unlock(_ pack: ProgramPack, profile: UserProfile?, context: ModelContext) {
        guard let profile else { return }
        if !profile.unlockedProgramIDs.contains(pack.id) {
            profile.unlockedProgramIDs.append(pack.id)
        }
        profile.activeProgramID = pack.id
        try? context.save()
    }

    func activate(_ pack: ProgramPack, profile: UserProfile?, context: ModelContext) {
        profile?.activeProgramID = pack.id
        try? context.save()
    }

    func restore(profile: UserProfile?, context: ModelContext) async {
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  transaction.revocationDate == nil,
                  let pack = packs.first(where: { $0.productID == transaction.productID }) else {
                continue
            }
            if !(profile?.unlockedProgramIDs.contains(pack.id) ?? true) {
                profile?.unlockedProgramIDs.append(pack.id)
            }
        }
        try? context.save()
        message = "已恢复购买。"
    }
}
