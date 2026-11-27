import Foundation

/// 每种动作模式的四句话要领（本地 JSON）。
struct ExerciseGuide: Decodable, Equatable {
    let setup: String
    let execution: String
    let mistake: String
    let breathing: String
}

enum ExerciseGuideStore {

    static let bundled: [String: ExerciseGuide] = load()

    private static func load() -> [String: ExerciseGuide] {
        guard let url = Bundle.main.url(forResource: "ExerciseGuides", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: ExerciseGuide].self, from: data) else {
            return [:]
        }
        return decoded
    }

    static func guide(for pattern: MovementPattern) -> ExerciseGuide? {
        bundled[pattern.rawValue]
    }

    /// 示意图资源名，与 Assets.xcassets/Exercise 中一致
    static func imageName(for pattern: MovementPattern) -> String {
        "exercise-\(pattern.rawValue)"
    }
}
