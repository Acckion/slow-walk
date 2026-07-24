import SlowWalkDataInterfaces
import SlowWalkDomain
import SlowWalkMedicinePipeline
import XCTest

final class MedicineResolverTests: XCTestCase {
    func testExactCanonicalNameResolves() throws {
        let result = try resolve(
            makeRecognitionInput(["Acetaminophen"])
        )

        XCTAssertEqual(result.status, .resolved)
        XCTAssertEqual(
            result.selectedMedicine?.id,
            "demo-acetaminophen"
        )
        XCTAssertTrue(
            result.candidates[0].matchReasons.contains(
                .canonicalExact
            )
        )
    }

    func testExactAliasResolves() throws {
        let result = try resolve(
            makeRecognitionInput(["对乙酰氨基酚"])
        )

        XCTAssertEqual(result.status, .resolved)
        XCTAssertEqual(
            result.selectedMedicine?.id,
            "demo-acetaminophen"
        )
        XCTAssertEqual(
            result.candidates[0].matchedAlias,
            "对乙酰氨基酚"
        )
    }

    func testSharedAliasIsAmbiguous() throws {
        let result = try resolve(
            makeRecognitionInput(["Cold Relief"])
        )

        XCTAssertEqual(result.status, .ambiguous)
        XCTAssertNil(result.selectedMedicine)
        XCTAssertEqual(result.candidates.count, 2)
        XCTAssertTrue(result.requiresUserConfirmation)
    }

    func testLowConfidenceIsInsufficientEvenForExactName() throws {
        let result = try resolve(
            makeRecognitionInput(
                ["Ibuprofen"],
                confidence: 0.4
            )
        )

        XCTAssertEqual(result.status, .insufficientEvidence)
        XCTAssertNil(result.selectedMedicine)
        XCTAssertEqual(
            result.candidates.first?.medicine.id,
            "demo-ibuprofen"
        )
    }

    func testMissingConfidenceIsInsufficientEvidence() throws {
        let result = try resolve(
            makeRecognitionInput(
                ["Ibuprofen"],
                confidence: nil
            )
        )

        XCTAssertEqual(result.status, .insufficientEvidence)
        XCTAssertTrue(result.requiresUserConfirmation)
    }

    func testUnknownNameIsNotFound() throws {
        let result = try resolve(
            makeRecognitionInput(["Unknown Remedy"])
        )

        XCTAssertEqual(result.status, .notFound)
        XCTAssertTrue(result.candidates.isEmpty)
        XCTAssertNil(result.selectedMedicine)
    }

    func testNoiseOnlyInputIsRecognitionFailed() throws {
        let result = try resolve(
            makeRecognitionInput(["###", "OTC"])
        )

        XCTAssertEqual(result.status, .recognitionFailed)
        XCTAssertTrue(result.candidates.isEmpty)
    }

    func testOneEditDifferenceIsOnlyConservativeCandidate() throws {
        let result = try resolve(
            makeRecognitionInput(["Ibuprofem"])
        )

        XCTAssertEqual(result.status, .insufficientEvidence)
        XCTAssertNil(result.selectedMedicine)
        XCTAssertEqual(
            result.candidates.first?.medicine.id,
            "demo-ibuprofen"
        )
        XCTAssertTrue(
            result.candidates.first?.matchReasons.contains(
                .conservativeApproximate
            ) == true
        )
    }

    func testContainedNameIsNotAutomaticallyResolved() throws {
        let result = try resolve(
            makeRecognitionInput([
                "package acetaminophen front",
            ])
        )

        XCTAssertEqual(result.status, .insufficientEvidence)
        XCTAssertNil(result.selectedMedicine)
        XCTAssertEqual(
            result.candidates.first?.medicine.id,
            "demo-acetaminophen"
        )
    }

    func testCandidateOrderIsIndependentOfCatalogOrder() throws {
        let catalog = try loadDemoCatalog()
        let input = makeRecognitionInput(["Cold Relief"])
        let normalizer = MedicineNameNormalizer()
        let normalized = normalizer.normalize(input)
        let resolver = MedicineResolver()

        let forward = resolver.resolve(
            input: input,
            normalizedName: normalized,
            medicines: catalog.medicines
        )
        let reverse = resolver.resolve(
            input: input,
            normalizedName: normalized,
            medicines: Array(catalog.medicines.reversed())
        )

        XCTAssertEqual(forward, reverse)
    }

    func testEvidenceContainsMatcherAndSourceVersions() throws {
        let result = try resolve(
            makeRecognitionInput(["Metformin"])
        )

        XCTAssertEqual(
            result.evidence.matcherVersion,
            "slowwalk-resolver-v1"
        )
        XCTAssertEqual(
            result.evidence.sourceDataVersions,
            ["slowwalk-demo-catalog-v1"]
        )
    }

    private func resolve(
        _ input: MedicineRecognitionInput
    ) throws -> MedicineResolution {
        let catalog = try loadDemoCatalog()
        let normalizer = MedicineNameNormalizer()
        return MedicineResolver().resolve(
            input: input,
            normalizedName: normalizer.normalize(input),
            medicines: catalog.medicines
        )
    }
}
