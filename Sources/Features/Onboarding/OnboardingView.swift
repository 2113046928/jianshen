import SwiftData
import SwiftUI

struct OnboardingView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [UserProfile]

    @State private var step = 0
    @State private var answers = OnboardingAnswers()

    private let totalSteps = 5

    private var plan: OnboardingPlan { OnboardingPlanner.plan(for: answers) }

    var body: some View {
        VStack(spacing: 0) {
            progress

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    stepContent
                }
                .padding(Theme.pad)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            footer
        }
        .background(Theme.bg)
    }

    // MARK: - 进度

    private var progress: some View {
        VStack(spacing: 10) {
            HStack(spacing: 6) {
                ForEach(0..<totalSteps, id: \.self) { index in
                    Capsule()
                        .fill(index <= step ? Theme.accent : Theme.line)
                        .frame(height: 4)
                }
            }
            HStack {
                Text(L10n.stepProgress(current: step + 1, total: totalSteps))
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)
                Spacer()
                if step < totalSteps - 1 {
                    Button("跳过") { finish() }
                        .font(.caption)
                        .foregroundStyle(Theme.inkFaint)
                }
            }
        }
        .padding(.horizontal, Theme.pad)
        .padding(.top, 12)
    }

    // MARK: - 各步内容

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case 0:
            question("你现在的目标是？", "会影响热量策略与训练结构，之后随时能改。")
            ForEach(TrainingGoal.allCases) { goal in
                option(
                    title: goal.title,
                    subtitle: goal.subtitle,
                    selected: answers.goal == goal
                ) {
                    answers.goal = goal
                }
            }
        case 1:
            question("每周能练几次？", "按真实能保证的次数选，选多了反而容易断。")
            daysGrid
        case 2:
            question("你能用到的器械？", "决定了给你排杠铃动作还是哑铃动作。")
            ForEach(EquipmentAccess.allCases) { item in
                option(
                    title: item.title,
                    subtitle: item.subtitle,
                    selected: answers.equipment == item
                ) {
                    answers.equipment = item
                }
            }
        case 3:
            question("训练经验？", "新手会先排全身训练，避免一上来就分化。")
            ForEach(ExperienceLevel.allCases) { item in
                option(
                    title: item.title,
                    subtitle: item == .beginner ? "还在学动作" : (item == .intermediate ? "动作熟练，能自己安排" : "有自己的节奏"),
                    selected: answers.experience == item
                ) {
                    answers.experience = item
                }
            }
        default:
            question("体重多少？", "用于估算 1RM 与力量等级，只存在本机。")
            weightPicker
            planPreview
        }
    }

    private func question(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.ink)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(Theme.inkSoft)
        }
    }

    private func option(
        title: String,
        subtitle: String,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.ink)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft)
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? Theme.accent : Theme.line)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(selected ? Theme.accent : Theme.line, lineWidth: selected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var daysGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
            ForEach(2...6, id: \.self) { day in
                Button {
                    answers.daysPerWeek = day
                } label: {
                    VStack(spacing: 3) {
                        Text("\(day)")
                            .font(.title3.weight(.semibold))
                        Text("次 / 周")
                            .font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(answers.daysPerWeek == day ? Theme.solid : Theme.card)
                    .foregroundStyle(answers.daysPerWeek == day ? .white : Theme.ink)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var weightPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(Fmt.kg(answers.bodyweight))
                    .font(.system(.largeTitle, design: .rounded).weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Text("kg")
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSoft)
            }
            Slider(value: $answers.bodyweight, in: 35...160, step: 0.5)
                .tint(Theme.accent)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var planPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("给你的建议")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.inkSoft)
            Text(plan.headline)
                .font(.headline)
                .foregroundStyle(Theme.ink)
            Text(plan.detail)
                .font(.caption)
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .card()
    }

    // MARK: - 底部按钮

    private var footer: some View {
        HStack(spacing: 10) {
            if step > 0 {
                Button {
                    step -= 1
                } label: {
                    Text("上一步")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.card)
                        .foregroundStyle(Theme.ink)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }

            Button {
                if step < totalSteps - 1 {
                    step += 1
                } else {
                    finish()
                }
            } label: {
                Text(step < totalSteps - 1 ? "下一步" : "开始训练")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.ink)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .padding(Theme.pad)
        .background(Theme.bg)
    }

    // MARK: - 保存

    private func finish() {
        guard let profile = profiles.first else {
            dismiss()
            return
        }
        let plan = OnboardingPlanner.plan(for: answers)
        profile.phase = plan.phase
        profile.weeklyGoal = plan.weeklyGoal
        profile.activeProgramID = plan.programID
        profile.bodyweight = answers.bodyweight
        profile.phaseStartedAt = .now
        profile.didOnboard = true
        context.insert(BodyMetric(date: .now, bodyweight: answers.bodyweight))
        try? context.save()
        dismiss()
    }
}

#Preview {
    OnboardingView()
        .modelContainer(PreviewData.container)
}
