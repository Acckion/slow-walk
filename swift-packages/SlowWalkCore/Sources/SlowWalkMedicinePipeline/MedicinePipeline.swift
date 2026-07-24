import Foundation
import SlowWalkDataInterfaces
import SlowWalkDomain
import SlowWalkRiskEngine

public struct MedicinePipelineResolutionResult: Sendable, Equatable {
    public let resolution: MedicineResolution
    public let cacheStatus: MedicineResolutionCacheStatus
    public let sourceDataVersion: String
    public let generatedAt: Date
    public let cacheHit: Bool

    public init(
        resolution: MedicineResolution,
        cacheStatus: MedicineResolutionCacheStatus,
        sourceDataVersion: String,
        generatedAt: Date,
        cacheHit: Bool
    ) {
        self.resolution = resolution
        self.cacheStatus = cacheStatus
        self.sourceDataVersion = sourceDataVersion
        self.generatedAt = generatedAt
        self.cacheHit = cacheHit
    }
}

public struct MedicinePipelineAssessmentResult: Sendable, Equatable {
    public let resolution: MedicineResolution
    public let cacheStatus: MedicineResolutionCacheStatus
    public let sourceDataVersion: String
    public let generatedAt: Date
    public let cacheHit: Bool
    public let scanEvent: MedicineScanEvent
    public let assessment: RiskAssessment?
    public let actionCard: ActionCard

    public init(
        resolution: MedicineResolution,
        cacheStatus: MedicineResolutionCacheStatus,
        sourceDataVersion: String,
        generatedAt: Date,
        cacheHit: Bool,
        scanEvent: MedicineScanEvent,
        assessment: RiskAssessment?,
        actionCard: ActionCard
    ) {
        self.resolution = resolution
        self.cacheStatus = cacheStatus
        self.sourceDataVersion = sourceDataVersion
        self.generatedAt = generatedAt
        self.cacheHit = cacheHit
        self.scanEvent = scanEvent
        self.assessment = assessment
        self.actionCard = actionCard
    }
}

/// Orchestrates deterministic name resolution, cache use, and risk assessment.
///
/// A cache hit reuses only the candidate set. The current confidence is always
/// revalidated and every assessment invokes the risk engine again.
public struct MedicinePipeline: Sendable {
    private let catalogLoader: any MedicineCatalogLoading
    private let cache: any MedicineCache
    private let dateProvider: any DateProviding
    private let uuidProvider: any UUIDProviding
    private let normalizer: any MedicineNameNormalizing
    private let resolver: any MedicineResolving
    private let riskAssessor: any RiskAssessing
    private let actionCardFactory: ActionCardFactory

    public init(
        catalogLoader: any MedicineCatalogLoading =
            BundledDemoMedicineCatalogLoader(),
        cache: any MedicineCache = InMemoryMedicineCache(),
        dateProvider: any DateProviding = SystemDateProvider(),
        uuidProvider: any UUIDProviding = SystemUUIDProvider(),
        normalizer: any MedicineNameNormalizing =
            MedicineNameNormalizer(),
        resolver: any MedicineResolving = MedicineResolver(),
        riskAssessor: any RiskAssessing = MedicationRiskEngine(),
        actionCardFactory: ActionCardFactory = ActionCardFactory()
    ) {
        self.catalogLoader = catalogLoader
        self.cache = cache
        self.dateProvider = dateProvider
        self.uuidProvider = uuidProvider
        self.normalizer = normalizer
        self.resolver = resolver
        self.riskAssessor = riskAssessor
        self.actionCardFactory = actionCardFactory
    }

    public func resolve(
        input: MedicineRecognitionInput
    ) async throws -> MedicinePipelineResolutionResult {
        let generatedAt = dateProvider.now()
        return try await resolve(
            input: input,
            generatedAt: generatedAt
        )
    }

    public func assess(
        input: MedicineRecognitionInput,
        userProfile: UserHealthProfile,
        recentRecords: [MedicationRecord]
    ) async throws -> MedicinePipelineAssessmentResult {
        let generatedAt = dateProvider.now()
        let resolutionResult = try await resolve(
            input: input,
            generatedAt: generatedAt
        )
        let scanEvent = makeScanEvent(
            input: input,
            resolution: resolutionResult.resolution
        )

        let assessment: RiskAssessment?
        if resolutionResult.resolution.status == .resolved,
           let medicine =
            resolutionResult.resolution.selectedMedicine {
            assessment = riskAssessor.assess(
                context: MedicationRiskContext(
                    medicine: medicine,
                    userProfile: userProfile,
                    recentRecords: recentRecords,
                    scanEvent: scanEvent,
                    assessedAt: generatedAt,
                    evidenceCompleteness:
                        medicine.sourceReferences.isEmpty
                        ? .insufficient
                        : .complete
                )
            )
        } else {
            assessment = nil
        }
        let actionCard = actionCardFactory.makeCard(
            resolution: resolutionResult.resolution,
            assessment: assessment,
            generatedAt: generatedAt
        )

        return MedicinePipelineAssessmentResult(
            resolution: resolutionResult.resolution,
            cacheStatus: resolutionResult.cacheStatus,
            sourceDataVersion:
                resolutionResult.sourceDataVersion,
            generatedAt: generatedAt,
            cacheHit: resolutionResult.cacheHit,
            scanEvent: scanEvent,
            assessment: assessment,
            actionCard: actionCard
        )
    }

    private func resolve(
        input: MedicineRecognitionInput,
        generatedAt: Date
    ) async throws -> MedicinePipelineResolutionResult {
        let normalizedName = normalizer.normalize(input)
        let catalog = try catalogLoader.loadCatalog()

        guard !normalizedName.normalizedQuery.isEmpty else {
            let resolution = resolver.resolve(
                input: input,
                normalizedName: normalizedName,
                medicines: catalog.medicines
            )
            return MedicinePipelineResolutionResult(
                resolution: resolution,
                cacheStatus: .miss,
                sourceDataVersion: catalog.sourceDataVersion,
                generatedAt: generatedAt,
                cacheHit: false
            )
        }

        let cacheQuery = cacheKey(for: normalizedName)
        let lookup = try await cache.cachedResolution(
            normalizedQuery: cacheQuery,
            sourceDataVersion: catalog.sourceDataVersion,
            now: generatedAt
        )
        let resolution: MedicineResolution
        if lookup.status == .hit,
           let cachedResolution = lookup.resolution {
            resolution = resolver.resolve(
                input: input,
                normalizedName: normalizedName,
                medicines: medicinesForRevalidation(
                    cachedResolution
                )
            )
        } else {
            resolution = resolver.resolve(
                input: input,
                normalizedName: normalizedName,
                medicines: catalog.medicines
            )
            try await cache.storeResolution(
                resolution,
                normalizedQuery: cacheQuery,
                sourceDataVersion: catalog.sourceDataVersion,
                now: generatedAt
            )
        }

        return MedicinePipelineResolutionResult(
            resolution: resolution,
            cacheStatus: lookup.status,
            sourceDataVersion: catalog.sourceDataVersion,
            generatedAt: generatedAt,
            cacheHit: lookup.status == .hit
        )
    }

    private func medicinesForRevalidation(
        _ cachedResolution: MedicineResolution
    ) -> [Medicine] {
        var medicinesByID = [String: Medicine]()
        for candidate in cachedResolution.candidates {
            medicinesByID[candidate.medicine.id] =
                candidate.medicine
        }
        if let selectedMedicine =
            cachedResolution.selectedMedicine {
            medicinesByID[selectedMedicine.id] = selectedMedicine
        }
        return medicinesByID.values.sorted {
            $0.id < $1.id
        }
    }

    private func cacheKey(
        for normalizedName: NormalizedMedicineName
    ) -> String {
        normalizedName.queryVariants.joined(separator: " || ")
    }

    private func makeScanEvent(
        input: MedicineRecognitionInput,
        resolution: MedicineResolution
    ) -> MedicineScanEvent {
        MedicineScanEvent(
            id: uuidProvider.makeUUID(),
            recognizedText: input.recognizedTexts.joined(
                separator: " "
            ),
            candidateMedicineID:
                resolution.selectedMedicine?.id,
            confidence: normalizedConfidence(
                input.rawConfidence
            ),
            scannedAt: input.capturedAt,
            recognitionStatus: recognitionStatus(
                for: resolution.status
            )
        )
    }

    private func normalizedConfidence(_ value: Double?) -> Double {
        guard let value, value.isFinite else {
            return 0
        }
        return min(1, max(0, value))
    }

    private func recognitionStatus(
        for status: MedicineResolutionStatus
    ) -> RecognitionStatus {
        switch status {
        case .resolved:
            return .recognized
        case .ambiguous, .insufficientEvidence:
            return .uncertain
        case .notFound, .recognitionFailed:
            return .failed
        }
    }
}
