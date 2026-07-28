import Foundation
import SlowWalkClientCore
import SlowWalkDomain
import XCTest

final class OCRContractsTests: XCTestCase {
    func testSingleObservationMapsToRecognitionInput()
        throws
    {
        let mapper = try makeRecognitionMapper()
        let input = mapper.map(
            observations: [makeObservation()],
            capturedAt: clientTestDate
        )

        XCTAssertEqual(
            input.recognizedTexts,
            ["Demo Medicine"]
        )
        XCTAssertEqual(input.rawConfidence, 0.95)
        XCTAssertEqual(input.languageCode, "en")
        XCTAssertEqual(input.capturedAt, clientTestDate)
    }

    func testMultilineObservationsUseStableVisualOrder()
        throws
    {
        let mapper = try makeRecognitionMapper()
        let observations = [
            makeObservation(
                text: "third",
                x: 0,
                y: 0.8
            ),
            makeObservation(
                text: "second",
                x: 0.5,
                y: 0.2
            ),
            makeObservation(
                text: "first",
                x: 0,
                y: 0.2
            ),
        ]

        let first = mapper.map(
            observations: observations,
            capturedAt: clientTestDate
        )
        let second = mapper.map(
            observations: Array(
                observations.reversed()
            ),
            capturedAt: clientTestDate
        )

        XCTAssertEqual(
            first.recognizedTexts,
            ["first", "second", "third"]
        )
        XCTAssertEqual(first, second)
    }

    func testLowConfidenceObservationCanBeDiscarded()
        throws
    {
        let mapper = try makeRecognitionMapper(
            minimumConfidence: 0.8,
            handling: .discard
        )
        let input = mapper.map(
            observations: [
                makeObservation(
                    text: "low",
                    confidence: 0.2
                ),
                makeObservation(
                    text: "high",
                    confidence: 0.9,
                    y: 0.5
                ),
            ],
            capturedAt: clientTestDate
        )

        XCTAssertEqual(input.recognizedTexts, ["high"])
        XCTAssertEqual(input.rawConfidence, 0.9)
    }

    func testLowConfidenceObservationCanBeRetainedAsEvidence()
        throws
    {
        let mapper = try makeRecognitionMapper(
            minimumConfidence: 0.8,
            handling: .retainAsEvidence
        )
        let input = mapper.map(
            observations: [
                makeObservation(
                    text: "low",
                    confidence: 0.2
                ),
                makeObservation(
                    text: "high",
                    confidence: 0.8,
                    y: 0.5
                ),
            ],
            capturedAt: clientTestDate
        )

        XCTAssertEqual(
            input.recognizedTexts,
            ["low", "high"]
        )
        XCTAssertEqual(input.rawConfidence, 0.5)
    }

    func testEmptyAndWhitespaceTextAreRemoved()
        throws
    {
        let input = try makeRecognitionMapper().map(
            observations: [
                makeObservation(text: ""),
                makeObservation(
                    text: " \n ",
                    y: 0.5
                ),
            ],
            capturedAt: clientTestDate
        )

        XCTAssertTrue(input.recognizedTexts.isEmpty)
        XCTAssertNil(input.rawConfidence)
        XCTAssertNil(input.languageCode)
    }

    func testMultilingualTextIsPreserved()
        throws
    {
        let input = try makeRecognitionMapper().map(
            observations: [
                makeObservation(
                    text: "感冒药",
                    x: 0,
                    y: 0,
                    languageCode: "zh-Hans"
                ),
                makeObservation(
                    text: "TABLETS",
                    x: 0,
                    y: 0.5,
                    languageCode: "en"
                ),
            ],
            capturedAt: clientTestDate
        )

        XCTAssertEqual(
            input.recognizedTexts,
            ["感冒药", "TABLETS"]
        )
        XCTAssertEqual(input.languageCode, "zh-Hans")
    }

    func testInvalidConfidenceThresholdIsRejected() {
        XCTAssertThrowsError(
            try MedicineRecognitionMappingConfiguration(
                minimumConfidence: 1.1,
                lowConfidenceHandling: .discard
            )
        ) { error in
            XCTAssertEqual(
                error as? ClientCoreConfigurationError,
                .invalidConfidenceThreshold
            )
        }
    }

    func testRecognizerReturnsObservationsWithoutResolvingMedicine()
        async throws
    {
        let observation = makeObservation()
        let recognizer = MockMedicineTextRecognizer(
            behavior: .observations([observation])
        )

        let output = try await recognizer.recognizeText(
            in: makeOCRImageInput()
        )

        XCTAssertEqual(output, [observation])
        XCTAssertEqual(output.first?.text, "Demo Medicine")
    }

    func testImageBytesDoNotEnterRecognitionInput()
        throws
    {
        let image = makeOCRImageInput()
        let input = try makeRecognitionMapper().map(
            observations: [makeObservation()],
            capturedAt: image.capturedAt
        )
        let encoded = try JSONEncoder().encode(input)
        let json = try XCTUnwrap(
            String(data: encoded, encoding: .utf8)
        )

        XCTAssertFalse(json.contains("AQID"))
        XCTAssertFalse(json.contains("orientation"))
    }
}
