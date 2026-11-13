import Foundation

struct FoodItem: Codable, Equatable, Identifiable {
    let name: String
    let protein: Double
    let kcal: Double

    var id: String { name }

    /// 提供 grams 克时的蛋白质
    func protein(forGrams grams: Double) -> Double {
        protein * grams / 100
    }

    /// 要吃到 gap 克蛋白质需要多少克
    func grams(forProtein gap: Double) -> Double {
        guard protein > 0 else { return 0 }
        return gap / protein * 100
    }
}

private struct FoodFile: Codable {
    let version: Int
    let items: [FoodItem]
}

struct FoodSuggestion: Identifiable {
    let item: FoodItem
    let grams: Double

    var id: String { item.id }
}

/// 小规模参照表：不是食物数据库，只用来把「还差 60g 蛋白」换算成看得懂的分量。
enum FoodCatalog {

    static let items: [FoodItem] = load()

    private static func load() -> [FoodItem] {
        guard let url = Bundle.main.url(forResource: "FoodReference", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(FoodFile.self, from: data) else {
            return []
        }
        return file.items
    }

    /// 按蛋白密度挑出若干条，用于给出「吃多少克」的建议
    static func suggestions(forProtein gap: Double, limit: Int = 3) -> [FoodSuggestion] {
        guard gap > 0 else { return [] }
        let staples = ["鸡胸肉", "鸡蛋", "乳清蛋白粉", "希腊酸奶", "牛奶", "北豆腐"]
        return staples
            .compactMap { name in items.first { $0.name == name } }
            .prefix(limit)
            .map { FoodSuggestion(item: $0, grams: ($0.grams(forProtein: gap) / 10).rounded() * 10) }
    }
}
