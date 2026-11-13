import ActivityKit
import SwiftData
import SwiftUI

struct WorkoutView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let session: TrainingSession

    @Query(sort: \Exercise.sortIndex) private var exercises: [Exercise]
    @Query(sort: \TrainingSession.startedAt, order: .reverse) private var allSessions: [TrainingSession]

    @State private var restRemaining = 0
    @State private var restEndsAt: Date?
    @State private var showFinishConfirm = false

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var title: String {
        session.phase.title + " · 训练中"
    }

    /// 当前进度所在的动作
    private var currentItem: SessionExercise? {
        session.orderedExercises.first { $0.completedSets.count < $0.orderedSets.count }
            ?? session.orderedExercises.first
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    summaryBar
                    ForEach(session.orderedExercises) { item in
                        ExerciseCard(
                            item: item,
                            catalog: exercises,
                            sessions: allSessions,
                            onSetCompleted: { seconds in
                                startRest(seconds)
                            }
                        )
                    }
                }
                .padding(Theme.pad)
                .padding(.bottom, restRemaining > 0 ? 76 : 8)
            }
            .background(Theme.bg)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("返回") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { showFinishConfirm = true }
                        .fontWeight(.semibold)
                }
            }
            .overlay(alignment: .bottom) {
                if restRemaining > 0 {
                    restBar
                }
            }
            .onReceive(ticker) { _ in tick() }
            .onChange(of: session.completedSetCount) { _, _ in
                updateLiveActivity()
                pushWatchState()
            }
            .onAppear(perform: activateCompanions)
            .onDisappear(perform: deactivateCompanions)
            .confirmationDialog(
                "结束这次训练？",
                isPresented: $showFinishConfirm,
                titleVisibility: .visible
            ) {
                Button("完成训练") { finish() }
                Button("继续练", role: .cancel) {}
            } message: {
                Text("已完成的组会被记录，未完成的组将被忽略。")
            }
        }
    }

    // MARK: - 概览

    private var summaryBar: some View {
        HStack(spacing: 8) {
            StatTile(title: "完成组数", value: "\(session.completedSetCount)")
            StatTile(title: "总容量", value: Fmt.volume(session.totalVolume))
            StatTile(title: "动作数", value: "\(session.exercises.count)")
        }
    }

    // MARK: - 休息计时

    private var restBar: some View {
        HStack(spacing: 14) {
            Image(systemName: "timer")
                .font(.title3)
            Text(String(format: "%d:%02d", restRemaining / 60, restRemaining % 60))
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .monospacedDigit()
            Text("组间休息")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
            Spacer()
            Button("跳过") {
                restRemaining = 0
                restEndsAt = nil
                updateLiveActivity()
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(Theme.solid)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.horizontal, Theme.pad)
        .padding(.bottom, 10)
    }

    private func startRest(_ seconds: Int) {
        restRemaining = max(seconds, 0)
        restEndsAt = Date.now.addingTimeInterval(TimeInterval(max(seconds, 0)))
        updateLiveActivity()
        pushWatchState()
    }

    private func tick() {
        guard restRemaining > 0 else { return }
        restRemaining -= 1
        if restRemaining == 0 {
            restEndsAt = nil
            updateLiveActivity()
        }
    }

    // MARK: - 实时活动与手表

    private var contentState: WorkoutActivityAttributes.ContentState {
        let item = currentItem
        let completed = item?.completedSets.count ?? 0
        let total = item?.orderedSets.count ?? 1
        return WorkoutActivityAttributes.ContentState(
            exerciseName: item?.exercise?.name ?? "训练",
            setNumber: min(completed + 1, total),
            totalSets: total,
            weight: item?.suggestedWeight ?? 0,
            reps: item?.targetReps.lowerBound ?? 0,
            completedSets: session.completedSetCount,
            restEndsAt: restEndsAt
        )
    }

    private func updateLiveActivity() {
        LiveActivityManager.shared.update(contentState)
    }

    private func pushWatchState() {
        let item = currentItem
        let completed = item?.completedSets.count ?? 0
        let total = item?.orderedSets.count ?? 1
        WatchBridge.shared.push(
            WatchWorkoutState(
                exerciseName: item?.exercise?.name ?? "训练",
                setNumber: min(completed + 1, total),
                totalSets: total,
                weight: item?.suggestedWeight ?? 0,
                reps: item?.targetReps.lowerBound ?? 0,
                isActive: !session.isFinished
            )
        )
    }

    private func activateCompanions() {
        LiveActivityManager.shared.start(
            sessionID: String(describing: session.persistentModelID),
            state: contentState
        )
        // 手表点「完成本组」：把第一条未完成的组标记为完成，其余交给 SwiftData 变更回调
        WatchBridge.shared.onCompleteSet = { [session, context] in
            guard !session.isFinished else { return }
            for item in session.orderedExercises {
                if let set = item.orderedSets.first(where: { !$0.isCompleted }) {
                    set.isCompleted = true
                    try? context.save()
                    return
                }
            }
        }
        pushWatchState()
    }

    private func deactivateCompanions() {
        WatchBridge.shared.onCompleteSet = nil
        WatchBridge.shared.push(.idle)
        if session.isFinished {
            LiveActivityManager.shared.end()
        }
    }


    // MARK: - 结束

    private func finish() {
        session.finishedAt = .now
        try? context.save()
        BackupService.captureAfterWorkout(context: context)
        LiveActivityManager.shared.end()
        WatchBridge.shared.push(.idle)
        dismiss()
    }
}

// MARK: - 单个动作卡片

private struct ExerciseCard: View {
    @Environment(\.modelContext) private var context
    @Bindable var item: SessionExercise
    var catalog: [Exercise] = []
    var sessions: [TrainingSession] = []
    var onSetCompleted: (Int) -> Void

    @State private var showAlternatives = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.exercise?.name ?? "未命名动作")
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                    Text(L10n.repRangeWithRest(low: item.targetReps.lowerBound, high: item.targetReps.upperBound, rest: item.restSeconds))
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft)
                }
                Spacer()
                if let weight = item.suggestedWeight {
                    Pill(text: L10n.suggestedLoad(Fmt.kg(weight)), color: Theme.ink)
                } else {
                    Pill(text: "待校准", color: Theme.warn)
                }
            }

            VStack(spacing: 8) {
                ForEach(item.orderedSets) { set in
                    SetRow(set: set) {
                        onSetCompleted(item.restSeconds)
                    }
                }
            }

            Button {
                addSet()
            } label: {
                Label("加一组", systemImage: "plus.circle")
                    .font(.subheadline)
            }
            .tint(Theme.accent)
        }
        .card()
        .sheet(isPresented: $showAlternatives) {
            alternativesSheet
        }
    }

    // MARK: 换动作

    private var alternatives: [Exercise] {
        guard let base = item.exercise else { return [] }
        return ExerciseSubstitution.alternatives(for: base, in: catalog)
    }

    private var alternativesSheet: some View {
        NavigationStack {
            List {
                if let base = item.exercise {
                    Section("现在的动作") {
                        row(base, isCurrent: true)
                    }
                }

                Section("可以换成") {
                    if alternatives.isEmpty {
                        Text("没有找到合适的替代动作，动作库里还缺少同模式的选项。")
                            .font(.subheadline)
                            .foregroundStyle(Theme.inkSoft)
                    } else {
                        ForEach(alternatives) { exercise in
                            Button {
                                replace(with: exercise)
                            } label: {
                                row(exercise, isCurrent: false)
                            }
                        }
                    }
                }
            }
            .navigationTitle("换动作")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { showAlternatives = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func row(_ exercise: Exercise, isCurrent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(exercise.name)
                    .font(.subheadline.weight(isCurrent ? .semibold : .regular))
                    .foregroundStyle(Theme.ink)
                Spacer()
                if isCurrent {
                    Text("当前")
                        .font(.caption2)
                        .foregroundStyle(Theme.inkFaint)
                }
            }
            Text("\(exercise.pattern.title) · \(exercise.equipment.title) · \(exercise.targetReps.lowerBound)–\(exercise.targetReps.upperBound) 次")
                .font(.caption2)
                .foregroundStyle(Theme.inkSoft)
        }
    }

    /// 换动作后重算目标次数与建议重量，重量留空让用户自己决定要不要沿用
    private func replace(with exercise: Exercise) {
        item.exercise = exercise
        item.targetRepsLow = exercise.targetReps.lowerBound
        item.targetRepsHigh = exercise.targetReps.upperBound
        item.restSeconds = exercise.defaultRestSeconds
        item.suggestedWeight = WorkoutFactory
            .prescription(for: exercise, sessions: sessions)
            .weight
        try? context.save()
        showAlternatives = false
    }

    private func addSet() {
        let last = item.orderedSets.last
        let newSet = WorkoutSet(
            order: (last?.order ?? 0) + 1,
            weight: last?.weight ?? (item.suggestedWeight ?? 0),
            reps: last?.reps ?? item.targetReps.lowerBound
        )
        context.insert(newSet)
        newSet.sessionExercise = item
        try? context.save()
    }
}

// MARK: - 单组

private struct SetRow: View {
    @Bindable var set: WorkoutSet
    var onComplete: () -> Void

    private let rpeOptions: [Double] = [6, 6.5, 7, 7.5, 8, 8.5, 9, 9.5, 10]

    var body: some View {
        HStack(spacing: 8) {
            Text(set.setType == .warmup ? "热身" : "\(set.order)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(set.setType == .warmup ? Theme.warn : Theme.inkSoft)
                .frame(width: 30, alignment: .leading)

            TextField("重量", value: $set.weight, format: .number.precision(.fractionLength(0...1)))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .textFieldStyle(.roundedBorder)
                .frame(width: 62)

            Text("kg")
                .font(.caption2)
                .foregroundStyle(Theme.inkFaint)

            TextField("次数", value: $set.reps, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .textFieldStyle(.roundedBorder)
                .frame(width: 44)

            Text("次")
                .font(.caption2)
                .foregroundStyle(Theme.inkFaint)

            rpeMenu

            Spacer(minLength: 0)

            Button {
                set.isCompleted.toggle()
                if set.isCompleted { onComplete() }
                try? set.modelContext?.save()
            } label: {
                Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(set.isCompleted ? Theme.good : Theme.inkFaint)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                L10n.setAccessibility(
                    warmup: set.setType == .warmup,
                    index: set.order,
                    completed: set.isCompleted
                )
            )
        }
    }

    private var rpeMenu: some View {
        Menu {
            Button("不记录") { set.rpe = nil }
            ForEach(rpeOptions, id: \.self) { value in
                Button(L10n.rpeLabel(Fmt.kg(value))) { set.rpe = value }
            }
        } label: {
            Text(set.rpe.map { L10n.rpeLabel(Fmt.kg($0)) } ?? "RPE")
                .font(.caption2.weight(.medium))
                .foregroundStyle(set.rpe == nil ? Theme.inkFaint : Theme.ink)
                .frame(width: 56)
        }
    }
}
