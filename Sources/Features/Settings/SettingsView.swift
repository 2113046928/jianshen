import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]
    @Query(sort: \TrainingSession.startedAt, order: .reverse) private var sessions: [TrainingSession]

    @StateObject private var purchases = PurchaseService()

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        Form {
            trainingSection
            phaseSection
            programSection
            purchaseSection
            toolSection
            programPackSection
            BackupSection()
            aboutSection
        }
        .navigationTitle("我的")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await purchases.load()
        }
    }

    // MARK: - 训练

    private var trainingSection: some View {
        Section("训练") {
            Picker("当前阶段", selection: phaseBinding) {
                ForEach(Phase.allCases) { phase in
                    Text(phase.title).tag(phase)
                }
            }

            Stepper(value: goalBinding, in: 1...7) {
                HStack {
                    Text("每周目标")
                    Spacer()
                    Text(L10n.weeklyGoalValue(profile?.weeklyGoal ?? 3))
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Text("体重")
                Spacer()
                TextField(
                    "kg",
                    value: bodyweightBinding,
                    format: .number.precision(.fractionLength(0...1))
                )
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
                Text("kg").foregroundStyle(.secondary)
            }

            Button {
                recordBodyweight()
            } label: {
                Label("记录今天体重", systemImage: "scalemass")
            }

            Text((profile?.phase ?? .bulk).summary)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var phaseSection: some View {
        Section("阶段") {
            NavigationLink {
                PhaseView()
            } label: {
                HStack {
                    Label("阶段与力量保持率", systemImage: "chart.line.downtrend.xyaxis")
                    Spacer()
                    Text("查看")
                        .font(.caption)
                        .foregroundStyle(Theme.accent)
                }
            }
        }
    }

    // MARK: - 计划

    private var programSection: some View {
        Section("训练计划") {
            Picker("模板", selection: programBinding) {
                ForEach(ProgramCatalog.all(unlocked: profile?.unlockedProgramIDs ?? [])) { template in
                    Text(L10n.templateOption(name: template.name, days: template.days.count)).tag(template.id)
                }
            }
            Text(ProgramCatalog.template(id: profile?.activeProgramID ?? "ppl", unlocked: profile?.unlockedProgramIDs ?? []).subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - 购买

    private var toolSection: some View {
        Section("工具") {
            NavigationLink {
                BodyCompositionView()
            } label: {
                Label("体脂率与瘦体重", systemImage: "figure.arms.open")
            }

            NavigationLink {
                FormCheckView()
            } label: {
                Label("动作评估（深蹲）", systemImage: "figure.gymnastics")
            }
        }
    }

    private var programPackSection: some View {
        Section("计划包") {
            NavigationLink {
                PackStoreView()
            } label: {
                HStack {
                    Label("按目标买计划", systemImage: "square.stack.3d.up")
                    Spacer()
                    Text(L10n.unlockedCount(profile?.unlockedProgramIDs.count ?? 0))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var purchaseSection: some View {
        Section("升级") {
            NavigationLink {
                PaywallView()
            } label: {
                HStack {
                    Label("练账 Pro", systemImage: "bolt.fill")
                    Spacer()
                    Text(purchases.isPurchased ? "已解锁" : "买断")
                        .font(.caption)
                        .foregroundStyle(purchases.isPurchased ? Theme.good : Theme.accent)
                }
            }
        }
    }

    // MARK: - 关于

    private var aboutSection: some View {
        Section("关于") {
            HStack {
                Text("版本")
                Spacer()
                Text(version)
                    .foregroundStyle(.secondary)
            }
            NavigationLink("隐私说明") {
                PrivacyView()
            }
        }
    }

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "0.1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }

    // MARK: - 绑定

    private var phaseBinding: Binding<Phase> {
        Binding(
            get: { profile?.phase ?? .bulk },
            set: { newValue in
                guard let profile else { return }
                if profile.phase != newValue {
                    profile.phase = newValue
                    // 切换阶段的那一刻，作为力量保持率的起点
                    profile.phaseStartedAt = .now
                }
                try? context.save()
            }
        )
    }

    /// 同一天重复记录就覆盖，避免体重曲线出现锯齿
    private func recordBodyweight() {
        guard let profile else { return }
        let calendar = Calendar.current
        let todayMetric = (try? context.fetch(FetchDescriptor<BodyMetric>()))?
            .first { calendar.isDateInToday(.date) }
        if let todayMetric {
            todayMetric.bodyweight = profile.bodyweight
        } else {
            context.insert(BodyMetric(date: .now, bodyweight: profile.bodyweight))
        }
        try? context.save()
    }

    private var goalBinding: Binding<Int> {
        Binding(
            get: { profile?.weeklyGoal ?? 3 },
            set: { newValue in
                profile?.weeklyGoal = newValue
                try? context.save()
            }
        )
    }

    private var bodyweightBinding: Binding<Double> {
        Binding(
            get: { profile?.bodyweight ?? 70 },
            set: { newValue in
                profile?.bodyweight = newValue
                try? context.save()
            }
        )
    }

    private var programBinding: Binding<String> {
        Binding(
            get: { profile?.activeProgramID ?? "ppl" },
            set: { newValue in
                profile?.activeProgramID = newValue
                try? context.save()
            }
        )
    }

}

// MARK: - 隐私说明

struct PrivacyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("数据只存在你的设备上")
                    .font(.headline)
                Text("练账不设账号、不上传训练数据。你的动作、组数、重量、体重和备注全部保存在本机数据库里，只有你本人能读取。")
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSoft)

                Text("关于 AI 建议")
                    .font(.headline)
                    .padding(.top, 6)
                Text("配重与容量建议由设备上的规则引擎计算，不联网、不调用云端模型。建议基于你过去几次训练记录，仅供参考，不构成医疗或康复建议。出现疼痛或伤病请就医。")
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSoft)

                Text("关于导出与删除")
                    .font(.headline)
                    .padding(.top, 6)
                Text("你可以随时把训练数据导出为 CSV，或删除全部训练记录。删除 App 会同时删除数据。")
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSoft)
            }
            .padding(Theme.pad)
        }
        .navigationTitle("隐私说明")
        .navigationBarTitleDisplayMode(.inline)
        .background(Theme.bg)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .modelContainer(PreviewData.container)
}
