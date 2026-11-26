import SwiftData
import SwiftUI

@main
struct TrainLedgerApp: App {
    private let container: ModelContainer

    init() {
        // 启动次数：如果每次打开都显示 1，说明 App 数据被安装方式清掉了（例如每次都重装）
        let defaults = UserDefaults.standard
        let count = defaults.integer(forKey: "trainledger.launchCount") + 1
        defaults.set(count, forKey: "trainledger.launchCount")
        StorageHealth.launchCount = count

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

    /// 只用**磁盘上的文件库**，绝不退到内存。
    ///
    /// 顺序：默认库 → 挪走坏库后重试 → 换一个本地库文件（recovery.store）。
    /// 三档全部落在 Application Support，任何一档成功，数据都会持久保存在手机上。
    private static func makeContainer() -> ModelContainer {
        if let container = open(ModelConfiguration()) {
            return container
        }

        StorageHealth.record(errorText: "默认数据库打不开，已备份并重建")
        quarantineStoreFiles()

        if let container = open(ModelConfiguration()) {
            return container
        }

        // 还是不行：换一个本地库文件，数据依然保存在手机上
        StorageHealth.markRecovery()
        if let container = open(ModelConfiguration("recovery")) {
            return container
        }

        quarantineStoreFiles()
        if let container = open(ModelConfiguration("recovery")) {
            return container
        }

        fatalError("本地数据库无法创建：\(StorageHealth.errorText ?? "未知原因")")
    }

    private static func open(_ configuration: ModelConfiguration) -> ModelContainer? {
        try? ModelContainer(for: schema, configurations: [configuration])
    }

    /// 把打不开的库文件挪到旁边（含 -shm / -wal 与 recovery 系列），保留现场
    private static func quarantineStoreFiles() {
        let manager = FileManager.default
        guard let base = manager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return
        }
        let stamp = Int(Date().timeIntervalSince1970)
        let contents = (try? manager.contentsOfDirectory(at: base, includingPropertiesForKeys: nil)) ?? []

        for url in contents {
            let name = url.lastPathComponent
            guard name.hasPrefix("default.store") || name.hasPrefix("recovery.store") else { continue }
            let target = base.appendingPathComponent("broken-\(stamp)-\(name)")
            try? manager.moveItem(at: url, to: target)
        }
    }
}

// MARK: - 存储健康状态

/// 数据库异常时记录原因，界面上直接显示，省得用户去导日志。
enum StorageHealth {
    /// 默认库打不开、改用 recovery 库（数据仍会保存在手机上，只是换了文件）
    static var usedRecoveryStore = false
    /// 最近一次异常的描述
    static var errorText: String?
    /// 本机累计启动次数
    static var launchCount = 0

    static func record(errorText: String) {
        if self.errorText == nil {
            self.errorText = errorText
        }
    }

    static func markRecovery() {
        usedRecoveryStore = true
    }
}
