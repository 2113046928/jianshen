import Foundation
import SwiftData

/// 生成「今天练什么」以及每次训练的初始结构
enum WorkoutFactory {

    /// 按已完成训练次数轮转训练日
    static func nextDay(program: ProgramTemplate, finishedSessionCount: Int) -> ProgramDay {
        guard !program.days.isEmpty else {
            return ProgramDay(id: "empty", name: "自由训练", focus: "", exerciseIDs: [])
        }
        let index = finishedSessionCount % program.days.count
        return program.days[index]
    }

    static func prescription(
        for exercise: Exercise,
        sessions: [TrainingSession]
    ) -> Prescription {
        let history = HistoryMapping.history(for: exercise.id, in: sessions)
        return LoadPrescription.next(
            history: history,
            increment: exercise.loadIncrement,
            target: exercise.targetReps
        )
    }

    /// 创建一次训练并预填动作与组
    @discardableResult
    static func makeSession(
        day: ProgramDay,
        phase: Phase,
        exercises: [Exercise],
        sessions: [TrainingSession],
        weeklyGoal: Int = 3,
        context: ModelContext
    ) -> TrainingSession {
        let finished = sessions.filter { $0.isFinished }.count
        let perWeek = max(weeklyGoal, 1)
        let isDeload = Periodization.isDeloadWeek(finishedSessions: finished, sessionsPerWeek: perWeek)
        let blockWeek = Periodization.blockWeek(finishedSessions: finished, sessionsPerWeek: perWeek)

        // 近 7 天的容量缺口：不足就加组，过量就减组；减载周不叠加
        let weekStart = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        let recentSets = HistoryMapping.loggedSets(from: sessions, since: weekStart)
        let adjustments = isDeload
            ? []
            : VolumeProgression.adjustments(volumes: VolumeAnalyzer.analyze(sets: recentSets))

        let session = TrainingSession(
            startedAt: .now,
            phase: phase,
            note: isDeload ? "减载周" : (blockWeek == 4 ? "峰值周" : "")
        )
        context.insert(session)

        var order = 0
        for exerciseID in day.exerciseIDs {
            guard let exercise = exercises.first(where: { $0.id == exerciseID }) else { continue }
            let prescription = prescription(for: exercise, sessions: sessions)
            // 预填上一次的组数据：让用户只需要改数字，而不是从零输入
            let lastSets = HistoryMapping.lastWorkingSets(for: exercise.id, in: sessions)
            let prefillWeight = prescription.weight ?? lastSets.last?.weight ?? 0
            let prefillReps = lastSets.last?.reps ?? exercise.targetReps.lowerBound

            let item = SessionExercise(
                order: order,
                exercise: exercise,
                targetReps: exercise.targetReps,
                suggestedWeight: prescription.weight,
                restSeconds: exercise.defaultRestSeconds
            )
            context.insert(item)
            item.session = session
            order += 1

            // 复合动作自动加一组热身，重量取建议重量的一半
            if exercise.isCompound, let base = prescription.weight, base > 0 {
                let warmup = WorkoutSet(
                    order: 0,
                    weight: LoadPrescription.roundHalf(base * 0.5),
                    reps: 8,
                    rpe: nil,
                    setType: .warmup,
                    isCompleted: false
                )
                context.insert(warmup)
                warmup.sessionExercise = item
            }

            var setCount = Periodization.sets(forBlockWeek: blockWeek)
            if !isDeload {
                setCount += VolumeProgression.extraSets(for: exercise, adjustments: adjustments)
                setCount -= VolumeProgression.reducedSets(for: exercise, adjustments: adjustments)
            }
            setCount = max(2, min(setCount, 5))

            for index in 0..<setCount {
                let working = WorkoutSet(
                    order: index + 1,
                    weight: isDeload ? (lastSets.map(\.weight).max() ?? prefillWeight) : prefillWeight,
                    reps: prefillReps,
                    rpe: nil,
                    setType: .normal,
                    isCompleted: false
                )
                context.insert(working)
                working.sessionExercise = item
            }
        }

        try? context.save()
        return session
    }

    /// 未完成的训练（用于「继续上次训练」）
    static func activeSession(in sessions: [TrainingSession]) -> TrainingSession? {
        sessions
            .filter { !$0.isFinished }
            .sorted { $0.startedAt > $1.startedAt }
            .first
    }
}
