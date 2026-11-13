import Foundation
import SwiftData

/// 把 SwiftData 模型转成算法需要的值类型。集中放在这里，保证 Core/ 下的算法不依赖持久化层。
enum HistoryMapping {

    static func snapshot(of set: WorkoutSet) -> SetSnapshot {
        SetSnapshot(weight: set.weight, reps: set.reps, rpe: set.rpe, setType: set.setType)
    }

    /// 某个动作的历史（只包含已完成、非热身的组），按时间升序，取最近 limit 次
    static func history(
        for exerciseID: String,
        in sessions: [TrainingSession],
        limit: Int = 8
    ) -> [SessionSnapshot] {
        let relevant = sessions
            .filter { $0.isFinished }
            .sorted { $0.startedAt < $1.startedAt }
            .compactMap { session -> SessionSnapshot? in
                let sets = session.orderedExercises
                    .filter { $0.exercise?.id == exerciseID }
                    .flatMap { $0.orderedSets }
                    .filter { $0.isCompleted }
                    .map(snapshot(of:))
                guard !sets.isEmpty else { return nil }
                return SessionSnapshot(date: session.startedAt, sets: sets)
            }
        return Array(relevant.suffix(limit))
    }

    /// 最近一次训练里该动作的正式组
    static func lastWorkingSets(for exerciseID: String, in sessions: [TrainingSession]) -> [SetSnapshot] {
        history(for: exerciseID, in: sessions, limit: 1)
            .last?
            .sets
            .filter { $0.setType != .warmup } ?? []
    }

    /// 指定时间范围内的已完成组（用于容量判断）
    static func loggedSets(from sessions: [TrainingSession], since date: Date) -> [LoggedSet] {
        sessions
            .filter { $0.isFinished && $0.startedAt >= date }
            .flatMap { session in
                session.orderedExercises.flatMap { item -> [LoggedSet] in
                    guard let exercise = item.exercise else { return [] }
                    return item.orderedSets
                        .filter { $0.isCompleted }
                        .map { set in
                            LoggedSet(
                                exerciseID: exercise.id,
                                primary: exercise.primaryMuscles,
                                secondary: exercise.secondaryMuscles,
                                weight: set.weight,
                                reps: set.reps,
                                setType: set.setType
                            )
                        }
                }
            }
    }

    /// 单次训练转成周报输入
    static func reportSession(_ session: TrainingSession) -> ReportSession {
        let sets: [ReportSet] = session.orderedExercises.flatMap { item -> [ReportSet] in
            guard let exercise = item.exercise else { return [] }
            return item.orderedSets
                .filter(\.isCompleted)
                .map { set in
                    ReportSet(
                        exerciseID: exercise.id,
                        weight: set.weight,
                        reps: set.reps,
                        setType: set.setType,
                        primary: exercise.primaryMuscles,
                        secondary: exercise.secondaryMuscles
                    )
                }
        }
        return ReportSession(date: session.startedAt, sets: sets)
    }

    /// 指定时间范围内的训练，转成周报输入
    static func reportSessions(
        from sessions: [TrainingSession],
        since date: Date
    ) -> [ReportSession] {
        sessions
            .filter { $0.isFinished && $0.startedAt >= date }
            .sorted { $0.startedAt < $1.startedAt }
            .map(reportSession)
    }
}
