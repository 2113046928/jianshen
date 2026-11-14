import AVFoundation
import Combine
import Foundation
import Vision

/// 端上动作评估：抽帧 + Vision 人体关键点，不联网、不上传视频。
@MainActor
final class FormCheckService: ObservableObject {

    enum State: Equatable {
        case idle
        case analyzing(Double)
        case finished(FormCheckResult)
        case failed(String)
    }

    @Published private(set) var state: State = .idle

    /// 抽帧间隔（秒）。0.2 秒足够恢复 30fps 视频里的蹲起节奏，又不至于太慢。
    private let frameInterval: Double = 0.2

    func reset() {
        state = .idle
    }

    func analyze(videoURL: URL) async {
        state = .analyzing(0)

        let asset = AVURLAsset(url: videoURL)
        do {
            let duration = try await asset.load(.duration)
            let seconds = CMTimeGetSeconds(duration)
            guard seconds.isFinite, seconds > 0.5 else {
                state = .failed("视频太短，至少录一次完整下蹲。")
                return
            }

            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.requestedTimeToleranceBefore = .zero
            generator.requestedTimeToleranceAfter = .zero
            generator.maximumSize = CGSize(width: 720, height: 720)

            var samples: [JointSample] = []
            var elapsed = 0.0

            while elapsed < seconds {
                if Task.isCancelled {
                    state = .idle
                    return
                }
                let time = CMTime(seconds: elapsed, preferredTimescale: 600)
                if let frame = try? await generator.image(at: time),
                   let sample = poseSample(from: frame.image) {
                    samples.append(sample)
                }
                elapsed += frameInterval
                state = .analyzing(min(elapsed / seconds, 1))
                // Vision 是同步调用，整段都在主线程；每帧让出一次，至少让进度条能刷新。
                // 彻底解决要把抽帧 + 推理挪到后台 actor，见 README 已知限制。
                await Task.yield()
            }

            state = .finished(SquatAnalyzer.analyze(samples: samples, frameInterval: frameInterval))
        } catch {
            state = .failed("读取视频失败：\(error.localizedDescription)")
        }
    }

    // MARK: - Vision

    private func poseSample(from image: CGImage) -> JointSample? {
        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }
        guard let observation = request.results?.first,
              let points = try? observation.recognizedPoints(.all) else {
            return nil
        }

        func point(_ name: VNHumanBodyPoseObservation.JointName) -> CGPoint? {
            guard let recognized = points[name], recognized.confidence > 0.3 else { return nil }
            return recognized.location
        }

        var kneeAngles: [Double] = []
        var hipAngles: [Double] = []
        var torsoAngles: [Double] = []

        let sides: [(hip: VNHumanBodyPoseObservation.JointName, knee: VNHumanBodyPoseObservation.JointName, ankle: VNHumanBodyPoseObservation.JointName, shoulder: VNHumanBodyPoseObservation.JointName)] = [
            (.leftHip, .leftKnee, .leftAnkle, .leftShoulder),
            (.rightHip, .rightKnee, .rightAnkle, .rightShoulder)
        ]

        for side in sides {
            guard let hip = point(side.hip),
                  let knee = point(side.knee),
                  let ankle = point(side.ankle) else { continue }

            kneeAngles.append(PoseMath.angle(hip, knee, ankle))
            if let shoulder = point(side.shoulder) {
                hipAngles.append(PoseMath.angle(shoulder, hip, knee))
                torsoAngles.append(PoseMath.tiltFromVertical(from: hip, to: shoulder))
            }
        }

        guard !kneeAngles.isEmpty else { return nil }

        return JointSample(
            knee: kneeAngles.reduce(0, +) / Double(kneeAngles.count),
            hip: hipAngles.isEmpty ? 0 : hipAngles.reduce(0, +) / Double(hipAngles.count),
            torso: torsoAngles.isEmpty ? 0 : torsoAngles.reduce(0, +) / Double(torsoAngles.count)
        )
    }
}
