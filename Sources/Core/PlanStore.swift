import Foundation
import SwiftData

/// 自定义训练计划的读写。
///
/// 计划是值类型（`ProgramTemplate`），序列化成 JSON 存在 UserDefaults。
/// 刻意**不**放进 SwiftData 模型：那样每次加字段都要迁移，一旦迁移失败，
/// 整个库打不开、数据全掉——代价远大于收益。
enum PlanStore {

    /// 自定义计划的固定 id
    static let customID = "custom"

    private static let storageKey = "trainledger.customPlan.v1"

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
        if profile?.activeProgramID == customID,
           let custom = decode(rawJSON) {
            return custom
        }
        return ProgramCatalog.template(
            id: profile?.activeProgramID ?? "ppl",
            unlocked: profile?.unlockedProgramIDs ?? []
        )
    }

    static func customTemplate(for profile: UserProfile?) -> ProgramTemplate? {
        decode(rawJSON)
    }

    static var rawJSON: String? {
        UserDefaults.standard.string(forKey: storageKey)
    }

    // MARK: - 写入

    /// 保存自定义计划并立刻切过去
    static func save(_ template: ProgramTemplate, profile: UserProfile?, context: ModelContext) {
        UserDefaults.standard.set(encode(template), forKey: storageKey)
        guard let profile else { return }
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

/// 排课规则：只要有一天设了星期，就按星期排；否则沿用「按完成次数轮转」。
enum PlanSchedule {

    /// 与 Calendar.weekday 对齐：1 = 周日 … 7 = 周六
    private static let names = ["日", "一", "二", "三", "四", "五", "六"]

    static func name(for weekday: Int) -> String {
        let index = min(max(weekday - 1, 0), names.count - 1)
        return "周" + names[index]
    }

    static func usesWeekdays(_ program: ProgramTemplate) -> Bool {
        program.days.contains { $0.weekday != nil }
    }

    /// 今天该练哪一天。返回 nil = 今天休息。
    static func day(
        for program: ProgramTemplate,
        finishedSessions: Int,
        on date: Date = .now,
        calendar: Calendar = .current
    ) -> ProgramDay? {
        if usesWeekdays(program) {
            let weekday = calendar.component(.weekday, from: date)
            return program.days.first { $0.weekday == weekday }
        }
        guard !program.days.isEmpty else { return nil }
        let index = max(0, finishedSessions) % program.days.count
        return program.days[index]
    }
}
