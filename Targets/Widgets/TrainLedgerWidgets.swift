import ActivityKit
import SwiftUI
import WidgetKit

@main
struct TrainLedgerWidgets: WidgetBundle {
    var body: some Widget {
        WorkoutLiveActivity()
        HomePlanWidget()
    }
}

// MARK: - 颜色（扩展内自带一份，避免依赖主 App 的 Theme）

enum Palette {
    static let ink = Color(red: 0.11, green: 0.11, blue: 0.12)
    static let paper = Color(red: 0.976, green: 0.973, blue: 0.965)
    static let accent = Color(red: 0.910, green: 0.349, blue: 0.047)
    static let soft = Color(red: 0.85, green: 0.85, blue: 0.87)
    static let line = Color(red: 0.25, green: 0.25, blue: 0.27)
}

struct WorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            LockScreenView(context: context)
                .activityBackgroundTint(Palette.ink)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("练账", systemImage: "figure.strengthtraining.traditional")
                        .font(.caption2)
                        .foregroundStyle(Palette.soft)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    RestCountdown(endsAt: context.state.restEndsAt, font: .caption2)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 2) {
                        Text(context.state.exerciseName)
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text(detailText(context.state))
                            .font(.caption2)
                            .foregroundStyle(Palette.soft)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(L10n.completedSets(context.state.completedSets))
                            .font(.caption2)
                            .foregroundStyle(Palette.soft)
                        Spacer()
                        Text(L10n.targetLoad(kilograms: kg(context.state.weight), reps: context.state.reps))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Palette.accent)
                    }
                }
            } compactLeading: {
                Image(systemName: "dumbbell.fill")
                    .foregroundStyle(Palette.accent)
            } compactTrailing: {
                RestCountdown(endsAt: context.state.restEndsAt, font: .caption2)
            } minimal: {
                Image(systemName: "dumbbell.fill")
                    .foregroundStyle(Palette.accent)
            }
            .keylineTint(Palette.accent)
        }
    }

    private func detailText(_ state: WorkoutActivityAttributes.ContentState) -> String {
        "第 \(state.setNumber)/\(state.totalSets) 组 · \(kg(state.weight))kg × \(state.reps)"
    }
}

// MARK: - 锁屏样式

private struct LockScreenView: View {
    let context: ActivityViewContext<WorkoutActivityAttributes>

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(context.state.exerciseName)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(L10n.liveSetLine(set: context.state.setNumber, total: context.state.totalSets, kilograms: kg(context.state.weight), reps: context.state.reps))
                    .font(.caption2)
                    .foregroundStyle(Palette.soft)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                RestCountdown(endsAt: context.state.restEndsAt, font: .title3)
                Text(L10n.completedSets(context.state.completedSets))
                    .font(.caption2)
                    .foregroundStyle(Palette.soft)
            }
        }
        .padding(14)
        .background(Palette.ink)
    }
}

// MARK: - 休息倒计时

private struct RestCountdown: View {
    let endsAt: Date?
    let font: Font

    var body: some View {
        if let endsAt, endsAt > Date.now {
            Text(timerInterval: Date.now...endsAt, countsDown: true)
                .font(font.monospacedDigit())
                .foregroundStyle(Palette.accent)
        } else {
            Text("—")
                .font(font)
                .foregroundStyle(Palette.soft)
        }
    }
}

private func kg(_ value: Double) -> String {
    if value == value.rounded() {
        return "\(Int(value))"
    }
    return String(format: "%.1f", value)
}
