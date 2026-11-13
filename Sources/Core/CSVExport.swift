import Foundation
import SwiftData

/// 导出训练数据为 CSV。数据完全在设备上生成，不上传。
enum CSVExport {

    static func make(sessions: [TrainingSession]) -> String {
        var rows: [String] = ["日期,动作,组序,类型,重量kg,次数,RPE,完成"]

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime]

        for session in sessions.sorted(by: { $0.startedAt < $1.startedAt }) {
            let date = formatter.string(from: session.startedAt)
            for item in session.orderedExercises {
                let name = item.exercise?.name ?? ""
                for set in item.orderedSets {
                    let fields = [
                        date,
                        escape(name),
                        "\(set.order)",
                        set.setType.title,
                        Fmt.kg(set.weight),
                        "\(set.reps)",
                        set.rpe.map { Fmt.kg($0) } ?? "",
                        set.isCompleted ? "是" : "否"
                    ]
                    rows.append(fields.joined(separator: ","))
                }
            }
        }
        return rows.joined(separator: "\n")
    }

    private static func escape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") {
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return value
    }
}
