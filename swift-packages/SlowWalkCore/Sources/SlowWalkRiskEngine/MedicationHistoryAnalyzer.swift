import Foundation
import SlowWalkDomain

public enum MedicationHistoryAnalysisConfigurationError:
    Error,
    Sendable,
    Equatable
{
    case nonPositiveRecentWindow
    case nonPositiveDuplicateWindow
    case negativeFutureTimestampTolerance
    case missingIntakeEventTypes
}

/// Centralized, deterministic medication-history policy.
///
/// Time windows are product-demo settings and are not clinical thresholds.
public struct MedicationHistoryAnalysisConfiguration:
    Sendable,
    Equatable,
    Hashable
{
    public let recentWindow: TimeInterval
    public let duplicateWindow: TimeInterval
    public let futureTimestampTolerance: TimeInterval
    public let calendarIdentifier: Calendar.Identifier
    public let timeZone: TimeZone
    public let intakeEventTypes: Set<MedicationEventType>

    public init(
        recentWindow: TimeInterval,
        duplicateWindow: TimeInterval,
        futureTimestampTolerance: TimeInterval,
        calendarIdentifier: Calendar.Identifier = .gregorian,
        timeZone: TimeZone,
        intakeEventTypes: Set<MedicationEventType>
    ) throws {
        guard recentWindow > 0 else {
            throw MedicationHistoryAnalysisConfigurationError
                .nonPositiveRecentWindow
        }
        guard duplicateWindow > 0 else {
            throw MedicationHistoryAnalysisConfigurationError
                .nonPositiveDuplicateWindow
        }
        guard futureTimestampTolerance >= 0 else {
            throw MedicationHistoryAnalysisConfigurationError
                .negativeFutureTimestampTolerance
        }
        guard !intakeEventTypes.isEmpty else {
            throw MedicationHistoryAnalysisConfigurationError
                .missingIntakeEventTypes
        }
        self.recentWindow = recentWindow
        self.duplicateWindow = duplicateWindow
        self.futureTimestampTolerance = futureTimestampTolerance
        self.calendarIdentifier = calendarIdentifier
        self.timeZone = timeZone
        self.intakeEventTypes = intakeEventTypes
    }

    public static let demo = MedicationHistoryAnalysisConfiguration(
        validatedRecentWindow: 7 * 24 * 60 * 60,
        duplicateWindow: 60,
        futureTimestampTolerance: 0,
        calendarIdentifier: .gregorian,
        timeZone: TimeZone(secondsFromGMT: 0)!,
        intakeEventTypes: [.confirmedIntake, .taken]
    )

    private init(
        validatedRecentWindow: TimeInterval,
        duplicateWindow: TimeInterval,
        futureTimestampTolerance: TimeInterval,
        calendarIdentifier: Calendar.Identifier,
        timeZone: TimeZone,
        intakeEventTypes: Set<MedicationEventType>
    ) {
        recentWindow = validatedRecentWindow
        self.duplicateWindow = duplicateWindow
        self.futureTimestampTolerance = futureTimestampTolerance
        self.calendarIdentifier = calendarIdentifier
        self.timeZone = timeZone
        self.intakeEventTypes = intakeEventTypes
    }
}

public enum MedicationRecordFindingCode:
    String,
    Codable,
    Sendable,
    CaseIterable,
    Hashable
{
    case emptyMedicineID = "EMPTY_MEDICINE_ID"
    case emptyIngredientID = "EMPTY_INGREDIENT_ID"
    case futureRecord = "FUTURE_MEDICATION_RECORD"
    case duplicateRecordID = "DUPLICATE_MEDICATION_RECORD_ID"
    case duplicateWithinWindow = "DUPLICATE_MEDICATION_RECORD_WINDOW"
}

public struct MedicationRecordFinding:
    Codable,
    Sendable,
    Equatable,
    Hashable
{
    public let code: MedicationRecordFindingCode
    public let recordID: UUID
    public let message: String
    public let severity: HealthContextIssueSeverity
    public let ruleIdentifier: String

    public init(
        code: MedicationRecordFindingCode,
        recordID: UUID,
        message: String,
        severity: HealthContextIssueSeverity,
        ruleIdentifier: String
    ) {
        self.code = code
        self.recordID = recordID
        self.message = message
        self.severity = severity
        self.ruleIdentifier = ruleIdentifier
    }
}

public struct DuplicateIngredientFinding:
    Codable,
    Sendable,
    Equatable,
    Hashable
{
    public let ingredientID: String
    public let medicineIDs: [String]
    public let evidenceSources: [String]
    public let ruleIdentifier: String

    public init(
        ingredientID: String,
        medicineIDs: [String],
        evidenceSources: [String],
        ruleIdentifier: String
    ) {
        self.ingredientID = ingredientID
        self.medicineIDs = medicineIDs
        self.evidenceSources = evidenceSources
        self.ruleIdentifier = ruleIdentifier
    }
}

public protocol MedicationHistoryAnalyzing: Sendable {
    func records(
        within interval: TimeInterval,
        relativeTo referenceDate: Date
    ) -> [MedicationRecord]

    func usageCount(
        medicineID: String,
        within interval: TimeInterval
    ) -> Int

    func activeIngredientUsageCount(
        ingredientID: String,
        within interval: TimeInterval
    ) -> Int

    func consecutiveUsageDays(
        medicineID: String,
        endingAt endDate: Date
    ) -> Int

    func duplicateIngredientFindings(
        currentMedicine: Medicine,
        profile: UserHealthProfile,
        recentRecords: [MedicationRecord]
    ) -> [DuplicateIngredientFinding]

    var invalidRecordFindings: [MedicationRecordFinding] { get }
}

/// Deterministic history analyzer using an injected clock and calendar policy.
public struct MedicationHistoryAnalyzer:
    MedicationHistoryAnalyzing,
    Sendable
{
    private let sourceRecords: [MedicationRecord]
    private let clock: any Clock
    public let configuration: MedicationHistoryAnalysisConfiguration

    public init(
        records: [MedicationRecord],
        clock: any Clock,
        configuration: MedicationHistoryAnalysisConfiguration = .demo
    ) {
        sourceRecords = records
        self.clock = clock
        self.configuration = configuration
    }

    public func records(
        within interval: TimeInterval,
        relativeTo referenceDate: Date
    ) -> [MedicationRecord] {
        guard interval > 0 else {
            return []
        }
        let lowerBound = referenceDate.addingTimeInterval(-interval)
        let upperBound = referenceDate.addingTimeInterval(
            configuration.futureTimestampTolerance
        )
        return sanitizedRecords(relativeTo: referenceDate).filter {
            $0.recordedAt >= lowerBound && $0.recordedAt <= upperBound
        }
    }

    public func usageCount(
        medicineID: String,
        within interval: TimeInterval
    ) -> Int {
        let normalizedID = normalize(medicineID)
        guard !normalizedID.isEmpty else {
            return 0
        }
        return records(within: interval, relativeTo: clock.now())
            .filter {
                isConfirmedIntake($0)
                    && normalize($0.medicineID) == normalizedID
            }
            .count
    }

    public func activeIngredientUsageCount(
        ingredientID: String,
        within interval: TimeInterval
    ) -> Int {
        let normalizedID = normalize(ingredientID)
        guard !normalizedID.isEmpty else {
            return 0
        }
        return records(within: interval, relativeTo: clock.now())
            .filter {
                isConfirmedIntake($0)
                    && normalizedSet($0.activeIngredientIDs)
                        .contains(normalizedID)
            }
            .count
    }

    public func consecutiveUsageDays(
        medicineID: String,
        endingAt endDate: Date
    ) -> Int {
        let normalizedID = normalize(medicineID)
        guard !normalizedID.isEmpty else {
            return 0
        }
        var calendar = Calendar(
            identifier: configuration.calendarIdentifier
        )
        calendar.timeZone = configuration.timeZone
        let endingDay = calendar.startOfDay(for: endDate)
        let days = Set(
            sanitizedRecords(relativeTo: endDate)
                .filter {
                    isConfirmedIntake($0)
                        && normalize($0.medicineID) == normalizedID
                        && $0.recordedAt <= endDate
                }
                .map { calendar.startOfDay(for: $0.recordedAt) }
        )
        guard days.contains(endingDay) else {
            return 0
        }

        var count = 0
        var cursor = endingDay
        while days.contains(cursor) {
            count += 1
            guard let previousDay = calendar.date(
                byAdding: .day,
                value: -1,
                to: cursor
            ) else {
                break
            }
            cursor = previousDay
        }
        return count
    }

    public func duplicateIngredientFindings(
        currentMedicine: Medicine,
        profile: UserHealthProfile,
        recentRecords: [MedicationRecord]
    ) -> [DuplicateIngredientFinding] {
        let candidateIngredients = normalizedSet(
            currentMedicine.activeIngredientIDs
        )
        let profileIngredients = normalizedSet(
            profile.currentMedicineIngredientIDs
        )
        let recentAnalyzer = MedicationHistoryAnalyzer(
            records: recentRecords,
            clock: clock,
            configuration: configuration
        )
        let recent = recentAnalyzer.records(
            within: configuration.recentWindow,
            relativeTo: clock.now()
        )
        .filter(isConfirmedIntake)

        return candidateIngredients.compactMap { ingredientID in
            var medicineIDs = Set<String>()
            var sources = Set<String>()
            if profileIngredients.contains(ingredientID) {
                sources.insert("user_profile")
            }
            for record in recent
            where normalizedSet(record.activeIngredientIDs)
                .contains(ingredientID) {
                medicineIDs.insert(normalize(record.medicineID))
                sources.insert("medication_history")
            }
            guard !sources.isEmpty else {
                return nil
            }
            medicineIDs.insert(normalize(currentMedicine.id))
            return DuplicateIngredientFinding(
                ingredientID: ingredientID,
                medicineIDs: medicineIDs.sorted(),
                evidenceSources: sources.sorted(),
                ruleIdentifier: "duplicate-active-ingredient-context"
            )
        }
        .sorted {
            if $0.ingredientID != $1.ingredientID {
                return $0.ingredientID < $1.ingredientID
            }
            return $0.medicineIDs.lexicographicallyPrecedes(
                $1.medicineIDs
            )
        }
    }

    public var invalidRecordFindings: [MedicationRecordFinding] {
        findings(relativeTo: clock.now())
    }

    public func findings(
        relativeTo referenceDate: Date
    ) -> [MedicationRecordFinding] {
        var findings = [MedicationRecordFinding]()
        var seenIDs = Set<UUID>()
        var seenSemanticKeys = Set<SemanticRecordKey>()
        let latestAcceptedDate = referenceDate.addingTimeInterval(
            configuration.futureTimestampTolerance
        )

        for record in sourceRecords.sorted(by: Self.recordOrder) {
            if normalize(record.medicineID).isEmpty {
                findings.append(
                    finding(
                        code: .emptyMedicineID,
                        record: record,
                        message: "Medication record medicineID is empty.",
                        severity: .error,
                        rule: "medication-record-required-fields"
                    )
                )
            }
            if record.activeIngredientIDs.contains(
                where: { normalize($0).isEmpty }
            ) {
                findings.append(
                    finding(
                        code: .emptyIngredientID,
                        record: record,
                        message: "Medication record contains an empty ingredient ID.",
                        severity: .error,
                        rule: "medication-record-required-fields"
                    )
                )
            }
            if record.recordedAt > latestAcceptedDate {
                findings.append(
                    finding(
                        code: .futureRecord,
                        record: record,
                        message: "Medication record timestamp is in the future.",
                        severity: .error,
                        rule: "medication-record-future-timestamp"
                    )
                )
            }
            if !seenIDs.insert(record.id).inserted {
                findings.append(
                    finding(
                        code: .duplicateRecordID,
                        record: record,
                        message: "Medication record ID is duplicated.",
                        severity: .warning,
                        rule: "medication-record-id-deduplication"
                    )
                )
                continue
            }
            let semanticKey = semanticKey(for: record)
            if !seenSemanticKeys.insert(semanticKey).inserted {
                findings.append(
                    finding(
                        code: .duplicateWithinWindow,
                        record: record,
                        message: "Equivalent medication events occur in the same configured minute window.",
                        severity: .warning,
                        rule: "medication-record-window-deduplication"
                    )
                )
            }
        }
        return findings.sorted(by: Self.findingOrder)
    }

    public func sanitizedRecords(
        relativeTo referenceDate: Date
    ) -> [MedicationRecord] {
        let latestAcceptedDate = referenceDate.addingTimeInterval(
            configuration.futureTimestampTolerance
        )
        var seenIDs = Set<UUID>()
        var seenSemanticKeys = Set<SemanticRecordKey>()
        return sourceRecords.sorted(by: Self.recordOrder).filter { record in
            guard !normalize(record.medicineID).isEmpty,
                  !record.activeIngredientIDs.contains(
                    where: { normalize($0).isEmpty }
                  ),
                  record.recordedAt <= latestAcceptedDate,
                  seenIDs.insert(record.id).inserted
            else {
                return false
            }
            return seenSemanticKeys.insert(
                semanticKey(for: record)
            ).inserted
        }
    }

    private func isConfirmedIntake(
        _ record: MedicationRecord
    ) -> Bool {
        configuration.intakeEventTypes.contains(record.eventType)
    }

    private func semanticKey(
        for record: MedicationRecord
    ) -> SemanticRecordKey {
        let bucket = Int(
            floor(
                record.recordedAt.timeIntervalSince1970
                    / configuration.duplicateWindow
            )
        )
        return SemanticRecordKey(
            medicineID: normalize(record.medicineID),
            ingredients: normalizedSet(record.activeIngredientIDs)
                .sorted(),
            eventType: record.eventType,
            bucket: bucket
        )
    }

    private func finding(
        code: MedicationRecordFindingCode,
        record: MedicationRecord,
        message: String,
        severity: HealthContextIssueSeverity,
        rule: String
    ) -> MedicationRecordFinding {
        MedicationRecordFinding(
            code: code,
            recordID: record.id,
            message: message,
            severity: severity,
            ruleIdentifier: rule
        )
    }

    private func normalize(_ value: String) -> String {
        value.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).lowercased()
    }

    private func normalizedSet(_ values: [String]) -> Set<String> {
        Set(values.map(normalize).filter { !$0.isEmpty })
    }

    private static func recordOrder(
        _ lhs: MedicationRecord,
        _ rhs: MedicationRecord
    ) -> Bool {
        if lhs.recordedAt != rhs.recordedAt {
            return lhs.recordedAt < rhs.recordedAt
        }
        if lhs.medicineID != rhs.medicineID {
            return lhs.medicineID < rhs.medicineID
        }
        if lhs.eventType != rhs.eventType {
            return lhs.eventType.rawValue < rhs.eventType.rawValue
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    private static func findingOrder(
        _ lhs: MedicationRecordFinding,
        _ rhs: MedicationRecordFinding
    ) -> Bool {
        if lhs.code != rhs.code {
            return lhs.code.rawValue < rhs.code.rawValue
        }
        return lhs.recordID.uuidString < rhs.recordID.uuidString
    }
}

private struct SemanticRecordKey: Hashable {
    let medicineID: String
    let ingredients: [String]
    let eventType: MedicationEventType
    let bucket: Int
}
