import SwiftData
import SwiftUI

/// 动作库：搜索 + 按动作模式分组，点进去看示意图与要领。
struct ExerciseLibraryView: View {
    @Query(sort: \Exercise.sortIndex) private var exercises: [Exercise]
    @State private var query = ""

    private var filtered: [Exercise] {
        let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !needle.isEmpty else { return exercises }
        return exercises.filter { $0.searchText.contains(needle) }
    }

    private var groups: [(pattern: MovementPattern, items: [Exercise])] {
        MovementPattern.allCases.compactMap { pattern in
            let items = filtered.filter { $0.pattern == pattern }
            return items.isEmpty ? nil : (pattern, items)
        }
    }

    var body: some View {
        List {
            ForEach(groups, id: \.pattern) { group in
                Section {
                    ForEach(group.items) { exercise in
                        NavigationLink {
                            ExerciseDetailView(exercise: exercise)
                        } label: {
                            row(exercise)
                        }
                    }
                } header: {
                    HStack {
                        Text(group.pattern.title)
                        Spacer()
                        Text("\(group.items.count)")
                            .foregroundStyle(Theme.inkFaint)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $query, prompt: "搜索动作、器械或别名")
        .navigationTitle("动作库")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ exercise: Exercise) -> some View {
        HStack(spacing: 12) {
            thumbnail(exercise.pattern, size: CGSize(width: 72, height: 45))
            VStack(alignment: .leading, spacing: 3) {
                Text(exercise.name)
                Text("\(exercise.equipment.title) · \(exercise.targetReps.lowerBound)–\(exercise.targetReps.upperBound) 次")
                    .font(.caption)
                    .foregroundStyle(Theme.inkFaint)
            }
        }
    }
}

// MARK: - 详情

struct ExerciseDetailView: View {
    let exercise: Exercise

    @Query(sort: \TrainingSession.startedAt, order: .reverse) private var sessions: [TrainingSession]

    private var guide: ExerciseGuide? {
        ExerciseGuideStore.guide(for: exercise.pattern)
    }

    /// 最近一次该动作的正式组
    private var lastSets: [SetSnapshot] {
        HistoryMapping.lastWorkingSets(for: exercise.id, in: sessions)
    }

    private var lastBest: (weight: Double, reps: Int, oneRepMax: Double)? {
        lastSets
            .map { ($0.weight, $0.reps, StrengthEstimate.oneRepMax(weight: $0.weight, reps: $0.reps)) }
            .max { $0.2 < $1.2 }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Image(ExerciseGuideStore.imageName(for: exercise.pattern))
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .background(Theme.bg)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text(exercise.name)
                        .font(.system(size: 26, weight: .bold))
                        .tracking(-0.5)
                    HStack(spacing: 6) {
                        Pill(text: exercise.pattern.title, color: Theme.ink)
                        Pill(text: exercise.equipment.title, color: Theme.inkSoft)
                        if exercise.isCompound {
                            Pill(text: "复合", color: Theme.accent)
                        }
                    }
                }

                HStack(spacing: 0) {
                    stat("目标次数", "\(exercise.targetReps.lowerBound)–\(exercise.targetReps.upperBound)")
                    divider()
                    stat("组间休息", "\(exercise.defaultRestSeconds)s")
                    divider()
                    stat("递增", "\(Fmt.kg(exercise.loadIncrement))kg")
                }
                .card()

                if let guide {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("动作要领")
                            .microLabel()
                            .foregroundColor(Theme.inkFaint)
                        guidanceRow("起始", guide.setup, Theme.ink)
                        guidanceRow("执行", guide.execution, Theme.accent)
                        guidanceRow("常见错误", guide.mistake, Theme.warn)
                        guidanceRow("呼吸", guide.breathing, Theme.inkSoft)
                    }
                    .card()
                }

                if let lastBest {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("你的记录")
                            .microLabel()
                            .foregroundColor(Theme.inkFaint)
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("\(Fmt.kg(lastBest.weight))")
                                .heroNumber(size: 34)
                                .foregroundStyle(Theme.ink)
                            Text("kg × \(lastBest.reps)")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Theme.inkSoft)
                            Spacer()
                            Text("估算 1RM \(Fmt.kg(lastBest.oneRepMax))")
                                .font(.caption)
                                .foregroundStyle(Theme.inkFaint)
                        }
                    }
                    .card()
                }

                Text("示意图为动作模式的简化示意，用于理解发力方向，不代替专业指导。")
                    .font(.caption2)
                    .foregroundStyle(Theme.inkFaint)
            }
            .padding(Theme.pad)
        }
        .background(Theme.bg)
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .microLabel()
                .foregroundColor(Theme.inkFaint)
            Text(value)
                .tabular(size: 17, weight: .bold)
                .foregroundStyle(Theme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func divider() -> some View {
        Rectangle()
            .fill(Theme.hair)
            .frame(width: 1, height: 28)
            .padding(.horizontal, 12)
    }

    private func guidanceRow(_ title: String, _ text: String, _ tint: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 56, alignment: .leading)
            Text(text)
                .font(.system(size: 13.5))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - 共用缩略图

func thumbnail(_ pattern: MovementPattern, size: CGSize) -> some View {
    Image(ExerciseGuideStore.imageName(for: pattern))
        .resizable()
        .scaledToFill()
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
}
