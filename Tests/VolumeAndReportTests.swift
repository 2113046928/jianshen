import XCTest
@testable import TrainLedger

final class VolumeAndReportTests: XCTestCase {

    // MARK: - 容量

    func testChestVolumeUnderTarget() {
        let sets = (0..<8).map { _ in
            LoggedSet(exerciseID: "bench", primary: [.chest], secondary: [.arms], weight: 80, reps: 8)
        }
        let volumes = VolumeAnalyzer.analyze(sets: sets)
        let chest = volumes.first { $0.muscle == .chest }
        XCTAssertEqual(chest?.sets, 8)
        XCTAssertEqual(chest?.status, .under)

        let arms = volumes.first { $0.muscle == .arms }
        XCTAssertEqual(arms?.sets, 4)   // 协同肌按 0.5 组计
    }

    func testWarmupDoesNotCount() {
        var sets = (0..<8).map { _ in
            LoggedSet(exerciseID: "bench", primary: [.chest], secondary: [.arms], weight: 80, reps: 8)
        }
        sets.append(LoggedSet(exerciseID: "bench", primary: [.chest], secondary: [.arms], weight: 40, reps: 15, setType: .warmup))
        let chest = VolumeAnalyzer.analyze(sets: sets).first { $0.muscle == .chest }
        XCTAssertEqual(chest?.sets, 8)
    }

    func testVolumeInRange() {
        let sets = (0..<14).map { _ in
            LoggedSet(exerciseID: "squat", primary: [.legs], weight: 100, reps: 5)
        }
        let legs = VolumeAnalyzer.analyze(sets: sets).first { $0.muscle == .legs }
        XCTAssertEqual(legs?.status, .inRange)
    }

    func testWeakestMuscleIsTheLargestGap() {
        let sets = [LoggedSet(exerciseID: "curl", primary: [.arms], weight: 20, reps: 10)]
        let volumes = VolumeAnalyzer.analyze(sets: sets)
        XCTAssertEqual(VolumeAnalyzer.weakest(volumes)?.muscle, .legs)
    }

    // MARK: - 1RM 与等级

    func testEpleyFormula() {
        XCTAssertEqual(StrengthEstimate.oneRepMax(weight: 100, reps: 1), 100, accuracy: 0.001)
        XCTAssertEqual(StrengthEstimate.oneRepMax(weight: 100, reps: 5), 116.666, accuracy: 0.01)
        XCTAssertEqual(StrengthEstimate.oneRepMax(weight: 80, reps: 10), 106.666, accuracy: 0.01)
        XCTAssertEqual(StrengthEstimate.oneRepMax(weight: 0, reps: 5), 0, accuracy: 0.001)
    }

    func testStrengthTierMapping() {
        XCTAssertEqual(StrengthEstimate.tier(oneRepMax: 100, bodyweight: 80, lift: .bench), .advanced)
        XCTAssertEqual(StrengthEstimate.tier(oneRepMax: 60, bodyweight: 80, lift: .bench), .novice)
        XCTAssertEqual(StrengthEstimate.tier(oneRepMax: 120, bodyweight: 80, lift: .bench), .elite)
        XCTAssertEqual(StrengthEstimate.tier(oneRepMax: 180, bodyweight: 80, lift: .squat), .elite)
        XCTAssertNil(StrengthEstimate.tier(oneRepMax: 90, bodyweight: 0, lift: .bench))
    }

    func testBestEstimatePicksHighestOneRepMax() {
        let sets = [
            SetSnapshot(weight: 100, reps: 3),
            SetSnapshot(weight: 80, reps: 10),
            SetSnapshot(weight: 60, reps: 10, setType: .warmup)
        ]
        let best = StrengthEstimate.bestEstimate(from: sets)
        XCTAssertEqual(best?.source.weight, 100)
    }

    // MARK: - 周报

    private func reportSet(
        _ weight: Double,
        _ reps: Int,
        _ type: SetType = .normal,
        exerciseID: String = "bench"
    ) -> ReportSet {
        ReportSet(
            exerciseID: exerciseID,
            weight: weight,
            reps: reps,
            setType: type,
            primary: [.chest],
            secondary: [.arms]
        )
    }

    private func reportSession(_ day: Int, _ sets: [ReportSet]) -> ReportSession {
        ReportSession(date: Date(timeIntervalSince1970: TimeInterval(day) * 86_400), sets: sets)
    }

    func testWeeklyReportAggregation() {
        let sessions = [
            reportSession(1, [
                reportSet(80, 8), reportSet(80, 8), reportSet(80, 9), reportSet(90, 5)
            ]),
            reportSession(3, [
                reportSet(80, 8), reportSet(90, 6), reportSet(40, 15, .warmup)
            ])
        ]
        let report = WeeklyReportBuilder.build(sessions: sessions, plannedSessions: 3)

        XCTAssertEqual(report.sessionCount, 2)
        XCTAssertEqual(report.totalSets, 6)              // 热身不计
        XCTAssertEqual(report.totalVolume, 3630, accuracy: 0.01)
        XCTAssertEqual(report.prCount, 1)                // 只有 90×6 超过此前最佳 e1RM
        XCTAssertEqual(report.adherence, 2.0 / 3.0, accuracy: 0.001)
    }

    func testFirstSessionNeverCountsAsPR() {
        let sessions = [reportSession(1, [reportSet(100, 5)])]
        let report = WeeklyReportBuilder.build(sessions: sessions, plannedSessions: 3)
        XCTAssertEqual(report.prCount, 0)
    }

    func testPRUsesHistoryBeforeWindow() {
        let history = [reportSession(1, [reportSet(100, 5)])]
        let window = [reportSession(10, [reportSet(110, 5)])]
        let report = WeeklyReportBuilder.build(sessions: window, plannedSessions: 3, history: history)
        XCTAssertEqual(report.prCount, 1)
        XCTAssertEqual(report.sessionCount, 1)
    }

    func testEmptyReportIsSafe() {
        let report = WeeklyReportBuilder.build(sessions: [], plannedSessions: 3)
        XCTAssertEqual(report.sessionCount, 0)
        XCTAssertEqual(report.totalSets, 0)
        XCTAssertEqual(report.adherence, 0)
        XCTAssertEqual(report.volumes.count, MuscleGroup.allCases.count)
    }

    func testPlannedSessionsZeroDoesNotDivideByZero() {
        let report = WeeklyReportBuilder.build(
            sessions: [reportSession(1, [reportSet(80, 8)])],
            plannedSessions: 0
        )
        XCTAssertEqual(report.adherence, 0)
    }

    // MARK: - 导出

    func testCSVHeaderAndEscaping() throws {
        let csv = CSVExport.make(sessions: [])
        XCTAssertTrue(csv.hasPrefix("日期,动作,组序"))
    }
}
