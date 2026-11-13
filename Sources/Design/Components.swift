import Foundation
import SwiftUI

// MARK: - 标题

struct SectionHeader: View {
    private let title: LocalizedStringKey
    private let subtitle: LocalizedStringKey?

    init(title: String, subtitle: String? = nil) {
        self.title = LocalizedStringKey(title)
        self.subtitle = subtitle.map { LocalizedStringKey($0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .tracking(-0.1)
                .foregroundStyle(Theme.ink)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.inkFaint)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - 标签

struct Pill: View {
    private let text: LocalizedStringKey
    private let color: Color
    private let filled: Bool

    init(text: String, color: Color = Theme.accent, filled: Bool = false) {
        self.text = LocalizedStringKey(text)
        self.color = color
        self.filled = filled
    }

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .tracking(0.3)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(filled ? color : color.opacity(0.10))
            .foregroundStyle(filled ? Theme.onAccent : color)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

// MARK: - 数字

struct StatTile: View {
    private let title: LocalizedStringKey
    private let value: String
    private let unit: String?
    private let tint: Color

    init(title: String, value: String, unit: String? = nil, tint: Color = Theme.ink) {
        self.title = LocalizedStringKey(title)
        self.value = value
        self.unit = unit
        self.tint = tint
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .microLabel()
                .foregroundStyle(Theme.inkFaint)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .tabular(size: 21, weight: .bold)
                    .foregroundStyle(tint)
                if let unit {
                    Text(unit)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.inkGhost)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 一行统计：中间用细线分隔，不再塞进灰色小方块
struct StatRow: View {
    struct Item: Identifiable {
        var id: String { title }
        let title: String
        let value: String
        var unit: String? = nil
        var tint: Color = Theme.ink
    }

    let items: [Item]

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { pair in
                StatTile(
                    title: pair.element.title,
                    value: pair.element.value,
                    unit: pair.element.unit,
                    tint: pair.element.tint
                )
                .padding(.leading, pair.offset == 0 ? 0 : 14)

                if pair.offset < items.count - 1 {
                    Rectangle()
                        .fill(Theme.hair)
                        .frame(width: 1, height: 30)
                        .padding(.horizontal, 14)
                }
            }
        }
    }
}

// MARK: - 环形进度

struct ProgressRing: View {
    var progress: Double
    var caption: String
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.hair, lineWidth: 3)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(Theme.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(caption)
                .font(.system(size: 11, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(Theme.inkSoft)
        }
        .frame(width: size, height: size)
        .accessibilityLabel("本周完成 \(caption)")
    }
}

// MARK: - 一周柱条

/// 7 根柱子，高度编码当天训练量，今天用强调色高亮
struct WeekStrip: View {
    /// 从最早到今天，共 7 个值
    var values: [Double]
    var tint: Color = Theme.accent

    private var peak: Double { max(values.max() ?? 0, 1) }

    var body: some View {
        HStack(alignment: .bottom, spacing: 9) {
            ForEach(0..<7, id: \.self) { index in
                VStack(spacing: 7) {
                    Spacer(minLength: 0)
                    bar(index)
                    Text(weekdayLabel(index))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(labelColor(index))
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 64)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("本周训练量柱状图")
    }

    private func bar(_ index: Int) -> some View {
        let value = index < values.count ? values[index] : 0
        let ratio = min(value / peak, 1)
        let isToday = index == values.count - 1
        let hasTraining = value > 0

        return RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(barFill(index, isToday: isToday, hasTraining: hasTraining))
            .frame(width: 24, height: hasTraining ? max(12, 46 * ratio) : 6)
    }

    private func barFill(_ index: Int, isToday: Bool, hasTraining: Bool) -> LinearGradient {
        if isToday {
            return LinearGradient(
                colors: [tint.opacity(0.95), tint],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        let alpha = hasTraining ? 0.42 : 0.16
        return LinearGradient(
            colors: [Color.white.opacity(alpha), Color.white.opacity(alpha)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func weekdayLabel(_ index: Int) -> String {
        let calendar = Calendar.current
        let today = calendar.component(.weekday, from: .now)
        // 把「今天」对齐到最后一根柱子
        let offset = values.count - 1 - index
        let weekday = ((today - offset - 1) % 7 + 7) % 7
        return ["日", "一", "二", "三", "四", "五", "六"][weekday]
    }

    private func labelColor(_ index: Int) -> Color {
        let isToday = index == values.count - 1
        let value = index < values.count ? values[index] : 0
        if isToday { return .white }
        return .white.opacity(value > 0 ? 0.8 : 0.3)
    }
}

// MARK: - 细条

struct VolumeBar: View {
    let volume: MuscleVolume

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(volume.muscle.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text("\(Fmt.kg(volume.sets)) 组")
                    .tabular(size: 13, weight: .bold)
                    .foregroundStyle(Theme.inkSoft)
                Text(volume.status.title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(volume.status.tint)
                    .frame(width: 30, alignment: .trailing)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.hair)
                    Capsule()
                        .fill(volume.status.tint)
                        .frame(width: max(4, proxy.size.width * volume.progress))
                }
            }
            .frame(height: 6)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            L10n.volumeAccessibility(
                muscle: volume.muscle.title,
                sets: Fmt.kg(volume.sets),
                low: Fmt.kg(volume.low),
                high: Fmt.kg(volume.high),
                status: volume.status.title
            )
        )
    }
}

// MARK: - 主按钮

struct PrimaryButton: View {
    private let title: LocalizedStringKey
    private let systemImage: String?
    private let enabled: Bool
    private let action: () -> Void

    init(
        title: String,
        systemImage: String? = nil,
        enabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = LocalizedStringKey(title)
        self.systemImage = systemImage
        self.enabled = enabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 14, weight: .bold))
                }
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .tracking(-0.2)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(enabled ? Theme.solid : Theme.inkGhost.opacity(0.45))
            .foregroundStyle(Theme.onSolid)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(enabled ? 0.22 : 0), radius: 14, x: 0, y: 7)
        }
        .buttonStyle(PressableStyle())
        .disabled(!enabled)
    }
}

/// 按下立刻缩一点，松手弹回——比默认的透明度反馈更有触感
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.9), value: configuration.isPressed)
    }
}

// MARK: - 置信度徽章

struct ConfidenceBadge: View {
    let confidence: Confidence

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: confidence.symbol)
                .font(.system(size: 10, weight: .bold))
            Text(confidence.title)
                .font(.system(size: 11, weight: .bold))
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(confidence.tint.opacity(0.12))
        .foregroundStyle(confidence.tint)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

// MARK: - 空状态

struct EmptyHint: View {
    private let text: LocalizedStringKey

    init(text: String) {
        self.text = LocalizedStringKey(text)
    }

    var body: some View {
        Text(text)
            .font(.system(size: 14))
            .foregroundStyle(Theme.inkFaint)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 22)
    }
}
