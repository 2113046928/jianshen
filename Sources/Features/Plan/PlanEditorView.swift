import SwiftData
import SwiftUI

/// 编辑训练计划：改训练日、增删动作、调顺序。保存后立即生效。
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

    private var nameByID: [String: String] {
        Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0.name) })
    }

    var body: some View {
        List {
            Section {
                ForEach($draft.days) { $day in
                    NavigationLink {
                        DayEditorView(day: $day)
                    } label: {
                        row(for: day, nameByID: nameByID)
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
                Text("点某一天可以增删动作、调整顺序。左右滑动删除训练日。")
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
                let base = PlanStore.makeDraft(from: PlanStore.template(for: profile))
                draft = base
            }
            Button("取消", role: .cancel) {}
        }
    }

    private func row(for day: ProgramDay, nameByID: [String: String]) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(day.name.isEmpty ? "未命名训练日" : day.name)
                .font(.body.weight(.medium))
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

    private var nameByID: [String: String] {
        Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0.name) })
    }

    var body: some View {
        List {
            Section {
                TextField("训练日名称", text: $day.name)
                TextField("重点（例如：胸 · 肩 · 三头）", text: $day.focus)
            }

            Section {
                ForEach(day.exerciseIDs, id: \.self) { id in
                    HStack {
                        Text(nameByID[id] ?? id)
                        Spacer()
                        Text(patternText(for: id))
                            .font(.caption)
                            .foregroundStyle(Theme.inkFaint)
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
    }

    private func patternText(for id: String) -> String {
        guard let exercise = exercises.first(where: { $0.id == id }) else { return "" }
        return exercise.equipment.title
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
