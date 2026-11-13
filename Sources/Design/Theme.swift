import Foundation
import SwiftUI
import UIKit

/// 颜色全部走动态色。v2 把层级拉开：更暖的纸色底、更沉的墨色字、更细的分隔线。
enum Theme {
    static let bg = dynamic(light: (0.957, 0.949, 0.925), dark: (0.071, 0.071, 0.078))
    static let card = dynamic(light: (1.000, 1.000, 1.000), dark: (0.110, 0.110, 0.118))

    static let ink = dynamic(light: (0.086, 0.086, 0.102), dark: (0.949, 0.945, 0.925))
    static let inkSoft = dynamic(light: (0.235, 0.235, 0.259), dark: (0.725, 0.725, 0.745))
    static let inkFaint = dynamic(light: (0.478, 0.478, 0.510), dark: (0.549, 0.549, 0.580))
    /// 最弱的一级：单位、次数区间这种注释性信息
    static let inkGhost = dynamic(light: (0.659, 0.659, 0.690), dark: (0.451, 0.451, 0.478))

    static let line = dynamic(light: (0.894, 0.882, 0.847), dark: (0.165, 0.165, 0.176))
    /// 卡片内的细分隔线，比 line 更淡
    static let hair = dynamic(light: (0.933, 0.925, 0.894), dark: (0.137, 0.137, 0.149))

    /// 反色块（按钮、休息条）：两种外观下都保持深底白字
    static let solid = dynamic(light: (0.086, 0.086, 0.102), dark: (0.140, 0.140, 0.152))
    static let onSolid = Color.white

    static let accent = dynamic(light: (0.851, 0.314, 0.055), dark: (0.961, 0.396, 0.102))
    /// 强调色上的文字：橙底配深字，对比度约 7:1，比白字更易读
    static let onAccent = Color(red: 0.10, green: 0.09, blue: 0.08)

    static let good = dynamic(light: (0.184, 0.561, 0.420), dark: (0.290, 0.760, 0.560))
    static let warn = dynamic(light: (0.769, 0.514, 0.098), dark: (0.960, 0.680, 0.260))
    static let danger = dynamic(light: (0.784, 0.271, 0.184), dark: (0.980, 0.420, 0.340))

    /// 深色卡片的两端色
    static let darkCardTop = dynamic(light: (0.137, 0.137, 0.161), dark: (0.165, 0.165, 0.180))
    static let darkCardBottom = dynamic(light: (0.078, 0.078, 0.094), dark: (0.098, 0.098, 0.110))
    static let onDarkSoft = Color.white.opacity(0.55)
    static let onDarkFaint = Color.white.opacity(0.35)

    static let radius: CGFloat = 22
    static let pad: CGFloat = 20
    static let gap: CGFloat = 18

    private static func dynamic(
        light: (Double, Double, Double),
        dark: (Double, Double, Double)
    ) -> Color {
        Color(UIColor { trait in
            let value = trait.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: value.0, green: value.1, blue: value.2, alpha: 1)
        })
    }
}

extension View {
    /// 卡片：无边线，靠两层阴影浮起来
    func card() -> some View {
        self
            .padding(Theme.pad)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
            .shadow(color: .black.opacity(0.10), radius: 22, x: 0, y: 10)
    }

    /// 深色数据卡：渐变底 + 右上角橙色光晕，用来做每屏的视觉锚点
    func darkCard() -> some View {
        self
            .padding(Theme.pad)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [Theme.darkCardTop, Theme.darkCardBottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(alignment: .topTrailing) {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Theme.accent.opacity(0.55), Theme.accent.opacity(0)],
                            center: .center,
                            startRadius: 0,
                            endRadius: 110
                        )
                    )
                    .frame(width: 230, height: 230)
                    .offset(x: 70, y: -95)
                    .blur(radius: 8)
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            .shadow(color: .black.opacity(0.16), radius: 6, x: 0, y: 2)
            .shadow(color: .black.opacity(0.34), radius: 26, x: 0, y: 16)
    }

    /// 1px 细分隔线
    func hairline() -> some View {
        Rectangle()
            .fill(Theme.hair)
            .frame(height: 1)
    }
}

// MARK: - 排版

extension Text {
    /// 大数字：紧字距、等宽数字
    func heroNumber(size: CGFloat = 52) -> Text {
        font(.system(size: size, weight: .bold))
            .tracking(-size * 0.035)
            .monospacedDigit()
    }

    /// 小标题：字距略开，作为信息分组
    func microLabel() -> Text {
        font(.system(size: 11, weight: .semibold))
            .tracking(0.6)
    }

    /// 行内数字：等宽，避免跳动
    func tabular(size: CGFloat, weight: Font.Weight = .semibold) -> Text {
        font(.system(size: size, weight: weight))
            .tracking(-0.2)
            .monospacedDigit()
    }
}

enum Fmt {
    static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 EEEE"
        return formatter
    }()

    static let shortDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M/d"
        return formatter
    }()

    static func kg(_ value: Double) -> String {
        if value == value.rounded() {
            return "\(Int(value))"
        }
        return String(format: "%.1f", value)
    }

    static func weight(_ value: Double) -> String {
        "\(kg(value)) kg"
    }

    static func volume(_ value: Double) -> String {
        if value >= 10000 {
            return String(format: "%.1f 吨", value / 1000)
        }
        return "\(Int(value.rounded())) kg"
    }

    static func duration(_ interval: TimeInterval) -> String {
        let minutes = Int(interval / 60)
        if minutes < 60 { return "\(minutes) 分钟" }
        return "\(minutes / 60) 小时 \(minutes % 60) 分"
    }

    static func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }
}
