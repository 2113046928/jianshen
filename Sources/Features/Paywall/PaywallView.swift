import SwiftUI

struct PaywallView: View {
    @StateObject private var purchases = PurchaseService()

    private struct Benefit: Identifiable {
        let id = UUID()
        let symbol: String
        let title: String
        let detail: String
    }

    private let benefits: [Benefit] = [
        Benefit(
            symbol: "arrow.up.right.circle.fill",
            title: "每组配重",
            detail: "根据上次的重量、次数和 RPE，算好下一次该加多少"
        ),
        Benefit(
            symbol: "chart.bar.fill",
            title: "进阶分析",
            detail: "肌群容量、力量趋势、估算 1RM 与 PR 时间线"
        ),
        Benefit(
            symbol: "figure.run",
            title: "减脂期力量保持率",
            detail: "区分掉的是脂肪还是肌肉，这是体重秤给不了的答案"
        ),
        Benefit(
            symbol: "square.and.arrow.up",
            title: "数据导出",
            detail: "随时导出 CSV，数据属于你，不被锁死"
        )
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                benefitList
                purchaseCard
                footerNote
            }
            .padding(Theme.pad)
        }
        .background(Theme.bg)
        .navigationTitle("练账 Pro")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await purchases.load()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("一次买断，不用订阅")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Theme.ink)
            Text("记录功能永久免费。Pro 解锁「算得清」的那部分：配重、分析、保持率。")
                .font(.subheadline)
                .foregroundStyle(Theme.inkSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var benefitList: some View {
        VStack(spacing: 14) {
            ForEach(benefits) { benefit in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: benefit.symbol)
                        .font(.title3)
                        .foregroundStyle(Theme.accent)
                        .frame(width: 26)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(benefit.title)
                            .font(.subheadline.weight(.semibold))
                        Text(benefit.detail)
                            .font(.caption)
                            .foregroundStyle(Theme.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .card()
    }

    private var purchaseCard: some View {
        VStack(spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(purchases.priceText)
                    .font(.system(.title, design: .rounded).weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Text("买断")
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)
            }
            Text("含首年功能更新，后续大版本升级另行收费")
                .font(.caption2)
                .foregroundStyle(Theme.inkFaint)

            PrimaryButton(
                title: purchases.isPurchased ? "已解锁" : "立即解锁",
                systemImage: purchases.isPurchased ? "checkmark.seal.fill" : "lock.open.fill",
                enabled: !purchases.isPurchased
            ) {
                Task { await purchases.purchase() }
            }

            Button("恢复购买") {
                Task { await purchases.restore() }
            }
            .font(.caption)
            .foregroundStyle(Theme.inkSoft)

            if let message = purchases.message {
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(Theme.inkFaint)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(Theme.pad)
        .frame(maxWidth: .infinity)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                .stroke(Theme.line, lineWidth: 1)
        )
    }

    private var footerNote: some View {
        Text("购买通过 App Store 完成，可在「设置 - Apple ID - 订阅」中管理。所有训练数据只保存在本机。")
            .font(.caption2)
            .foregroundStyle(Theme.inkFaint)
    }
}

#Preview {
    NavigationStack {
        PaywallView()
    }
}
