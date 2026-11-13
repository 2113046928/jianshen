import SwiftData
import SwiftUI

struct BodyCompositionView: View {
    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]

    private var profile: UserProfile? { profiles.first }
    private var sex: Sex { Sex(rawValue: profile?.sexRaw ?? "") ?? .male }
    private var age: Int { profile?.age ?? 30 }
    private var height: Double { profile?.heightCM ?? 175 }
    private var weight: Double { profile?.bodyweight ?? 70 }

    private var waist: Double { profile?.waistCM ?? 80 }
    private var neck: Double { profile?.neckCM ?? 38 }
    private var hip: Double { profile?.hipCM ?? 95 }

    // MARK: - 计算

    private var bmi: Double { BodyComposition.bmi(weightKG: weight, heightCM: height) }

    private var deurenberg: Double {
        BodyComposition.deurenberg(weightKG: weight, heightCM: height, age: age, sex: sex)
    }

    private var navy: Double? {
        BodyComposition.navy(
            waistCM: waist,
            neckCM: neck,
            hipCM: sex == .female ? hip : nil,
            heightCM: height,
            sex: sex
        )
    }

    private var primaryPercent: Double { navy ?? deurenberg }

    private var leanKG: Double {
        BodyComposition.leanMass(weightKG: weight, bodyFatPercent: primaryPercent)
    }

    private var fatKG: Double {
        BodyComposition.fatMass(weightKG: weight, bodyFatPercent: primaryPercent)
    }

    private var ffmi: Double {
        BodyComposition.ffmi(leanKG: leanKG, heightCM: height)
    }

    private var ffmiNormalized: Double {
        BodyComposition.normalizedFFMI(leanKG: leanKG, heightCM: height)
    }

    private var category: BodyFatCategory {
        BodyComposition.category(bodyFatPercent: primaryPercent, sex: sex)
    }

    private var targets: [(percent: Double, weight: Double)] {
        let goals: [Double] = sex == .male ? [10, 12, 15, 18] : [20, 24, 28, 32]
        return goals.compactMap { goal in
            BodyComposition.targetWeight(leanKG: leanKG, targetBodyFatPercent: goal)
                .map { (percent: goal, weight: $0) }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.gap) {
                resultCard
                measureCard
                compositionCard
                targetCard
                methodCard
            }
            .padding(.horizontal, Theme.pad)
            .padding(.top, 4)
            .padding(.bottom, 28)
        }
        .background(Theme.bg)
        .navigationTitle("身体成分")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 结果

    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(navy == nil ? "由 BMI 估算" : "围度法估算")
                    .microLabel()
                    .foregroundColor(Theme.onDarkFaint)
                Spacer()
                Text(category.title)
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Theme.accent)
                    .foregroundStyle(Theme.onAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: "%.1f", primaryPercent))
                    .heroNumber(size: 56)
                    .foregroundStyle(.white)
                Text("%")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.onDarkFaint)
                Spacer()
                Text("健康区间 \(Int(BodyComposition.healthyRange(sex: sex).lowerBound))–\(Int(BodyComposition.healthyRange(sex: sex).upperBound))%")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.onDarkFaint)
            }

            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(height: 1)

            HStack(spacing: 0) {
                darkStat("BMI", String(format: "%.1f", bmi))
                darkDivider()
                darkStat("瘦体重", String(format: "%.1f", leanKG), unit: "kg")
                darkDivider()
                darkStat("脂肪量", String(format: "%.1f", fatKG), unit: "kg")
            }
        }
        .darkCard()
    }

    private func darkStat(_ title: String, _ value: String, unit: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .microLabel()
                .foregroundColor(Theme.onDarkFaint)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .tabular(size: 21, weight: .bold)
                    .foregroundStyle(.white)
                if let unit {
                    Text(unit)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.onDarkFaint)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func darkDivider() -> some View {
        Rectangle()
            .fill(Color.white.opacity(0.12))
            .frame(width: 1, height: 30)
            .padding(.horizontal, 14)
    }

    // MARK: - 围度

    private var measureCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("围度（可选）")
                    .microLabel()
                    .foregroundColor(Theme.inkFaint)
                Spacer()
                Text("量对了误差能到 ±3%")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.inkGhost)
            }

            measureRow("腰围", value: waistBinding, range: 50...180)
            measureRow("颈围", value: neckBinding, range: 25...60)
            if sex == .female {
                measureRow("臀围", value: hipBinding, range: 60...180)
            }

            if navy == nil {
                Text("腰围需要大于颈围才能计算；女性还需要臀围。")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.warn)
            }
        }
        .card()
    }

    private func measureRow(_ title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.ink)
            Spacer()
            Stepper(value: value, in: range, step: 0.5) {
                Text("\(String(format: "%.1f", value.wrappedValue)) cm")
                    .tabular(size: 14, weight: .semibold)
                    .foregroundStyle(Theme.inkSoft)
            }
            .labelsHidden()
            Text("\(String(format: "%.1f", value.wrappedValue)) cm")
                .tabular(size: 14, weight: .semibold)
                .foregroundStyle(Theme.inkSoft)
                .frame(width: 64, alignment: .trailing)
        }
    }

    // MARK: - 组成

    private var compositionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("去脂体重指数")
                    .microLabel()
                    .foregroundColor(Theme.inkFaint)
                Spacer()
                Text("FFMI")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.inkGhost)
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(String(format: "%.1f", ffmi))
                    .heroNumber(size: 34)
                    .foregroundStyle(Theme.ink)
                Text("归一化 \(String(format: "%.1f", ffmiNormalized))")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.inkGhost)
                Spacer()
            }

            Text("FFMI 20–22 常见于规律训练者，23 以上通常意味着多年训练或用药；这个指标不适用未成年人。")
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.inkFaint)
                .fixedSize(horizontal: false, vertical: true)
        }
        .card()
    }

    // MARK: - 目标体重

    private var targetCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("目标体重")
                    .microLabel()
                    .foregroundColor(Theme.inkFaint)
                Spacer()
                Text("假设瘦体重不变")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.inkGhost)
            }

            ForEach(Array(targets.enumerated()), id: \.offset) { pair in
                HStack {
                    Text("\(Int(pair.element.percent))%")
                        .tabular(size: 14, weight: .semibold)
                        .foregroundStyle(Theme.inkSoft)
                        .frame(width: 44, alignment: .leading)
                    Text(String(format: "%.1f kg", pair.element.weight))
                        .tabular(size: 14, weight: .bold)
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Text(delta(pair.element.weight))
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(deltaTint(pair.element.weight))
                }
                .padding(.vertical, 2)
            }
        }
        .card()
    }

    private func delta(_ target: Double) -> String {
        let diff = target - weight
        let sign = diff >= 0 ? "+" : "−"
        return "\(sign)\(String(format: "%.1f", abs(diff))) kg"
    }

    private func deltaTint(_ target: Double) -> Color {
        target >= weight ? Theme.warn : Theme.good
    }

    // MARK: - 方法说明

    private var methodCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("这个数字怎么来的")
                .microLabel()
                .foregroundColor(Theme.inkFaint)

            Text("围度法（US Navy）用腰围、颈围和身高做对数回归，误差约 ±3%；只填身高体重时用 Deurenberg 公式，误差约 ±4–5%。两个都只是估算，比绝对数值更重要的是同一方法下的变化趋势。")
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)

            Text("同一时间、同一状态测量：早晨空腹、呼气末量腰围，软尺贴皮不勒。这样下周的数字才可比。")
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .card()
    }

    // MARK: - 绑定

    private var waistBinding: Binding<Double> {
        Binding(
            get: { profile?.waistCM ?? 80 },
            set: { profile?.waistCM = $0; try? context.save() }
        )
    }

    private var neckBinding: Binding<Double> {
        Binding(
            get: { profile?.neckCM ?? 38 },
            set: { profile?.neckCM = $0; try? context.save() }
        )
    }

    private var hipBinding: Binding<Double> {
        Binding(
            get: { profile?.hipCM ?? 95 },
            set: { profile?.hipCM = $0; try? context.save() }
        )
    }
}

#Preview {
    NavigationStack {
        BodyCompositionView()
    }
    .modelContainer(PreviewData.container)
}
