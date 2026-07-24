import Foundation
import SlowWalkDomain

/// Fixed safety metadata required on every bundled demo medicine catalog.
public enum DemoMedicineCatalogPolicy {
    public static let supportedSchemaVersion = 1
    public static let minimumMedicineCount = 12
    public static let requiredDisclaimer =
        "DEMO DATA — NOT FOR CLINICAL USE"
}

/// Validated snapshot of the bundled, synthetic demo medicine catalog.
public struct MedicineCatalog: Sendable, Equatable {
    public let schemaVersion: Int
    public let documentTitle: String
    public let disclaimer: String
    public let sourceDataVersion: String
    public let medicines: [Medicine]

    public init(
        schemaVersion: Int,
        documentTitle: String,
        disclaimer: String,
        sourceDataVersion: String,
        medicines: [Medicine]
    ) throws {
        try Self.validate(
            schemaVersion: schemaVersion,
            documentTitle: documentTitle,
            disclaimer: disclaimer,
            sourceDataVersion: sourceDataVersion,
            medicines: medicines
        )
        self.schemaVersion = schemaVersion
        self.documentTitle = documentTitle
        self.disclaimer = disclaimer
        self.sourceDataVersion = sourceDataVersion
        self.medicines = medicines
    }

    private static func validate(
        schemaVersion: Int,
        documentTitle: String,
        disclaimer: String,
        sourceDataVersion: String,
        medicines: [Medicine]
    ) throws {
        guard schemaVersion == DemoMedicineCatalogPolicy.supportedSchemaVersion else {
            throw MedicineCatalogError.unsupportedSchemaVersion(schemaVersion)
        }
        guard disclaimer == DemoMedicineCatalogPolicy.requiredDisclaimer else {
            throw MedicineCatalogError.invalidDisclaimer
        }
        guard documentTitle == DemoMedicineCatalogPolicy.requiredDisclaimer else {
            throw MedicineCatalogError.invalidDocumentTitle
        }

        let version = sourceDataVersion.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !version.isEmpty else {
            throw MedicineCatalogError.emptySourceDataVersion
        }
        guard medicines.count >= DemoMedicineCatalogPolicy.minimumMedicineCount else {
            throw MedicineCatalogError.tooFewMedicines(
                minimum: DemoMedicineCatalogPolicy.minimumMedicineCount,
                actual: medicines.count
            )
        }

        var medicineIDs = Set<String>()
        for medicine in medicines {
            guard medicineIDs.insert(medicine.id).inserted else {
                throw MedicineCatalogError.duplicateMedicineID(medicine.id)
            }
            guard medicine.dosageTextFromSource == nil else {
                throw MedicineCatalogError.dosageTextPresent(
                    medicineID: medicine.id
                )
            }
            guard medicine.dataVersion == version else {
                throw MedicineCatalogError.medicineVersionMismatch(
                    medicineID: medicine.id,
                    expected: version,
                    actual: medicine.dataVersion
                )
            }
            guard medicine.warnings.contains(disclaimer) else {
                throw MedicineCatalogError.missingDisclaimerWarning(
                    medicineID: medicine.id
                )
            }
            guard !medicine.sourceReferences.isEmpty else {
                throw MedicineCatalogError.missingSourceReference(
                    medicineID: medicine.id
                )
            }

            for source in medicine.sourceReferences {
                guard source.documentTitle == documentTitle else {
                    throw MedicineCatalogError.sourceDocumentTitleMismatch(
                        medicineID: medicine.id
                    )
                }
                guard source.versionOrDate == version else {
                    throw MedicineCatalogError.sourceVersionMismatch(
                        medicineID: medicine.id,
                        expected: version,
                        actual: source.versionOrDate
                    )
                }
            }
        }
    }
}

public enum MedicineCatalogError: Error, Sendable, Equatable {
    case resourceNotFound(name: String)
    case unsupportedSchemaVersion(Int)
    case invalidDisclaimer
    case invalidDocumentTitle
    case emptySourceDataVersion
    case tooFewMedicines(minimum: Int, actual: Int)
    case duplicateMedicineID(String)
    case dosageTextPresent(medicineID: String)
    case medicineVersionMismatch(
        medicineID: String,
        expected: String,
        actual: String
    )
    case missingDisclaimerWarning(medicineID: String)
    case missingSourceReference(medicineID: String)
    case sourceDocumentTitleMismatch(medicineID: String)
    case sourceVersionMismatch(
        medicineID: String,
        expected: String,
        actual: String
    )
}

public protocol MedicineCatalogLoading: Sendable {
    func loadCatalog() throws -> MedicineCatalog
}

/// Decodes catalog bytes and applies all demo-data safety validation.
public struct MedicineCatalogDecoder: Sendable {
    public init() {}

    public func decode(_ data: Data) throws -> MedicineCatalog {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(MedicineCatalogPayload.self, from: data)
        return try MedicineCatalog(
            schemaVersion: payload.schemaVersion,
            documentTitle: payload.documentTitle,
            disclaimer: payload.disclaimer,
            sourceDataVersion: payload.sourceDataVersion,
            medicines: payload.medicines
        )
    }
}

/// Loads the catalog through SwiftPM's generated resource bundle.
///
/// `Bundle.module` is independent of the process working directory and works
/// in Linux SwiftPM test jobs.
public struct BundledDemoMedicineCatalogLoader: MedicineCatalogLoading, Sendable {
    public static let resourceName = "demo-medicine-catalog"

    public init() {}

    public func loadCatalog() throws -> MedicineCatalog {
        guard let resourceURL = Bundle.module.url(
            forResource: Self.resourceName,
            withExtension: "json"
        ) else {
            throw MedicineCatalogError.resourceNotFound(
                name: "\(Self.resourceName).json"
            )
        }

        let data = try Data(contentsOf: resourceURL)
        return try MedicineCatalogDecoder().decode(data)
    }
}

private struct MedicineCatalogPayload: Decodable {
    let schemaVersion: Int
    let documentTitle: String
    let disclaimer: String
    let sourceDataVersion: String
    let medicines: [Medicine]
}
