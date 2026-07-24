import Foundation
import SlowWalkDataInterfaces
import SlowWalkDomain
import SlowWalkMedicineKnowledge
import SlowWalkRiskEngine

public struct MedicinePipelineResolutionResult: Sendable, Equatable {
    public let resolution: MedicineResolution
    public let cacheStatus: MedicineResolutionCacheStatus
    public let sourceDataVersion: String
    public let generatedAt: Date
    public let cacheHit: Bool
    public let knowledgeResult: MedicineKnowledgeSearchResult?

    public init(
        resolution: MedicineResolution,
        cacheStatus: MedicineResolutionCacheStatus,
        sourceDataVersion: String,
        generatedAt: Date,
        cacheHit: Bool,
        knowledgeResult: MedicineKnowledgeSearchResult? = nil
    ) {
        self.resolution = resolution
        self.cacheStatus = cacheStatus
        self.sourceDataVersion = sourceDataVersion
        self.generatedAt = generatedAt
        self.cacheHit = cacheHit
        self.knowledgeResult = knowledgeResult
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
    public let healthContextValidation: HealthContextValidation
    public let knowledgeResult: MedicineKnowledgeSearchResult?

    public init(
        resolution: MedicineResolution,
        cacheStatus: MedicineResolutionCacheStatus,
        sourceDataVersion: String,
        generatedAt: Date,
        cacheHit: Bool,
        scanEvent: MedicineScanEvent,
        assessment: RiskAssessment?,
        actionCard: ActionCard,
        healthContextValidation: HealthContextValidation,
        knowledgeResult: MedicineKnowledgeSearchResult? = nil
    ) {
        self.resolution = resolution
        self.cacheStatus = cacheStatus
        self.sourceDataVersion = sourceDataVersion
        self.generatedAt = generatedAt
        self.cacheHit = cacheHit
        self.scanEvent = scanEvent
        self.assessment = assessment
        self.actionCard = actionCard
        self.healthContextValidation = healthContextValidation
        self.knowledgeResult = knowledgeResult
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
    private let contextBuilder: any MedicationRiskContextBuilding
    private let knowledgeSearcher:
        (any MedicineKnowledgeSearching)?

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
        actionCardFactory: ActionCardFactory = ActionCardFactory(),
        contextBuilder: (any MedicationRiskContextBuilding)? = nil,
        knowledgeSearcher:
            (any MedicineKnowledgeSearching)? = nil
    ) {
        self.catalogLoader = catalogLoader
        self.cache = cache
        self.dateProvider = dateProvider
        self.uuidProvider = uuidProvider
        self.normalizer = normalizer
        self.resolver = resolver
        self.riskAssessor = riskAssessor
        self.actionCardFactory = actionCardFactory
        self.contextBuilder = contextBuilder
            ?? MedicationRiskContextBuilder(clock: dateProvider)
        self.knowledgeSearcher = knowledgeSearcher
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
        let preflight = try contextBuilder.validate(
            userProfile: userProfile,
            bodyMetrics: userProfile.bodyMetrics,
            medicationRecords: recentRecords
        )
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
        let healthContextValidation: HealthContextValidation
        if resolutionResult.resolution.status == .resolved,
           let medicine =
            resolutionResult.resolution.selectedMedicine {
            let buildResult = try contextBuilder.build(
                medicine: medicine,
                resolution: resolutionResult.resolution,
                preflight: preflight,
                scanEvent: scanEvent,
                sourceReferences: medicine.sourceReferences
            )
            let baseAssessment = riskAssessor.assess(
                context: buildResult.context
            )
            assessment = applyKnowledgeSafety(
                to: baseAssessment,
                knowledgeResult:
                    resolutionResult.knowledgeResult
            )
            healthContextValidation = addingKnowledgeWarnings(
                to: buildResult.validation,
                knowledgeResult:
                    resolutionResult.knowledgeResult
            )
        } else {
            assessment = nil
            healthContextValidation = preflight.validation
        }
        let actionCard = actionCardFactory.makeCard(
            resolution: resolutionResult.resolution,
            assessment: assessment,
            generatedAt: generatedAt,
            healthContextWarnings:
                healthContextValidation.issues,
            knowledgeWarnings:
                resolutionResult.knowledgeResult?
                    .warnings.map(\.message) ?? [],
            requiresKnowledgeConfirmation:
                resolutionResult.knowledgeResult?
                    .requiresConservativeAction ?? false
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
            actionCard: actionCard,
            healthContextValidation: healthContextValidation,
            knowledgeResult:
                resolutionResult.knowledgeResult
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

        if let knowledgeSearcher {
            let knowledgeResult = try await knowledgeSearcher
                .search(
                    query: MedicineKnowledgeQuery(
                        normalizedQuery:
                            normalizedName.normalizedQuery
                    )
                )
            let resolution = resolver.resolve(
                input: input,
                normalizedName: normalizedName,
                medicines: knowledgeResult.candidates.map(
                    \.medicine
                )
            )
            let governedResolution =
                applyingKnowledgeConfirmation(
                    to: resolution,
                    knowledgeResult: knowledgeResult
                )
            return MedicinePipelineResolutionResult(
                resolution: governedResolution,
                cacheStatus: resolutionCacheStatus(
                    from: knowledgeResult.cacheStatus
                ),
                sourceDataVersion:
                    knowledgeResult.sourceDataVersion,
                generatedAt: generatedAt,
                cacheHit: knowledgeResult.cacheStatus == .hit,
                knowledgeResult: knowledgeResult
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

    private func applyingKnowledgeConfirmation(
        to resolution: MedicineResolution,
        knowledgeResult: MedicineKnowledgeSearchResult
    ) -> MedicineResolution {
        guard resolution.status == .resolved,
            let selectedMedicine = resolution.selectedMedicine
        else {
            return resolution
        }
        let selectedCandidate = knowledgeResult.candidates.first {
            $0.medicine.id == selectedMedicine.id
        }
        let requiresConfirmation =
            knowledgeResult.requiresConservativeAction
            || selectedCandidate?.requiresConfirmation == true
        guard requiresConfirmation else {
            return resolution
        }
        return MedicineResolution(
            status: resolution.status,
            candidates: resolution.candidates,
            selectedMedicine: selectedMedicine,
            evidence: resolution.evidence,
            requiresUserConfirmation: true
        )
    }

    private func resolutionCacheStatus(
        from status: MedicineKnowledgeCacheStatus
    ) -> MedicineResolutionCacheStatus {
        switch status {
        case .hit:
            return .hit
        case .sourceVersionChanged:
            return .sourceVersionChanged
        case .expired, .revalidated, .staleOffline:
            return .expired
        case .miss, .notStored:
            return .miss
        }
    }

    private func applyKnowledgeSafety(
        to assessment: RiskAssessment,
        knowledgeResult: MedicineKnowledgeSearchResult?
    ) -> RiskAssessment {
        guard let knowledgeResult,
            knowledgeResult.requiresConservativeAction
        else {
            return assessment
        }
        let warningCodes = knowledgeResult.warnings
            .map { $0.code.rawValue }
            .sorted()
        let reason = RiskReason(
            code: .knowledgeSourceWarning,
            message:
                "Medicine knowledge requires source review, so a green result is not permitted.",
            evidence: [
                "sourceStatus=\(knowledgeResult.sourceStatus.rawValue)",
                "cacheStatus=\(knowledgeResult.cacheStatus.rawValue)",
                "warnings=\(warningCodes.joined(separator: ","))",
            ]
            .joined(separator: ";"),
            ruleIdentifier: "medicine-knowledge-source-safety"
        )
        var actions = assessment.recommendedActions.filter {
            $0 != .followVerifiedSourceInformation
        }
        actions.append(.reviewMedicineSources)
        actions.append(.consultHealthcareProfessional)
        return RiskAssessment(
            level: max(.yellow, assessment.level),
            reasons: (assessment.reasons + [reason]).sorted {
                $0.ruleIdentifier < $1.ruleIdentifier
            },
            recommendedActions: Array(Set(actions)).sorted {
                $0.rawValue < $1.rawValue
            },
            assessedAt: assessment.assessedAt,
            requiresProfessionalAdvice: true,
            requiresFamilyAttention:
                assessment.requiresFamilyAttention,
            evidenceCompleteness: min(
                assessment.evidenceCompleteness,
                knowledgeResult.isOffline
                    ? .insufficient
                    : .partial
            )
        )
    }

    private func addingKnowledgeWarnings(
        to validation: HealthContextValidation,
        knowledgeResult: MedicineKnowledgeSearchResult?
    ) -> HealthContextValidation {
        guard let knowledgeResult,
            knowledgeResult.requiresConservativeAction
        else {
            return validation
        }
        let knowledgeIssues = knowledgeResult.warnings.map {
            HealthContextValidationIssue(
                code: $0.code.rawValue,
                field: "medicineKnowledge",
                message: $0.message,
                severity: .warning,
                ruleIdentifier:
                    "medicine-knowledge-source-safety"
            )
        }
        var seen = Set<String>()
        let issues = (validation.issues + knowledgeIssues)
            .sorted {
                if $0.code == $1.code {
                    return ($0.field ?? "") < ($1.field ?? "")
                }
                return $0.code < $1.code
            }
            .filter {
                seen.insert(
                    "\($0.code)|\($0.field ?? "")|\($0.message)"
                ).inserted
            }
        return HealthContextValidation(
            status: issues.isEmpty
                ? validation.status
                : .validWithWarnings,
            issues: issues,
            configurationNotices:
                validation.configurationNotices
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
