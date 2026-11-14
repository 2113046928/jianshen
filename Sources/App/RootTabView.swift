import SwiftData
import SwiftUI

struct RootTabView: View {
    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]
    @State private var ready = false
    @State private var showOnboarding = false
    @State private var selection = 0

    var body: some View {
        TabView(selection: $selection) {
            TodayView()
                .tag(0)
                .tabItem {
                    Label("今天", systemImage: "figure.strengthtraining.traditional")
                }

            HistoryView()
                .tag(1)
                .tabItem {
                    Label("记录", systemImage: "list.bullet.rectangle")
                }

            NutritionView()
                .tag(2)
                .tabItem {
                    Label("饮食", systemImage: "fork.knife")
                }

            ReportView()
                .tag(3)
                .tabItem {
                    Label("周报", systemImage: "chart.bar.xaxis")
                }

            NavigationStack {
                SettingsView()
            }
            .tag(4)
            .tabItem {
                Label("我的", systemImage: "person.crop.circle")
            }
        }
        .tint(Theme.accent)
        .task {
            guard !ready else { return }
            ready = true

            await ProEntitlement.shared.refreshFromStore()

            if DemoSeed.isRequested {
                DemoSeed.seed(context: context)
            } else {
                SeedLoader.seedIfNeeded(context: context)
                let profile = SeedLoader.ensureProfile(context: context)
                if profile.didOnboard != true {
                    showOnboarding = true
                }
            }

            switch DemoSeed.requestedScreen {
            case "history": selection = 1
            case "nutrition": selection = 2
            case "report", "phase": selection = 3
            case "settings", "packs": selection = 4
            default: selection = 0
            }
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView()
        }
    }
}

#Preview {
    RootTabView()
        .modelContainer(PreviewData.container)
}

/// 预览与测试用的内存数据库
enum PreviewData {
    static let container: ModelContainer = {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: Exercise.self,
            WorkoutSet.self,
            SessionExercise.self,
            TrainingSession.self,
            BodyMetric.self,
            UserProfile.self,
            configurations: configuration
        )
        return container
    }()
}
