import SwiftData
import SwiftUI

/// 编辑训练计划：改训练日、指定星期、增删动作、调顺序、一键换同类动作。
struct PlanEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.sortIndex) private var exercises: [Exercise]

    let profile: UserProfile

    @State private var draft: ProgramTemplate
    @State private var showResetConfirm = false

    init(profile: UserProfile) {
        self.profile = profile
        let existing = PlanStore.customTemplate(for: profile)
        let base = existing ?? PlanStore.makeDraft(from: PlanStore.template(for: profile))
        _draft = State(initialValue: base)
    }

    private var weekdayMode: Bool { PlanSchedule.usesWeekdays(draft) }

    var body: some View {
        List {
            Section {
                ForEach($draft.days) { $day in
                    NavigationLink {
                        DayEditorView(day: $day)
                    } label: {
                        row(for: day)
                    }
                }
                .onDelete { offsets in
                    draft.days.remove(atOffsets: offsets)
                    draft = PlanStore.normalized(draft)
                }
                .onMove { source, destination in
                    draft.days.move(fromOffsets: source, toOffset: destination)
                }

                Button {
                    draft.days.append(PlanStore.blankDay(index: draft.days.count + 1))
                    draft = PlanStore.normalized(draft)
                } label: {
                    Label("添加训练日", systemImage: "plus.circle")
                }
            } header: {
                Text("训练日")
            } footer: {
                if weekdayMode {
                    Text("已按星期排课：今天没有对应训练日就自动显示休息日。")
                } else {
                    Text("点某一天可以增删动作、指定星期。左右滑动删除训练日。")
                }
            }

            Section {
                Button("用当前预设重新开始") {
                    showResetConfirm = true
                }
                .foregroundStyle(Theme.danger)
            } footer: {
                Text("会丢弃你在这份自定义计划里做过的修改。")
            }
        }
        .navigationTitle("编辑训练计划")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                EditButton()
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("保存") {
                    PlanStore.save(PlanStore.normalized(draft), profile: profile, context: context)
                    dismiss()
                }
                .fontWeight(.semibold)
            }
        }
        .confirmationDialog("用当前预设重新开始？", isPresented: $showResetConfirm, titleVisibility: .visible) {
            Button("丢弃修改并重置", role: .destructive) {
                draft = PlanStore.makeDraft(from: PlanStore.template(for: profile))
            }
            Button("取消", role: .cancel) {}
        }
    }

    private func row(for day: ProgramDay) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(day.name.isEmpty ? "未命名训练日" : day.name)
                    .font(.body.weight(.medium))
                if let weekday = day.weekday {
                    Text(PlanSchedule.name(for: weekday))
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.accent.opacity(0.12))
                        .foregroundStyle(Theme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
            }
            HStack(spacing: 6) {
                if !day.focus.isEmpty {
                    Text(day.focus)
                }
                Text("\(day.exerciseIDs.count) 个动作")
            }
            .font(.caption)
            .foregroundStyle(day.exerciseIDs.isEmpty ? Theme.warn : Theme.inkSoft)
        }
    }
}

// MARK: - 单日编辑

private struct DayEditorView: View {
    @Binding var day: ProgramDay
    @Query(sort: \Exercise.sortIndex) private var exercises: [Exercise]

    @State private var showPicker = false
    @State private var swapBaseID = ""
    @State private var showSwap = false

    private var nameByID: [String: String] {
        Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0.name) })
    }

    private var weekdayBinding: Binding<Int> {
        Binding(
            get: { day.weekday ?? 0 },
            set: { day.weekday = $0 == 0 ? nil : $0 }
        )
    }

    var body: some View {
        List {
            Section {
                TextField("训练日名称", text: $day.name)
                TextField("重点（例如：胸 · 肩 · 三头）", text: $day.focus)
            }

            Section {
                Picker("固定星期", selection: weekdayBinding) {
                    Text("不指定（按完成次数轮转）").tag(0)
                    ForEach(1...7, id: \.self) { weekday in
                        Text(PlanSchedule.name(for: weekday)).tag(weekday)
                    }
                }
            } footer: {
                Text("给任意一天设了星期，整个计划就改为「按星期」；没设星期的日子就是休息日。")
            }

            Section {
                ForEach(day.exerciseIDs, id: \.self) { id in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(nameByID[id] ?? id)
                            Text(equipmentText(for: id))
                                .font(.caption)
                                .foregroundStyle(Theme.inkFaint)
                        }
                        Spacer()
                        Button {
                            swapBaseID = id
                            showSwap = true
                        } label: {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundStyle(Theme.accent)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("换成同类动作")
                    }
                }
                .onDelete { offsets in
                    day.exerciseIDs.remove(atOffsets: offsets)
                }
                .onMove { source, destination in
                    day.exerciseIDs.move(fromOffsets: source, toOffset: destination)
                }

                Button {
                    showPicker = true
                } label: {
                    Label("添加动作", systemImage: "plus.circle")
                }
            } header: {
                Text("动作")
            } footer: {
                if day.exerciseIDs.isEmpty {
                    Text("这一天还没有动作，练不了。至少要加一个。")
                        .foregroundStyle(Theme.warn)
                } else {
                    Text("点右边的循环图标可以换成同动作模式的替代动作。")
                }
            }
        }
        .navigationTitle(day.name.isEmpty ? "训练日" : day.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { EditButton() }
        .sheet(isPresented: $showPicker) {
            ExercisePickerView(existing: day.exerciseIDs) { id in
                day.exerciseIDs.append(id)
            }
        }
        .sheet(isPresented: $showSwap) {
            ExerciseSwapView(baseID: swapBaseID) { newID in
                replace(swapBaseID, with: newID)
            }
        }
    }

    private func equipmentText(for id: String) -> String {
        guard let exercise = exercises.first(where: { $0.id == id }) else { return "" }
        return "\(exercise.pattern.title) · \(exercise.equipment.title)"
    }

    private func replace(_ oldID: String, with newID: String) {
        guard let index = day.exerciseIDs.firstIndex(of: oldID),
              !day.exerciseIDs.contains(newID) else { return }
        day.exerciseIDs[index] = newID
    }
}

// MARK: - 换同类动作

private struct ExerciseSwapView: View {
    let baseID: String
    let onPick: (String) -> Void

    @Query(sort: \Exercise.sortIndex) private var exercises: [Exercise]
    @Environment(\.dismiss) private var dismiss

    private var base: Exercise? {
        exercises.first { $0.id == baseID }
    }

    private var alternatives: [Exercise] {
        guard let base else { return [] }
        return ExerciseSubstitution.alternatives(for: base, in: exercises)
    }

    var body: some View {
        NavigationStack {
            List {
                if let base {
                    Section("现在的动作") {
                        row(base, current: true)
                    }
                }

                Section("换成") {
                    if alternatives.isEmpty {
                        Text("动作库里没有合适的同类动作。")
                            .font(.caption)
                            .foregroundStyle(Theme.inkFaint)
                    } else {
                        ForEach(alternatives) { exercise in
                            Button {
                                onPick(exercise.id)
                                dismiss()
                            } label: {
                                row(exercise, current: false)
                            }
                        }
                    }
                }
            }
            .navigationTitle("换成同类动作")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func row(_ exercise: Exercise, current: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(exercise.name)
                    .foregroundStyle(Theme.ink)
                Text("\(exercise.pattern.title) · \(exercise.equipment.title) · \(exercise.targetReps.lowerBound)–\(exercise.targetReps.upperBound) 次")
                    .font(.caption)
                    .foregroundStyle(Theme.inkFaint)
            }
            Spacer()
            if current {
                Text("当前")
                    .font(.caption2)
                    .foregroundStyle(Theme.inkFaint)
            }
        }
    }
}

// MARK: - 选动作

private struct ExercisePickerView: View {
    let existing: [String]
    let onPick: (String) -> Void

    @Query(sort: \Exercise.sortIndex) private var exercises: [Exercise]
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var filtered: [Exercise] {
        let needle = query.trimmingCharacters(in: .whitespaces)
        guard !needle.isEmpty else { return exercises }
        return exercises.filter { $0.searchText.contains(needle.lowercased()) }
    }

    var body: some View {
        NavigationStack {
            List(filtered) { exercise in
                let already = existing.contains(exercise.id)
                Button {
                    onPick(exercise.id)
                    dismiss()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(exercise.name)
                                .foregroundStyle(Theme.ink)
                            Text("\(exercise.pattern.title) · \(exercise.equipment.title)")
                                .font(.caption)
                                .foregroundStyle(Theme.inkFaint)
                        }
                        Spacer()
                        if already {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Theme.good)
                        }
                    }
                }
                .disabled(already)
            }
            .searchable(text: $query, prompt: "搜索动作或器械")
            .navigationTitle("添加动作")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}
