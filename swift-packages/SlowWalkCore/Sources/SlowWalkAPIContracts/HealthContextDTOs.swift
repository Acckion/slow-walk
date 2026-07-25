import Foundation
import SlowWalkDomain

public struct BodyMetricsDTO:
    Codable,
    Sendable,
    Equatable,
    Hashable
{
    public let systolicBloodPressure: Int?
    public let diastolicBloodPressure: Int?
    public let heartRate: Int?
    public let measuredAt: Date?
    public let source: String?
    public let deviceIdentifier: String?

    public init(
        systolicBloodPressure: Int?,
        diastolicBloodPressure: Int?,
        heartRate: Int?,
        measuredAt: Date?,
        source: String?,
        deviceIdentifier: String?
    ) {
        self.systolicBloodPressure = systolicBloodPressure
        self.diastolicBloodPressure = diastolicBloodPressure
        self.heartRate = heartRate
        self.measuredAt = measuredAt
        self.source = source
        self.deviceIdentifier = deviceIdentifier
    }

    public init(_ metrics: BodyMetrics) {
        self.init(
            systolicBloodPressure: metrics.systolicBloodPressure,
            diastolicBloodPressure: metrics.diastolicBloodPressure,
            heartRate: metrics.heartRate,
            measuredAt: metrics.measuredAt,
            source: metrics.source,
            deviceIdentifier: metrics.deviceIdentifier
        )
    }

    public var domainModel: BodyMetrics {
        BodyMetrics(
            systolicBloodPressure: systolicBloodPressure,
            diastolicBloodPressure: diastolicBloodPressure,
            heartRate: heartRate,
            measuredAt: measuredAt,
            source: source,
            deviceIdentifier: deviceIdentifier
        )
    }
}

public struct UserHealthProfileDTO:
    Codable,
    Sendable,
    Equatable,
    Hashable
{
    public let id: UUID
    public let age: Int
    public let allergies: [String]
    public let diagnosedConditions: [String]
    public let currentMedicineIngredientIDs: [String]
    public let bodyMetrics: BodyMetricsDTO?
    public let createdAt: Date
    public let updatedAt: Date
    public let schemaVersion: Int

    public init(
        id: UUID,
        age: Int,
        allergies: [String],
        diagnosedConditions: [String],
        currentMedicineIngredientIDs: [String],
        bodyMetrics: BodyMetricsDTO?,
        createdAt: Date,
        updatedAt: Date,
        schemaVersion: Int
    ) {
        self.id = id
        self.age = age
        self.allergies = allergies
        self.diagnosedConditions = diagnosedConditions
        self.currentMedicineIngredientIDs =
            currentMedicineIngredientIDs
        self.bodyMetrics = bodyMetrics
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.schemaVersion = schemaVersion
    }

    public init(_ profile: UserHealthProfile) {
        self.init(
            id: profile.id,
            age: profile.age,
            allergies: profile.allergies,
            diagnosedConditions: profile.diagnosedConditions,
            currentMedicineIngredientIDs:
                profile.currentMedicineIngredientIDs,
            bodyMetrics: profile.bodyMetrics.map(BodyMetricsDTO.init),
            createdAt: profile.createdAt,
            updatedAt: profile.updatedAt,
            schemaVersion: profile.schemaVersion
        )
    }

    public var domainModel: UserHealthProfile {
        UserHealthProfile(
            id: id,
            age: age,
            allergies: allergies,
            diagnosedConditions: diagnosedConditions,
            currentMedicineIngredientIDs:
                currentMedicineIngredientIDs,
            bodyMetrics: bodyMetrics?.domainModel,
            updatedAt: updatedAt,
            createdAt: createdAt,
            schemaVersion: schemaVersion
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case age
        case allergies
        case diagnosedConditions
        case currentMedicineIngredientIDs
        case bodyMetrics
        case createdAt
        case updatedAt
        case schemaVersion
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )
        id = try container.decode(UUID.self, forKey: .id)
        age = try container.decode(Int.self, forKey: .age)

        // Missing means unknown/incomplete. An explicit [] means the user
        // answered that no relevant information is currently known.
        allergies = try container.decode(
            [String].self,
            forKey: .allergies
        )
        diagnosedConditions = try container.decode(
            [String].self,
            forKey: .diagnosedConditions
        )
        currentMedicineIngredientIDs = try container.decode(
            [String].self,
            forKey: .currentMedicineIngredientIDs
        )

        bodyMetrics = try container.decodeIfPresent(
            BodyMetricsDTO.self,
            forKey: .bodyMetrics
        )
        updatedAt = try container.decode(
            Date.self,
            forKey: .updatedAt
        )
        createdAt = try container.decodeIfPresent(
            Date.self,
            forKey: .createdAt
        ) ?? updatedAt
        schemaVersion = try container.decodeIfPresent(
            Int.self,
            forKey: .schemaVersion
        ) ?? UserHealthProfile.currentSchemaVersion
    }
}

public struct MedicationRecordDTO:
    Codable,
    Sendable,
    Equatable,
    Hashable
{
    public let id: UUID
    public let medicineID: String
    public let activeIngredientIDs: [String]
    public let recordedAt: Date
    public let eventType: String
    public let source: String

    public init(
        id: UUID,
        medicineID: String,
        activeIngredientIDs: [String],
        recordedAt: Date,
        eventType: String,
        source: String
    ) {
        self.id = id
        self.medicineID = medicineID
        self.activeIngredientIDs = activeIngredientIDs
        self.recordedAt = recordedAt
        self.eventType = eventType
        self.source = source
    }

    public init(_ record: MedicationRecord) {
        self.init(
            id: record.id,
            medicineID: record.medicineID,
            activeIngredientIDs: record.activeIngredientIDs,
            recordedAt: record.recordedAt,
            eventType: record.eventType.rawValue,
            source: record.source.rawValue
        )
    }

    public func domainModel() throws -> MedicationRecord {
        guard let eventType = MedicationEventType(
            rawValue: eventType
        ), let source = MedicationRecordSource(rawValue: source) else {
            throw HealthContextDTOError.invalidStableEnum
        }
        return MedicationRecord(
            id: id,
            medicineID: medicineID,
            activeIngredientIDs: activeIngredientIDs,
            recordedAt: recordedAt,
            eventType: eventType,
            source: source
        )
    }
}

public struct HealthContextWarningDTO:
    Codable,
    Sendable,
    Equatable,
    Hashable
{
    public let code: String
    public let field: String?
    public let message: String
    public let severity: String
    public let ruleIdentifier: String

    public init(
        code: String,
        field: String?,
        message: String,
        severity: String,
        ruleIdentifier: String
    ) {
        self.code = code
        self.field = field
        self.message = message
        self.severity = severity
        self.ruleIdentifier = ruleIdentifier
    }

    public init(_ issue: HealthContextValidationIssue) {
        self.init(
            code: issue.code,
            field: issue.field,
            message: issue.message,
            severity: issue.severity.rawValue,
            ruleIdentifier: issue.ruleIdentifier
        )
    }
}

public struct HealthContextValidationDTO:
    Codable,
    Sendable,
    Equatable,
    Hashable
{
    public let status: String
    public let warnings: [HealthContextWarningDTO]
    public let configurationNotices: [String]

    public init(
        status: String,
        warnings: [HealthContextWarningDTO],
        configurationNotices: [String]
    ) {
        self.status = status
        self.warnings = warnings
        self.configurationNotices = configurationNotices
    }

    public init(_ validation: HealthContextValidation) {
        self.init(
            status: validation.status.rawValue,
            warnings: validation.issues.map(
                HealthContextWarningDTO.init
            ),
            configurationNotices:
                validation.configurationNotices
        )
    }
}

public enum HealthContextDTOError: Error, Sendable, Equatable {
    case invalidStableEnum
}
