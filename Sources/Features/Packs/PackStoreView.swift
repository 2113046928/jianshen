import SwiftData
import SwiftUI

struct PackStoreView: View {
    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]
    @StateObject private var store = PackStore.shared

    private var profile: UserProfile? { profiles.first }
    private var unlocked: [String] { profile?.unlockedProgramIDs ?? [] }
    private var activeID: String { profile?.activeProgramID ?? "ppl" }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                ForEach(store.packs) { pack in
                    packCard(pack)
                }
                footer
            }
            .padding(Theme.pad)
        }
        .background(Theme.bg)
        .navigationTitle("计划包")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await store.loadProducts()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("按目标买计划，不用买订阅")
                .font(.title3.weight(.semibold))
            Text("计划包是一次性买断，买完永久可用，也会自动成为当前训练计划。")
                .font(.caption)
                .foregroundStyle(Theme.inkSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func packCard(_ pack: ProgramPack) -> some View {
        let isUnlocked = unlocked.contains(pack.id)
        let isActive = activeID == pack.id

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(pack.name)
                    .font(.headline)
                Spacer()
                if isActive {
                    Pill(text: "正在使用", color: Theme.good)
                } else if isUnlocked {
                    Pill(text: "已解锁", color: Theme.ink)
                }
            }

            Text(L10n.packMeta(weeks: pack.weeks, days: pack.template.days.count, coach: pack.coach))
                .font(.caption2)
                .foregroundStyle(Theme.inkFaint)

            Text(pack.summary)
                .font(.caption)
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Text(dayPreview(pack))
                    .font(.caption2)
                    .foregroundStyle(Theme.inkFaint)
                Spacer()
            }

            if isUnlocked {
                Button {
                    store.activate(pack, profile: profile, context: context)
                } label: {
                    Text(isActive ? "当前计划" : "设为当前计划")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(isActive ? Theme.bg : Theme.ink)
                        .foregroundStyle(isActive ? Theme.inkSoft : .white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .disabled(isActive)
            } else {
                Button {
                    Task { await store.purchase(pack, profile: profile, context: context) }
                } label: {
                    HStack {
                        Text(store.purchasingID == pack.id ? "处理中…" : "解锁")
                        Spacer()
                        Text(store.price(for: pack))
                    }
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(Theme.accent)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .disabled(store.purchasingID != nil)
            }
        }
        .card()
    }

    private func dayPreview(_ pack: ProgramPack) -> String {
        pack.template.days.map { "\($0.name)：\($0.exerciseIDs.count) 个动作" }.joined(separator: "  ")
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button("恢复购买") {
                Task { await store.restore(profile: profile, context: context) }
            }
            .font(.caption)

            if let message = store.message {
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(Theme.inkFaint)
            }

            Text("计划包只包含训练安排，不包含任何云端服务；购买记录由 App Store 管理。")
                .font(.caption2)
                .foregroundStyle(Theme.inkFaint)

            #if DEBUG
            Button("本地解锁（仅调试）") {
                for pack in store.packs {
                    if !unlocked.contains(pack.id) {
                        profile?.unlockedProgramIDs.append(pack.id)
                    }
                }
                try? context.save()
            }
            .font(.caption2)
            .foregroundStyle(Theme.warn)
            #endif
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    NavigationStack {
        PackStoreView()
    }
    .modelContainer(PreviewData.container)
}
