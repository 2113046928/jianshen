import Foundation
import SwiftData

/// 自定义训练计划的读写。
///
/// 计划本身是值类型（`ProgramTemplate`），序列化后存在 `UserProfile.customPlanJSON`，
/// 不新增实体，避免 SwiftData 迁移风险。
enum PlanStore {

    /// 自定义计划的固定 id
    static let customID = "custom"

    // MARK: - 编解码

    static func decode(_ json: String?) -> ProgramTemplate? {
        guard let json, let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(ProgramTemplate.self, from: data)
    }

    static func encode(_ template: ProgramTemplate) -> String? {
        guard let data = try? JSONEncoder().encode(template) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - 读取

    /// 当前生效的计划：自定义优先，其次解锁的预设，最后回落到推拉腿
    static func template(for profile: UserProfile?) -> ProgramTemplate {
        if let profile,
           profile.activeProgramID == customID,
           let custom = decode(profile.customPlanJSON) {
            return custom
        }
        return ProgramCatalog.template(
            id: profile?.activeProgramID ?? "ppl",
            unlocked: profile?.unlockedProgramIDs ?? []
        )
    }

    static func customTemplate(for profile: UserProfile?) -> ProgramTemplate? {
        decode(profile?.customPlanJSON)
    }

    // MARK: - 写入

    /// 保存自定义计划并立刻切过去
    static func save(_ template: ProgramTemplate, profile: UserProfile?, context: ModelContext) {
        guard let profile else { return }
        profile.customPlanJSON = encode(template)
        profile.activeProgramID = customID
        try? context.save()
    }

    /// 以某个预设为底稿，复制出一份可编辑的自定义计划（不改原件）
    static func makeDraft(from template: ProgramTemplate) -> ProgramTemplate {
        ProgramTemplate(
            id: customID,
            name: template.name,
            subtitle: subtitle(dayCount: template.days.count),
            days: template.days
        )
    }

    static func subtitle(dayCount: Int) -> String {
        "自定义 · \(dayCount) 天"
    }

    /// 新建空训练日
    static func blankDay(index: Int) -> ProgramDay {
        ProgramDay(
            id: "custom-\(UUID().uuidString.prefix(8))",
            name: "第 \(index) 天",
            focus: "",
            exerciseIDs: []
        )
    }

    /// 统一在编辑时刷新副标题
    static func normalized(_ template: ProgramTemplate) -> ProgramTemplate {
        ProgramTemplate(
            id: template.id,
            name: template.name,
            subtitle: subtitle(dayCount: template.days.count),
            days: template.days
        )
    }
}
