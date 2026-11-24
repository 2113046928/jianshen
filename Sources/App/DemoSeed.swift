import Foundation
import SwiftData

/// 演示数据：只在启动参数含 `-demoData` 时写入，用于截图与审核演示。
/// 正常启动路径完全不经过这里，不会污染真实数据。
enum DemoSeed {

    static var isRequested: Bool {
        ProcessInfo.processInfo.arguments.contains("-demoData")
    }

    /// 截图脚本用它决定打开哪个界面
    static var requestedScreen: String? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-screen"), index + 1 < args.count else {
            return nil
        }
        return args[index + 1]
    }

    static var shouldAutoStartWorkout: Bool {
        requestedScreen == "workout"
    }

    @MainActor
    static func seed(context: ModelContext) {
        clear(context: context)
        SeedLoader.seedIfNeeded(context: context)

        let exercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        let lookup = exercises.reduce(into: [String: Exercise]()) { $0[$1.id] = $1 }
        guard !lookup.isEmpty else { return }

        let profile = SeedLoader.ensureProfile(context: context)
        profile.bodyweight = 72.5
        profile.phase = .cut
        profile.weeklyGoal = 4
        profile.activeProgramID = "ppl"
        profile.phaseStartedAt = Calendar.current.date(byAdding: .day, value: -28, to: .now)
        profile.didOnboard = true
        profile.unlockedProgramIDs = ["cut-keep-strength", "home-20min"]

        var random = LinearCongruentialGenerator(seed: 20261113)
        let program = ProgramTemplates.ppl
        let calendar = Calendar.current

        // 最近 4 周，每周 3 练，重量按小幅渐进递增
        var baseWeights: [String: Double] = [
            "barbell-bench-press": 72.5,
            "back-squat": 95,
            "deadlift": 120,
            "overhead-press": 42.5,
            "barbell-row": 65,
            "lat-pulldown": 55,
            "leg-press": 120
        ]

        for week in stride(from: 4, through: 1, by: -1) {
            for (dayIndex, day) in program.days.enumerated() {
                let offset = -(week * 7) + dayIndex * 2 + 1
                guard let date = calendar.date(byAdding: .day, value: offset, to: .now),
                      date < .now else { continue }

                let session = TrainingSession(startedAt: date, phase: .cut, note: week == 1 ? "状态不错" : "")
                session.finishedAt = date.addingTimeInterval(3_900)
                context.insert(session)

                for (order, exerciseID) in day.exerciseIDs.enumerated() {
                    guard let exercise = lookup[exerciseID] else { continue }
                    let base = baseWeights[exerciseID] ?? 40
                    let weight = LoadPrescription.roundHalf(base + Double(4 - week) * 2.5)

                    let item = SessionExercise(
                        order: order,
                        exercise: exercise,
                        targetReps: exercise.targetReps,
                        suggestedWeight: weight,
                        restSeconds: exercise.defaultRestSeconds
                    )
                    context.insert(item)
                    item.session = session

                    for setIndex in 0..<3 {
                        let reps = exercise.targetReps.upperBound - setIndex
                            - Int((random.next() % 2))
                        let rpe = 7.5 + Double(random.next() % 4) * 0.5
                        let set = WorkoutSet(
                            order: setIndex + 1,
                            weight: weight,
                            reps: max(reps, 1),
                            rpe: min(rpe, 10),
                            setType: .normal,
                            isCompleted: true
                        )
                        context.insert(set)
                        set.sessionExercise = item
                    }
                }
            }
        }

        // 体重记录：缓慢下降
        for week in stride(from: 4, through: 0, by: -1) {
            guard let date = calendar.date(byAdding: .day, value: -(week * 7), to: .now) else { continue }
            let weight = 74.2 - Double(4 - week) * 0.4
            context.insert(BodyMetric(date: date, bodyweight: weight))
        }
        profile.bodyweight = 74.2 - Double(4) * 0.4

        try? context.save()
    }

    @MainActor
    private static func clear(context: ModelContext) {
        for session in (try? context.fetch(FetchDescriptor<TrainingSession>())) ?? [] {
            context.delete(session)
        }
        for metric in (try? context.fetch(FetchDescriptor<BodyMetric>())) ?? [] {
            context.delete(metric)
        }
        try? context.save()
    }
}

/// 固定种子，保证每次截图的数据一致
struct LinearCongruentialGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return state >> 33
    }
}
