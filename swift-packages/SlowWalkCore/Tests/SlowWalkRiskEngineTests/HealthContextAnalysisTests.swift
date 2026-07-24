import Foundation
import SlowWalkDomain
import XCTest
@testable import SlowWalkRiskEngine

final class HealthContextAnalysisTests: XCTestCase {
    private static let day: TimeInterval = 24 * 60 * 60
    private let now = Date(timeIntervalSince1970: 1_753_315_200)

    func testEmptyHistoryProducesStableEmptyAnalysis() {
        let analyzer = makeAnalyzer(records: [])

        XCTAssertEqual(
            analyzer.records(
                within: 7 * Self.day,
                relativeTo: now
            ),
            []
        )
        XCTAssertEqual(
            analyzer.usageCount(
                medicineID: "medicine-a",
                within: 7 * Self.day
            ),
            0
        )
        XCTAssertTrue(analyzer.invalidRecordFindings.isEmpty)
    }

    func testSevenDayWindowIncludesExactBoundary() {
        let boundary = makeRecord(
            token: 1,
            at: now.addingTimeInterval(-7 * Self.day)
        )
        let outside = makeRecord(
            token: 2,
            at: now.addingTimeInterval(-(7 * Self.day) - 1)
        )
        let records = makeAnalyzer(
            records: [outside, boundary]
        ).records(
            within: 7 * Self.day,
            relativeTo: now
        )

        XCTAssertEqual(records.map(\.id), [boundary.id])
    }

    func testUnorderedRecordsHaveStableOrder() {
        let first = makeRecord(
            token: 1,
            at: now.addingTimeInterval(-300)
        )
        let second = makeRecord(
            token: 2,
            at: now.addingTimeInterval(-100)
        )

        let forward = makeAnalyzer(
            records: [first, second]
        ).records(within: Self.day, relativeTo: now)
        let reversed = makeAnalyzer(
            records: [second, first]
        ).records(within: Self.day, relativeTo: now)

        XCTAssertEqual(forward, reversed)
        XCTAssertEqual(forward.map(\.id), [first.id, second.id])
    }

    func testDuplicateIDAndSameMinuteAreReportedAndDeduplicated() {
        let first = makeRecord(
            token: 1,
            at: now.addingTimeInterval(-120)
        )
        let sameMinute = makeRecord(
            token: 2,
            at: now.addingTimeInterval(-119)
        )
        let analyzer = makeAnalyzer(
            records: [first, first, sameMinute]
        )

        XCTAssertEqual(
            Set(analyzer.invalidRecordFindings.map(\.code)),
            [
                .duplicateRecordID,
                .duplicateWithinWindow,
            ]
        )
        XCTAssertEqual(
            analyzer.usageCount(
                medicineID: "medicine-a",
                within: Self.day
            ),
            1
        )
    }

    func testFutureRecordIsInvalidAndExcluded() {
        let future = makeRecord(
            token: 1,
            at: now.addingTimeInterval(1)
        )
        let analyzer = makeAnalyzer(records: [future])

        XCTAssertEqual(
            analyzer.invalidRecordFindings.map(\.code),
            [.futureRecord]
        )
        XCTAssertEqual(
            analyzer.records(
                within: Self.day,
                relativeTo: now
            ),
            []
        )
    }

    func testConsecutiveUsageDaysCountsCalendarDays() {
        let records = [
            makeRecord(token: 1, at: now),
            makeRecord(
                token: 2,
                at: now.addingTimeInterval(-Self.day)
            ),
            makeRecord(
                token: 3,
                at: now.addingTimeInterval(-2 * Self.day)
            ),
        ]

        XCTAssertEqual(
            makeAnalyzer(records: records).consecutiveUsageDays(
                medicineID: "medicine-a",
                endingAt: now
            ),
            3
        )
    }

    func testConsecutiveUsageRestartsAfterGap() {
        let records = [
            makeRecord(token: 1, at: now),
            makeRecord(
                token: 2,
                at: now.addingTimeInterval(-Self.day)
            ),
            makeRecord(
                token: 3,
                at: now.addingTimeInterval(-3 * Self.day)
            ),
        ]

        XCTAssertEqual(
            makeAnalyzer(records: records).consecutiveUsageDays(
                medicineID: "medicine-a",
                endingAt: now
            ),
            2
        )
    }

    func testSharedIngredientAcrossMedicinesIsCounted() {
        let records = [
            makeRecord(
                token: 1,
                medicineID: "medicine-a",
                ingredients: ["ingredient-shared"],
                at: now.addingTimeInterval(-120)
            ),
            makeRecord(
                token: 2,
                medicineID: "medicine-b",
                ingredients: ["ingredient-shared"],
                at: now.addingTimeInterval(-60)
            ),
        ]
        let analyzer = makeAnalyzer(records: records)

        XCTAssertEqual(
            analyzer.activeIngredientUsageCount(
                ingredientID: "ingredient-shared",
                within: Self.day
            ),
            2
        )
    }

    func testScanEventIsNotCountedAsConfirmedIntake() {
        let records = [
            makeRecord(
                token: 1,
                eventType: .scanned,
                at: now.addingTimeInterval(-120)
            ),
            makeRecord(
                token: 2,
                eventType: .confirmedIntake,
                at: now.addingTimeInterval(-60)
            ),
        ]

        XCTAssertEqual(
            makeAnalyzer(records: records).usageCount(
                medicineID: "medicine-a",
                within: Self.day
            ),
            1
        )
    }

    func testInjectedTimeZoneControlsDateBoundary() throws {
        let timeZone = try XCTUnwrap(
            TimeZone(secondsFromGMT: 8 * 60 * 60)
        )
        let configuration = try MedicationHistoryAnalysisConfiguration(
            recentWindow: 7 * Self.day,
            duplicateWindow: 60,
            futureTimestampTolerance: 0,
            timeZone: timeZone,
            intakeEventTypes: [.confirmedIntake]
        )
        let end = Date(timeIntervalSince1970: 1_735_750_800)
        let records = [
            makeRecord(
                token: 1,
                eventType: .confirmedIntake,
                at: end
            ),
            makeRecord(
                token: 2,
                eventType: .confirmedIntake,
                at: end.addingTimeInterval(-Self.day)
            ),
        ]
        let analyzer = MedicationHistoryAnalyzer(
            records: records,
            clock: AnalysisFixedClock(now: end),
            configuration: configuration
        )

        XCTAssertEqual(
            analyzer.consecutiveUsageDays(
                medicineID: "medicine-a",
                endingAt: end
            ),
            2
        )
    }

    func testDuplicateIngredientFindingTracesProfileAndHistory() {
        let analyzer = makeAnalyzer(
            records: [
                makeRecord(
                    token: 1,
                    medicineID: "medicine-b",
                    ingredients: ["ingredient-a"],
                    at: now.addingTimeInterval(-60)
                ),
            ]
        )
        let findings = analyzer.duplicateIngredientFindings(
            currentMedicine: makeMedicine(),
            profile: makeProfile(
                currentIngredients: ["ingredient-a"]
            ),
            recentRecords: [
                makeRecord(
                    token: 1,
                    medicineID: "medicine-b",
                    ingredients: ["ingredient-a"],
                    at: now.addingTimeInterval(-60)
                ),
            ]
        )

        XCTAssertEqual(findings.map(\.ingredientID), ["ingredient-a"])
        XCTAssertEqual(
            findings.first?.evidenceSources,
            ["medication_history", "user_profile"]
        )
        XCTAssertEqual(
            findings.first?.medicineIDs,
            ["medicine-a", "medicine-b"]
        )
    }

    func testCompleteEvidenceBuildsCompleteContext() throws {
        let builder = makeBuilder()
        let medicine = makeMedicine()
        let resolution = makeResolution(
            medicine: medicine,
            status: .resolved
        )
        let preflight = try builder.validate(
            userProfile: makeProfile(),
            bodyMetrics: makeProfile().bodyMetrics,
            medicationRecords: []
        )
        let result = try builder.build(
            medicine: medicine,
            resolution: resolution,
            preflight: preflight,
            scanEvent: makeScan(),
            sourceReferences: medicine.sourceReferences
        )

        XCTAssertEqual(result.validation.status, .valid)
        XCTAssertEqual(
            result.context.evidenceCompleteness,
            .complete
        )
        XCTAssertTrue(result.context.healthContextWarnings.isEmpty)
    }

    func testMissingProfileIsRejected() {
        XCTAssertThrowsError(
            try makeBuilder().validate(
                userProfile: nil,
                bodyMetrics: nil,
                medicationRecords: []
            )
        ) { error in
            XCTAssertEqual(
                error as? MedicationRiskContextBuildError,
                .missingUserProfile
            )
        }
    }

    func testMissingMedicineSourcesAreInsufficient() throws {
        let builder = makeBuilder()
        let medicine = makeMedicine(sourceReferences: [])
        let preflight = try builder.validate(
            userProfile: makeProfile(),
            bodyMetrics: makeProfile().bodyMetrics,
            medicationRecords: []
        )
        let result = try builder.build(
            medicine: medicine,
            resolution: makeResolution(
                medicine: medicine,
                status: .resolved
            ),
            preflight: preflight,
            scanEvent: makeScan(),
            sourceReferences: []
        )

        XCTAssertEqual(
            result.context.evidenceCompleteness,
            .insufficient
        )
        XCTAssertTrue(
            result.validation.issues.map(\.code).contains(
                "MEDICINE_SOURCES_MISSING"
            )
        )
    }

    func testStaleMetricsRemainAsStructuredWarning() throws {
        let staleProfile = makeProfile(
            metrics: makeMetrics(
                measuredAt: now.addingTimeInterval(
                    -(31 * Self.day)
                )
            )
        )
        let preflight = try makeBuilder().validate(
            userProfile: staleProfile,
            bodyMetrics: staleProfile.bodyMetrics,
            medicationRecords: []
        )

        XCTAssertEqual(
            preflight.validation.status,
            .validWithWarnings
        )
        XCTAssertTrue(
            preflight.validation.issues.map(\.code).contains(
                "STALE_BODY_METRICS"
            )
        )
    }

    func testUnresolvedMedicineCannotBuildNormalContext() throws {
        let builder = makeBuilder()
        let medicine = makeMedicine()
        let preflight = try builder.validate(
            userProfile: makeProfile(),
            bodyMetrics: makeProfile().bodyMetrics,
            medicationRecords: []
        )

        XCTAssertThrowsError(
            try builder.build(
                medicine: medicine,
                resolution: makeResolution(
                    medicine: medicine,
                    status: .recognitionFailed
                ),
                preflight: preflight,
                scanEvent: makeScan(
                    candidateMedicineID: nil,
                    status: .failed
                ),
                sourceReferences: medicine.sourceReferences
            )
        ) { error in
            XCTAssertEqual(
                error as? MedicationRiskContextBuildError,
                .unresolvedMedicine(.recognitionFailed)
            )
        }
    }

    func testDuplicateIngredientContextProducesRedTraceableRisk() throws {
        let builder = makeBuilder()
        let medicine = makeMedicine()
        let profile = makeProfile(
            currentIngredients: ["ingredient-a"]
        )
        let preflight = try builder.validate(
            userProfile: profile,
            bodyMetrics: profile.bodyMetrics,
            medicationRecords: []
        )
        let result = try builder.build(
            medicine: medicine,
            resolution: makeResolution(
                medicine: medicine,
                status: .resolved
            ),
            preflight: preflight,
            scanEvent: makeScan(),
            sourceReferences: medicine.sourceReferences
        )
        let assessment = MedicationRiskEngine().assess(
            context: result.context
        )

        XCTAssertEqual(assessment.level, .red)
        XCTAssertEqual(
            assessment.reasons.first?.code,
            .duplicateActiveIngredient
        )
        XCTAssertFalse(
            assessment.recommendedActions.contains(
                .followVerifiedSourceInformation
            )
        )
    }

    private func makeAnalyzer(
        records: [MedicationRecord]
    ) -> MedicationHistoryAnalyzer {
        MedicationHistoryAnalyzer(
            records: records,
            clock: AnalysisFixedClock(now: now)
        )
    }

    private func makeBuilder() -> MedicationRiskContextBuilder {
        MedicationRiskContextBuilder(
            clock: AnalysisFixedClock(now: now)
        )
    }

    private func makeRecord(
        token: UInt8,
        medicineID: String = "medicine-a",
        ingredients: [String] = ["ingredient-a"],
        eventType: MedicationEventType = .confirmedIntake,
        at date: Date
    ) -> MedicationRecord {
        MedicationRecord(
            id: UUID(
                uuid: (
                    0, 0, 0, 0, 0, 0, 0, 0,
                    0, 0, 0, 0, 0, 0, 0, token
                )
            ),
            medicineID: medicineID,
            activeIngredientIDs: ingredients,
            recordedAt: date,
            eventType: eventType,
            source: .demoData
        )
    }

    private func makeProfile(
        currentIngredients: [String] = [],
        metrics: BodyMetrics? = nil
    ) -> UserHealthProfile {
        UserHealthProfile(
            id: UUID(
                uuid: (
                    0, 0, 0, 0, 0, 0, 0, 0,
                    0, 0, 0, 0, 0, 0, 0, 20
                )
            ),
            age: 70,
            allergies: ["pollen"],
            diagnosedConditions: [],
            currentMedicineIngredientIDs: currentIngredients,
            bodyMetrics: metrics ?? makeMetrics(),
            updatedAt: now.addingTimeInterval(-60)
        )
    }

    private func makeMetrics(
        measuredAt: Date? = nil
    ) -> BodyMetrics {
        BodyMetrics(
            systolicBloodPressure: 120,
            diastolicBloodPressure: 80,
            heartRate: 70,
            measuredAt: measuredAt ?? now.addingTimeInterval(-60),
            source: "demo_data"
        )
    }

    private func makeMedicine(
        sourceReferences: [SourceReference]? = nil
    ) -> Medicine {
        Medicine(
            id: "medicine-a",
            canonicalName: "Demo Medicine",
            aliases: [],
            activeIngredientIDs: ["ingredient-a"],
            medicineCategory: .other,
            sourceReferences: sourceReferences ?? [
                SourceReference(
                    sourceName: "Demo Source",
                    documentTitle:
                        "DEMO DATA — NOT FOR CLINICAL USE",
                    optionalURL: nil,
                    retrievedAt: now,
                    versionOrDate: "demo-v1"
                ),
            ],
            dosageTextFromSource: nil,
            contraindicationTags: []
        )
    }

    private func makeResolution(
        medicine: Medicine,
        status: MedicineResolutionStatus
    ) -> MedicineResolution {
        MedicineResolution(
            status: status,
            candidates: status == .resolved
                ? [
                    MedicineCandidate(
                        medicine: medicine,
                        matchScore: 1,
                        matchedAlias: nil,
                        matchReasons: [.canonicalExact]
                    ),
                ]
                : [],
            selectedMedicine: status == .resolved ? medicine : nil,
            evidence: MedicineResolutionEvidence(
                recognizedTexts: ["Demo Medicine"],
                normalizedText: "demo medicine",
                normalizedQuery: "demo medicine",
                languageCode: "en",
                rawConfidence: 0.99,
                dosageForms: [],
                removedSpecifications: [],
                discardedNoise: [],
                matcherVersion: "test",
                sourceDataVersions: ["demo-v1"]
            ),
            requiresUserConfirmation: status != .resolved
        )
    }

    private func makeScan(
        candidateMedicineID: String? = "medicine-a",
        status: RecognitionStatus = .recognized
    ) -> MedicineScanEvent {
        MedicineScanEvent(
            id: UUID(
                uuid: (
                    0, 0, 0, 0, 0, 0, 0, 0,
                    0, 0, 0, 0, 0, 0, 0, 21
                )
            ),
            recognizedText: "Demo Medicine",
            candidateMedicineID: candidateMedicineID,
            confidence: status == .recognized ? 0.99 : 0,
            scannedAt: now.addingTimeInterval(-30),
            recognitionStatus: status
        )
    }
}

private struct AnalysisFixedClock: Clock, Sendable {
    let date: Date

    init(now: Date) {
        date = now
    }

    func now() -> Date {
        date
    }
}
