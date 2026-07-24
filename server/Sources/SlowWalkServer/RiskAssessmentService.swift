import SlowWalkAPIContracts
import SlowWalkDataInterfaces
import SlowWalkDomain
import SlowWalkRiskEngine

/// Application service that maps the transport DTO to the deterministic core engine.
public struct RiskAssessmentService: Sendable {
    private let engine: any RiskAssessing
    private let dateProvider: any DateProviding

    public init(
        engine: any RiskAssessing = MedicationRiskEngine(),
        dateProvider: any DateProviding = SystemDateProvider()
    ) {
        self.engine = engine
        self.dateProvider = dateProvider
    }

    public func assess(
        request: RiskAssessmentRequestDTO
    ) -> RiskAssessmentResponseDTO {
        let now = dateProvider.now()
        let context = MedicationRiskContext(
            medicine: request.medicine,
            userProfile: request.userProfile,
            recentRecords: request.recentRecords,
            scanEvent: request.scanEvent,
            assessedAt: now,
            evidenceCompleteness: evidenceCompleteness(for: request)
        )
        let assessment = engine.assess(context: context)

        return RiskAssessmentResponseDTO(
            requestID: request.requestID,
            assessment: assessment,
            sourceReferences: request.medicine.sourceReferences,
            generatedAt: now,
            apiVersion: SlowWalkAPI.version
        )
    }

    private func evidenceCompleteness(
        for request: RiskAssessmentRequestDTO
    ) -> EvidenceCompleteness {
        request.medicine.sourceReferences.isEmpty ? .insufficient : .complete
    }
}
