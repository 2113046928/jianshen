import XCTest
@testable import TrainLedger

final class RetentionAnalyzerTests: XCTestCase {

    private let day: TimeInterval = 86_400
    private var phaseStart: Date { Date(timeIntervalSince1970: 100 * day) }

    private func sample(_ dayIndex: Int, _ exerciseID: String, _ oneRepMax: Double) -> RetentionSample {
        RetentionSample(
            date: Date(timeIntervalSince1970: Double(dayIndex) * day),
            exerciseID: exerciseID,
            oneRepMax: oneRepMax
        )
    }

    func testKeptWhenCurrentMatchesBaseline() {
        let samples = [
            sample(90, LiftClass.bench.anchorExerciseID, 100),
            sample(110, LiftClass.bench.anchorExerciseID, 100)
        ]
        let result = RetentionAnalyzer.analyze(samples: samples, phaseStart: phaseStart)
        let bench = result.first { $0.lift == .bench }
        XCTAssertEqual(bench?.ratio ?? 0, 1.0, accuracy: 0.0001)
        XCTAssertEqual(bench?.status, .kept)
    }

    func testWatchWhenDroppedFivePercent() {
        let samples = [
            sample(90, LiftClass.squat.anchorExerciseID, 140),
            sample(110, LiftClass.squat.anchorExerciseID, 133)
        ]
        let result = RetentionAnalyzer.analyze(samples: samples, phaseStart: phaseStart)
        let squat = result.first { $0.lift == .squat }
        XCTAssertEqual(squat?.ratio ?? 0, 133.0 / 140.0, accuracy: 0.0001)
        XCTAssertEqual(squat?.status, .watch)
    }

    func testRiskWhenDroppedMoreThanTenPercent() {
        let samples = [
            sample(90, LiftClass.deadlift.anchorExerciseID, 180),
            sample(110, LiftClass.deadlift.anchorExerciseID, 150)
        ]
        let result = RetentionAnalyzer.analyze(samples: samples, phaseStart: phaseStart)
        let deadlift = result.first { $0.lift == .deadlift }
        XCTAssertEqual(deadlift?.status, .risk)
        XCTAssertEqual(deadlift?.delta ?? 0, -30, accuracy: 0.0001)
    }

    func testBaselineOnlyBeforePhaseStart() {
        let samples = [
            sample(90, LiftClass.press.anchorExerciseID, 60),
            sample(95, LiftClass.press.anchorExerciseID, 62),
            sample(110, LiftClass.press.anchorExerciseID, 55)
        ]
        let result = RetentionAnalyzer.analyze(samples: samples, phaseStart: phaseStart)
        let press = result.first { $0.lift == .press }
        // 基线取阶段前的最大值 62，而不是最早的一条
        XCTAssertEqual(press?.baseline ?? 0, 62, accuracy: 0.0001)
        XCTAssertEqual(press?.current ?? 0, 55, accuracy: 0.0001)
    }

    func testUnknownWhenMissingData() {
        let result = RetentionAnalyzer.analyze(samples: [], phaseStart: phaseStart)
        XCTAssertEqual(result.count, LiftClass.allCases.count)
        XCTAssertTrue(result.allSatisfy { $0.status == .unknown })
        XCTAssertNil(RetentionAnalyzer.overall(result))
    }

    func testOverallAveragesAvailableLifts() {
        let samples = [
            sample(90, LiftClass.bench.anchorExerciseID, 100),
            sample(110, LiftClass.bench.anchorExerciseID, 100),
            sample(90, LiftClass.squat.anchorExerciseID, 100),
            sample(110, LiftClass.squat.anchorExerciseID, 90)
        ]
        let result = RetentionAnalyzer.analyze(samples: samples, phaseStart: phaseStart)
        let overall = RetentionAnalyzer.overall(result)
        XCTAssertEqual(overall ?? 0, 0.95, accuracy: 0.0001)
    }

    func testAnchorsAreUniquePerLift() {
        let anchors = LiftClass.allCases.map(\.anchorExerciseID)
        XCTAssertEqual(Set(anchors).count, anchors.count)
    }
}
