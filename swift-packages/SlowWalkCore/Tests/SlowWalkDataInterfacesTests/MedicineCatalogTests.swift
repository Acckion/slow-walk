import Foundation
import SlowWalkDataInterfaces
import SlowWalkDomain
import XCTest

final class MedicineCatalogTests: XCTestCase {
    private let version = "slowwalk-demo-catalog-v1"
    private let retrievedAt = Date(timeIntervalSince1970: 1_753_315_200)

    func testBundledCatalogLoadsAtLeastTwelveDoseFreeLabeledMedicines() throws {
        let catalog = try BundledDemoMedicineCatalogLoader().loadCatalog()

        XCTAssertEqual(
            catalog.schemaVersion,
            DemoMedicineCatalogPolicy.supportedSchemaVersion
        )
        XCTAssertEqual(
            catalog.documentTitle,
            DemoMedicineCatalogPolicy.requiredDisclaimer
        )
        XCTAssertEqual(
            catalog.disclaimer,
            DemoMedicineCatalogPolicy.requiredDisclaimer
        )
        XCTAssertGreaterThanOrEqual(
            catalog.medicines.count,
            DemoMedicineCatalogPolicy.minimumMedicineCount
        )
        XCTAssertEqual(
            Set(catalog.medicines.map(\.id)).count,
            catalog.medicines.count
        )
        XCTAssertEqual(
            Set(catalog.medicines.map(\.canonicalName)),
            Set([
                "Acetaminophen",
                "Ibuprofen",
                "Dextromethorphan",
                "Chlorpheniramine",
                "Amlodipine",
                "Losartan",
                "Metformin",
                "Gliclazide",
                "Cetirizine",
                "Loratadine",
                "Omeprazole",
                "Famotidine",
            ])
        )
        let requiredCategories: Set<MedicineCategory> = [
            .analgesic,
            .antipyretic,
            .coldAndFlu,
            .antihypertensive,
            .antidiabetic,
            .antihistamine,
            .gastrointestinal,
        ]
        XCTAssertTrue(
            Set(catalog.medicines.map(\.medicineCategory)).isSuperset(
                of: requiredCategories
            )
        )

        for medicine in catalog.medicines {
            XCTAssertNil(medicine.dosageTextFromSource)
            XCTAssertEqual(medicine.dataVersion, catalog.sourceDataVersion)
            XCTAssertTrue(
                medicine.warnings.contains(
                    DemoMedicineCatalogPolicy.requiredDisclaimer
                )
            )
            XCTAssertFalse(medicine.sourceReferences.isEmpty)
            XCTAssertTrue(
                medicine.sourceReferences.allSatisfy {
                    $0.documentTitle
                        == DemoMedicineCatalogPolicy.requiredDisclaimer
                        && $0.versionOrDate == catalog.sourceDataVersion
                }
            )
        }
    }

    func testBundledCatalogKeepsColdReliefAliasAmbiguous() throws {
        let catalog = try BundledDemoMedicineCatalogLoader().loadCatalog()

        let matchingIDs = catalog.medicines
            .filter { $0.aliases.contains("Cold Relief") }
            .map(\.id)
            .sorted()

        XCTAssertEqual(
            matchingIDs,
            ["demo-chlorpheniramine", "demo-dextromethorphan"]
        )
    }

    func testCatalogRejectsWrongTopLevelDisclaimer() {
        XCTAssertThrowsError(
            try makeCatalog(disclaimer: "demo")
        ) { error in
            XCTAssertEqual(
                error as? MedicineCatalogError,
                .invalidDisclaimer
            )
        }
    }

    func testCatalogRejectsWrongTopLevelDocumentTitle() {
        XCTAssertThrowsError(
            try makeCatalog(documentTitle: "Demo catalog")
        ) { error in
            XCTAssertEqual(
                error as? MedicineCatalogError,
                .invalidDocumentTitle
            )
        }
    }

    func testCatalogRejectsMedicineVersionMismatch() {
        var medicines = makeMedicines()
        medicines[0] = makeMedicine(
            index: 0,
            medicineVersion: "catalog-v2"
        )

        XCTAssertThrowsError(
            try makeCatalog(medicines: medicines)
        ) { error in
            XCTAssertEqual(
                error as? MedicineCatalogError,
                .medicineVersionMismatch(
                    medicineID: "demo-medicine-0",
                    expected: version,
                    actual: "catalog-v2"
                )
            )
        }
    }

    func testCatalogRejectsSourceDocumentMismatch() {
        var medicines = makeMedicines()
        medicines[0] = makeMedicine(
            index: 0,
            sourceDocumentTitle: "Unlabelled document"
        )

        XCTAssertThrowsError(
            try makeCatalog(medicines: medicines)
        ) { error in
            XCTAssertEqual(
                error as? MedicineCatalogError,
                .sourceDocumentTitleMismatch(
                    medicineID: "demo-medicine-0"
                )
            )
        }
    }

    func testCatalogRejectsSourceVersionMismatch() {
        var medicines = makeMedicines()
        medicines[0] = makeMedicine(
            index: 0,
            sourceVersion: "catalog-v2"
        )

        XCTAssertThrowsError(
            try makeCatalog(medicines: medicines)
        ) { error in
            XCTAssertEqual(
                error as? MedicineCatalogError,
                .sourceVersionMismatch(
                    medicineID: "demo-medicine-0",
                    expected: version,
                    actual: "catalog-v2"
                )
            )
        }
    }

    func testCatalogRejectsAnyDosageText() {
        var medicines = makeMedicines()
        medicines[0] = makeMedicine(
            index: 0,
            dosageTextFromSource: "Not permitted in demo data"
        )

        XCTAssertThrowsError(
            try makeCatalog(medicines: medicines)
        ) { error in
            XCTAssertEqual(
                error as? MedicineCatalogError,
                .dosageTextPresent(medicineID: "demo-medicine-0")
            )
        }
    }

    func testCatalogRejectsMissingPerMedicineDisclaimer() {
        var medicines = makeMedicines()
        medicines[0] = makeMedicine(index: 0, warnings: [])

        XCTAssertThrowsError(
            try makeCatalog(medicines: medicines)
        ) { error in
            XCTAssertEqual(
                error as? MedicineCatalogError,
                .missingDisclaimerWarning(
                    medicineID: "demo-medicine-0"
                )
            )
        }
    }

    func testCatalogRejectsFewerThanTwelveMedicines() {
        let medicines = Array(makeMedicines().prefix(11))

        XCTAssertThrowsError(
            try makeCatalog(medicines: medicines)
        ) { error in
            XCTAssertEqual(
                error as? MedicineCatalogError,
                .tooFewMedicines(minimum: 12, actual: 11)
            )
        }
    }

    private func makeCatalog(
        documentTitle: String = DemoMedicineCatalogPolicy.requiredDisclaimer,
        disclaimer: String = DemoMedicineCatalogPolicy.requiredDisclaimer,
        medicines: [Medicine]? = nil
    ) throws -> MedicineCatalog {
        try MedicineCatalog(
            schemaVersion: 1,
            documentTitle: documentTitle,
            disclaimer: disclaimer,
            sourceDataVersion: version,
            medicines: medicines ?? makeMedicines()
        )
    }

    private func makeMedicines() -> [Medicine] {
        (0 ..< DemoMedicineCatalogPolicy.minimumMedicineCount).map {
            makeMedicine(index: $0)
        }
    }

    private func makeMedicine(
        index: Int,
        medicineVersion: String? = nil,
        sourceDocumentTitle: String? = nil,
        sourceVersion: String? = nil,
        dosageTextFromSource: String? = nil,
        warnings: [String]? = nil
    ) -> Medicine {
        Medicine(
            id: "demo-medicine-\(index)",
            canonicalName: "Demo Medicine \(index)",
            aliases: ["Demo Alias \(index)"],
            activeIngredientIDs: ["demo-ingredient-\(index)"],
            medicineCategory: .other,
            sourceReferences: [
                SourceReference(
                    sourceName: "SlowWalk Synthetic Demo Catalog",
                    documentTitle: sourceDocumentTitle
                        ?? DemoMedicineCatalogPolicy.requiredDisclaimer,
                    optionalURL: nil,
                    retrievedAt: retrievedAt,
                    versionOrDate: sourceVersion ?? version
                ),
            ],
            dosageTextFromSource: dosageTextFromSource,
            contraindicationTags: [],
            warnings: warnings
                ?? [DemoMedicineCatalogPolicy.requiredDisclaimer],
            dataVersion: medicineVersion ?? version
        )
    }
}
