import Combine
import Foundation
import HealthKit

/// 只读「健康」里的体重与体脂，用来补齐减脂期的称重数据。
/// 不写回、不上传；用户不授权也能正常使用全部记录功能。
@MainActor
final class HealthService: ObservableObject {
    static let shared = HealthService()

    @Published var isAuthorized = false
    @Published var lastError: String?
    @Published var isWorking = false

    private let store = HKHealthStore()

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private var readTypes: Set<HKObjectType> {
        var types = Set<HKObjectType>()
        if let mass = HKObjectType.quantityType(forIdentifier: .bodyMass) {
            types.insert(mass)
        }
        if let fat = HKObjectType.quantityType(forIdentifier: .bodyFatPercentage) {
            types.insert(fat)
        }
        return types
    }

    func requestAuthorization() async {
        guard isAvailable else {
            lastError = "此设备不支持健康数据"
            return
        }
        isWorking = true
        defer { isWorking = false }
        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            isAuthorized = true
            lastError = nil
        } catch {
            lastError = friendly(error)
        }
    }

    /// 未签名/精简构建里没有 HealthKit 权限，系统给的原话很难懂，这里翻成人话。
    private func friendly(_ error: Error) -> String {
        let text = error.localizedDescription
        if text.lowercased().contains("entitlement") {
            return "这个安装包没有 HealthKit 权限（重新签名打包后可用）。健康同步先跳过，其他功能不受影响。"
        }
        return text
    }

    /// 最近一条体重（kg）
    func latestBodyMass() async -> Double? {
        guard isAvailable,
              let type = HKObjectType.quantityType(forIdentifier: .bodyMass) else { return nil }
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sort]
            ) { _, samples, _ in
                let sample = samples?.first as? HKQuantitySample
                let value = sample?.quantity.doubleValue(for: .gramUnit(with: .kilo))
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }

    /// 最近一条体脂率（0–1）
    func latestBodyFat() async -> Double? {
        guard isAvailable,
              let type = HKObjectType.quantityType(forIdentifier: .bodyFatPercentage) else { return nil }
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sort]
            ) { _, samples, _ in
                let sample = samples?.first as? HKQuantitySample
                let value = sample?.quantity.doubleValue(for: .percent())
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }
}
