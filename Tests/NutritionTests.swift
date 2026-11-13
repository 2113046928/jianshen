import XCTest
@testable import TrainLedger

final class NutritionEngineTests: XCTestCase {

    // 期望值来自 _spec/test_nutrition.py（同一套公式的可运行参考实现）
    private let male = BodyProfile(
        sex: .male, age: 30, heightCM: 180, weightKG: 80, activity: .moderate
    )

    private let female = BodyProfile(
        sex: .female, age: 28, heightCM: 165, weightKG: 60, activity: .light
    )

    func testBMRMatchesMifflinStJeor() {
        XCTAssertEqual(NutritionEngine.bmr(male), 1780, accuracy: 0.01)
        XCTAssertEqual(NutritionEngine.bmr(female), 1330.25, accuracy: 0.01)
    }

    func testTDEEUsesActivityFactor() {
        XCTAssertEqual(NutritionEngine.tdee(male), 2759, accuracy: 0.5)
    }

    func testCutPlanMacros() {
        let plan = NutritionEngine.plan(for: male, phase: .cut)
        XCTAssertEqual(plan.targets.calories, 2262.4, accuracy: 0.1)
        XCTAssertEqual(plan.targets.proteinG, 176, accuracy: 0.1)   // 2.2 g/kg
        XCTAssertEqual(plan.targets.fatG, 72, accuracy: 0.1)        // 0.9 g/kg
        XCTAssertEqual(plan.targets.carbsG, 227.6, accuracy: 0.1)
    }

    func testBulkPlanMacros() {
        let plan = NutritionEngine.plan(for: male, phase: .bulk)
        XCTAssertEqual(plan.targets.calories, 3034.9, accuracy: 0.1)
        XCTAssertEqual(plan.targets.proteinG, 144, accuracy: 0.1)   // 1.8 g/kg
    }

    func testMacrosSumBackToCalories() {
        for phase in Phase.allCases {
            let plan = NutritionEngine.plan(for: male, phase: phase)
            XCTAssertEqual(
                plan.targets.caloriesFromMacros,
                plan.targets.calories,
                accuracy: 1.0,
                "\(phase) 宏量回算与目标热量不一致"
            )
        }
    }

    func testCutNeverBelowBMR() {
        let tiny = BodyProfile(sex: .female, age: 45, heightCM: 150, weightKG: 42, activity: .sedentary)
        let plan = NutritionEngine.plan(for: tiny, phase: .cut)
        XCTAssertGreaterThanOrEqual(plan.targets.calories, plan.bmr)
    }

    func testMaintainEqualsTDEE() {
        let plan = NutritionEngine.plan(for: male, phase: .maintain)
        XCTAssertEqual(plan.targets.calories, plan.tdee, accuracy: 0.2)
    }

    func testProteinPerKgReflectsPhase() {
        XCTAssertEqual(NutritionEngine.plan(for: male, phase: .cut).targets.proteinPerKg, 2.2, accuracy: 0.01)
        XCTAssertEqual(NutritionEngine.plan(for: male, phase: .bulk).targets.proteinPerKg, 1.8, accuracy: 0.01)
    }

    func testMealSplitSumsToCalories() {
        XCTAssertEqual(NutritionEngine.mealSplit(calories: 2400, meals: 3).reduce(0, +), 2400, accuracy: 1)
        XCTAssertEqual(NutritionEngine.mealSplit(calories: 2400, meals: 4).reduce(0, +), 2400, accuracy: 1)
        XCTAssertEqual(NutritionEngine.mealSplit(calories: 2400, meals: 4).count, 4)
    }

    func testWeeklyAdjustmentCut() {
        XCTAssertEqual(NutritionEngine.weeklyAdjustment(weeklyChangePercent: -0.006, phase: .cut).action, .hold)
        XCTAssertEqual(NutritionEngine.weeklyAdjustment(weeklyChangePercent: -0.001, phase: .cut).action, .reduce)
        XCTAssertEqual(NutritionEngine.weeklyAdjustment(weeklyChangePercent: -0.02, phase: .cut).action, .increase)
    }

    func testWeeklyAdjustmentBulk() {
        XCTAssertEqual(NutritionEngine.weeklyAdjustment(weeklyChangePercent: 0.003, phase: .bulk).action, .hold)
        XCTAssertEqual(NutritionEngine.weeklyAdjustment(weeklyChangePercent: 0.0, phase: .bulk).action, .increase)
        XCTAssertEqual(NutritionEngine.weeklyAdjustment(weeklyChangePercent: 0.01, phase: .bulk).action, .reduce)
    }

    func testWeeklyAdjustmentMaintain() {
        XCTAssertEqual(NutritionEngine.weeklyAdjustment(weeklyChangePercent: 0.02, phase: .maintain).action, .adjust)
        XCTAssertEqual(NutritionEngine.weeklyAdjustment(weeklyChangePercent: 0.001, phase: .maintain).action, .hold)
    }
}

final class PeriodizationTests: XCTestCase {

    func testFirstFourWeeksAreLoading() {
        for sessions in 0..<12 {
            XCTAssertFalse(
                Periodization.isDeloadWeek(finishedSessions: sessions, sessionsPerWeek: 3),
                "第 \(sessions / 3 + 1) 周不应减载"
            )
        }
    }

    func testFifthWeekIsDeload() {
        for sessions in 12..<15 {
            XCTAssertTrue(Periodization.isDeloadWeek(finishedSessions: sessions, sessionsPerWeek: 3))
        }
    }

    func testBlockRestartsAfterDeload() {
        for sessions in 15..<18 {
            XCTAssertFalse(Periodization.isDeloadWeek(finishedSessions: sessions, sessionsPerWeek: 3))
        }
    }

    func testWeeklyFrequencyChangesBlockLength() {
        // 每周 4 练时，第 17–20 次落在第 5 周，应当减载
        XCTAssertTrue(Periodization.isDeloadWeek(finishedSessions: 17, sessionsPerWeek: 4))
        XCTAssertFalse(Periodization.isDeloadWeek(finishedSessions: 17, sessionsPerWeek: 3))
    }

    func testZeroSessionsIsSafe() {
        XCTAssertFalse(Periodization.isDeloadWeek(finishedSessions: 0, sessionsPerWeek: 0))
        XCTAssertEqual(Periodization.blockWeek(finishedSessions: 0, sessionsPerWeek: 3), 1)
    }
}

final class FoodCatalogTests: XCTestCase {

    private let chicken = FoodItem(name: "鸡胸肉", protein: 31, kcal: 165)

    func testGramsForProtein() {
        XCTAssertEqual(chicken.grams(forProtein: 31), 100, accuracy: 0.01)
        XCTAssertEqual(chicken.grams(forProtein: 62), 200, accuracy: 0.01)
    }

    func testProteinForGrams() {
        XCTAssertEqual(chicken.protein(forGrams: 150), 46.5, accuracy: 0.01)
    }

    func testZeroProteinDoesNotDivideByZero() {
        let water = FoodItem(name: "水", protein: 0, kcal: 0)
        XCTAssertEqual(water.grams(forProtein: 30), 0)
    }
}
