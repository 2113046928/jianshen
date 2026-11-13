import XCTest
@testable import TrainLedger

/// 期望值来自 _spec/bodyfat.py（同一套公式的可运行参考实现）
final class BodyCompositionTests: XCTestCase {

    // 男：180cm / 80kg / 30 岁
    private let maleWeight = 80.0
    private let maleHeight = 180.0

    // 女：165cm / 60kg / 28 岁
    private let femaleWeight = 60.0
    private let femaleHeight = 165.0

    func testBMI() {
        XCTAssertEqual(
            BodyComposition.bmi(weightKG: maleWeight, heightCM: maleHeight),
            24.69, accuracy: 0.01
        )
        XCTAssertEqual(
            BodyComposition.bmi(weightKG: femaleWeight, heightCM: femaleHeight),
            22.04, accuracy: 0.01
        )
        XCTAssertEqual(BodyComposition.bmi(weightKG: 80, heightCM: 0), 0)
    }

    func testDeurenberg() {
        XCTAssertEqual(
            BodyComposition.deurenberg(
                weightKG: maleWeight, heightCM: maleHeight, age: 30, sex: .male
            ),
            20.3, accuracy: 0.1
        )
        XCTAssertEqual(
            BodyComposition.deurenberg(
                weightKG: femaleWeight, heightCM: femaleHeight, age: 28, sex: .female
            ),
            27.5, accuracy: 0.1
        )
    }

    func testNavyMale() {
        let value = BodyComposition.navy(
            waistCM: 85, neckCM: 38, hipCM: nil, heightCM: maleHeight, sex: .male
        )
        XCTAssertNotNil(value)
        XCTAssertEqual(value!, 16.1, accuracy: 0.1)
    }

    func testNavyFemale() {
        let value = BodyComposition.navy(
            waistCM: 72, neckCM: 32, hipCM: 95, heightCM: femaleHeight, sex: .female
        )
        XCTAssertNotNil(value)
        XCTAssertEqual(value!, 25.9, accuracy: 0.1)
    }

    func testNavyRequiresValidInput() {
        // 腰围小于颈围，对数无定义
        XCTAssertNil(
            BodyComposition.navy(waistCM: 38, neckCM: 40, hipCM: nil, heightCM: 180, sex: .male)
        )
        // 女性没有臀围
        XCTAssertNil(
            BodyComposition.navy(waistCM: 72, neckCM: 32, hipCM: nil, heightCM: 165, sex: .female)
        )
        // 女性臀围为 0
        XCTAssertNil(
            BodyComposition.navy(waistCM: 72, neckCM: 32, hipCM: 0, heightCM: 165, sex: .female)
        )
    }

    func testNavyIsClampedToSaneRange() {
        let value = BodyComposition.navy(
            waistCM: 200, neckCM: 10, hipCM: nil, heightCM: 180, sex: .male
        )
        XCTAssertNotNil(value)
        XCTAssertLessThanOrEqual(value!, 60)
        XCTAssertGreaterThanOrEqual(value!, 2)
    }

    func testLeanAndFatMass() {
        XCTAssertEqual(
            BodyComposition.leanMass(weightKG: 80, bodyFatPercent: 16.1),
            67.12, accuracy: 0.05
        )
        XCTAssertEqual(
            BodyComposition.fatMass(weightKG: 80, bodyFatPercent: 16.1),
            12.88, accuracy: 0.05
        )
    }

    func testFFMI() {
        let lean = BodyComposition.leanMass(weightKG: 80, bodyFatPercent: 16.1)
        XCTAssertEqual(
            BodyComposition.ffmi(leanKG: lean, heightCM: 180),
            20.7, accuracy: 0.1
        )
        // 归一化对 180cm 没有修正
        XCTAssertEqual(
            BodyComposition.normalizedFFMI(leanKG: lean, heightCM: 180),
            20.7, accuracy: 0.1
        )
        // 190cm 会被下调
        XCTAssertLessThan(
            BodyComposition.normalizedFFMI(leanKG: lean, heightCM: 190),
            BodyComposition.ffmi(leanKG: lean, heightCM: 190)
        )
    }

    func testTargetWeight() {
        let lean = BodyComposition.leanMass(weightKG: 80, bodyFatPercent: 16.1)
        let target = BodyComposition.targetWeight(leanKG: lean, targetBodyFatPercent: 12)
        XCTAssertNotNil(target)
        XCTAssertEqual(target!, 76.3, accuracy: 0.2)
        // 目标体脂越高，体重越大
        let easier = BodyComposition.targetWeight(leanKG: lean, targetBodyFatPercent: 18)!
        XCTAssertGreaterThan(easier, target!)
    }

    func testCategoryBands() {
        XCTAssertEqual(BodyComposition.category(bodyFatPercent: 4, sex: .male), .low)
        XCTAssertEqual(BodyComposition.category(bodyFatPercent: 12, sex: .male), .athletic)
        XCTAssertEqual(BodyComposition.category(bodyFatPercent: 16.1, sex: .male), .fit)
        XCTAssertEqual(BodyComposition.category(bodyFatPercent: 22, sex: .male), .average)
        XCTAssertEqual(BodyComposition.category(bodyFatPercent: 27, sex: .male), .high)
        XCTAssertEqual(BodyComposition.category(bodyFatPercent: 33, sex: .male), .obese)

        XCTAssertEqual(BodyComposition.category(bodyFatPercent: 12, sex: .female), .low)
        XCTAssertEqual(BodyComposition.category(bodyFatPercent: 25.9, sex: .female), .average)
        XCTAssertEqual(BodyComposition.category(bodyFatPercent: 40, sex: .female), .obese)
    }

    func testHealthyRange() {
        XCTAssertEqual(BodyComposition.healthyRange(sex: .male), 10...20)
        XCTAssertEqual(BodyComposition.healthyRange(sex: .female), 18...28)
    }

    func testNavyAndDeurenbergAgreeWithinAFewPoints() {
        // 两个方法给男性温和体型的结果不该差太多（<8 个点）
        let navy = BodyComposition.navy(
            waistCM: 85, neckCM: 38, hipCM: nil, heightCM: 180, sex: .male
        )!
        let deurenberg = BodyComposition.deurenberg(
            weightKG: 80, heightCM: 180, age: 30, sex: .male
        )
        XCTAssertLessThan(abs(navy - deurenberg), 8)
    }
}
