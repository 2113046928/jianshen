import Foundation

/// 中周期：4 周渐进 + 1 周减载。减载周组数降到 2 组、不加重，让恢复追上训练。
enum Periodization {
    static let weeksPerBlock = 5

    static func weekIndex(finishedSessions: Int, sessionsPerWeek: Int) -> Int {
        max(0, finishedSessions) / max(sessionsPerWeek, 1)
    }

    static func blockWeek(finishedSessions: Int, sessionsPerWeek: Int) -> Int {
        weekIndex(finishedSessions: finishedSessions, sessionsPerWeek: sessionsPerWeek) % weeksPerBlock + 1
    }

    /// 中周期内每周的组数波峰：渐进 → 峰值 → 减载
    static func sets(forBlockWeek week: Int) -> Int {
        let wave = [3, 3, 4, 3, 2]
        let index = min(max(week - 1, 0), wave.count - 1)
        return wave[index]
    }

    static func isPeakWeek(finishedSessions: Int, sessionsPerWeek: Int) -> Bool {
        blockWeek(finishedSessions: finishedSessions, sessionsPerWeek: sessionsPerWeek) == 4
    }

    static func isDeloadWeek(finishedSessions: Int, sessionsPerWeek: Int) -> Bool {
        weekIndex(finishedSessions: finishedSessions, sessionsPerWeek: sessionsPerWeek) % weeksPerBlock
            == weeksPerBlock - 1
    }
}
