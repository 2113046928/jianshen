import Foundation

struct ProgramPackDayDTO: Codable {
    let id: String
    let name: String
    let focus: String
    let exerciseIDs: [String]
}

struct ProgramPackDTO: Codable {
    let id: String
    let name: String
    let coach: String
    let productID: String
    let priceHint: String
    let weeks: Int
    let summary: String
    let days: [ProgramPackDayDTO]
}

struct ProgramPack: Identifiable {
    let id: String
    let name: String
    let coach: String
    let productID: String
    let priceHint: String
    let weeks: Int
    let summary: String
    let template: ProgramTemplate
}

enum PackCatalog {

    static let bundled: [ProgramPack] = load()

    private static func load() -> [ProgramPack] {
        guard let url = Bundle.main.url(forResource: "ProgramPacks", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let items = try? JSONDecoder().decode([ProgramPackDTO].self, from: data) else {
            return []
        }
        return items.map { dto in
            let days = dto.days.map {
                ProgramDay(id: $0.id, name: $0.name, focus: $0.focus, exerciseIDs: $0.exerciseIDs)
            }
            let template = ProgramTemplate(
                id: dto.id,
                name: dto.name,
                subtitle: "\(dto.weeks) 周 · \(dto.coach)",
                days: days
            )
            return ProgramPack(
                id: dto.id,
                name: dto.name,
                coach: dto.coach,
                productID: dto.productID,
                priceHint: dto.priceHint,
                weeks: dto.weeks,
                summary: dto.summary,
                template: template
            )
        }
    }
}

/// 内置模板 + 已解锁的计划包，统一按 id 解析
enum ProgramCatalog {

    static func all(unlocked: [String]) -> [ProgramTemplate] {
        let packs = PackCatalog.bundled
            .filter { unlocked.contains($0.id) }
            .map(\.template)
        return ProgramTemplates.all + packs
    }

    static func template(id: String, unlocked: [String]) -> ProgramTemplate {
        all(unlocked: unlocked).first { $0.id == id } ?? ProgramTemplates.ppl
    }
}
