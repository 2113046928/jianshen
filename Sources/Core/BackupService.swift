import Foundation
import SwiftData

// MARK: - 备份文件格式

struct BackupSetDTO: Codable, Equatable {
    var order: Int
    var weight: Double
    var reps: Int
    var rpe: Double?
    var type: String
    var completed: Bool
}

struct BackupExerciseDTO: Codable, Equatable {
    var exerciseID: String
    var order: Int
    var suggestedWeight: Double?
    var restSeconds: Int
    var sets: [BackupSetDTO]
}

struct BackupSessionDTO: Codable, Equatable {
    var startedAt: Date
    var finishedAt: Date?
    var phase: String
    var note: String
    var exercises: [BackupExerciseDTO]
}

struct BackupMetricDTO: Codable, Equatable {
    var date: Date
    var bodyweight: Double
    var bodyFat: Double?
}

struct BackupProfileDTO: Codable, Equatable {
    var bodyweight: Double
    var phase: String
    var weeklyGoal: Int
    var programID: String
    var phaseStartedAt: Date?
    var unlockedProgramIDs: [String]
}

struct BackupFile: Codable, Equatable {
    var version: Int
    var exportedAt: Date
    var profile: BackupProfileDTO
    var sessions: [BackupSessionDTO]
    var metrics: [BackupMetricDTO]
}

struct RestoreSummary: Equatable {
    var sessions: Int
    var metrics: Int
    var skippedSessions: Int
}

// MARK: - 服务

/// 纯本地的备份与恢复。用户不需要账号，但必须能自己把数据带走、也能从备份回来。
enum BackupService {
    static let currentVersion = 1
    static let exportFileName = "练账备份.json"

    private static var backupDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base.appendingPathComponent("Backups", isDirectory: true)
    }

    // MARK: 编码

    static func makeFile(
        profile: UserProfile?,
        sessions: [TrainingSession],
        metrics: [BodyMetric]
    ) -> BackupFile {
        BackupFile(
            version: currentVersion,
            exportedAt: .now,
            profile: makeProfile(profile),
            sessions: sessions
                .sorted { $0.startedAt < $1.startedAt }
                .map(makeSession),
            metrics: metrics
                .sorted { $0.date < $1.date }
                .map { BackupMetricDTO(date: $0.date, bodyweight: $0.bodyweight, bodyFat: $0.bodyFat) }
        )
    }

    static func makeProfile(_ profile: UserProfile?) -> BackupProfileDTO {
        BackupProfileDTO(
            bodyweight: profile?.bodyweight ?? 70,
            phase: profile?.phaseRaw ?? Phase.bulk.rawValue,
            weeklyGoal: profile?.weeklyGoal ?? 3,
            programID: profile?.activeProgramID ?? "ppl",
            phaseStartedAt: profile?.phaseStartedAt,
            unlockedProgramIDs: profile?.unlockedProgramIDs ?? []
        )
    }

    static func makeSession(_ session: TrainingSession) -> BackupSessionDTO {
        BackupSessionDTO(
            startedAt: session.startedAt,
            finishedAt: session.finishedAt,
            phase: session.phaseRaw,
            note: session.note,
            exercises: session.orderedExercises.map { item in
                BackupExerciseDTO(
                    exerciseID: item.exercise?.id ?? "",
                    order: item.order,
                    suggestedWeight: item.suggestedWeight,
                    restSeconds: item.restSeconds,
                    sets: item.orderedSets.map { set in
                        BackupSetDTO(
                            order: set.order,
                            weight: set.weight,
                            reps: set.reps,
                            rpe: set.rpe,
                            type: set.setTypeRaw,
                            completed: set.isCompleted
                        )
                    }
                )
            }
        )
    }

    // MARK: JSON

    static func encode(_ file: BackupFile) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(file)
    }

    static func decode(_ data: Data) throws -> BackupFile {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(BackupFile.self, from: data)
    }

    // MARK: 自动备份

    /// 每次训练结束后写一份，只保留最近 3 份
    static func writeAutoBackup(data: Data) throws {
        let manager = FileManager.default
        try manager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)

        let stamp = ISO8601DateFormatter().string(from: .now)
            .replacingOccurrences(of: ":", with: "-")
        let url = backupDirectory.appendingPathComponent("backup-\(stamp).json")
        try data.write(to: url, options: .atomic)

        for old in autoBackups().dropFirst(3) {
            try? manager.removeItem(at: old)
        }
    }

    static func autoBackups() -> [URL] {
        let manager = FileManager.default
        guard let files = try? manager.contentsOfDirectory(
            at: backupDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey]
        ) else { return [] }
        return files
            .filter { $0.lastPathComponent.hasSuffix(".json") }
            .sorted { a, b in
                let da = (try? a.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
                let db = (try? b.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
                return da > db
            }
    }

    /// 写到临时目录，供 ShareLink 分享
    static func writeExportFile(data: Data) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(exportFileName)
        try data.write(to: url, options: .atomic)
        return url
    }

    // MARK: 恢复

    /// 全量恢复：先清空现有训练与体重记录，再按备份重建。
    @discardableResult
    static func restore(
        _ file: BackupFile,
        into context: ModelContext,
        exercises: [Exercise]
    ) throws -> RestoreSummary {
        let lookup = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })

        for session in try context.fetch(FetchDescriptor<TrainingSession>()) {
            context.delete(session)
        }
        for metric in try context.fetch(FetchDescriptor<BodyMetric>()) {
            context.delete(metric)
        }

        var restored = 0
        var skipped = 0

        for dto in file.sessions {
            let session = TrainingSession(
                startedAt: dto.startedAt,
                phase: Phase(rawValue: dto.phase) ?? .bulk,
                note: dto.note
            )
            session.finishedAt = dto.finishedAt
            context.insert(session)

            var known = 0
            for itemDTO in dto.exercises {
                guard let exercise = lookup[itemDTO.exerciseID] else { continue }
                known += 1
                let item = SessionExercise(
                    order: itemDTO.order,
                    exercise: exercise,
                    targetReps: exercise.targetReps,
                    suggestedWeight: itemDTO.suggestedWeight,
                    restSeconds: itemDTO.restSeconds
                )
                context.insert(item)
                item.session = session

                for setDTO in itemDTO.sets {
                    let set = WorkoutSet(
                        order: setDTO.order,
                        weight: setDTO.weight,
                        reps: setDTO.reps,
                        rpe: setDTO.rpe,
                        setType: SetType(rawValue: setDTO.type) ?? .normal,
                        isCompleted: setDTO.completed
                    )
                    context.insert(set)
                    set.sessionExercise = item
                }
            }

            if known == 0 {
                context.delete(session)
                skipped += 1
            } else {
                restored += 1
            }
        }

        for metricDTO in file.metrics {
            context.insert(
                BodyMetric(date: metricDTO.date, bodyweight: metricDTO.bodyweight, bodyFat: metricDTO.bodyFat)
            )
        }

        if let profile = try context.fetch(FetchDescriptor<UserProfile>()).first {
            profile.bodyweight = file.profile.bodyweight
            profile.phaseRaw = file.profile.phase
            profile.weeklyGoal = file.profile.weeklyGoal
            profile.activeProgramID = file.profile.programID
            profile.phaseStartedAt = file.profile.phaseStartedAt
            // 计划包属于购买权益，以本机当前状态为准；备份只能补充，不能反向撤销
            let merged = Set(profile.unlockedProgramIDs)
                .union(file.profile.unlockedProgramIDs)
            profile.unlockedProgramIDs = Array(merged).sorted()
        }

        try context.save()
        return RestoreSummary(
            sessions: restored,
            metrics: file.metrics.count,
            skippedSessions: skipped
        )
    }

    /// 判断备份里有哪些动作是当前动作库认识的（用于恢复前的提示）
    static func unknownExerciseIDs(in file: BackupFile, exercises: [Exercise]) -> [String] {
        let known = Set(exercises.map(\.id))
        var unknown = Set<String>()
        for session in file.sessions {
            for item in session.exercises where !known.contains(item.exerciseID) {
                unknown.insert(item.exerciseID)
            }
        }
        return unknown.sorted()
    }
    /// 训练结束后立刻写一份备份，用户不需要记得手动导出
    @MainActor
    static func captureAfterWorkout(context: ModelContext) {
        let sessions = (try? context.fetch(FetchDescriptor<TrainingSession>())) ?? []
        let metrics = (try? context.fetch(FetchDescriptor<BodyMetric>())) ?? []
        let profiles = (try? context.fetch(FetchDescriptor<UserProfile>())) ?? []
        let file = makeFile(profile: profiles.first, sessions: sessions, metrics: metrics)
        guard let data = try? encode(file) else { return }
        try? writeAutoBackup(data: data)
    }
}
