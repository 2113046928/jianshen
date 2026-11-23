import SwiftData
import SwiftUI

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \TrainingSession.startedAt, order: .reverse) private var sessions: [TrainingSession]
    @Query(sort: \Exercise.sortIndex) private var exercises: [Exercise]
    @Query private var profiles: [UserProfile]

    @State private var activeWorkout: TrainingSession?
    @State private var showPhaseFromLaunch = false


    private var profile: UserProfile? { profiles.first }
    private var phase: Phase { profile?.phase ?? .bulk }
    private var weeklyGoal: Int { max(profile?.weeklyGoal ?? 3, 1) }
    private var program: ProgramTemplate {
        PlanStore.template(for: profile)
    }
    private var finishedSessions: [TrainingSession] { sessions.filter { $0.isFinished } }
    /// 今天排到的那一天；nil 表示按星期排时今天休息
    private var scheduledDay: ProgramDay? {
        PlanSchedule.day(for: program, finishedSessions: finishedSessions.count)
    }

    private var isRestDay: Bool {
        PlanSchedule.usesWeekdays(program) && scheduledDay == nil
    }

    private var nextDay: ProgramDay {
        scheduledDay ?? ProgramDay(
            id: "rest",
            name: "休息日",
            focus: "今天不安排训练",
            exerciseIDs: []
        )
    }
    private var unfinishedSession: TrainingSession? { sessions.first { !$0.isFinished } }

    private var isDeloadWeek: Bool {
        Periodization.isDeloadWeek(
            finishedSessions: finishedSessions.count,
            sessionsPerWeek: weeklyGoal
        )
    }

    private var weekStart: Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        return calendar.date(byAdding: .day, value: -6, to: today) ?? today
    }

    private var weekReport: WeeklyReport {
        WeeklyReportBuilder.build(
            sessions: HistoryMapping.reportSessions(from: sessions, since: weekStart),
            plannedSessions: weeklyGoal
        )
    }

    /// 最近 7 天（含今天）每天的总容量，用于周柱条
    private var dailyVolumes: [Double] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        return (0...6).reversed().map { offset -> Double in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return 0 }
            return sessions
                .filter { $0.isFinished && calendar.isDate($0.startedAt, inSameDayAs: day) }
                .reduce(0) { $0 + $1.totalVolume }
        }
    }

    private var estimatedMinutes: Int {
        max(nextDay.exerciseIDs.count * 9, 20)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.gap) {
                    intro
                    weekCard
                    if isRestDay {
                        restCard
                    } else {
                        todayCard
                    }
                    if let last = finishedSessions.first {
                        lastSessionCard(last)
                    }
                    if phase == .cut {
                        retentionCard
                    }
                    volumeCard
                }
                .padding(.horizontal, Theme.pad)
                .padding(.top, 4)
                .padding(.bottom, 28)
            }
            .background(Theme.bg)
            .navigationTitle("今天")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.inkSoft)
                    }
                    .accessibilityLabel("设置")
                }
            }
            .fullScreenCover(item: $activeWorkout) { session in
                WorkoutView(session: session)
            }
            .navigationDestination(isPresented: $showPhaseFromLaunch) {
                PhaseView()
            }
            .onAppear(perform: handleLaunchOptions)
            .onAppear { writeWidgetSnapshot() }
            .onChange(of: weekReport.sessionCount) { _, _ in writeWidgetSnapshot() }
        }
    }

    // MARK: - 开场

    private var intro: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("\(Fmt.dayFormatter.string(from: .now)) · \(phase.title)")
                .microLabel()
                .foregroundColor(Theme.inkFaint)
            if isRestDay {
                Text("今天休息。按你设定的星期安排，不训练也没关系。")
                    .font(.system(size: 13.5))
                    .foregroundStyle(Theme.inkSoft)
            } else {
                Text("今天练\(nextDay.name)，\(nextDay.exerciseIDs.count) 个动作，约 \(estimatedMinutes) 分钟")
                    .font(.system(size: 13.5))
                    .foregroundStyle(Theme.inkSoft)
            }
        }
    }

    // MARK: - 本周

    private var weekCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("本周")
                    .microLabel()
                    .foregroundColor(Theme.onDarkFaint)
                Spacer()
                Text("\(phase.title) · 目标 \(weeklyGoal) 练")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.onDarkSoft)
            }

            HStack(alignment: .firstTextBaseline, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(weekReport.sessionCount)")
                        .heroNumber(size: 52)
                        .foregroundStyle(.white)
                    Text("/\(weeklyGoal)")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Theme.onDarkFaint)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("已完成 \(Fmt.volume(weekReport.totalVolume))")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.78))
                    Text(remainingText)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.onDarkFaint)
                }
                .padding(.bottom, 4)

                Spacer(minLength: 0)
            }

            WeekStrip(values: dailyVolumes)
        }
        .darkCard()
    }

    private var restCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("今天")
                .microLabel()
                .foregroundColor(Theme.inkFaint)
            Text("休息日")
                .font(.system(size: 34, weight: .bold))
                .tracking(-1)
                .foregroundStyle(Theme.ink)
            Text("按你设定的星期安排，今天不训练。散步、拉伸都行；想改安排可以去「我的 → 训练计划」。")
                .font(.system(size: 13))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .card()
    }

    private var remainingText: String {
        let gap = max(weeklyGoal - weekReport.sessionCount, 0)
        return gap == 0 ? "本周目标已达成" : "还差 \(gap) 次"
    }

    // MARK: - 今天练什么

    private var todayCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(nextDay.name)
                        .font(.system(size: 34, weight: .bold))
                        .tracking(-1)
                        .foregroundStyle(Theme.ink)
                    Text(nextDay.focus)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.inkFaint)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    if isDeloadWeek {
                        Pill(text: "减载周", color: Theme.warn)
                    }
                    Pill(text: "第 \(finishedSessions.count + 1) 练", color: Theme.ink)
                }
            }

            VStack(spacing: 0) {
                ForEach(Array(nextDay.exerciseIDs.enumerated()), id: \.offset) { pair in
                    exerciseRow(pair.element)
                    if pair.offset < nextDay.exerciseIDs.count - 1 {
                        hairline()
                    }
                }
            }

            if nextDay.exerciseIDs.isEmpty {
                Text("这一天的动作是空的。去「我的 → 训练计划」加几个动作，或者换一天。")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.warn)
                    .fixedSize(horizontal: false, vertical: true)
            }

            PrimaryButton(
                title: unfinishedSession == nil ? "开始训练" : "继续上次训练",
                systemImage: "play.fill",
                enabled: unfinishedSession != nil || !nextDay.exerciseIDs.isEmpty
            ) {
                startWorkout()
            }
        }
        .card()
    }

    private func exerciseRow(_ id: String) -> some View {
        let exercise = exercises.first { $0.id == id }
        let prescription = exercise.map { WorkoutFactory.prescription(for: $0, sessions: sessions) }
        let hasWeight = prescription?.weight != nil

        let loadText: String = {
            guard let prescription else { return "—" }
            if let weight = prescription.weight {
                return Fmt.kg(weight)
            }
            return "待校准"
        }()

        return HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(exercise?.name ?? id)
                .font(.system(size: 15.5, weight: .medium))
                .tracking(-0.1)
                .foregroundStyle(Theme.ink)

            if let exercise {
                Text("\(exercise.targetReps.lowerBound)–\(exercise.targetReps.upperBound) 次")
                    .font(.system(size: 11.5, weight: .semibold))
                    .tracking(0.3)
                    .foregroundStyle(Theme.inkGhost)
            }

            Spacer(minLength: 8)

            Text(loadText)
                .tabular(size: hasWeight ? 15 : 12, weight: .bold)
                .foregroundStyle(hasWeight ? Theme.ink : Theme.inkGhost)
        }
        .padding(.vertical, 11)
    }

    // MARK: - 上次训练

    private func lastSessionCard(_ session: TrainingSession) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("上次训练")
                    .microLabel()
                    .foregroundColor(Theme.inkFaint)
                Spacer()
                Text(Fmt.dayFormatter.string(from: session.startedAt))
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Theme.inkGhost)
            }

            StatRow(items: [
                .init(title: "总容量", value: Fmt.volume(session.totalVolume)),
                .init(title: "完成组数", value: "\(session.completedSetCount)"),
                .init(
                    title: "时长",
                    value: session.duration.map { "\(Int($0 / 60))" } ?? "—",
                    unit: "分"
                )
            ])
        }
        .card()
    }

    // MARK: - 减脂期保持率

    private var retentionCard: some View {
        let start = profile?.phaseStartedAt ?? Date.now.addingTimeInterval(-28 * 86_400)
        let retentions = RetentionAnalyzer.analyze(
            samples: RetentionAnalyzer.samples(from: sessions),
            phaseStart: start
        )
        let overall = RetentionAnalyzer.overall(retentions)

        return NavigationLink {
            PhaseView()
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("力量保持率")
                        .microLabel()
                        .foregroundColor(Theme.inkFaint)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.inkGhost)
                }

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(overall.map { "\(Int(($0 * 100).rounded()))%" } ?? "—")
                        .heroNumber(size: 40)
                        .foregroundStyle(retentionTint(overall))
                    Text("阶段内最佳 1RM ÷ 阶段前最佳 1RM")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.inkGhost)
                    Spacer()
                }
            }
            .card()
        }
        .buttonStyle(.plain)
    }

    private func retentionTint(_ value: Double?) -> Color {
        guard let value else { return Theme.inkGhost }
        if value >= 0.97 { return Theme.good }
        if value >= 0.90 { return Theme.warn }
        return Theme.danger
    }

    // MARK: - 容量

    private var volumeCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("近 7 天肌群容量")
                    .microLabel()
                    .foregroundColor(Theme.inkFaint)
                Spacer()
                Text("有效组")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.inkGhost)
            }

            ForEach(weekReport.volumes) { volume in
                VolumeBar(volume: volume)
            }

            if let weakest = VolumeAnalyzer.weakest(weekReport.volumes) {
                let gap = max(0, weakest.low - weakest.sets)
                Text("最需要补：\(weakest.muscle.title)，还差 \(Fmt.kg(gap)) 组")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.inkFaint)
            }
        }
        .card()
    }

    // MARK: - 动作

    private func startWorkout() {
        if let unfinishedSession {
            activeWorkout = unfinishedSession
            return
        }
        let session = WorkoutFactory.makeSession(
            day: nextDay,
            phase: phase,
            exercises: exercises,
            sessions: sessions,
            weeklyGoal: weeklyGoal,
            context: context
        )
        activeWorkout = session
    }

    /// 把今天的安排同步给桌面小组件
    private func writeWidgetSnapshot() {
        let names = nextDay.exerciseIDs.compactMap { id in
            exercises.first { $0.id == id }?.name
        }
        WidgetSnapshotWriter.update(
            dayName: nextDay.name,
            focus: nextDay.focus,
            exerciseNames: Array(names.prefix(3)),
            weekCompleted: weekReport.sessionCount,
            weeklyGoal: weeklyGoal
        )
    }

    // MARK: - 截图 / 演示启动参数

    private func handleLaunchOptions() {
        guard DemoSeed.isRequested else { return }
        if DemoSeed.shouldAutoStartWorkout, activeWorkout == nil {
            startWorkout()
        }
        if DemoSeed.requestedScreen == "phase" {
            showPhaseFromLaunch = true
        }
    }
}

#Preview {
    TodayView()
        .modelContainer(PreviewData.container)
}
