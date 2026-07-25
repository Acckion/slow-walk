import Foundation

/// Optional measurements supplied by a user or trusted source.
///
/// Values are stored for data-quality checks only. SlowWalkCore does not apply
/// diagnostic thresholds to them.
public struct BodyMetrics: Codable, Sendable, Equatable, Hashable {
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
        source: String? = nil,
        deviceIdentifier: String? = nil
    ) {
        self.systolicBloodPressure = systolicBloodPressure
        self.diastolicBloodPressure = diastolicBloodPressure
        self.heartRate = heartRate
        self.measuredAt = measuredAt
        self.source = source
        self.deviceIdentifier = deviceIdentifier
    }

    private enum CodingKeys: String, CodingKey {
        case systolicBloodPressure
        case diastolicBloodPressure
        case heartRate
        case measuredAt
        case source
        case deviceIdentifier
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        systolicBloodPressure = try container.decodeIfPresent(
            Int.self,
            forKey: .systolicBloodPressure
        )
        diastolicBloodPressure = try container.decodeIfPresent(
            Int.self,
            forKey: .diastolicBloodPressure
        )
        heartRate = try container.decodeIfPresent(
            Int.self,
            forKey: .heartRate
        )
        measuredAt = try container.decodeIfPresent(
            Date.self,
            forKey: .measuredAt
        )
        source = try container.decodeIfPresent(String.self, forKey: .source)
        deviceIdentifier = try container.decodeIfPresent(
            String.self,
            forKey: .deviceIdentifier
        )
    }
}

/// User-supplied health context used by risk rules.
public struct UserHealthProfile: Codable, Sendable, Equatable, Hashable {
    public static let currentSchemaVersion = 1

    public let id: UUID
    public let age: Int
    public let allergies: [String]
    public let diagnosedConditions: [String]
    public let currentMedicineIngredientIDs: [String]
    public let bodyMetrics: BodyMetrics?
    public let createdAt: Date
    public let updatedAt: Date
    public let schemaVersion: Int

    public init(
        id: UUID,
        age: Int,
        allergies: [String],
        diagnosedConditions: [String],
        currentMedicineIngredientIDs: [String],
        bodyMetrics: BodyMetrics?,
        updatedAt: Date,
        createdAt: Date? = nil,
        schemaVersion: Int = UserHealthProfile.currentSchemaVersion
    ) {
        self.id = id
        self.age = age
        self.allergies = allergies
        self.diagnosedConditions = diagnosedConditions
        self.currentMedicineIngredientIDs = currentMedicineIngredientIDs
        self.bodyMetrics = bodyMetrics
        self.createdAt = createdAt ?? updatedAt
        self.updatedAt = updatedAt
        self.schemaVersion = schemaVersion
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
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        age = try container.decode(Int.self, forKey: .age)
        allergies = try container.decodeIfPresent(
            [String].self,
            forKey: .allergies
        ) ?? []
        diagnosedConditions = try container.decodeIfPresent(
            [String].self,
            forKey: .diagnosedConditions
        ) ?? []
        currentMedicineIngredientIDs = try container.decodeIfPresent(
            [String].self,
            forKey: .currentMedicineIngredientIDs
        ) ?? []
        bodyMetrics = try container.decodeIfPresent(
            BodyMetrics.self,
            forKey: .bodyMetrics
        )
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
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
