import Foundation
import SwiftData

// MARK: - 动作

@Model
final class Exercise {
    @Attribute(.unique) var id: String
    var name: String
    var aliases: [String]
    var patternRaw: String
    var primaryRaw: [String]
    var secondaryRaw: [String]
    var equipmentRaw: String
    var isCompound: Bool
    var loadIncrement: Double
    var targetRepsLow: Int
    var targetRepsHigh: Int
    var defaultRestSeconds: Int
    var sortIndex: Int

    init(
        id: String,
        name: String,
        aliases: [String] = [],
        pattern: MovementPattern,
        primary: [MuscleGroup],
        secondary: [MuscleGroup] = [],
        equipment: Equipment,
        isCompound: Bool,
        loadIncrement: Double,
        targetReps: ClosedRange<Int>,
        defaultRestSeconds: Int = 120,
        sortIndex: Int = 0
    ) {
        self.id = id
        self.name = name
        self.aliases = aliases
        self.patternRaw = pattern.rawValue
        self.primaryRaw = primary.map(\.rawValue)
        self.secondaryRaw = secondary.map(\.rawValue)
        self.equipmentRaw = equipment.rawValue
        self.isCompound = isCompound
        self.loadIncrement = loadIncrement
        self.targetRepsLow = targetReps.lowerBound
        self.targetRepsHigh = targetReps.upperBound
        self.defaultRestSeconds = defaultRestSeconds
        self.sortIndex = sortIndex
    }

    var pattern: MovementPattern { MovementPattern(rawValue: patternRaw) ?? .horizontalPush }
    var equipment: Equipment { Equipment(rawValue: equipmentRaw) ?? .barbell }
    var primaryMuscles: [MuscleGroup] { primaryRaw.compactMap { MuscleGroup(rawValue: $0) } }
    var secondaryMuscles: [MuscleGroup] { secondaryRaw.compactMap { MuscleGroup(rawValue: $0) } }
    var targetReps: ClosedRange<Int> { targetRepsLow...max(targetRepsLow, targetRepsHigh) }

    var searchText: String {
        ([name] + aliases + [pattern.title, equipment.title]).joined(separator: " ").lowercased()
    }
}

// MARK: - 训练组

@Model
final class WorkoutSet {
    var order: Int
    var weight: Double
    var reps: Int
    var rpe: Double?
    var setTypeRaw: String
    var isCompleted: Bool
    var sessionExercise: SessionExercise?

    init(
        order: Int,
        weight: Double = 0,
        reps: Int = 0,
        rpe: Double? = nil,
        setType: SetType = .normal,
        isCompleted: Bool = false
    ) {
        self.order = order
        self.weight = weight
        self.reps = reps
        self.rpe = rpe
        self.setTypeRaw = setType.rawValue
        self.isCompleted = isCompleted
    }

    var setType: SetType {
        get { SetType(rawValue: setTypeRaw) ?? .normal }
        set { setTypeRaw = newValue.rawValue }
    }

    var volume: Double { max(0, weight) * Double(max(0, reps)) }
}

// MARK: - 训练中的动作

@Model
final class SessionExercise {
    var order: Int
    var targetRepsLow: Int
    var targetRepsHigh: Int
    var suggestedWeight: Double?
    var restSeconds: Int
    var exercise: Exercise?
    var session: TrainingSession?
    @Relationship(deleteRule: .cascade, inverse: \WorkoutSet.sessionExercise)
    var sets: [WorkoutSet] = []

    init(
        order: Int,
        exercise: Exercise?,
        targetReps: ClosedRange<Int>,
        suggestedWeight: Double?,
        restSeconds: Int
    ) {
        self.order = order
        self.exercise = exercise
        self.targetRepsLow = targetReps.lowerBound
        self.targetRepsHigh = targetReps.upperBound
        self.suggestedWeight = suggestedWeight
        self.restSeconds = restSeconds
    }

    var targetReps: ClosedRange<Int> { targetRepsLow...max(targetRepsLow, targetRepsHigh) }
    var orderedSets: [WorkoutSet] { sets.sorted { $0.order < $1.order } }
    var completedSets: [WorkoutSet] { orderedSets.filter(\.isCompleted) }
    var volume: Double { completedSets.reduce(0) { $0 + $1.volume } }
}

// MARK: - 一次训练

@Model
final class TrainingSession {
    var startedAt: Date
    var finishedAt: Date?
    var phaseRaw: String
    var note: String
    @Relationship(deleteRule: .cascade, inverse: \SessionExercise.session)
    var exercises: [SessionExercise] = []

    init(startedAt: Date = .now, phase: Phase = .bulk, note: String = "") {
        self.startedAt = startedAt
        self.finishedAt = nil
        self.phaseRaw = phase.rawValue
        self.note = note
    }

    var phase: Phase { Phase(rawValue: phaseRaw) ?? .bulk }
    var orderedExercises: [SessionExercise] { exercises.sorted { $0.order < $1.order } }
    var isFinished: Bool { finishedAt != nil }
    var duration: TimeInterval? {
        guard let finishedAt else { return nil }
        return finishedAt.timeIntervalSince(startedAt)
    }

    var completedSetCount: Int {
        exercises.reduce(0) { partial, item in
            partial + item.sets.filter(\.isCompleted).count
        }
    }

    var totalVolume: Double {
        exercises.reduce(0) { partial, item in partial + item.volume }
    }
}

// MARK: - 身体数据

@Model
final class BodyMetric {
    var date: Date
    var bodyweight: Double
    var bodyFat: Double?

    init(date: Date = .now, bodyweight: Double, bodyFat: Double? = nil) {
        self.date = date
        self.bodyweight = bodyweight
        self.bodyFat = bodyFat
    }
}

// MARK: - 用户设置（单条记录）

@Model
final class UserProfile {
    var displayName: String
    var bodyweight: Double
    var phaseRaw: String
    var weeklyGoal: Int
    var unitRaw: String
    var activeProgramID: String
    /// 当前阶段开始时间，用于计算力量保持率
    var phaseStartedAt: Date?
    /// 是否完成首次建档（nil 视为未完成，便于旧数据迁移）
    var didOnboard: Bool?
    /// 已解锁的计划包 ID
    var unlockedProgramIDs: [String] = []
    /// 营养计算需要的字段（nil 表示还没填，界面用默认值兜底）
    var sexRaw: String?
    var age: Int?
    var heightCM: Double?
    var activityRaw: String?
    /// 体脂率围度法需要的尺寸（cm），nil 表示还没量
    var waistCM: Double?
    var neckCM: Double?
    var hipCM: Double?

    init(
        displayName: String = "",
        bodyweight: Double = 70,
        phase: Phase = .bulk,
        weeklyGoal: Int = 3,
        unitRaw: String = "kg",
        activeProgramID: String = "ppl"
    ) {
        self.displayName = displayName
        self.bodyweight = bodyweight
        self.phaseRaw = phase.rawValue
        self.weeklyGoal = weeklyGoal
        self.unitRaw = unitRaw
        self.activeProgramID = activeProgramID
        self.phaseStartedAt = nil
        self.didOnboard = nil
        self.unlockedProgramIDs = []
        self.sexRaw = nil
        self.age = nil
        self.heightCM = nil
        self.activityRaw = nil
        self.waistCM = nil
        self.neckCM = nil
        self.hipCM = nil
    }

    var phase: Phase {
        get { Phase(rawValue: phaseRaw) ?? .bulk }
        set { phaseRaw = newValue.rawValue }
    }
}
