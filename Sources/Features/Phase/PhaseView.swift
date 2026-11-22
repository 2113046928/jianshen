import SwiftData
import SwiftUI

extension RetentionStatus {
    var tint: Color {
        switch self {
        case .kept: return Theme.good
        case .watch: return Theme.warn
        case .risk: return Theme.danger
        case .unknown: return Theme.inkFaint
        }
    }
}

struct PhaseView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \TrainingSession.startedAt, order: .reverse) private var sessions: [TrainingSession]
    @Query(sort: \BodyMetric.date, order: .forward) private var metrics: [BodyMetric]
    @Query private var profiles: [UserProfile]

    @ObservedObject private var health = HealthService.shared
    @State private var syncMessage: String?

    private var profile: UserProfile? { profiles.first }
    private var phase: Phase { profile?.phase ?? .bulk }
    private var phaseStart: Date { profile?.phaseStartedAt ?? defaultPhaseStart }

    /// 老数据没有记录阶段开始时间时，退化为「最近 28 天」
    private var defaultPhaseStart: Date {
        Calendar.current.date(byAdding: .day, value: -28, to: .now) ?? .now
    }

    private var retentions: [LiftRetention] {
        RetentionAnalyzer.analyze(
            samples: RetentionAnalyzer.samples(from: sessions),
            phaseStart: phaseStart
        )
    }

    private var overallText: String {
        guard let value = RetentionAnalyzer.overall(retentions) else { return "—" }
        return "\(Int((value * 100).rounded()))%"
    }

    /// 保持率越高越绿：≥97% 正常，≥90% 注意，其余告警
    private var overallColor: Color {
        guard let value = RetentionAnalyzer.overall(retentions) else { return Theme.onDarkFaint }
        if value >= 0.97 { return Theme.good }
        if value >= 0.90 { return Theme.warn }
        return Theme.danger
    }

    private var weeks: Int {
        max(1, Int(Date.now.timeIntervalSince(phaseStart) / 604_800))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerCard
                retentionCard
                weightCard
                adviceCard
            }
            .padding(Theme.pad)
        }
        .background(Theme.bg)
        .navigationTitle("阶段与保持率")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 头部

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("综合力量保持率")
                    .microLabel()
                    .foregroundColor(Theme.onDarkFaint)
                Spacer()
                Text("\(phase.title) · \(L10n.weekNumber(weeks))")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.onDarkSoft)
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(overallText)
                    .heroNumber(size: 56)
                    .foregroundStyle(overallColor)
                Spacer()
                Text("阶段内最佳 1RM ÷ 阶段前最佳 1RM")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.onDarkFaint)
                    .multilineTextAlignment(.trailing)
            }

            Text(phase.summary)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
        }
        .darkCard()
    }

    private var retentionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "分项保持率", subtitle: "每个大项取一个固定动作，保证可比")
            ForEach(retentions) { item in
                retentionRow(item)
            }
        }
        .card()
    }

    private func retentionRow(_ item: LiftRetention) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(item.lift.title)
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text(item.ratio.map { "\(Int(($0 * 100).rounded()))%" } ?? "—")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(item.status.tint)
                Text(item.status.title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(item.status.tint)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.bg)
                    Capsule()
                        .fill(item.status.tint.opacity(0.85))
                        .frame(width: max(4, proxy.size.width * min(item.ratio ?? 0, 1)))
                }
            }
            .frame(height: 7)

            Text(detail(item))
                .font(.caption2)
                .foregroundStyle(Theme.inkFaint)
        }
    }

    private func detail(_ item: LiftRetention) -> String {
        guard let baseline = item.baseline, let current = item.current else {
            return "阶段开始后还没有这个动作的完整记录"
        }
        let delta = current - baseline
        let sign = delta >= 0 ? "+" : "−"
        return "阶段前 \(Fmt.kg(baseline))kg → 现在 \(Fmt.kg(current))kg（\(sign)\(Fmt.kg(abs(delta)))kg）"
    }

    // MARK: - 体重

    private var weightCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "体重趋势", subtitle: "配合保持率判断掉的是脂肪还是肌肉")

            HStack(spacing: 8) {
                StatTile(title: "当前体重", value: Fmt.kg(profile?.bodyweight ?? 0), unit: "kg")
                StatTile(title: "阶段内变化", value: weightChangeText, tint: Theme.ink)
                StatTile(title: "记录次数", value: "\(metrics.count)")
            }

            Button {
                Task { await syncFromHealth() }
            } label: {
                Label(
                    health.isWorking ? "正在读取…" : "从「健康」同步体重",
                    systemImage: "heart.text.square"
                )
                .font(.subheadline)
            }
            .disabled(health.isWorking)

            if let syncMessage {
                Text(syncMessage)
                    .font(.caption2)
                    .foregroundStyle(Theme.inkFaint)
            }
        }
        .card()
    }

    private var weightChangeText: String {
        guard let first = metrics.first(where: { $0.date >= phaseStart }),
              let last = metrics.last,
              metrics.count >= 2 else { return "—" }
        let delta = last.bodyweight - first.bodyweight
        let sign = delta >= 0 ? "+" : "−"
        return "\(sign)\(Fmt.kg(abs(delta))) kg"
    }

    // MARK: - 建议

    private var adviceCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "怎么读这张表", subtitle: nil)
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

        if RetentionAnalyzer.overall(retentions) == nil {
            items.append("还缺阶段前后的对照数据。建议在切换阶段那天，把卧推、深蹲、硬拉、推举各做一次 3–5 次的正式组。")
        } else if let value = RetentionAnalyzer.overall(retentions), value >= 0.97 {
            items.append("力量基本没掉，说明减脂速度合理。保持当前热量缺口，不用再加有氧。")
        } else if let value = RetentionAnalyzer.overall(retentions), value >= 0.90 {
            items.append("力量小幅下滑，先把缺口收小 5% 左右，并确认蛋白吃到每公斤体重 1.8g 以上。")
        } else {
            items.append("力量掉得偏多，优先排查三件事：热量缺口是否过大、睡眠是否不足、组数是否砍太狠。")
        }

        if let risk = retentions.first(where: { $0.status == .risk }) {
            items.append("\(risk.lift.title)掉得最明显，这个动作保持原来的重量与组数，不要用降重量换次数。")
        }

        items.append("减脂期的原则是「强度不掉、容量可减」：组数可以减 20–30%，重量尽量守住。")
        return items
    }

    // MARK: - 健康同步

    private func syncFromHealth() async {
        if !health.isAuthorized {
            await health.requestAuthorization()
        }
        if let mass = await health.latestBodyMass() {
            profile?.bodyweight = mass
            context.insert(BodyMetric(date: .now, bodyweight: mass))
            try? context.save()
            syncMessage = "已同步：\(Fmt.kg(mass)) kg"
        } else {
            syncMessage = health.lastError ?? "没有读到体重数据，请确认「健康」里有记录并已授权。"
        }
    }
}

#Preview {
    NavigationStack {
        PhaseView()
    }
    .modelContainer(PreviewData.container)
}
