import XCTest
@testable import TrainLedger

final class PoseAnalysisTests: XCTestCase {

    // MARK: - 角度

    func testRightAngle() {
        let value = PoseMath.angle(
            CGPoint(x: 0, y: 0),
            CGPoint(x: 0, y: 1),
            CGPoint(x: 1, y: 1)
        )
        XCTAssertEqual(value, 90, accuracy: 0.001)
    }

    func testStraightLine() {
        let value = PoseMath.angle(
            CGPoint(x: 0, y: 0),
            CGPoint(x: 1, y: 0),
            CGPoint(x: 2, y: 0)
        )
        XCTAssertEqual(value, 180, accuracy: 0.001)
    }

    func testDegenerateInputReturnsZero() {
        let value = PoseMath.angle(
            CGPoint(x: 1, y: 1),
            CGPoint(x: 1, y: 1),
            CGPoint(x: 1, y: 1)
        )
        XCTAssertEqual(value, 0, accuracy: 0.001)
    }

    func testTiltFromVertical() {
        XCTAssertEqual(
            PoseMath.tiltFromVertical(from: CGPoint(x: 0, y: 0), to: CGPoint(x: 0, y: 1)),
            0,
            accuracy: 0.001
        )
        XCTAssertEqual(
            PoseMath.tiltFromVertical(from: CGPoint(x: 0, y: 0), to: CGPoint(x: 1, y: 1)),
            45,
            accuracy: 0.001
        )
    }

    // MARK: - 次数识别

    private func samples(_ knees: [Double], torso: Double = 10) -> [JointSample] {
        knees.map { JointSample(knee: $0, hip: 90, torso: torso) }
    }

    func testCountsTwoReps() {
        let series = samples([170, 150, 100, 80, 100, 150, 170, 150, 100, 80, 100, 150, 170])
        let result = SquatAnalyzer.analyze(samples: series, frameInterval: 0.2)

        XCTAssertEqual(result.reps, 2)
        XCTAssertEqual(result.minKneeAngle, 80, accuracy: 0.001)
        XCTAssertEqual(result.frameCount, 13)
        // 每段 80° 出现在第 3 帧、回到 170° 在第 6 帧，约 0.6 秒
        XCTAssertEqual(result.averageTempo, 0.6, accuracy: 0.001)
    }

    func testNoRepWhenNeverDeepEnough() {
        let series = samples([170, 150, 130, 150, 170])
        let result = SquatAnalyzer.analyze(samples: series, frameInterval: 0.2)
        XCTAssertEqual(result.reps, 0)
        XCTAssertTrue(result.notes.first?.contains("没有识别到完整") ?? false)
    }

    func testDepthWarning() {
        let series = samples([170, 130, 105, 130, 170])
        let result = SquatAnalyzer.analyze(samples: series, frameInterval: 0.2)
        XCTAssertEqual(result.reps, 1)
        XCTAssertTrue(result.notes.contains { $0.contains("深度不够") })
    }

    func testTorsoWarning() {
        let series = samples([170, 100, 80, 100, 170], torso: 60)
        let result = SquatAnalyzer.analyze(samples: series, frameInterval: 0.2)
        XCTAssertTrue(result.notes.contains { $0.contains("前倾") })
    }

    func testSlowTempoIsNotWarned() {
        // 每帧 1 秒，全程 4 秒，节奏合理
        let series = samples([170, 100, 80, 100, 170])
        let result = SquatAnalyzer.analyze(samples: series, frameInterval: 1.0)
        XCTAssertTrue(result.notes.contains { $0.contains("节奏合理") })
    }

    func testEmptyInput() {
        let result = SquatAnalyzer.analyze(samples: [], frameInterval: 0.2)
        XCTAssertEqual(result, FormCheckResult.empty)
    }

    func testZeroIntervalIsSafe() {
        let result = SquatAnalyzer.analyze(samples: samples([170, 100, 80, 170]), frameInterval: 0)
        XCTAssertEqual(result, FormCheckResult.empty)
    }
}
