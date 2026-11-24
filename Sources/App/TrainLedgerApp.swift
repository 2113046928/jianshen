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

    /// 启动时优先用旧库；迁移失败也不许崩：
    /// 把旧库挪到旁边备份，再建一个新库；连新库都建不出来就退回内存库。
    private static func makeContainer() -> ModelContainer {
        let configuration = ModelConfiguration()

        if let container = try? ModelContainer(for: schema, configurations: [configuration]) {
            return container
        }

        quarantineLegacyStore()

        if let retry = try? ModelContainer(for: schema, configurations: [configuration]) {
            return retry
        }

        let memory = ModelConfiguration(isStoredInMemoryOnly: true)
        if let fallback = try? ModelContainer(for: schema, configurations: [memory]) {
            return fallback
        }

        fatalError("本地数据库无法初始化，请重装 App")
    }

    /// 把打不开的旧库挪走（保留现场，方便以后排查），并清掉 -shm / -wal
    private static func quarantineLegacyStore() {
        let manager = FileManager.default
        guard let base = manager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return
        }

        let stamp = Int(Date().timeIntervalSince1970)
        let store = base.appendingPathComponent("default.store")
        if manager.fileExists(atPath: store.path) {
            let backup = base.appendingPathComponent("default.store.broken-\(stamp)")
            try? manager.moveItem(at: store, to: backup)
        }

        for suffix in ["-shm", "-wal"] {
            try? manager.removeItem(at: base.appendingPathComponent("default.store\(suffix)"))
        }
    }
}
