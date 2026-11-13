import SwiftUI
import WidgetKit

// MARK: - 桌面小组件：今天练什么

struct HomePlanEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
}

struct HomePlanProvider: TimelineProvider {
    func placeholder(in context: Context) -> HomePlanEntry {
        HomePlanEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (HomePlanEntry) -> Void) {
        completion(HomePlanEntry(date: .now, snapshot: WidgetStore.load() ?? .placeholder))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HomePlanEntry>) -> Void) {
        let entry = HomePlanEntry(date: .now, snapshot: WidgetStore.load())
        // App 里每次训练变化会主动刷新；这里再兜一个 6 小时后的兜底刷新
        let next = Calendar.current.date(byAdding: .hour, value: 6, to: .now)
            ?? Date.now.addingTimeInterval(21_600)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct HomePlanWidget: Widget {
    let kind = "HomePlanWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HomePlanProvider()) { entry in
            HomePlanView(entry: entry)
                .containerBackground(for: .widget) { Palette.ink }
        }
        .configurationDisplayName("今天练什么")
        .description("今天的训练安排和本周进度")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct HomePlanView: View {
    @Environment(\.widgetFamily) private var family
    let entry: HomePlanEntry

    var body: some View {
        if let snapshot = entry.snapshot {
            content(snapshot)
        } else {
            empty
        }
    }

    private func content(_ snapshot: WidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("今天")
                    .font(.caption2)
                    .foregroundStyle(Palette.soft)
                Spacer()
                Text(L10n.widgetProgress(done: snapshot.weekCompleted, goal: snapshot.weeklyGoal))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(Palette.accent)
            }

            Text(snapshot.dayName)
                .font(.headline)
                .foregroundStyle(.white)

            Text(snapshot.focus)
                .font(.caption2)
                .foregroundStyle(Palette.soft)
                .lineLimit(1)

            if family == .systemMedium {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(snapshot.exerciseNames.prefix(3).enumerated()), id: \.offset) { pair in
                        Text(L10n.widgetExercise(pair.element))
                            .font(.caption2)
                            .foregroundStyle(Palette.soft)
                            .lineLimit(1)
                    }
                }
                .padding(.top, 2)
            } else {
                weekDots(snapshot)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func weekDots(_ snapshot: WidgetSnapshot) -> some View {
        HStack(spacing: 4) {
            ForEach(0..<max(snapshot.weeklyGoal, 1), id: \.self) { index in
                Circle()
                    .fill(index < snapshot.weekCompleted ? Palette.accent : Palette.line)
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.top, 2)
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("练账")
                .font(.caption2)
                .foregroundStyle(Palette.soft)
            Text("打开 App 开始训练")
                .font(.headline)
                .foregroundStyle(.white)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
