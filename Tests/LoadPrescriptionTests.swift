import XCTest
@testable import TrainLedger

/// 期望值来自 _spec/engine.py（可运行参考实现）生成的 fixtures.json，
/// 两端必须给出同样的结论，避免"Swift 和规格各说各话"。
final class LoadPrescriptionTests: XCTestCase {

    private func set(
        _ weight: Double,
        _ reps: Int,
        _ rpe: Double? = nil,
        _ type: SetType = .normal
    ) -> SetSnapshot {
        SetSnapshot(weight: weight, reps: reps, rpe: rpe, setType: type)
    }

    private func session(_ day: Int, _ sets: [SetSnapshot]) -> SessionSnapshot {
        SessionSnapshot(date: Date(timeIntervalSince1970: TimeInterval(day) * 86_400), sets: sets)
    }

    func testFirstTimeNeedsCalibration() {
        let result = LoadPrescription.next(history: [], increment: 2.5, target: 8...12)
        XCTAssertNil(result.weight)
        XCTAssertEqual(result.confidence, .calibrate)
        XCTAssertTrue(result.isCalibration)
    }

    func testIncreaseWhenReachingUpperBoundWithRoomLeft() {
        let history = [session(1, [set(100, 12, 8)])]
        let result = LoadPrescription.next(history: history, increment: 2.5, target: 8...12)
        XCTAssertEqual(result.weight, 102.5)
        XCTAssertEqual(result.confidence, .increase)
        XCTAssertEqual(result.conservative, 100)
        XCTAssertEqual(result.aggressive, 105)
    }

    func testHoldWhenReachingUpperBoundNearFailure() {
        let history = [session(1, [set(100, 12, 9.5)])]
        let result = LoadPrescription.next(history: history, increment: 2.5, target: 8...12)
        XCTAssertEqual(result.weight, 100)
        XCTAssertEqual(result.confidence, .hold)
    }

    func testHoldOnFirstMiss() {
        let history = [session(1, [set(100, 6, 9)])]
        let result = LoadPrescription.next(history: history, increment: 2.5, target: 8...12)
        XCTAssertEqual(result.weight, 100)
        XCTAssertEqual(result.confidence, .hold)
    }

    func testReduceAfterTwoConsecutiveMisses() {
        let history = [
            session(1, [set(100, 6, 9)]),
            session(2, [set(100, 5, 9.5)])
        ]
        let result = LoadPrescription.next(history: history, increment: 2.5, target: 8...12)
        XCTAssertEqual(result.weight, 97.5)
        XCTAssertEqual(result.confidence, .reduce)
        XCTAssertEqual(result.conservative, 95)
        XCTAssertEqual(result.aggressive, 100)
    }

    func testIncreaseWhenTooLightInsideRange() {
        let history = [session(1, [set(100, 9, 6.5)])]
        let result = LoadPrescription.next(history: history, increment: 2.5, target: 8...12)
        XCTAssertEqual(result.weight, 102.5)
        XCTAssertEqual(result.confidence, .increase)
    }

    func testHoldInsideRange() {
        let history = [session(1, [set(100, 9, 8)])]
        let result = LoadPrescription.next(history: history, increment: 2.5, target: 8...12)
        XCTAssertEqual(result.weight, 100)
        XCTAssertEqual(result.confidence, .hold)
    }

    func testWarmupSetsAreIgnored() {
        let history = [session(1, [set(60, 10, nil, .warmup), set(100, 12, 8)])]
        let result = LoadPrescription.next(history: history, increment: 2.5, target: 8...12)
        XCTAssertEqual(result.weight, 102.5)
        XCTAssertEqual(result.confidence, .increase)
    }

    func testReductionNeverGoesBelowMinimumIncrement() {
        let history = [
            session(1, [set(2.5, 3, 9)]),
            session(2, [set(2.5, 2, 10)])
        ]
        let result = LoadPrescription.next(history: history, increment: 2.5, target: 8...12)
        XCTAssertEqual(result.weight, 2.5)
        XCTAssertEqual(result.confidence, .reduce)
    }

    func testIncreaseWithoutRPE() {
        let history = [session(1, [set(100, 12, nil)])]
        let result = LoadPrescription.next(history: history, increment: 2.5, target: 8...12)
        XCTAssertEqual(result.weight, 102.5)
        XCTAssertEqual(result.confidence, .increase)
    }

    func testRoundingAlignsToHalfKilo() {
        XCTAssertEqual(LoadPrescription.roundHalf(101.24), 101.0)
        XCTAssertEqual(LoadPrescription.roundHalf(101.26), 101.5)
        XCTAssertEqual(LoadPrescription.roundHalf(100), 100)
    }

    func testIncrementZeroForBodyweightKeepsWeight() {
        let history = [session(1, [set(0, 12, 8)])]
        let result = LoadPrescription.next(history: history, increment: 0, target: 5...10)
        XCTAssertEqual(result.weight, 0)
        XCTAssertEqual(result.confidence, .increase)
    }
}
