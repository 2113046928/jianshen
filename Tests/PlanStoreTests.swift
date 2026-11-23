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

// MARK: - 按星期排课

final class PlanScheduleTests: XCTestCase {

    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }

    /// 2026-11-23 12:00 UTC，星期几由日历自己算，避免写死
    private var sampleDate: Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: 23, hour: 12))!
    }

    private var sampleWeekday: Int {
        calendar.component(.weekday, from: sampleDate)
    }

    private func plan(weekdays: [Int?]) -> ProgramTemplate {
        ProgramTemplate(
            id: PlanStore.customID,
            name: "测试计划",
            subtitle: "",
            days: weekdays.enumerated().map { index, weekday in
                ProgramDay(
                    id: "d\(index)",
                    name: "第 \(index + 1) 天",
                    focus: "",
                    exerciseIDs: ["barbell-bench-press"],
                    weekday: weekday
                )
            }
        )
    }

    func testMatchesConfiguredWeekday() {
        let template = plan(weekdays: [sampleWeekday, nil])
        let day = PlanSchedule.day(
            for: template,
            finishedSessions: 0,
            on: sampleDate,
            calendar: calendar
        )
        XCTAssertEqual(day?.id, "d0")
    }

    func testReturnsNilOnRestDay() {
        let other = sampleWeekday == 1 ? 2 : 1
        let template = plan(weekdays: [other])
        XCTAssertTrue(PlanSchedule.usesWeekdays(template))
        XCTAssertNil(
            PlanSchedule.day(for: template, finishedSessions: 0, on: sampleDate, calendar: calendar)
        )
    }

    func testFallsBackToRotationWhenNoWeekdays() {
        let template = plan(weekdays: [nil, nil])
        XCTAssertFalse(PlanSchedule.usesWeekdays(template))

        let first = PlanSchedule.day(for: template, finishedSessions: 0, on: sampleDate, calendar: calendar)
        let second = PlanSchedule.day(for: template, finishedSessions: 1, on: sampleDate, calendar: calendar)
        let third = PlanSchedule.day(for: template, finishedSessions: 2, on: sampleDate, calendar: calendar)

        XCTAssertEqual(first?.id, "d0")
        XCTAssertEqual(second?.id, "d1")
        XCTAssertEqual(third?.id, "d0")
    }

    func testEmptyPlanReturnsNil() {
        let empty = ProgramTemplate(id: PlanStore.customID, name: "空", subtitle: "", days: [])
        XCTAssertNil(PlanSchedule.day(for: empty, finishedSessions: 0, on: sampleDate, calendar: calendar))
    }

    func testWeekdayNameMapping() {
        XCTAssertEqual(PlanSchedule.name(for: 1), "周日")
        XCTAssertEqual(PlanSchedule.name(for: 2), "周一")
        XCTAssertEqual(PlanSchedule.name(for: 7), "周六")
        // 越界也不崩
        XCTAssertEqual(PlanSchedule.name(for: 0), "周日")
        XCTAssertEqual(PlanSchedule.name(for: 99), "周六")
    }
}
