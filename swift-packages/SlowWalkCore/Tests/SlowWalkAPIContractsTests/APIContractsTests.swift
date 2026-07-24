import Foundation
import SlowWalkAPIContracts
import SlowWalkDomain
import XCTest

final class APIContractsTests: XCTestCase {
    private let timestamp = Date(timeIntervalSince1970: 1_735_689_600)

    func testRequestAndResponseRoundTripWithISO8601Coding() throws {
        let request = makeRequest()
        let assessment = RiskAssessment(
            level: .green,
            reasons: [],
            recommendedActions: [.followVerifiedSourceInformation],
            assessedAt: timestamp,
            requiresProfessionalAdvice: false,
            requiresFamilyAttention: false,
            evidenceCompleteness: .complete
        )
        let response = RiskAssessmentResponseDTO(
            requestID: request.requestID,
            assessment: assessment,
            sourceReferences: request.medicine.sourceReferences,
            generatedAt: timestamp,
            apiVersion: SlowWalkAPI.version
        )
        let envelope = RoundTripEnvelope(request: request, response: response)

        let data = try SlowWalkJSONCoding.makeEncoder().encode(envelope)
        let decoded = try SlowWalkJSONCoding.makeDecoder().decode(
            RoundTripEnvelope.self,
            from: data
        )

        XCTAssertEqual(decoded, envelope)
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertTrue(json.contains("2025-01-01T00:00:00.000Z"))
        XCTAssertFalse(json.contains("RiskAssessmentRequestDTO"))
    }

    func testEncoderUsesFractionalISO8601AndDecoderPreservesMilliseconds() throws {
        let date = Date(timeIntervalSince1970: 1_735_689_600.123)
        let data = try SlowWalkJSONCoding.makeEncoder().encode(DateBox(date: date))
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))
        let decoded = try SlowWalkJSONCoding.makeDecoder().decode(
            DateBox.self,
            from: data
        )

        XCTAssertTrue(json.contains("2025-01-01T00:00:00.123Z"))
        XCTAssertEqual(decoded.date.timeIntervalSince1970, date.timeIntervalSince1970, accuracy: 0.001)
    }

    func testDecoderAcceptsISO8601WithoutFractionalSeconds() throws {
        let data = Data(#"{"date":"2025-01-01T00:00:00Z"}"#.utf8)

        let decoded = try SlowWalkJSONCoding.makeDecoder().decode(
            DateBox.self,
            from: data
        )

        XCTAssertEqual(decoded.date, timestamp)
    }

    func testDecoderRejectsNonISO8601Date() {
        let data = Data(#"{"date":"01/01/2025"}"#.utf8)

        XCTAssertThrowsError(
            try SlowWalkJSONCoding.makeDecoder().decode(DateBox.self, from: data)
        )
    }

    func testAPIErrorRoundTripsWithoutUntypedDetails() throws {
        let error = APIErrorDTO(
            code: "validation_failed",
            message: "The request is invalid.",
            requestID: fixedUUID(lastByte: 9),
            details: [
                APIErrorDetailDTO(
                    field: "scanEvent.confidence",
                    code: "out_of_range",
                    message: "Confidence must be between zero and one."
                ),
            ]
        )

        let data = try SlowWalkJSONCoding.makeEncoder().encode(error)
        let decoded = try SlowWalkJSONCoding.makeDecoder().decode(
            APIErrorDTO.self,
            from: data
        )

        XCTAssertEqual(decoded, error)
    }

    func testAllSharedRiskFixturesDecode() throws {
        let fixtureNames = [
            "green-risk.json",
            "yellow-risk.json",
            "orange-risk.json",
            "red-risk.json",
            "recognition-failed.json",
        ]
        let fixtureDirectory = sharedFixtureDirectory()

        for fixtureName in fixtureNames {
            let fixtureURL = fixtureDirectory.appendingPathComponent(fixtureName)
            let data = try Data(contentsOf: fixtureURL)
            let envelope = try SlowWalkJSONCoding.makeDecoder().decode(
                FixtureEnvelope.self,
                from: data
            )

            XCTAssertEqual(envelope.request.apiVersion, SlowWalkAPI.version)
            XCTAssertEqual(
                envelope.expectedResponse.apiVersion,
                SlowWalkAPI.version
            )
            XCTAssertEqual(
                envelope.request.requestID,
                envelope.expectedResponse.requestID
            )
        }
    }

    private func makeRequest() -> RiskAssessmentRequestDTO {
        let source = SourceReference(
            sourceName: "Demo Source",
            documentTitle: "DEMO DATA - NOT FOR CLINICAL USE",
            optionalURL: nil,
            retrievedAt: timestamp,
            versionOrDate: "demo-v1"
        )
        let medicine = Medicine(
            id: "medicine-a",
            canonicalName: "Demo Medicine",
            aliases: ["Demo Alias"],
            activeIngredientIDs: ["ingredient-a"],
            medicineCategory: .other,
            sourceReferences: [source],
            dosageTextFromSource: nil,
            contraindicationTags: []
        )
        let profile = UserHealthProfile(
            id: fixedUUID(lastByte: 1),
            age: 70,
            allergies: [],
            diagnosedConditions: [],
            currentMedicineIngredientIDs: [],
            bodyMetrics: BodyMetrics(
                systolicBloodPressure: 120,
                diastolicBloodPressure: 80,
                heartRate: 70,
                measuredAt: timestamp
            ),
            updatedAt: timestamp
        )
        let scan = MedicineScanEvent(
            id: fixedUUID(lastByte: 2),
            recognizedText: medicine.canonicalName,
            candidateMedicineID: medicine.id,
            confidence: 0.99,
            scannedAt: timestamp,
            recognitionStatus: .recognized
        )

        return RiskAssessmentRequestDTO(
            medicine: medicine,
            userProfile: profile,
            recentRecords: [],
            scanEvent: scan,
            requestID: fixedUUID(lastByte: 3),
            apiVersion: SlowWalkAPI.version
        )
    }

    private func fixedUUID(lastByte: UInt8) -> UUID {
        UUID(
            uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, lastByte)
        )
    }

    private func sharedFixtureDirectory() -> URL {
        var directory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
        for _ in 0 ..< 4 {
            directory.deleteLastPathComponent()
        }
        return directory
            .appendingPathComponent("shared", isDirectory: true)
            .appendingPathComponent("fixtures", isDirectory: true)
    }
}

private struct RoundTripEnvelope: Codable, Equatable {
    let request: RiskAssessmentRequestDTO
    let response: RiskAssessmentResponseDTO
}

private struct FixtureEnvelope: Decodable {
    let request: RiskAssessmentRequestDTO
    let expectedResponse: RiskAssessmentResponseDTO
}

private struct DateBox: Codable {
    let date: Date
}
