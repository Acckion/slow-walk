import Foundation

/// Broad display category for demo medicine data.
public enum MedicineCategory: String, Codable, Sendable, CaseIterable, Hashable {
    case analgesic
    case antipyretic
    case coldAndFlu = "cold_and_flu"
    case antihistamine
    case antihypertensive
    case antidiabetic
    case gastrointestinal
    case other
}

/// Canonicalized medicine information backed by source references.
public struct Medicine: Codable, Sendable, Equatable, Hashable {
    public let id: String
    public let canonicalName: String
    public let aliases: [String]
    public let activeIngredientIDs: [String]
    public let medicineCategory: MedicineCategory
    public let sourceReferences: [SourceReference]
    public let dosageTextFromSource: String?
    public let contraindicationTags: [String]
    public let warnings: [String]
    public let dataVersion: String

    public init(
        id: String,
        canonicalName: String,
        aliases: [String],
        activeIngredientIDs: [String],
        medicineCategory: MedicineCategory,
        sourceReferences: [SourceReference],
        dosageTextFromSource: String?,
        contraindicationTags: [String],
        warnings: [String] = [],
        dataVersion: String = "legacy-v1"
    ) {
        self.id = id
        self.canonicalName = canonicalName
        self.aliases = aliases
        self.activeIngredientIDs = activeIngredientIDs
        self.medicineCategory = medicineCategory
        self.sourceReferences = sourceReferences
        self.dosageTextFromSource = dosageTextFromSource
        self.contraindicationTags = contraindicationTags
        self.warnings = warnings
        self.dataVersion = dataVersion
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case canonicalName
        case aliases
        case activeIngredientIDs
        case medicineCategory
        case sourceReferences
        case dosageTextFromSource
        case contraindicationTags
        case warnings
        case dataVersion
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        canonicalName = try container.decode(String.self, forKey: .canonicalName)
        aliases = try container.decode([String].self, forKey: .aliases)
        activeIngredientIDs = try container.decode(
            [String].self,
            forKey: .activeIngredientIDs
        )
        medicineCategory = try container.decode(
            MedicineCategory.self,
            forKey: .medicineCategory
        )
        sourceReferences = try container.decode(
            [SourceReference].self,
            forKey: .sourceReferences
        )
        dosageTextFromSource = try container.decodeIfPresent(
            String.self,
            forKey: .dosageTextFromSource
        )
        contraindicationTags = try container.decode(
            [String].self,
            forKey: .contraindicationTags
        )
        warnings = try container.decodeIfPresent(
            [String].self,
            forKey: .warnings
        ) ?? []
        dataVersion = try container.decodeIfPresent(
            String.self,
            forKey: .dataVersion
        ) ?? "legacy-v1"
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(canonicalName, forKey: .canonicalName)
        try container.encode(aliases, forKey: .aliases)
        try container.encode(activeIngredientIDs, forKey: .activeIngredientIDs)
        try container.encode(medicineCategory, forKey: .medicineCategory)
        try container.encode(sourceReferences, forKey: .sourceReferences)
        try container.encodeIfPresent(
            dosageTextFromSource,
            forKey: .dosageTextFromSource
        )
        try container.encode(
            contraindicationTags,
            forKey: .contraindicationTags
        )
        try container.encode(warnings, forKey: .warnings)
        try container.encode(dataVersion, forKey: .dataVersion)
    }
}
