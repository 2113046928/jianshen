import SwiftData
import SwiftUI

@main
struct TrainLedgerApp: App {
    private let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(
                for: Exercise.self,
                WorkoutSet.self,
                SessionExercise.self,
                TrainingSession.self,
                BodyMetric.self,
                UserProfile.self
            )
        } catch {
            fatalError("无法创建本地数据容器：\(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        .modelContainer(container)
    }
}
