import SwiftData
import SwiftUI

struct HistoryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \TrainingSession.startedAt, order: .reverse) private var sessions: [TrainingSession]

    var body: some View {
        NavigationStack {
            List {
                ForEach(sessions) { session in
                    DisclosureGroup {
                        ForEach(session.orderedExercises) { item in
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text(item.exercise?.name ?? "未命名动作")
                                        .font(.subheadline)
                                    Spacer()
                                    Text(Fmt.volume(item.volume))
                                        .font(.caption)
                                        .foregroundStyle(Theme.inkSoft)
                                }
                                Text(setSummary(item))
                                    .font(.caption)
                                    .foregroundStyle(Theme.inkFaint)
                            }
                            .padding(.vertical, 2)
                        }
                    } label: {
                        row(session)
                    }
                    .tint(Theme.accent)
                }
                .onDelete(perform: delete)
            }
            .listStyle(.insetGrouped)
            .navigationTitle("训练记录")
            .overlay {
                if sessions.isEmpty {
                    ContentUnavailableView(
                        "还没有训练记录",
                        systemImage: "list.bullet.rectangle",
                        description: Text("去「今天」开始第一次训练")
                    )
                }
            }
        }
    }

    private func row(_ session: TrainingSession) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(Fmt.dayFormatter.string(from: session.startedAt))
                    .font(.subheadline.weight(.medium))
                Spacer()
                if !session.isFinished {
                    Pill(text: "未完成", color: Theme.warn)
                } else if let duration = session.duration {
                    Text(Fmt.duration(duration))
                        .font(.caption)
                        .foregroundStyle(Theme.inkFaint)
                }
            }
            Text(L10n.sessionSummary(sets: session.completedSetCount, volume: Fmt.volume(session.totalVolume), phase: session.phase.title))
                .font(.caption)
                .foregroundStyle(Theme.inkSoft)
        }
        .padding(.vertical, 2)
    }

    private func setSummary(_ item: SessionExercise) -> String {
        let sets = item.orderedSets.filter(\.isCompleted)
        guard !sets.isEmpty else { return "未记录" }
        return sets
            .prefix(5)
            .map { "\(Fmt.kg($0.weight))×\($0.reps)" }
            .joined(separator: "  ")
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            context.delete(sessions[index])
        }
        try? context.save()
    }
}

#Preview {
    HistoryView()
        .modelContainer(PreviewData.container)
}
