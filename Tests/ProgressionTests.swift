import XCTest
@testable import TrainLedger

final class ExerciseSubstitutionTests: XCTestCase {

    private func exercise(
        _ id: String,
        _ name: String,
        pattern: MovementPattern,
        primary: [MuscleGroup],
        equipment: Equipment,
        compound: Bool,
        index: Int = 0
    ) -> Exercise {
        Exercise(
            id: id,
            name: name,
            pattern: pattern,
            primary: primary,
            equipment: equipment,
            isCompound: compound,
            loadIncrement: 2.5,
            targetReps: 8...12,
            sortIndex: index
        )
    }

    private lazy var catalog: [Exercise] = [
        exercise("bench", "杠铃卧推", pattern: .horizontalPush, primary: [.chest], equipment: .barbell, compound: true, index: 0),
        exercise("db-bench", "哑铃卧推", pattern: .horizontalPush, primary: [.chest], equipment: .dumbbell, compound: true, index: 1),
        exercise("machine-press", "坐姿推胸", pattern: .horizontalPush, primary: [.chest], equipment: .machine, compound: true, index: 2),
        exercise("pushup", "俯卧撑", pattern: .horizontalPush, primary: [.chest], equipment: .bodyweight, compound: true, index: 3),
        exercise("fly", "绳索夹胸", pattern: .horizontalPush, primary: [.chest], equipment: .cable, compound: false, index: 4),
        exercise("squat", "深蹲", pattern: .squat, primary: [.legs], equipment: .barbell, compound: true, index: 5),
        exercise("row", "杠铃划船", pattern: .horizontalPull, primary: [.back], equipment: .barbell, compound: true, index: 6)
    ]

    func testAlternativesKeepTheSameMovementPattern() {
        let base = catalog[0]
        let result = ExerciseSubstitution.alternatives(for: base, in: catalog)
        XCTAssertFalse(result.isEmpty)
        XCTAssertTrue(result.allSatisfy { $0.pattern == .horizontalPush })
        XCTAssertFalse(result.contains { $0.id == base.id })
    }

    func testDumbbellVersionRanksAboveUnrelatedEquipment() {
        let base = catalog[0]
        let result = ExerciseSubstitution.alternatives(for: base, in: catalog)
        XCTAssertEqual(result.first?.id, "db-bench")
        XCTAssertGreaterThan(
            ExerciseSubstitution.score(catalog[1], against: base),
            ExerciseSubstitution.score(catalog[3], against: base)
        )
    }

    func testEquipmentFilterForHotelWorkouts() {
        let base = catalog[0]
        let dumbbellOnly = ExerciseSubstitution.alternatives(
            for: base,
            in: catalog,
            equipment: .dumbbell
        )
        XCTAssertEqual(dumbbellOnly.map(\.id), ["db-bench"])
    }

    func testNoAlternativesWhenNothingMatches() {
        let unique = exercise(
            "unique", "独有动作", pattern: .core, primary: [.core],
            equipment: .kettlebell, compound: false, index: 9
        )
        let result = ExerciseSubstitution.alternatives(for: unique, in: catalog)
        XCTAssertTrue(result.isEmpty)
    }

    func testNonCompoundMatchesNonCompound() {
        let base = catalog[4]  // 绳索夹胸，非复合
        let result = ExerciseSubstitution.alternatives(for: base, in: catalog)
        // 同模式但没有其它非复合动作，剩下的复合动作分数仍可过线
        XCTAssertFalse(result.contains { $0.id == base.id })
    }
}

final class VolumeProgressionTests: XCTestCase {

    private func volume(_ muscle: MuscleGroup, _ sets: Double, _ status: VolumeStatus) -> MuscleVolume {
        MuscleVolume(muscle: muscle, sets: sets, status: status)
    }

    func testAddsSetWhenWellBelowTarget() {
        let volumes = [
            volume(.chest, 6, .under),      // 目标 10–20，差 4
            volume(.back, 14, .inRange),
            volume(.legs, 20, .inRange)
        ]
        let adjustments = VolumeProgression.adjustments(volumes: volumes)
        XCTAssertEqual(adjustments.count, 1)
        XCTAssertEqual(adjustments.first?.muscle, .chest)
        XCTAssertEqual(adjustments.first?.delta, 1)
    }

    func testDoesNotChurnWhenOnlySlightlyLow() {
        let volumes = [volume(.chest, 9, .under)]   // 差 1，低于阈值
        XCTAssertTrue(VolumeProgression.adjustments(volumes: volumes).isEmpty)
    }

    func testReducesWhenWellAboveTarget() {
        let volumes = [volume(.legs, 28, .over)]    // 上限 22，超 6
        let adjustments = VolumeProgression.adjustments(volumes: volumes)
        XCTAssertEqual(adjustments.first?.delta, -1)
    }

    func testExtraSetsOnlyForMatchingMuscle() {
        let adjustments = [
            VolumeAdjustment(muscle: .chest, delta: 1, reason: "")
        ]
        let bench = Exercise(
            id: "bench", name: "卧推", pattern: .horizontalPush, primary: [.chest],
            equipment: .barbell, isCompound: true, loadIncrement: 2.5, targetReps: 8...12
        )
        let squat = Exercise(
            id: "squat", name: "深蹲", pattern: .squat, primary: [.legs],
            equipment: .barbell, isCompound: true, loadIncrement: 2.5, targetReps: 8...12
        )
        XCTAssertEqual(VolumeProgression.extraSets(for: bench, adjustments: adjustments), 1)
        XCTAssertEqual(VolumeProgression.extraSets(for: squat, adjustments: adjustments), 0)
    }

    func testReducedSetsOnlyForOverMuscle() {
        let adjustments = [VolumeAdjustment(muscle: .legs, delta: -1, reason: "")]
        let squat = Exercise(
            id: "squat", name: "深蹲", pattern: .squat, primary: [.legs],
            equipment: .barbell, isCompound: true, loadIncrement: 2.5, targetReps: 8...12
        )
        XCTAssertEqual(VolumeProgression.reducedSets(for: squat, adjustments: adjustments), 1)
    }
}

final class PeriodizationWaveTests: XCTestCase {

    func testSetsWave() {
        XCTAssertEqual(Periodization.sets(forBlockWeek: 1), 3)
        XCTAssertEqual(Periodization.sets(forBlockWeek: 2), 3)
        XCTAssertEqual(Periodization.sets(forBlockWeek: 3), 4)
        XCTAssertEqual(Periodization.sets(forBlockWeek: 4), 3)
        XCTAssertEqual(Periodization.sets(forBlockWeek: 5), 2)
    }

    func testOutOfRangeWeeksClamp() {
        XCTAssertEqual(Periodization.sets(forBlockWeek: 0), 3)
        XCTAssertEqual(Periodization.sets(forBlockWeek: 99), 2)
    }

    func testPeakWeekIsFourth() {
        // 每周 3 练：第 10–12 次落在第 4 周
        XCTAssertTrue(Periodization.isPeakWeek(finishedSessions: 9, sessionsPerWeek: 3))
        XCTAssertFalse(Periodization.isPeakWeek(finishedSessions: 12, sessionsPerWeek: 3))
    }
}
