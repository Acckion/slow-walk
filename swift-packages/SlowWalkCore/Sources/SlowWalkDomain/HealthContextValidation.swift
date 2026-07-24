import Foundation

public enum HealthContextValidationStatus:
    String,
    Codable,
    Sendable,
    CaseIterable,
    Hashable
{
    case valid
    case validWithWarnings = "valid_with_warnings"
    case invalid
}

public enum HealthContextIssueSeverity:
    String,
    Codable,
    Sendable,
    CaseIterable,
    Hashable
{
    case warning
    case error
}

/// Stable, privacy-safe data-quality finding.
public struct HealthContextValidationIssue:
    Codable,
    Sendable,
    Equatable,
    Hashable
{
    public let code: String
    public let field: String?
    public let message: String
    public let severity: HealthContextIssueSeverity
    public let ruleIdentifier: String

    public init(
        code: String,
        field: String?,
        message: String,
        severity: HealthContextIssueSeverity,
        ruleIdentifier: String
    ) {
        self.code = code
        self.field = field
        self.message = message
        self.severity = severity
        self.ruleIdentifier = ruleIdentifier
    }
}

public struct UserHealthProfileValidation:
    Sendable,
    Equatable,
    Hashable
{
    public let status: HealthContextValidationStatus
    public let normalizedProfile: UserHealthProfile
    public let issues: [HealthContextValidationIssue]

    public init(
        status: HealthContextValidationStatus,
        normalizedProfile: UserHealthProfile,
        issues: [HealthContextValidationIssue]
    ) {
        self.status = status
        self.normalizedProfile = normalizedProfile
        self.issues = issues
    }
}

public protocol UserHealthProfileValidating: Sendable {
    func validate(
        _ profile: UserHealthProfile,
        relativeTo referenceDate: Date
    ) -> UserHealthProfileValidation
}

public struct UserHealthProfileValidationConfiguration:
    Sendable,
    Equatable,
    Hashable
{
    public let supportedSchemaVersions: Set<Int>
    public let minimumAge: Int
    public let maximumAge: Int
    public let futureTimestampTolerance: TimeInterval

    public init(
        supportedSchemaVersions: Set<Int>,
        minimumAge: Int,
        maximumAge: Int,
        futureTimestampTolerance: TimeInterval
    ) {
        self.supportedSchemaVersions = supportedSchemaVersions
        self.minimumAge = minimumAge
        self.maximumAge = maximumAge
        self.futureTimestampTolerance = futureTimestampTolerance
    }

    public static let standard = UserHealthProfileValidationConfiguration(
        supportedSchemaVersions: [UserHealthProfile.currentSchemaVersion],
        minimumAge: 1,
        maximumAge: 130,
        futureTimestampTolerance: 0
    )
}

/// Normalizes user-entered labels and validates data shape only.
///
/// It does not diagnose disease, interpret severity, or produce treatment.
public struct UserHealthProfileValidator:
    UserHealthProfileValidating,
    Sendable
{
    private let configuration: UserHealthProfileValidationConfiguration

    public init(
        configuration: UserHealthProfileValidationConfiguration = .standard
    ) {
        self.configuration = configuration
    }

    public func validate(
        _ profile: UserHealthProfile,
        relativeTo referenceDate: Date
    ) -> UserHealthProfileValidation {
        var issues = [HealthContextValidationIssue]()
        let allergies = normalize(
            profile.allergies,
            field: "allergies",
            blankCode: "BLANK_ALLERGY_REMOVED",
            duplicateCode: "DUPLICATE_ALLERGY_REMOVED",
            issues: &issues
        )
        let conditions = normalize(
            profile.diagnosedConditions,
            field: "diagnosedConditions",
            blankCode: "BLANK_CONDITION_REMOVED",
            duplicateCode: "DUPLICATE_CONDITION_REMOVED",
            issues: &issues
        )
        let ingredients = normalize(
            profile.currentMedicineIngredientIDs,
            field: "currentMedicineIngredientIDs",
            blankCode: "BLANK_INGREDIENT_ID_REMOVED",
            duplicateCode: "DUPLICATE_INGREDIENT_ID_REMOVED",
            issues: &issues
        )

        if profile.id.uuidString
            == "00000000-0000-0000-0000-000000000000" {
            issues.append(
                error(
                    code: "INVALID_PROFILE_ID",
                    field: "id",
                    message: "Profile ID must not be the nil UUID.",
                    rule: "profile-id-format"
                )
            )
        }
        if !(configuration.minimumAge ... configuration.maximumAge)
            .contains(profile.age) {
            issues.append(
                error(
                    code: "INVALID_AGE",
                    field: "age",
                    message: "Age is outside the supported data format range.",
                    rule: "profile-age-format"
                )
            )
        }
        if profile.createdAt > profile.updatedAt {
            issues.append(
                error(
                    code: "CREATED_AFTER_UPDATED",
                    field: "createdAt",
                    message: "createdAt must not be later than updatedAt.",
                    rule: "profile-timestamp-order"
                )
            )
        }

        let latestAcceptedDate = referenceDate.addingTimeInterval(
            configuration.futureTimestampTolerance
        )
        if profile.createdAt > latestAcceptedDate {
            issues.append(
                error(
                    code: "FUTURE_PROFILE_TIMESTAMP",
                    field: "createdAt",
                    message: "createdAt is later than the reference time.",
                    rule: "profile-future-timestamp"
                )
            )
        }
        if profile.updatedAt > latestAcceptedDate {
            issues.append(
                error(
                    code: "FUTURE_PROFILE_TIMESTAMP",
                    field: "updatedAt",
                    message: "updatedAt is later than the reference time.",
                    rule: "profile-future-timestamp"
                )
            )
        }
        if !configuration.supportedSchemaVersions
            .contains(profile.schemaVersion) {
            issues.append(
                error(
                    code: "UNSUPPORTED_PROFILE_SCHEMA",
                    field: "schemaVersion",
                    message: "Profile schemaVersion is not supported.",
                    rule: "profile-schema-version"
                )
            )
        }
        if allergies.isEmpty,
           conditions.isEmpty,
           ingredients.isEmpty,
           profile.bodyMetrics == nil {
            issues.append(
                warning(
                    code: "PROFILE_EVIDENCE_INCOMPLETE",
                    field: nil,
                    message: "The profile contains limited health-context evidence.",
                    rule: "profile-evidence-completeness"
                )
            )
        }

        let normalized = UserHealthProfile(
            id: profile.id,
            age: profile.age,
            allergies: allergies,
            diagnosedConditions: conditions,
            currentMedicineIngredientIDs: ingredients,
            bodyMetrics: profile.bodyMetrics,
            updatedAt: profile.updatedAt,
            createdAt: profile.createdAt,
            schemaVersion: profile.schemaVersion
        )
        let sortedIssues = issues.sorted(by: Self.issueOrder)
        return UserHealthProfileValidation(
            status: Self.status(for: sortedIssues),
            normalizedProfile: normalized,
            issues: sortedIssues
        )
    }

    private func normalize(
        _ values: [String],
        field: String,
        blankCode: String,
        duplicateCode: String,
        issues: inout [HealthContextValidationIssue]
    ) -> [String] {
        var normalizedValues = [String]()
        var seen = Set<String>()
        var removedBlank = false
        var removedDuplicate = false

        for value in values {
            let trimmed = value.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            guard !trimmed.isEmpty else {
                removedBlank = true
                continue
            }
            let key = trimmed.lowercased()
            guard seen.insert(key).inserted else {
                removedDuplicate = true
                continue
            }
            normalizedValues.append(trimmed)
        }

        if removedBlank {
            issues.append(
                warning(
                    code: blankCode,
                    field: field,
                    message: "Blank values were removed.",
                    rule: "profile-label-normalization"
                )
            )
        }
        if removedDuplicate {
            issues.append(
                warning(
                    code: duplicateCode,
                    field: field,
                    message: "Duplicate values were removed.",
                    rule: "profile-label-normalization"
                )
            )
        }
        return normalizedValues
    }

    private func warning(
        code: String,
        field: String?,
        message: String,
        rule: String
    ) -> HealthContextValidationIssue {
        HealthContextValidationIssue(
            code: code,
            field: field,
            message: message,
            severity: .warning,
            ruleIdentifier: rule
        )
    }

    private func error(
        code: String,
        field: String?,
        message: String,
        rule: String
    ) -> HealthContextValidationIssue {
        HealthContextValidationIssue(
            code: code,
            field: field,
            message: message,
            severity: .error,
            ruleIdentifier: rule
        )
    }

    private static func status(
        for issues: [HealthContextValidationIssue]
    ) -> HealthContextValidationStatus {
        if issues.contains(where: { $0.severity == .error }) {
            return .invalid
        }
        return issues.isEmpty ? .valid : .validWithWarnings
    }

    private static func issueOrder(
        _ lhs: HealthContextValidationIssue,
        _ rhs: HealthContextValidationIssue
    ) -> Bool {
        if lhs.severity != rhs.severity {
            return lhs.severity.rawValue < rhs.severity.rawValue
        }
        if lhs.code != rhs.code {
            return lhs.code < rhs.code
        }
        return (lhs.field ?? "") < (rhs.field ?? "")
    }
}

public enum BodyMetricsQualityConfigurationError:
    Error,
    Sendable,
    Equatable
{
    case nonPositiveMaximumAge
    case negativeFutureTimestampTolerance
    case nonPositiveMinimumValue
}

/// DEMO DATA QUALITY CONFIGURATION
/// NOT A CLINICAL DIAGNOSTIC STANDARD
public struct BodyMetricsQualityConfiguration:
    Sendable,
    Equatable,
    Hashable
{
    public static let notice =
        "DEMO DATA QUALITY CONFIGURATION — NOT A CLINICAL DIAGNOSTIC STANDARD"

    public let maximumAge: TimeInterval
    public let futureTimestampTolerance: TimeInterval
    public let minimumPositiveValue: Int

    public init(
        maximumAge: TimeInterval,
        futureTimestampTolerance: TimeInterval,
        minimumPositiveValue: Int
    ) throws {
        guard maximumAge > 0 else {
            throw BodyMetricsQualityConfigurationError.nonPositiveMaximumAge
        }
        guard futureTimestampTolerance >= 0 else {
            throw BodyMetricsQualityConfigurationError
                .negativeFutureTimestampTolerance
        }
        guard minimumPositiveValue > 0 else {
            throw BodyMetricsQualityConfigurationError.nonPositiveMinimumValue
        }
        self.maximumAge = maximumAge
        self.futureTimestampTolerance = futureTimestampTolerance
        self.minimumPositiveValue = minimumPositiveValue
    }

    public static let demo = BodyMetricsQualityConfiguration(
        validatedMaximumAge: 30 * 24 * 60 * 60,
        futureTimestampTolerance: 0,
        minimumPositiveValue: 1
    )

    private init(
        validatedMaximumAge: TimeInterval,
        futureTimestampTolerance: TimeInterval,
        minimumPositiveValue: Int
    ) {
        maximumAge = validatedMaximumAge
        self.futureTimestampTolerance = futureTimestampTolerance
        self.minimumPositiveValue = minimumPositiveValue
    }
}

public struct BodyMetricsQualityAssessment:
    Sendable,
    Equatable,
    Hashable
{
    public let status: HealthContextValidationStatus
    public let normalizedMetrics: BodyMetrics?
    public let issues: [HealthContextValidationIssue]
    public let configurationNotice: String

    public init(
        status: HealthContextValidationStatus,
        normalizedMetrics: BodyMetrics?,
        issues: [HealthContextValidationIssue],
        configurationNotice: String
    ) {
        self.status = status
        self.normalizedMetrics = normalizedMetrics
        self.issues = issues
        self.configurationNotice = configurationNotice
    }
}

/// Combined validation summary returned by the pipeline and API.
public struct HealthContextValidation:
    Codable,
    Sendable,
    Equatable,
    Hashable
{
    public let status: HealthContextValidationStatus
    public let issues: [HealthContextValidationIssue]
    public let configurationNotices: [String]

    public init(
        status: HealthContextValidationStatus,
        issues: [HealthContextValidationIssue],
        configurationNotices: [String]
    ) {
        self.status = status
        self.issues = issues
        self.configurationNotices = configurationNotices
    }
}

public protocol BodyMetricsQualityAssessing: Sendable {
    func assess(
        _ metrics: BodyMetrics?,
        relativeTo referenceDate: Date
    ) -> BodyMetricsQualityAssessment
}

/// Performs only structural and recency checks, never clinical diagnosis.
public struct BodyMetricsQualityAssessor:
    BodyMetricsQualityAssessing,
    Sendable
{
    private let configuration: BodyMetricsQualityConfiguration

    public init(
        configuration: BodyMetricsQualityConfiguration = .demo
    ) {
        self.configuration = configuration
    }

    public func assess(
        _ metrics: BodyMetrics?,
        relativeTo referenceDate: Date
    ) -> BodyMetricsQualityAssessment {
        guard let metrics else {
            let issue = HealthContextValidationIssue(
                code: "BODY_METRICS_MISSING",
                field: "bodyMetrics",
                message: "No body-metrics record was supplied.",
                severity: .warning,
                ruleIdentifier: "body-metrics-presence"
            )
            return BodyMetricsQualityAssessment(
                status: .validWithWarnings,
                normalizedMetrics: nil,
                issues: [issue],
                configurationNotice:
                    BodyMetricsQualityConfiguration.notice
            )
        }

        var issues = [HealthContextValidationIssue]()
        let values = [
            metrics.systolicBloodPressure,
            metrics.diastolicBloodPressure,
            metrics.heartRate,
        ]
        let hasAnyValue = values.contains { $0 != nil }
        if !hasAnyValue {
            issues.append(
                issue(
                    code: "BODY_METRICS_VALUES_MISSING",
                    field: "bodyMetrics",
                    message: "At least one measurement value is required.",
                    severity: .error,
                    rule: "body-metrics-required-fields"
                )
            )
        }
        if (metrics.systolicBloodPressure == nil)
            != (metrics.diastolicBloodPressure == nil) {
            issues.append(
                issue(
                    code: "BLOOD_PRESSURE_PAIR_INCOMPLETE",
                    field: "bodyMetrics",
                    message: "Blood-pressure fields must be supplied together.",
                    severity: .error,
                    rule: "body-metrics-pressure-pair"
                )
            )
        }
        if values.compactMap({ $0 }).contains(
            where: { $0 < configuration.minimumPositiveValue }
        ) {
            issues.append(
                issue(
                    code: "BODY_METRICS_NON_POSITIVE",
                    field: "bodyMetrics",
                    message: "Measurement values must be positive numbers.",
                    severity: .error,
                    rule: "body-metrics-positive-format"
                )
            )
        }
        if let systolic = metrics.systolicBloodPressure,
           let diastolic = metrics.diastolicBloodPressure,
           systolic <= diastolic {
            issues.append(
                issue(
                    code: "BLOOD_PRESSURE_RELATION_INVALID",
                    field: "bodyMetrics",
                    message: "The pressure-field relationship is structurally invalid.",
                    severity: .error,
                    rule: "body-metrics-pressure-relation"
                )
            )
        }
        guard let measuredAt = metrics.measuredAt else {
            issues.append(
                issue(
                    code: "BODY_METRICS_TIMESTAMP_MISSING",
                    field: "bodyMetrics.measuredAt",
                    message: "A measurement timestamp is required.",
                    severity: .error,
                    rule: "body-metrics-timestamp"
                )
            )
            return result(metrics: metrics, issues: issues)
        }

        let latestAcceptedDate = referenceDate.addingTimeInterval(
            configuration.futureTimestampTolerance
        )
        if measuredAt > latestAcceptedDate {
            issues.append(
                issue(
                    code: "FUTURE_BODY_METRICS",
                    field: "bodyMetrics.measuredAt",
                    message: "The measurement timestamp is in the future.",
                    severity: .error,
                    rule: "body-metrics-future-timestamp"
                )
            )
        } else if referenceDate.timeIntervalSince(measuredAt)
            > configuration.maximumAge {
            issues.append(
                issue(
                    code: "STALE_BODY_METRICS",
                    field: "bodyMetrics.measuredAt",
                    message: "The measurement is older than the demo recency limit.",
                    severity: .warning,
                    rule: "body-metrics-recency"
                )
            )
        }

        let normalizedSource = metrics.source?.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        if normalizedSource?.isEmpty != false {
            issues.append(
                issue(
                    code: "BODY_METRICS_SOURCE_MISSING",
                    field: "bodyMetrics.source",
                    message: "The body-metrics source is missing.",
                    severity: .warning,
                    rule: "body-metrics-source"
                )
            )
        }

        let normalizedDeviceIdentifier =
            metrics.deviceIdentifier?.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
        let normalized = BodyMetrics(
            systolicBloodPressure: metrics.systolicBloodPressure,
            diastolicBloodPressure: metrics.diastolicBloodPressure,
            heartRate: metrics.heartRate,
            measuredAt: metrics.measuredAt,
            source: normalizedSource,
            deviceIdentifier:
                normalizedDeviceIdentifier?.isEmpty == true
                ? nil
                : normalizedDeviceIdentifier
        )
        return result(metrics: normalized, issues: issues)
    }

    private func result(
        metrics: BodyMetrics?,
        issues: [HealthContextValidationIssue]
    ) -> BodyMetricsQualityAssessment {
        let sorted = issues.sorted {
            if $0.severity != $1.severity {
                return $0.severity.rawValue < $1.severity.rawValue
            }
            return $0.code < $1.code
        }
        let status: HealthContextValidationStatus
        if sorted.contains(where: { $0.severity == .error }) {
            status = .invalid
        } else {
            status = sorted.isEmpty ? .valid : .validWithWarnings
        }
        return BodyMetricsQualityAssessment(
            status: status,
            normalizedMetrics: metrics,
            issues: sorted,
            configurationNotice: BodyMetricsQualityConfiguration.notice
        )
    }

    private func issue(
        code: String,
        field: String?,
        message: String,
        severity: HealthContextIssueSeverity,
        rule: String
    ) -> HealthContextValidationIssue {
        HealthContextValidationIssue(
            code: code,
            field: field,
            message: message,
            severity: severity,
            ruleIdentifier: rule
        )
    }
}
