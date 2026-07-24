import Foundation
import SlowWalkDomain
import XCTest

final class HealthContextValidationTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_753_315_200)

    func testValidProfileIsAcceptedWithoutWarnings() {
        let result = UserHealthProfileValidator().validate(
            makeProfile(),
            relativeTo: now
        )

        XCTAssertEqual(result.status, .valid)
        XCTAssertTrue(result.issues.isEmpty)
        XCTAssertEqual(result.normalizedProfile.schemaVersion, 1)
    }

    func testAllergiesAreTrimmedAndDeduplicated() {
        let result = UserHealthProfileValidator().validate(
            makeProfile(
                allergies: [" pollen ", "POLLEN", "", "dust"]
            ),
            relativeTo: now
        )

        XCTAssertEqual(
            result.normalizedProfile.allergies,
            ["pollen", "dust"]
        )
        XCTAssertTrue(
            result.issues.map(\.code).contains(
                "DUPLICATE_ALLERGY_REMOVED"
            )
        )
        XCTAssertTrue(
            result.issues.map(\.code).contains(
                "BLANK_ALLERGY_REMOVED"
            )
        )
    }

    func testConditionsAreTrimmedAndDeduplicated() {
        let result = UserHealthProfileValidator().validate(
            makeProfile(
                conditions: [" demo ", "DEMO", "another"]
            ),
            relativeTo: now
        )

        XCTAssertEqual(
            result.normalizedProfile.diagnosedConditions,
            ["demo", "another"]
        )
        XCTAssertTrue(
            result.issues.map(\.code).contains(
                "DUPLICATE_CONDITION_REMOVED"
            )
        )
    }

    func testIngredientIDsAreTrimmedAndDeduplicated() {
        let result = UserHealthProfileValidator().validate(
            makeProfile(
                ingredients: [" ingredient-a ", "INGREDIENT-A"]
            ),
            relativeTo: now
        )

        XCTAssertEqual(
            result.normalizedProfile.currentMedicineIngredientIDs,
            ["ingredient-a"]
        )
        XCTAssertTrue(
            result.issues.map(\.code).contains(
                "DUPLICATE_INGREDIENT_ID_REMOVED"
            )
        )
    }

    func testCreatedAtAfterUpdatedAtIsInvalid() {
        let result = UserHealthProfileValidator().validate(
            makeProfile(
                createdAt: now.addingTimeInterval(-10),
                updatedAt: now.addingTimeInterval(-20)
            ),
            relativeTo: now
        )

        XCTAssertEqual(result.status, .invalid)
        XCTAssertTrue(
            result.issues.map(\.code).contains(
                "CREATED_AFTER_UPDATED"
            )
        )
    }

    func testFutureProfileTimestampIsInvalid() {
        let result = UserHealthProfileValidator().validate(
            makeProfile(updatedAt: now.addingTimeInterval(1)),
            relativeTo: now
        )

        XCTAssertEqual(result.status, .invalid)
        XCTAssertTrue(
            result.issues.map(\.code).contains(
                "FUTURE_PROFILE_TIMESTAMP"
            )
        )
    }

    func testUnsupportedProfileSchemaIsInvalid() {
        let result = UserHealthProfileValidator().validate(
            makeProfile(schemaVersion: 99),
            relativeTo: now
        )

        XCTAssertEqual(result.status, .invalid)
        XCTAssertEqual(
            result.issues.first {
                $0.code == "UNSUPPORTED_PROFILE_SCHEMA"
            }?.field,
            "schemaVersion"
        )
    }

    func testIncompleteProfileProducesWarningNotDiagnosis() {
        let result = UserHealthProfileValidator().validate(
            UserHealthProfile(
                id: profileID,
                age: 70,
                allergies: [],
                diagnosedConditions: [],
                currentMedicineIngredientIDs: [],
                bodyMetrics: nil,
                updatedAt: now.addingTimeInterval(-60)
            ),
            relativeTo: now
        )

        XCTAssertEqual(result.status, .validWithWarnings)
        XCTAssertEqual(
            result.issues.map(\.code),
            ["PROFILE_EVIDENCE_INCOMPLETE"]
        )
    }

    func testCurrentBodyMetricsPassDataQualityAssessment() {
        let result = BodyMetricsQualityAssessor().assess(
            makeMetrics(),
            relativeTo: now
        )

        XCTAssertEqual(result.status, .valid)
        XCTAssertTrue(result.issues.isEmpty)
        XCTAssertEqual(
            result.configurationNotice,
            BodyMetricsQualityConfiguration.notice
        )
    }

    func testMissingBodyMetricsProducesWarning() {
        let result = BodyMetricsQualityAssessor().assess(
            nil,
            relativeTo: now
        )

        XCTAssertEqual(result.status, .validWithWarnings)
        XCTAssertEqual(
            result.issues.map(\.code),
            ["BODY_METRICS_MISSING"]
        )
    }

    func testNonPositiveBodyMetricsAreInvalid() {
        let result = BodyMetricsQualityAssessor().assess(
            makeMetrics(heartRate: 0),
            relativeTo: now
        )

        XCTAssertEqual(result.status, .invalid)
        XCTAssertTrue(
            result.issues.map(\.code).contains(
                "BODY_METRICS_NON_POSITIVE"
            )
        )
    }

    func testFutureBodyMetricsAreInvalid() {
        let result = BodyMetricsQualityAssessor().assess(
            makeMetrics(measuredAt: now.addingTimeInterval(1)),
            relativeTo: now
        )

        XCTAssertEqual(result.status, .invalid)
        XCTAssertTrue(
            result.issues.map(\.code).contains(
                "FUTURE_BODY_METRICS"
            )
        )
    }

    func testStaleBodyMetricsProduceWarning() {
        let result = BodyMetricsQualityAssessor().assess(
            makeMetrics(
                measuredAt: now.addingTimeInterval(
                    -(31 * 24 * 60 * 60)
                )
            ),
            relativeTo: now
        )

        XCTAssertEqual(result.status, .validWithWarnings)
        XCTAssertTrue(
            result.issues.map(\.code).contains(
                "STALE_BODY_METRICS"
            )
        )
    }

    func testInvalidPressureFieldRelationshipIsRejected() {
        let result = BodyMetricsQualityAssessor().assess(
            makeMetrics(systolic: 70, diastolic: 80),
            relativeTo: now
        )

        XCTAssertEqual(result.status, .invalid)
        XCTAssertTrue(
            result.issues.map(\.code).contains(
                "BLOOD_PRESSURE_RELATION_INVALID"
            )
        )
    }

    func testMissingBodyMetricsSourceProducesWarning() {
        let result = BodyMetricsQualityAssessor().assess(
            makeMetrics(source: nil),
            relativeTo: now
        )

        XCTAssertEqual(result.status, .validWithWarnings)
        XCTAssertTrue(
            result.issues.map(\.code).contains(
                "BODY_METRICS_SOURCE_MISSING"
            )
        )
    }

    func testInjectedDemoRecencyConfigurationIsApplied() throws {
        let configuration = try BodyMetricsQualityConfiguration(
            maximumAge: 60,
            futureTimestampTolerance: 0,
            minimumPositiveValue: 1
        )
        let result = BodyMetricsQualityAssessor(
            configuration: configuration
        ).assess(
            makeMetrics(
                measuredAt: now.addingTimeInterval(-61)
            ),
            relativeTo: now
        )

        XCTAssertEqual(result.status, .validWithWarnings)
        XCTAssertEqual(
            result.issues.map(\.code),
            ["STALE_BODY_METRICS"]
        )
        XCTAssertTrue(
            result.configurationNotice.contains(
                "NOT A CLINICAL DIAGNOSTIC STANDARD"
            )
        )
    }

    private var profileID: UUID {
        UUID(
            uuid: (
                0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 1
            )
        )
    }

    private func makeProfile(
        allergies: [String] = ["pollen"],
        conditions: [String] = ["demo-condition"],
        ingredients: [String] = ["ingredient-b"],
        createdAt: Date? = nil,
        updatedAt: Date? = nil,
        schemaVersion: Int = 1
    ) -> UserHealthProfile {
        let timestamp = updatedAt ?? now.addingTimeInterval(-60)
        return UserHealthProfile(
            id: profileID,
            age: 70,
            allergies: allergies,
            diagnosedConditions: conditions,
            currentMedicineIngredientIDs: ingredients,
            bodyMetrics: makeMetrics(),
            updatedAt: timestamp,
            createdAt: createdAt ?? timestamp,
            schemaVersion: schemaVersion
        )
    }

    private func makeMetrics(
        systolic: Int? = 120,
        diastolic: Int? = 80,
        heartRate: Int? = 70,
        measuredAt: Date? = nil,
        source: String? = "demo_data"
    ) -> BodyMetrics {
        BodyMetrics(
            systolicBloodPressure: systolic,
            diastolicBloodPressure: diastolic,
            heartRate: heartRate,
            measuredAt:
                measuredAt ?? now.addingTimeInterval(-60),
            source: source,
            deviceIdentifier: "demo-device"
        )
    }
}
