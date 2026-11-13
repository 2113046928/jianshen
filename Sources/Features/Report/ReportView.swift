import SwiftData
import SwiftUI

struct ReportView: View {
    @Query(sort: \TrainingSession.startedAt, order: .reverse) private var sessions: [TrainingSession]
    @Query private var profiles: [UserProfile]

    @State private var windowIndex = 0

    private let windowTitles = ["近 7 天", "前 7 天", "前 14 天"]

    private var profile: UserProfile? { profiles.first }
    private var weeklyGoal: Int { max(profile?.weeklyGoal ?? 3, 1) }
    private var phase: Phase { profile?.phase ?? .bulk }

    private var windowStart: Date {
        let calendar = Calendar.current
        let base = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: .now)) ?? .now
        return calendar.date(byAdding: .day, value: -7 * windowIndex, to: base) ?? base
    }

    private var windowEnd: Date {
        let calendar = Calendar.current
        return calendar.date(byAdding: .day, value: 7, to: windowStart) ?? .now
    }

    private func reportSessions(before date: Date) -> [ReportSession] {
        sessions
            .filter { $0.isFinished && $0.startedAt < date }
            .sorted { $0.startedAt < $1.startedAt }
            .map(HistoryMapping.reportSession)
    }

    private var report: WeeklyReport {
        let all = sessions
            .filter { $0.isFinished && $0.startedAt >= windowStart && $0.startedAt < windowEnd }
            .sorted { $0.startedAt < $1.startedAt }
            .map(HistoryMapping.reportSession)
        return WeeklyReportBuilder.build(
            sessions: all,
            plannedSessions: weeklyGoal,
            history: reportSessions(before: windowStart)
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Picker("时间范围", selection: $windowIndex) {
                        ForEach(Array(windowTitles.enumerated()), id: \.offset) { pair in
                            Text(pair.element).tag(pair.offset)
                        }
                    }
                    .pickerStyle(.segmented)

                    overviewCard
                    statsCard
                    volumeCard
                    adviceCard
                }
                .padding(Theme.pad)
            }
            .background(Theme.bg)
            .navigationTitle("周报")
        }
    }

    // MARK: - 概览

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(windowTitles[windowIndex])
                    .microLabel()
                    .foregroundColor(Theme.onDarkFaint)
                Spacer()
                Text(phase.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.onDarkSoft)
            }

            HStack(alignment: .firstTextBaseline, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(report.adherencePercent)")
                        .heroNumber(size: 52)
                        .foregroundStyle(.white)
                    Text("%")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Theme.onDarkFaint)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("\(report.sessionCount) / \(weeklyGoal) 次")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.78))
                    Text(adherenceNote)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.onDarkFaint)
                }
                .padding(.bottom, 4)

                Spacer(minLength: 0)
            }

            ProgressView(value: report.adherence)
                .tint(Theme.accent)
        }
        .darkCard()
    }

    private var adherenceNote: String {
        let gap = max(weeklyGoal - report.sessionCount, 0)
        return gap == 0 ? "本周目标已达成" : "差 \(gap) 次就满"
    }

    private var statsCard: some View {
        StatRow(items: [
            .init(title: "总容量", value: Fmt.volume(report.totalVolume)),
            .init(title: "完成组数", value: "\(report.totalSets)"),
            .init(title: "PR", value: "\(report.prCount)", tint: Theme.accent)
        ])
        .card()
    }

    // MARK: - 容量

    private var volumeCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "肌群容量", subtitle: "对比每周有效组目标区间")
            ForEach(report.volumes) { volume in
                VolumeBar(volume: volume)
            }
        }
        .card()
    }

    // MARK: - 建议

    private var adviceCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "这次报告说明什么", subtitle: nil)

            ForEach(Array(insights().enumerated()), id: \.offset) { pair in
                HStack(alignment: .top, spacing: 8) {
                    Circle()
                        .fill(Theme.accent)
                        .frame(width: 5, height: 5)
                        .padding(.top, 7)
                    Text(pair.element)
                        .font(.subheadline)
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .card()
    }

    private func insights() -> [String] {
        var items: [String] = []

        if report.sessionCount == 0 {
            items.append("这段时间没有已完成的训练，先开始第一次训练，报告才会有数据。")
        } else if report.adherence >= 1 {
            items.append("训练频率达成，节奏保持住比单次练到力竭更重要。")
        } else {
            items.append("完成率 \(report.adherencePercent)%，比目标少 \(max(0, weeklyGoal - report.sessionCount)) 次。")
        }

        if let weakest = VolumeAnalyzer.weakest(report.volumes) {
            let gap = max(0, weakest.low - weakest.sets)
            items.append("\(weakest.muscle.title) 还差 \(Fmt.kg(gap)) 个有效组，下次可以在动作后面加 1–2 组。")
        } else {
            items.append("六个肌群都在目标区间内，下周可以只做渐进超负荷，不用加容量。")
        }

        if let over = report.volumes.first(where: { $0.status == .over }) {
            items.append("\(over.muscle.title) 已经超过上限，注意恢复，别把疲劳堆在同一处。")
        }

        switch phase {
        case .cut:
            items.append("减脂期看的是「力量保持率」：重量别掉，组数可以减 20–30%，有氧按每周 3–4 次安排。")
        case .bulk:
            items.append("增肌期热量小幅盈余，蛋白按每公斤体重 1.6–2.2g 安排，重点是把容量稳定推上去。")
        case .maintain:
            items.append("维持期保持当前强度，每 4–6 周安排一个减载周。")
        }

        return items
    }

}

#Preview {
    ReportView()
        .modelContainer(PreviewData.container)
}
