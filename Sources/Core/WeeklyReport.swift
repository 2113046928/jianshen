import Foundation

struct ReportSet {
    var exerciseID: String
    var weight: Double
    var reps: Int
    var setType: SetType
    var primary: [MuscleGroup]
    var secondary: [MuscleGroup]
}

struct ReportSession {
    var date: Date
    var sets: [ReportSet]
}

struct WeeklyReport: Equatable {
    var sessionCount: Int
    var totalSets: Int
    var totalVolume: Double
    var prCount: Int
    var volumes: [MuscleVolume]
    var adherence: Double

    var adherencePercent: Int { Int((adherence * 100).rounded()) }

    static let empty = WeeklyReport(
        sessionCount: 0,
        totalSets: 0,
        totalVolume: 0,
        prCount: 0,
        volumes: VolumeAnalyzer.analyze(sets: []),
        adherence: 0
    )
}

enum WeeklyReportBuilder {

    static func build(
        sessions: [ReportSession],
        plannedSessions: Int,
        history: [ReportSession] = []
    ) -> WeeklyReport {
        let ordered = sessions.sorted { $0.date < $1.date }

        var totalSets = 0
        var totalVolume = 0.0
        var prCount = 0
        var logged: [LoggedSet] = []

        // PR 基准是「本次训练之前」的最佳成绩，同一次训练内不重复计 PR
        var bestEstimate: [String: Double] = [:]

        // 用窗口之前的训练打底，保证 PR 判定跟长期历史一致
        for session in history.sorted(by: { $0.date < $1.date }) {
            for set in session.sets where set.setType != .warmup {
                let estimate = StrengthEstimate.oneRepMax(weight: set.weight, reps: set.reps)
                bestEstimate[set.exerciseID] = max(bestEstimate[set.exerciseID] ?? 0, estimate)
            }
        }

        for session in ordered {
            let baseline = bestEstimate
            var sessionBest: [String: Double] = [:]
            // 同一动作在同一次训练里只记一次 PR，避免「3 组都破纪录」被算成 3 个
            var prFlagged: Set<String> = []

            for set in session.sets where set.setType != .warmup {
                totalSets += 1
                totalVolume += set.weight * Double(set.reps)
                logged.append(
                    LoggedSet(
                        exerciseID: set.exerciseID,
                        primary: set.primary,
                        secondary: set.secondary,
                        weight: set.weight,
                        reps: set.reps,
                        setType: set.setType
                    )
                )

                let estimate = StrengthEstimate.oneRepMax(weight: set.weight, reps: set.reps)
                if let previous = baseline[set.exerciseID],
                   set.setType == .normal,
                   estimate > previous,
                   !prFlagged.contains(set.exerciseID) {
                    prCount += 1
                    prFlagged.insert(set.exerciseID)
                }
                sessionBest[set.exerciseID] = max(sessionBest[set.exerciseID] ?? 0, estimate)
            }

            for (exerciseID, estimate) in sessionBest {
                bestEstimate[exerciseID] = max(bestEstimate[exerciseID] ?? 0, estimate)
            }
        }

        let adherence: Double
        if plannedSessions > 0 {
            adherence = min(Double(ordered.count) / Double(plannedSessions), 1)
        } else {
            adherence = 0
        }

        return WeeklyReport(
            sessionCount: ordered.count,
            totalSets: totalSets,
            totalVolume: totalVolume,
            prCount: prCount,
            volumes: VolumeAnalyzer.analyze(sets: logged),
            adherence: adherence
        )
    }
}
