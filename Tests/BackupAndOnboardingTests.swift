import XCTest
@testable import TrainLedger

final class OnboardingPlannerTests: XCTestCase {

    private func answers(
        goal: TrainingGoal = .buildMuscle,
        days: Int = 3,
        equipment: EquipmentAccess = .commercialGym,
        experience: ExperienceLevel = .beginner,
        bodyweight: Double = 70
    ) -> OnboardingAnswers {
        OnboardingAnswers(
            goal: goal,
            daysPerWeek: days,
            equipment: equipment,
            experience: experience,
            bodyweight: bodyweight
        )
    }

    func testHomeEquipmentAlwaysGetsHomeProgram() {
        for days in [2, 3, 4, 5, 6] {
            let plan = OnboardingPlanner.plan(for: answers(days: days, equipment: .homeDumbbell))
            XCTAssertEqual(plan.programID, "home", "days=\(days)")
        }
        let bodyweightOnly = OnboardingPlanner.plan(for: answers(equipment: .bodyweightOnly))
        XCTAssertEqual(bodyweightOnly.programID, "home")
    }

    func testGymSplitDependsOnFrequency() {
        // 新手 3 天 -> 全身
        XCTAssertEqual(OnboardingPlanner.plan(for: answers(days: 3)).programID, "fullBody")
        // 有经验 4 天 -> 上下肢
        XCTAssertEqual(
            OnboardingPlanner.plan(for: answers(days: 4, experience: .intermediate)).programID,
            "upperLower"
        )
        // 有经验 5 天以上 -> 推拉腿
        XCTAssertEqual(
            OnboardingPlanner.plan(for: answers(days: 5, experience: .advanced)).programID,
            "ppl"
        )
    }

    func testBeginnerWithFourDaysStillGetsFullBody() {
        let plan = OnboardingPlanner.plan(for: answers(days: 4, experience: .beginner))
        XCTAssertEqual(plan.programID, "fullBody")
    }

    func testGoalMapsToPhase() {
        XCTAssertEqual(OnboardingPlanner.plan(for: answers(goal: .buildMuscle)).phase, .bulk)
        XCTAssertEqual(OnboardingPlanner.plan(for: answers(goal: .loseFat)).phase, .cut)
        XCTAssertEqual(OnboardingPlanner.plan(for: answers(goal: .getStronger)).phase, .maintain)
        XCTAssertEqual(OnboardingPlanner.plan(for: answers(goal: .generalFitness)).phase, .maintain)
    }

    func testWeeklyGoalIsClamped() {
        XCTAssertEqual(OnboardingPlanner.plan(for: answers(days: 1)).weeklyGoal, 2)
        XCTAssertEqual(OnboardingPlanner.plan(for: answers(days: 9)).weeklyGoal, 6)
        XCTAssertEqual(OnboardingPlanner.plan(for: answers(days: 4)).weeklyGoal, 4)
    }

    func testPlanAlwaysReferencesExistingTemplate() {
        let ids = Set(ProgramTemplates.all.map(\.id))
        for goal in TrainingGoal.allCases {
            for equipment in EquipmentAccess.allCases {
                for days in 2...6 {
                    let plan = OnboardingPlanner.plan(
                        for: answers(goal: goal, days: days, equipment: equipment)
                    )
                    XCTAssertTrue(ids.contains(plan.programID), "未知模板 \(plan.programID)")
                }
            }
        }
    }

    func testCutPlanMentionsFatLoss() {
        let plan = OnboardingPlanner.plan(for: answers(goal: .loseFat))
        XCTAssertEqual(plan.headline.hasPrefix(Phase.cut.title), true)
    }
}

final class BackupServiceTests: XCTestCase {

    private func sampleFile() -> BackupFile {
        BackupFile(
            version: BackupService.currentVersion,
            exportedAt: Date(timeIntervalSince1970: 1_700_000_000),
            profile: BackupProfileDTO(
                bodyweight: 72.5,
                phase: Phase.cut.rawValue,
                weeklyGoal: 4,
                programID: "ppl",
                phaseStartedAt: Date(timeIntervalSince1970: 1_699_000_000),
                unlockedProgramIDs: ["home-20min"]
            ),
            sessions: [
                BackupSessionDTO(
                    startedAt: Date(timeIntervalSince1970: 1_699_500_000),
                    finishedAt: Date(timeIntervalSince1970: 1_699_503_600),
                    phase: Phase.cut.rawValue,
                    note: "状态不错",
                    exercises: [
                        BackupExerciseDTO(
                            exerciseID: "barbell-bench-press",
                            order: 0,
                            suggestedWeight: 80,
                            restSeconds: 180,
                            sets: [
                                BackupSetDTO(order: 1, weight: 80, reps: 8, rpe: 8, type: SetType.normal.rawValue, completed: true),
                                BackupSetDTO(order: 2, weight: 82.5, reps: 6, rpe: 9.5, type: SetType.normal.rawValue, completed: true)
                            ]
                        )
                    ]
                )
            ],
            metrics: [
                BackupMetricDTO(date: Date(timeIntervalSince1970: 1_699_400_000), bodyweight: 72.5, bodyFat: nil)
            ]
        )
    }

    func testRoundTripPreservesEverything() throws {
        let original = sampleFile()
        let data = try BackupService.encode(original)
        let decoded = try BackupService.decode(data)
        XCTAssertEqual(decoded, original)
    }

    func testEncodedJSONIsReadable() throws {
        let data = try BackupService.encode(sampleFile())
        let text = String(data: data, encoding: .utf8) ?? ""
        XCTAssertTrue(text.contains("\"version\""))
        XCTAssertTrue(text.contains("barbell-bench-press"))
        XCTAssertTrue(text.contains("状态不错"))
    }

    func testDecodingRejectsGarbage() {
        let garbage = Data("not json".utf8)
        XCTAssertThrowsError(try BackupService.decode(garbage))
    }

    func testUnknownExerciseDetection() {
        let known = [
            Exercise(
                id: "barbell-bench-press",
                name: "杠铃卧推",
                pattern: .horizontalPush,
                primary: [.chest],
                equipment: .barbell,
                isCompound: true,
                loadIncrement: 2.5,
                targetReps: 6...10
            )
        ]
        let file = sampleFile()
        XCTAssertTrue(BackupService.unknownExerciseIDs(in: file, exercises: known).isEmpty)

        let other = Exercise(
            id: "custom-move",
            name: "自定义动作",
            pattern: .arm,
            primary: [.arms],
            equipment: .dumbbell,
            isCompound: false,
            loadIncrement: 1,
            targetReps: 8...12
        )
        var mutated = file
        mutated.sessions[0].exercises.append(
            BackupExerciseDTO(exerciseID: "custom-move", order: 1, suggestedWeight: 10, restSeconds: 60, sets: [])
        )
        XCTAssertEqual(BackupService.unknownExerciseIDs(in: mutated, exercises: [known[0], other]), [])
        XCTAssertEqual(
            BackupService.unknownExerciseIDs(in: mutated, exercises: [known[0]]),
            ["custom-move"]
        )
    }
}
