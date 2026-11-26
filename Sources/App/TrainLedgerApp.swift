import SwiftData
import SwiftUI

@main
struct TrainLedgerApp: App {
    private let container: ModelContainer

    init() {
        container = Self.makeContainer()
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        .modelContainer(container)
    }

    // MARK: - 数据库

    private static var schema: Schema {
        Schema([
            Exercise.self,
            WorkoutSet.self,
            SessionExercise.self,
            TrainingSession.self,
            BodyMetric.self,
            UserProfile.self,
        ])
    }

    /// 启动时优先用旧库；打不开也不许崩，但要**如实记录原因**，
    /// 供界面展示（否则用户只能看到「数据没保存」，无法排查）。
    private static func makeContainer() -> ModelContainer {
        let configuration = ModelConfiguration()

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            StorageHealth.record(error: error)
            quarantineStoreFiles()
        }

        if let retry = try? ModelContainer(for: schema, configurations: [configuration]) {
            return retry
        }

        let memory = ModelConfiguration(isStoredInMemoryOnly: true)
        if let fallback = try? ModelContainer(for: schema, configurations: [memory]) {
            StorageHealth.markEphemeral()
            return fallback
        }

        // 连内存库都建不出来属于系统级异常，只能停在这里并保留错误信息
        StorageHealth.markEphemeral()
        fatalError("本地数据库无法初始化：\(StorageHealth.errorText ?? "未知原因")")
    }

    /// 把打不开的库文件挪走。
    /// 之前只处理了 `default.store`，实际 SwiftData 旁边还有 `-shm` / `-wal`；
    /// 而且真实文件名可能不同，所以这里按前缀整体扫描。
    private static func quarantineStoreFiles() {
        let manager = FileManager.default
        guard let base = manager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return
        }
        let stamp = Int(Date().timeIntervalSince1970)

        let contents = (try? manager.contentsOfDirectory(
            at: base,
            includingPropertiesForKeys: nil
        )) ?? []

        for url in contents where url.lastPathComponent.hasPrefix("default.store") {
            let target = base.appendingPathComponent("broken-\(stamp)-\(url.lastPathComponent)")
            try? manager.moveItem(at: url, to: target)
        }
    }
}

// MARK: - 存储健康状态

/// 数据库打不开时记录下来，界面上直接显示，省得用户去导日志。
enum StorageHealth {
    /// 是否退回了「内存模式」——此时任何数据都不会保存
    static var isEphemeral = false
    /// 第一次打开失败的真实错误
    static var errorText: String?

    static func record(error: Error) {
        if errorText == nil {
            errorText = String(describing: error)
        }
    }

    static func markEphemeral() {
        isEphemeral = true
    }
}
