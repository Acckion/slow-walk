import SlowWalkDomain
import SlowWalkMedicinePipeline
import XCTest

final class MedicineNameNormalizerTests: XCTestCase {
    func testFoldsCaseWidthPunctuationAndWhitespace() {
        let result = MedicineNameNormalizer().normalize(
            makeRecognitionInput(["  ＩＢＵＰＲＯＦＥＮ™  "])
        )

        XCTAssertEqual(result.normalizedQuery, "ibuprofen")
        XCTAssertEqual(result.queryVariants, ["ibuprofen"])
    }

    func testRemovesSpecificationAndRecordsDosageForm() {
        let result = MedicineNameNormalizer().normalize(
            makeRecognitionInput([
                "Acetaminophen 500mg tablets",
            ])
        )

        XCTAssertEqual(result.normalizedQuery, "acetaminophen")
        XCTAssertEqual(result.removedSpecifications, ["500mg"])
        XCTAssertEqual(result.dosageForms, ["tablets"])
    }

    func testRemovesChineseSpecificationAndSuffixDosageForm() {
        let result = MedicineNameNormalizer().normalize(
            makeRecognitionInput(["布洛芬缓释片300mg"])
        )

        XCTAssertEqual(result.normalizedQuery, "布洛芬")
        XCTAssertEqual(result.removedSpecifications, ["300mg"])
        XCTAssertEqual(result.dosageForms, ["缓释片"])
    }

    func testQuantityAndDosageFormRetainDosageEvidence() {
        let result = MedicineNameNormalizer().normalize(
            makeRecognitionInput(["布洛芬 2 片"])
        )

        XCTAssertEqual(result.normalizedQuery, "布洛芬")
        XCTAssertEqual(result.removedSpecifications, ["2 片"])
        XCTAssertEqual(result.dosageForms, ["片"])
    }

    func testManufacturerLineIsDiscardedWithoutGuessingName() {
        let result = MedicineNameNormalizer().normalize(
            makeRecognitionInput([
                "Example Pharmaceutical Ltd",
                "Ibuprofen",
            ])
        )

        XCTAssertEqual(result.normalizedQuery, "ibuprofen")
        XCTAssertFalse(
            result.queryVariants.contains(
                "example pharmaceutical ltd"
            )
        )
        XCTAssertTrue(
            result.discardedNoise.contains("pharmaceutical")
        )
    }

    func testEmbeddedNewlineSeparatesManufacturerAndMedicineName() {
        let result = MedicineNameNormalizer().normalize(
            makeRecognitionInput([
                "Example Pharma Ltd\nAcetaminophen",
            ])
        )

        XCTAssertEqual(result.normalizedQuery, "acetaminophen")
        XCTAssertEqual(result.queryVariants, ["acetaminophen"])
        XCTAssertTrue(result.discardedNoise.contains("pharma"))
    }

    func testChineseManufacturerLineIsDiscarded() {
        let result = MedicineNameNormalizer().normalize(
            makeRecognitionInput([
                "示例制药有限公司",
                "氯雷他定",
            ])
        )

        XCTAssertEqual(result.normalizedQuery, "氯雷他定")
        XCTAssertTrue(
            result.discardedNoise.contains("示例制药有限公司")
        )
    }

    func testNoiseOnlyInputProducesEmptyQuery() {
        let result = MedicineNameNormalizer().normalize(
            makeRecognitionInput(["###", "OTC", "药品"])
        )

        XCTAssertTrue(result.normalizedQuery.isEmpty)
        XCTAssertTrue(result.queryVariants.isEmpty)
    }

    func testNormalizationIsIdempotent() {
        let normalizer = MedicineNameNormalizer()
        let first = normalizer.normalizeName("  CÉTIRIZINE™ ")
        let second = normalizer.normalizeName(first)

        XCTAssertEqual(first, second)
        XCTAssertEqual(first, "cetirizine")
    }
}
