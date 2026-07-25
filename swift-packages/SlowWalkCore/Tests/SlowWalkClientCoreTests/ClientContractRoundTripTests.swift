import Foundation
import SlowWalkAPIContracts
import SlowWalkClientCore
import SlowWalkDomain
import SlowWalkLocationRisk
import XCTest

final class ClientContractRoundTripTests:
    XCTestCase
{
    func testMedicineRequestDTORoundTrip()
        throws
    {
        let recognition = MedicineRecognitionInput(
            recognizedTexts: ["Demo Medicine"],
            capturedAt: clientTestDate,
            languageCode: "en",
            rawConfidence: 0.95
        )
        let request =
            MedicineAssessmentRequestBuilder()
                .makeRequest(
                    input: recognition,
                    userProfile: makeClientProfile(),
                    recentRecords: [],
                    requestID: clientTestUUID(60),
                    apiVersion:
                        SlowWalkAPI.version
                )

        let decoded:
            MedicineAssessmentRequestDTO =
                try roundTrip(request)

        XCTAssertEqual(decoded, request)
    }

    func testMedicineResponseDTORoundTrip()
        throws
    {
        let response = makeMedicineResponse(
            requestID: clientTestUUID(61),
            riskLevel: .red
        )

        let decoded:
            MedicineAssessmentResponseDTO =
                try roundTrip(response)

        XCTAssertEqual(decoded, response)
    }

    func testLocationRequestDTORoundTrip()
        throws
    {
        let configuration =
            try LocationHistoryConfiguration(
                maximumSampleCount: 10,
                maximumSampleAge: 300
            )
        let request =
            LocationAssessmentRequestBuilder(
                historyConfiguration: configuration
            )
            .makeRequest(
                destination: makeDestination(),
                samples: [
                    makeLocationSample(offset: -10),
                    makeLocationSample(offset: 0),
                ],
                requestID: clientTestUUID(62),
                apiVersion: SlowWalkAPI.version,
                referenceDate: clientTestDate
            )

        let decoded:
            LocationAssessmentRequestDTO =
                try roundTrip(request)

        XCTAssertEqual(decoded, request)
    }

    func testLocationResponseDTORoundTrip()
        throws
    {
        let response = makeLocationResponse(
            requestID: clientTestUUID(63),
            level: .orange,
            reasonCode: .movingAway
        )

        let decoded:
            LocationAssessmentResponseDTO =
                try roundTrip(response)

        XCTAssertEqual(decoded, response)
    }

    func testViewStatesDoNotRetainImageOrTrajectory()
        throws
    {
        let recognition = MedicineRecognitionInput(
            recognizedTexts: ["Demo Medicine"],
            capturedAt: clientTestDate,
            languageCode: "en",
            rawConfidence: 0.95
        )
        let medicineState =
            MedicineAssessmentViewState
                .requiresMedicineConfirmation(
                    MedicineConfirmationRequirement(
                        reason: .ambiguousMedicine,
                        recognitionInput: recognition,
                        response: nil
                    )
                )
        let locationState =
            LocationAssessmentViewState
                .insufficientSamples(
                    InsufficientLocationSamples(
                        availableSampleCount: 1,
                        requiredSampleCount: 2
                    )
                )

        let medicineDescription =
            String(reflecting: medicineState)
        let locationDescription =
            String(reflecting: locationState)
        XCTAssertFalse(
            medicineDescription.contains("OCRImageInput")
        )
        XCTAssertFalse(
            medicineDescription.contains("AQID")
        )
        XCTAssertFalse(
            locationDescription.contains("GeoPoint")
        )
        XCTAssertFalse(
            locationDescription.contains("latitude")
        )
    }

    func testRiskPresentationUsesAttentionSemantics()
    {
        XCTAssertEqual(
            RiskPresentation(level: .green).attention,
            .routine
        )
        XCTAssertEqual(
            RiskPresentation(level: .yellow).attention,
            .reviewRequired
        )
        XCTAssertEqual(
            RiskPresentation(level: .orange).attention,
            .urgentAttention
        )
        XCTAssertEqual(
            RiskPresentation(level: .red).attention,
            .immediateAttention
        )
    }

    private func roundTrip<Value>(
        _ value: Value
    ) throws -> Value where Value: Codable {
        let data = try SlowWalkJSONCoding
            .makeEncoder()
            .encode(value)
        return try SlowWalkJSONCoding
            .makeDecoder()
            .decode(Value.self, from: data)
    }
}
