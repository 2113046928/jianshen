import Foundation
import SwiftData

struct SeedExercise: Codable {
    let id: String
    let name: String
    let aliases: [String]?
    let pattern: String
    let primary: [String]
    let secondary: [String]?
    let equipment: String
    let isCompound: Bool
    let loadIncrement: Double
    let repsLow: Int
    let repsHigh: Int
    let restSeconds: Int?
}

enum SeedError: Error {
    case missingResource
}

/// 首次启动时把内置动作库写入 SwiftData；已有数据则跳过（幂等）
enum SeedLoader {

    @discardableResult
    static func seedIfNeeded(context: ModelContext) -> Int {
        let count = (try? context.fetchCount(FetchDescriptor<Exercise>())) ?? 0
        guard count == 0 else { return 0 }
        do {
            return try seed(context: context)
        } catch {
            assertionFailure("动作库导入失败：\(error)")
            return 0
        }
    }

    @discardableResult
    static func seed(context: ModelContext) throws -> Int {
        guard let url = Bundle.main.url(forResource: "Exercises", withExtension: "json") else {
            throw SeedError.missingResource
        }
        let data = try Data(contentsOf: url)
        let items = try JSONDecoder().decode([SeedExercise].self, from: data)

        for (index, item) in items.enumerated() {
            let exercise = Exercise(
                id: item.id,
                name: item.name,
                aliases: item.aliases ?? [],
                pattern: MovementPattern(rawValue: item.pattern) ?? .horizontalPush,
                primary: item.primary.compactMap { MuscleGroup(rawValue: $0) },
                secondary: (item.secondary ?? []).compactMap { MuscleGroup(rawValue: $0) },
                equipment: Equipment(rawValue: item.equipment) ?? .barbell,
                isCompound: item.isCompound,
                loadIncrement: item.loadIncrement,
                targetReps: item.repsLow...max(item.repsLow, item.repsHigh),
                defaultRestSeconds: item.restSeconds ?? 120,
                sortIndex: index
            )
            context.insert(exercise)
        }
        try context.save()
        return items.count
    }

    /// 保证存在一条用户设置记录
    static func ensureProfile(context: ModelContext) -> UserProfile {
        if let profiles = try? context.fetch(FetchDescriptor<UserProfile>()),
           let existing = profiles.first {
            return existing
        }
        let profile = UserProfile()
        context.insert(profile)
        try? context.save()
        return profile
    }
}
