import Foundation
import SlowWalkAPIContracts
import SlowWalkDomain
import XCTest

final class HealthContextDTOTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_753_315_200)

    func testHealthContextDTOsRoundTripWithStableStrings() throws {
        let profile = makeProfile()
        let profileDTO = UserHealthProfileDTO(profile)
        let recordDTO = MedicationRecordDTO(makeRecord())
        let warning = HealthContextWarningDTO(
            HealthContextValidationIssue(
                code: "STALE_BODY_METRICS",
                field: "bodyMetrics.measuredAt",
                message: "Demo measurement is stale.",
                severity: .warning,
                ruleIdentifier: "body-metrics-recency"
            )
        )
        let envelope = HealthContextDTOEnvelope(
            profile: profileDTO,
            record: recordDTO,
            validation: HealthContextValidationDTO(
                status: "valid_with_warnings",
                warnings: [warning],
                configurationNotices: [
                    "NOT FOR CLINICAL USE",
                ]
            )
        )

        let data = try SlowWalkJSONCoding.makeEncoder().encode(
            envelope
        )
        let decoded = try SlowWalkJSONCoding.makeDecoder().decode(
            HealthContextDTOEnvelope.self,
            from: data
        )

        XCTAssertEqual(decoded, envelope)
        XCTAssertEqual(
            try decoded.record.domainModel().eventType,
            .confirmedIntake
        )
        XCTAssertEqual(decoded.profile.domainModel, profile)
    }

    func testLegacyProfileJSONReceivesSchemaAndCreatedAtDefaults()
        throws {
        let data = Data(
            """
            {
              "id": "00000000-0000-0000-0000-000000000001",
              "age": 70,
              "allergies": [],
              "diagnosedConditions": [],
              "currentMedicineIngredientIDs": [],
              "bodyMetrics": {
                "systolicBloodPressure": 120,
                "diastolicBloodPressure": 80,
                "heartRate": 70,
                "measuredAt": "2025-07-23T16:00:00Z"
              },
              "updatedAt": "2025-07-23T16:00:00Z"
            }
            """.utf8
        )

        let profile = try SlowWalkJSONCoding.makeDecoder().decode(
            UserHealthProfile.self,
            from: data
        )

        XCTAssertEqual(profile.schemaVersion, 1)
        XCTAssertEqual(profile.createdAt, profile.updatedAt)
        XCTAssertNil(profile.bodyMetrics?.source)
        XCTAssertNil(profile.bodyMetrics?.deviceIdentifier)
    }

    func testAPIProfileDTOAllowsCreatedAtAndSchemaDefaults()
        throws
    {
        let profile = try SlowWalkJSONCoding.makeDecoder()
            .decode(
                UserHealthProfileDTO.self,
                from: strictProfileData()
            )

        XCTAssertEqual(profile.schemaVersion, 1)
        XCTAssertEqual(profile.createdAt, profile.updatedAt)
    }

    func testAPIProfileDTORejectsMissingAllergies() {
        assertMissingRequiredField(
            "allergies",
            data: strictProfileData(
                allergies: nil
            )
        )
    }

    func testAPIProfileDTORejectsMissingDiagnosedConditions() {
        assertMissingRequiredField(
            "diagnosedConditions",
            data: strictProfileData(
                diagnosedConditions: nil
            )
        )
    }

    func testAPIProfileDTORejectsMissingCurrentMedicineIngredientIDs() {
        assertMissingRequiredField(
            "currentMedicineIngredientIDs",
            data: strictProfileData(
                currentMedicineIngredientIDs: nil
            )
        )
    }

    func testValidationDTOIncludesConfigurationNotice() {
        let dto = HealthContextValidationDTO(
            HealthContextValidation(
                status: .validWithWarnings,
                issues: [
                    HealthContextValidationIssue(
                        code: "BODY_METRICS_SOURCE_MISSING",
                        field: "bodyMetrics.source",
                        message: "Source is missing.",
                        severity: .warning,
                        ruleIdentifier: "body-metrics-source"
                    ),
                ],
                configurationNotices: [
                    BodyMetricsQualityConfiguration.notice,
                    "NOT FOR CLINICAL USE",
                ]
            )
        )

        XCTAssertEqual(dto.status, "valid_with_warnings")
        XCTAssertEqual(
            dto.warnings.map(\.code),
            ["BODY_METRICS_SOURCE_MISSING"]
        )
        XCTAssertTrue(
            dto.configurationNotices.contains(
                "NOT FOR CLINICAL USE"
            )
        )
    }

    private func makeProfile() -> UserHealthProfile {
        UserHealthProfile(
            id: UUID(
                uuid: (
                    0, 0, 0, 0, 0, 0, 0, 0,
                    0, 0, 0, 0, 0, 0, 0, 1
                )
            ),
            age: 70,
            allergies: ["demo-allergy"],
            diagnosedConditions: [],
            currentMedicineIngredientIDs: [],
            bodyMetrics: BodyMetrics(
                systolicBloodPressure: 120,
                diastolicBloodPressure: 80,
                heartRate: 70,
                measuredAt: now,
                source: "demo_data",
                deviceIdentifier: "demo-device"
            ),
            updatedAt: now,
            createdAt: now,
            schemaVersion: 1
        )
    }

    private func makeRecord() -> MedicationRecord {
        MedicationRecord(
            id: UUID(
                uuid: (
                    0, 0, 0, 0, 0, 0, 0, 0,
                    0, 0, 0, 0, 0, 0, 0, 2
                )
            ),
            medicineID: "medicine-a",
            activeIngredientIDs: ["ingredient-a"],
            recordedAt: now,
            eventType: .confirmedIntake,
            source: .demoData
        )
    }

    private func strictProfileData(
        allergies: String? = "[]",
        diagnosedConditions: String? = "[]",
        currentMedicineIngredientIDs:
            String? = "[]"
    ) -> Data {
        var fields = [
            #""id":"00000000-0000-0000-0000-000000000001""#,
            #""age":70"#,
            #""updatedAt":"2025-07-23T16:00:00Z""#,
        ]
        if let allergies {
            fields.append(
                #""allergies":\#(allergies)"#
            )
        }
        if let diagnosedConditions {
            fields.append(
                #""diagnosedConditions":\#(diagnosedConditions)"#
            )
        }
        if let currentMedicineIngredientIDs {
            fields.append(
                #""currentMedicineIngredientIDs":\#(currentMedicineIngredientIDs)"#
            )
        }
        return Data(
            "{\(fields.joined(separator: ","))}".utf8
        )
    }

    private func assertMissingRequiredField(
        _ expectedField: String,
        data: Data,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(
            try SlowWalkJSONCoding.makeDecoder().decode(
                UserHealthProfileDTO.self,
                from: data
            ),
            file: file,
            line: line
        ) { error in
            guard case DecodingError.keyNotFound(
                let key,
                _
            ) = error else {
                return XCTFail(
                    "Expected keyNotFound, got \(error).",
                    file: file,
                    line: line
                )
            }
            XCTAssertEqual(
                key.stringValue,
                expectedField,
                file: file,
                line: line
            )
        }
    }
}

private struct HealthContextDTOEnvelope:
    Codable,
    Equatable
{
    let profile: UserHealthProfileDTO
    let record: MedicationRecordDTO
    let validation: HealthContextValidationDTO
}
