import CoreGraphics
import Foundation

/// 单个姿态帧的三个关键角度（度）
struct JointSample: Equatable {
    /// 膝关节角：髋-膝-踝。越小蹲得越深
    var knee: Double
    /// 髋关节角：肩-髋-膝
    var hip: Double
    /// 躯干与竖直方向的夹角，越大越前倾
    var torso: Double
}

enum PoseMath {

    /// 以 b 为顶点，计算 a-b-c 的夹角（度，0...180）
    static func angle(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> Double {
        let v1 = CGVector(dx: a.x - b.x, dy: a.y - b.y)
        let v2 = CGVector(dx: c.x - b.x, dy: c.y - b.y)
        let n1 = (v1.dx * v1.dx + v1.dy * v1.dy).squareRoot()
        let n2 = (v2.dx * v2.dx + v2.dy * v2.dy).squareRoot()
        guard n1 > 0.0001, n2 > 0.0001 else { return 0 }
        let dot = v1.dx * v2.dx + v1.dy * v2.dy
        let cosine = max(-1, min(1, dot / (n1 * n2)))
        return acos(cosine) * 180 / .pi
    }

    /// 线段与竖直方向的夹角（度），用于判断躯干前倾
    static func tiltFromVertical(from base: CGPoint, to top: CGPoint) -> Double {
        let dx = top.x - base.x
        let dy = top.y - base.y
        guard abs(dx) > 0.0001 || abs(dy) > 0.0001 else { return 0 }
        return abs(atan2(dx, dy)) * 180 / .pi
    }
}

/// 一次动作评估的结论
struct FormCheckResult: Equatable {
    var reps: Int
    /// 全程最深处的膝角
    var minKneeAngle: Double
    /// 平均每次下蹲+起身耗时（秒）
    var averageTempo: Double
    /// 采样帧数
    var frameCount: Int
    var notes: [String]

    static let empty = FormCheckResult(
        reps: 0,
        minKneeAngle: 0,
        averageTempo: 0,
        frameCount: 0,
        notes: []
    )
}

/// 深蹲动作分析：从膝关节角度序列里切分次数、判断深度与节奏。
/// 这里刻意只做「能算准的几件事」，不做姿态评分——评分没有共识标准，容易变成伪科学。
enum SquatAnalyzer {

    static let bottomThreshold: Double = 110
    static let lockoutThreshold: Double = 160
    static let depthTarget: Double = 100
    static let torsoLimit: Double = 45

    static func analyze(samples: [JointSample], frameInterval: Double) -> FormCheckResult {
        guard !samples.isEmpty, frameInterval > 0 else { return .empty }

        var reps = 0
        var minKnee = 180.0
        var maxTorso = 0.0
        var inBottom = false
        var bottomStartedAt = 0.0
        var durations: [Double] = []

        for (index, sample) in samples.enumerated() {
            let time = Double(index) * frameInterval
            minKnee = min(minKnee, sample.knee)
            maxTorso = max(maxTorso, sample.torso)

            if !inBottom, sample.knee < bottomThreshold {
                inBottom = true
                bottomStartedAt = time
            } else if inBottom, sample.knee > lockoutThreshold {
                inBottom = false
                durations.append(time - bottomStartedAt)
                reps += 1
            }
        }

        var notes: [String] = []
        if reps == 0 {
            notes.append("没有识别到完整的一次下蹲，换侧向、全身入镜、光线更好的视频再试。")
        } else {
            if minKnee > depthTarget {
                notes.append(String(format: "最低点膝角 %.0f°，深度不够，再往下坐 5–10cm。", minKnee))
            } else {
                notes.append(String(format: "最低点膝角 %.0f°，深度达标。", minKnee))
            }
            if maxTorso > torsoLimit {
                notes.append(String(format: "躯干最大前倾 %.0f°，注意核心收紧、胸口别塌。", maxTorso))
            }
            let tempo = durations.reduce(0, +) / Double(durations.count)
            if tempo < 2.0 {
                notes.append(String(format: "平均每次 %.1f 秒，下放过快，离心建议控制在 2–3 秒。", tempo))
            } else {
                notes.append(String(format: "平均每次 %.1f 秒，节奏合理。", tempo))
            }
        }

        let averageTempo = durations.isEmpty ? 0 : durations.reduce(0, +) / Double(durations.count)
        return FormCheckResult(
            reps: reps,
            minKneeAngle: minKnee,
            averageTempo: averageTempo,
            frameCount: samples.count,
            notes: notes
        )
    }
}
