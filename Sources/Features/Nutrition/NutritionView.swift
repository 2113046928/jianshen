import SwiftData
import SwiftUI

struct NutritionView: View {
    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]
    @Query(sort: \BodyMetric.date, order: .forward) private var metrics: [BodyMetric]

    private var profile: UserProfile? { profiles.first }
    private var phase: Phase { profile?.phase ?? .bulk }

    // MARK: - 计算

    private var bodyProfile: BodyProfile {
        BodyProfile(
            sex: Sex(rawValue: profile?.sexRaw ?? "") ?? .male,
            age: profile?.age ?? 30,
            heightCM: profile?.heightCM ?? 175,
            weightKG: profile?.bodyweight ?? 70,
            activity: ActivityLevel(rawValue: profile?.activityRaw ?? "") ?? .moderate
        )
    }

    private var plan: NutritionPlan {
        NutritionEngine.plan(for: bodyProfile, phase: phase)
    }

    private var meals: [Double] {
        NutritionEngine.mealSplit(calories: plan.targets.calories, meals: 4)
    }

    private var proteinPerMeal: Double {
        plan.targets.proteinG / Double(max(meals.count, 1))
    }

    /// 最近 7 天相对前 7 天的体重变化比例
    private var weeklyChangePercent: Double? {
        guard metrics.count >= 2 else { return nil }
        let calendar = Calendar.current
        let now = Date.now
        guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) else { return nil }
        let recent = metrics.filter { $0.date >= weekAgo }
        let earlier = metrics.filter { $0.date < weekAgo }
        guard let recentAvg = average(recent.map(\.bodyweight)),
              let earlierAvg = average(earlier.map(\.bodyweight)),
              earlierAvg > 0 else { return nil }
        return (recentAvg - earlierAvg) / earlierAvg
    }

    private var adjustment: (action: NutritionAdjustment, advice: String)? {
        guard let change = weeklyChangePercent else { return nil }
        return NutritionEngine.weeklyAdjustment(weeklyChangePercent: change, phase: phase)
    }

    private func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    // MARK: - 视图

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    targetCard
                    macroCard
                    mealCard
                    if let adjustment {
                        adjustCard(adjustment)
                    }
                    bodyCard
                    bodyFatCard
                    foodCard
                }
                .padding(Theme.pad)
            }
            .background(Theme.bg)
            .navigationTitle("饮食")
        }
    }

    // MARK: 目标

    private var targetCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text("每日目标")
                    .microLabel()
                    .foregroundColor(Theme.onDarkFaint)
                Spacer()
                Text(phase.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.onDarkSoft)
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(Int(plan.targets.calories.rounded()))")
                    .heroNumber(size: 56)
                    .foregroundStyle(.white)
                Text("千卡")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.onDarkSoft)
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(L10n.bmrLine(bmr: Fmt.kg(plan.bmr), tdee: Fmt.kg(plan.tdee)))
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.onDarkFaint)
                    Text("蛋白 \(Int(plan.targets.proteinG.rounded()))g · 脂肪 \(Int(plan.targets.fatG.rounded()))g · 碳水 \(Int(plan.targets.carbsG.rounded()))g")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                }
            }

            if !plan.notes.isEmpty {
                ForEach(Array(plan.notes.enumerated()), id: \.offset) { pair in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.circle")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.warn)
                            .padding(.top, 2)
                        Text(pair.element)
                            .font(.system(size: 11.5))
                            .foregroundStyle(.white.opacity(0.72))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .darkCard()
    }

    // MARK: 宏量

    private var macroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "三大营养素", subtitle: "按体重分配，减脂期蛋白拉到上限")
            macroRow("蛋白质", grams: plan.targets.proteinG, kcalPerGram: 4, tint: Theme.accent)
            macroRow("脂肪", grams: plan.targets.fatG, kcalPerGram: 9, tint: Theme.warn)
            macroRow("碳水", grams: plan.targets.carbsG, kcalPerGram: 4, tint: Theme.good)

            Text(L10n.proteinQualityNote(
                perKg: String(format: "%.1f", plan.targets.proteinPerKg),
                kcal: "\(Int(plan.targets.caloriesFromMacros.rounded()))"
            ))
                .font(.caption2)
                .foregroundStyle(Theme.inkFaint)
        }
        .card()
    }

    private func macroRow(_ title: String, grams: Double, kcalPerGram: Double, tint: Color) -> some View {
        let kcal = grams * kcalPerGram
        let share = plan.targets.calories > 0 ? kcal / plan.targets.calories : 0

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text("\(Int(grams.rounded())) g")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint)
                Text("\(Int((share * 100).rounded()))%")
                    .font(.caption2)
                    .foregroundStyle(Theme.inkFaint)
                    .frame(width: 34, alignment: .trailing)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.bg)
                    Capsule()
                        .fill(tint.opacity(0.85))
                        .frame(width: max(4, proxy.size.width * min(share, 1)))
                }
            }
            .frame(height: 7)
        }
    }

    // MARK: 餐次

    private var mealCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "分到四餐", subtitle: "每餐约 \(Int(proteinPerMeal.rounded()))g 蛋白")
            ForEach(Array(meals.enumerated()), id: \.offset) { pair in
                HStack {
                    Text(mealTitle(pair.offset))
                        .font(.subheadline)
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Text("\(Int(pair.element.rounded())) 千卡")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.inkSoft)
                    Text(L10n.proteinApprox("\(Int(proteinForMeal(pair.offset).rounded()))"))
                        .font(.caption2)
                        .foregroundStyle(Theme.inkFaint)
                        .frame(width: 62, alignment: .trailing)
                }
            }
            Text("加餐放在训练后 1 小时内，蛋白和碳水一起吃。")
                .font(.caption2)
                .foregroundStyle(Theme.inkFaint)
        }
        .card()
    }

    /// 按各餐热量比例分配蛋白
    private func proteinForMeal(_ index: Int) -> Double {
        let total = meals.reduce(0, +)
        guard total > 0, index < meals.count else { return proteinPerMeal }
        return plan.targets.proteinG * meals[index] / total
    }

    private func mealTitle(_ index: Int) -> String {
        ["早餐", "午餐", "晚餐", "加餐"][safe: index] ?? "第 \(index + 1) 餐"
    }

    // MARK: 调整建议

    private func adjustCard(_ value: (action: NutritionAdjustment, advice: String)) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "本周调整", subtitle: "按体重趋势调，不按感觉调")
            HStack(spacing: 8) {
                Pill(
                    text: value.action.title,
                    color: value.action == .hold ? Theme.good : Theme.warn
                )
                if let change = weeklyChangePercent {
                    Text(L10n.weeklyChangePart(String(format: "%+.2f", change * 100)))
                        .font(.caption2)
                        .foregroundStyle(Theme.inkFaint)
                }
                Spacer()
            }
            Text(value.advice)
                .font(.caption)
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .card()
    }

    // MARK: 身体数据

    private var bodyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "身体数据", subtitle: "用于计算基础代谢，只存在本机")

            Picker("性别", selection: sexBinding) {
                ForEach(Sex.allCases) { sex in
                    Text(sex.title).tag(sex)
                }
            }
            .pickerStyle(.segmented)

            HStack {
                Text("年龄")
                Spacer()
                Stepper("\(profile?.age ?? 30)", value: ageBinding, in: 14...80)
                    .labelsHidden()
                Text("\(profile?.age ?? 30)")
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 34, alignment: .trailing)
            }

            HStack {
                Text("身高")
                Spacer()
                Stepper(
                    "\(Int((profile?.heightCM ?? 175).rounded())) cm",
                    value: heightBinding,
                    in: 140...210,
                    step: 1
                )
                .labelsHidden()
                Text("\(Int((profile?.heightCM ?? 175).rounded())) cm")
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 62, alignment: .trailing)
            }

            Picker("日常活动", selection: activityBinding) {
                ForEach(ActivityLevel.allCases) { level in
                    Text(level.title).tag(level)
                }
            }

            Text((ActivityLevel(rawValue: profile?.activityRaw ?? "") ?? .moderate).detail)
                .font(.caption2)
                .foregroundStyle(Theme.inkFaint)
        }
        .card()
    }

    // MARK: 体脂率入口

    private var bodyFatCard: some View {
        NavigationLink {
            BodyCompositionView()
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("体脂率与瘦体重")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text("按围度或 BMI 估算，算完能看目标体重")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.inkFaint)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.inkGhost)
            }
            .card()
        }
        .buttonStyle(.plain)
    }

    // MARK: 蛋白参照

    private var foodCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: "一餐蛋白怎么凑",
                subtitle: "约 \(Int(proteinPerMeal.rounded()))g 蛋白相当于"
            )
            ForEach(FoodCatalog.suggestions(forProtein: proteinPerMeal)) { suggestion in
                HStack {
                    Text(suggestion.item.name)
                        .font(.subheadline)
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Text("\(Int(suggestion.grams)) g")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.inkSoft)
                }
                .padding(.vertical, 1)
            }
            Text("生重参考，来自内置的小参照表，不是食物数据库。日常不必称重，按这个量级估就行。")
                .font(.caption2)
                .foregroundStyle(Theme.inkFaint)
        }
        .card()
    }

    // MARK: - 绑定

    private var sexBinding: Binding<Sex> {
        Binding(
            get: { Sex(rawValue: profile?.sexRaw ?? "") ?? .male },
            set: { profile?.sexRaw = $0.rawValue; try? context.save() }
        )
    }

    private var ageBinding: Binding<Int> {
        Binding(
            get: { profile?.age ?? 30 },
            set: { profile?.age = $0; try? context.save() }
        )
    }

    private var heightBinding: Binding<Double> {
        Binding(
            get: { profile?.heightCM ?? 175 },
            set: { profile?.heightCM = $0; try? context.save() }
        )
    }

    private var activityBinding: Binding<ActivityLevel> {
        Binding(
            get: { ActivityLevel(rawValue: profile?.activityRaw ?? "") ?? .moderate },
            set: { profile?.activityRaw = $0.rawValue; try? context.save() }
        )
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    NutritionView()
        .modelContainer(PreviewData.container)
}
