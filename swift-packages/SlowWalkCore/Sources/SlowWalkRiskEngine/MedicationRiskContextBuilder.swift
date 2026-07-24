import Foundation
import SlowWalkDomain

public enum MedicationRiskContextBuildError:
    Error,
    Sendable,
    Equatable
{
    case missingUserProfile
    case invalidUserProfile([HealthContextValidationIssue])
    case unsupportedProfileSchema([HealthContextValidationIssue])
    case invalidMedicationRecord([HealthContextValidationIssue])
    case futureMedicationRecord([HealthContextValidationIssue])
    case invalidBodyMetrics([HealthContextValidationIssue])
    case unresolvedMedicine(MedicineResolutionStatus)
    case medicineResolutionMismatch
}

public struct MedicationRiskContextBuilderConfiguration:
    Sendable,
    Equatable,
    Hashable
{
    public let profile: UserHealthProfileValidationConfiguration
    public let bodyMetrics: BodyMetricsQualityConfiguration
    public let medicationHistory:
        MedicationHistoryAnalysisConfiguration

    public init(
        profile: UserHealthProfileValidationConfiguration,
        bodyMetrics: BodyMetricsQualityConfiguration,
        medicationHistory: MedicationHistoryAnalysisConfiguration
    ) {
        self.profile = profile
        self.bodyMetrics = bodyMetrics
        self.medicationHistory = medicationHistory
    }

    public static let demo = MedicationRiskContextBuilderConfiguration(
        profile: .standard,
        bodyMetrics: .demo,
        medicationHistory: .demo
    )
}

public struct MedicationRiskContextPreflightResult:
    Sendable,
    Equatable
{
    public let normalizedProfile: UserHealthProfile
    public let normalizedRecords: [MedicationRecord]
    public let validation: HealthContextValidation

    public init(
        normalizedProfile: UserHealthProfile,
        normalizedRecords: [MedicationRecord],
        validation: HealthContextValidation
    ) {
        self.normalizedProfile = normalizedProfile
        self.normalizedRecords = normalizedRecords
        self.validation = validation
    }
}

public struct MedicationRiskContextBuildResult:
    Sendable,
    Equatable
{
    public let context: MedicationRiskContext
    public let validation: HealthContextValidation

    public init(
        context: MedicationRiskContext,
        validation: HealthContextValidation
    ) {
        self.context = context
        self.validation = validation
    }
}

public protocol MedicationRiskContextBuilding: Sendable {
    func validate(
        userProfile: UserHealthProfile?,
        bodyMetrics: BodyMetrics?,
        medicationRecords: [MedicationRecord]
    ) throws -> MedicationRiskContextPreflightResult

    func build(
        medicine: Medicine,
        resolution: MedicineResolution,
        preflight: MedicationRiskContextPreflightResult,
        scanEvent: MedicineScanEvent,
        sourceReferences: [SourceReference]
    ) throws -> MedicationRiskContextBuildResult
}

/// Central validation and context-construction boundary before RiskEngine.
public struct MedicationRiskContextBuilder:
    MedicationRiskContextBuilding,
    Sendable
{
    private let clock: any Clock
    private let configuration: MedicationRiskContextBuilderConfiguration

    public init(
        clock: any Clock,
        configuration: MedicationRiskContextBuilderConfiguration = .demo
    ) {
        self.clock = clock
        self.configuration = configuration
    }

    public func validate(
        userProfile: UserHealthProfile?,
        bodyMetrics: BodyMetrics?,
        medicationRecords: [MedicationRecord]
    ) throws -> MedicationRiskContextPreflightResult {
        guard let userProfile else {
            throw MedicationRiskContextBuildError.missingUserProfile
        }
        let now = clock.now()
        let profileValidation = UserHealthProfileValidator(
            configuration: configuration.profile
        ).validate(userProfile, relativeTo: now)
        if profileValidation.issues.contains(
            where: { $0.code == "UNSUPPORTED_PROFILE_SCHEMA" }
        ) {
            throw MedicationRiskContextBuildError
                .unsupportedProfileSchema(profileValidation.issues)
        }
        if profileValidation.status == .invalid {
            throw MedicationRiskContextBuildError.invalidUserProfile(
                profileValidation.issues
            )
        }

        let selectedMetrics = bodyMetrics
            ?? profileValidation.normalizedProfile.bodyMetrics
        let metricsAssessment = BodyMetricsQualityAssessor(
            configuration: configuration.bodyMetrics
        ).assess(selectedMetrics, relativeTo: now)
        if metricsAssessment.status == .invalid {
            throw MedicationRiskContextBuildError.invalidBodyMetrics(
                metricsAssessment.issues
            )
        }

        let historyAnalyzer = MedicationHistoryAnalyzer(
            records: medicationRecords,
            clock: clock,
            configuration: configuration.medicationHistory
        )
        let recordFindings = historyAnalyzer.findings(relativeTo: now)
        let recordIssues = recordFindings.map(Self.validationIssue)
        if recordFindings.contains(where: { $0.code == .futureRecord }) {
            throw MedicationRiskContextBuildError.futureMedicationRecord(
                recordIssues
            )
        }
        if recordFindings.contains(where: {
            $0.severity == .error
        }) {
            throw MedicationRiskContextBuildError.invalidMedicationRecord(
                recordIssues
            )
        }

        let issues = (
            profileValidation.issues
            + metricsAssessment.issues
            + recordIssues
        ).sorted(by: Self.issueOrder)

        let normalizedProfile = UserHealthProfile(
            id: profileValidation.normalizedProfile.id,
            age: profileValidation.normalizedProfile.age,
            allergies: profileValidation.normalizedProfile.allergies,
            diagnosedConditions:
                profileValidation.normalizedProfile.diagnosedConditions,
            currentMedicineIngredientIDs:
                profileValidation.normalizedProfile
                    .currentMedicineIngredientIDs,
            bodyMetrics: metricsAssessment.normalizedMetrics,
            updatedAt: profileValidation.normalizedProfile.updatedAt,
            createdAt: profileValidation.normalizedProfile.createdAt,
            schemaVersion:
                profileValidation.normalizedProfile.schemaVersion
        )
        let validation = HealthContextValidation(
            status: issues.isEmpty ? .valid : .validWithWarnings,
            issues: issues,
            configurationNotices: [
                BodyMetricsQualityConfiguration.notice,
                "NOT FOR CLINICAL USE",
            ]
        )
        return MedicationRiskContextPreflightResult(
            normalizedProfile: normalizedProfile,
            normalizedRecords: historyAnalyzer.sanitizedRecords(
                relativeTo: now
            ),
            validation: validation
        )
    }

    public func build(
        medicine: Medicine,
        resolution: MedicineResolution,
        preflight: MedicationRiskContextPreflightResult,
        scanEvent: MedicineScanEvent,
        sourceReferences: [SourceReference]
    ) throws -> MedicationRiskContextBuildResult {
        guard resolution.status == .resolved else {
            throw MedicationRiskContextBuildError.unresolvedMedicine(
                resolution.status
            )
        }
        guard resolution.selectedMedicine?.id == medicine.id,
              scanEvent.candidateMedicineID == medicine.id else {
            throw MedicationRiskContextBuildError
                .medicineResolutionMismatch
        }

        let now = clock.now()
        let allSources = uniqueSources(
            sourceReferences + medicine.sourceReferences
        )
        var validationIssues = preflight.validation.issues
        if allSources.isEmpty {
            validationIssues.append(
                HealthContextValidationIssue(
                    code: "MEDICINE_SOURCES_MISSING",
                    field: "sourceReferences",
                    message: "No traceable medicine source was supplied.",
                    severity: .warning,
                    ruleIdentifier: "medicine-source-completeness"
                )
            )
        }
        if scanEvent.recognitionStatus != .recognized {
            validationIssues.append(
                HealthContextValidationIssue(
                    code: "MEDICINE_RECOGNITION_UNCONFIRMED",
                    field: "scanEvent.recognitionStatus",
                    message: "Medicine recognition is not confirmed.",
                    severity: .warning,
                    ruleIdentifier: "medicine-recognition-completeness"
                )
            )
        }
        validationIssues = validationIssues.sorted(by: Self.issueOrder)

        let historyAnalyzer = MedicationHistoryAnalyzer(
            records: preflight.normalizedRecords,
            clock: clock,
            configuration: configuration.medicationHistory
        )
        let duplicates = historyAnalyzer.duplicateIngredientFindings(
            currentMedicine: medicine,
            profile: preflight.normalizedProfile,
            recentRecords: preflight.normalizedRecords
        )
        let completeness: EvidenceCompleteness
        if allSources.isEmpty {
            completeness = .insufficient
        } else if validationIssues.isEmpty {
            completeness = .complete
        } else {
            completeness = .partial
        }
        let validation = HealthContextValidation(
            status: validationIssues.isEmpty
                ? .valid
                : .validWithWarnings,
            issues: validationIssues,
            configurationNotices:
                preflight.validation.configurationNotices
        )
        let context = MedicationRiskContext(
            medicine: medicine,
            userProfile: preflight.normalizedProfile,
            recentRecords: preflight.normalizedRecords,
            scanEvent: scanEvent,
            assessedAt: now,
            evidenceCompleteness: completeness,
            healthContextWarnings: validationIssues,
            duplicateIngredientFindings: duplicates,
            sourceReferences: allSources
        )
        return MedicationRiskContextBuildResult(
            context: context,
            validation: validation
        )
    }

    private func uniqueSources(
        _ sources: [SourceReference]
    ) -> [SourceReference] {
        Array(Set(sources)).sorted {
            if $0.sourceName != $1.sourceName {
                return $0.sourceName < $1.sourceName
            }
            if $0.documentTitle != $1.documentTitle {
                return $0.documentTitle < $1.documentTitle
            }
            return $0.retrievedAt < $1.retrievedAt
        }
    }

    private static func validationIssue(
        _ finding: MedicationRecordFinding
    ) -> HealthContextValidationIssue {
        HealthContextValidationIssue(
            code: finding.code.rawValue,
            field: "recentRecords",
            message: finding.message,
            severity: finding.severity,
            ruleIdentifier: finding.ruleIdentifier
        )
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
        if lhs.ruleIdentifier != rhs.ruleIdentifier {
            return lhs.ruleIdentifier < rhs.ruleIdentifier
        }
        return (lhs.field ?? "") < (rhs.field ?? "")
    }
}
