import Foundation

/// Broad display category for demo medicine data.
public enum MedicineCategory: String, Codable, Sendable, CaseIterable, Hashable {
    case analgesic
    case antipyretic
    case coldAndFlu = "cold_and_flu"
    case antihistamine
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

    public init(
        id: String,
        canonicalName: String,
        aliases: [String],
        activeIngredientIDs: [String],
        medicineCategory: MedicineCategory,
        sourceReferences: [SourceReference],
        dosageTextFromSource: String?,
        contraindicationTags: [String]
    ) {
        self.id = id
        self.canonicalName = canonicalName
        self.aliases = aliases
        self.activeIngredientIDs = activeIngredientIDs
        self.medicineCategory = medicineCategory
        self.sourceReferences = sourceReferences
        self.dosageTextFromSource = dosageTextFromSource
        self.contraindicationTags = contraindicationTags
    }
}
