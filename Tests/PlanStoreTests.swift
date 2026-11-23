import XCTest
@testable import TrainLedger

final class PlanStoreTests: XCTestCase {

    private func sample() -> ProgramTemplate {
        ProgramTemplate(
            id: PlanStore.customID,
            name: "我的计划",
            subtitle: PlanStore.subtitle(dayCount: 2),
            days: [
                ProgramDay(
                    id: "d1",
                    name: "上肢",
                    focus: "胸 · 背",
                    exerciseIDs: ["barbell-bench-press", "barbell-row"]
                ),
                ProgramDay(
                    id: "d2",
                    name: "下肢",
                    focus: "腿",
                    exerciseIDs: ["back-squat"]
                )
            ]
        )
    }

    func testEncodeDecodeRoundTrip() {
        let original = sample()
        let json = PlanStore.encode(original)
        XCTAssertNotNil(json)
        XCTAssertEqual(PlanStore.decode(json), original)
    }

    func testDecodeRejectsGarbage() {
        XCTAssertNil(PlanStore.decode(nil))
        XCTAssertNil(PlanStore.decode(""))
        XCTAssertNil(PlanStore.decode("not json"))
        XCTAssertNil(PlanStore.decode("{\"id\":\"custom\"}"))
    }

    func testDraftFromPresetKeepsDays() {
        let base = ProgramTemplates.ppl
        let draft = PlanStore.makeDraft(from: base)

        XCTAssertEqual(draft.id, PlanStore.customID)
        XCTAssertEqual(draft.days.count, base.days.count)
        XCTAssertEqual(draft.days.first?.exerciseIDs, base.days.first?.exerciseIDs)
        XCTAssertEqual(draft.days.first?.name, base.days.first?.name)
    }

    func testDayRotationFollowsCustomOrder() {
        let template = sample()

        XCTAssertEqual(WorkoutFactory.nextDay(program: template, finishedSessionCount: 0).id, "d1")
        XCTAssertEqual(WorkoutFactory.nextDay(program: template, finishedSessionCount: 1).id, "d2")
        // 轮完一圈回到第一天
        XCTAssertEqual(WorkoutFactory.nextDay(program: template, finishedSessionCount: 2).id, "d1")
    }

    func testNormalizedSubtitleTracksDayCount() {
        var draft = sample()
        draft.days.append(PlanStore.blankDay(index: 3))

        let normalized = PlanStore.normalized(draft)
        XCTAssertEqual(normalized.subtitle, PlanStore.subtitle(dayCount: 3))
        XCTAssertEqual(normalized.days.count, 3)
    }

    func testBlankDayStartsEmptyAndHasID() {
        let day = PlanStore.blankDay(index: 1)
        XCTAssertTrue(day.exerciseIDs.isEmpty)
        XCTAssertFalse(day.id.isEmpty)
        XCTAssertTrue(day.id.hasPrefix("custom-"))
    }

    func testEmptyTemplateFallsBackToFreeDay() {
        let empty = ProgramTemplate(id: "custom", name: "空", subtitle: "", days: [])
        let day = WorkoutFactory.nextDay(program: empty, finishedSessionCount: 3)
        XCTAssertTrue(day.exerciseIDs.isEmpty)
    }
}
