import Foundation
import SlowWalkDomain

/// Complete, immutable input to a deterministic medication-risk assessment.
///
/// `assessedAt` is supplied by the application clock. Keeping time in the
/// input makes the engine deterministic and prevents hidden `Date()` calls.
public struct MedicationRiskContext: Sendable, Equatable, Hashable {
    public let medicine: Medicine
    public let userProfile: UserHealthProfile
    public let recentRecords: [MedicationRecord]
    public let scanEvent: MedicineScanEvent
    public let assessedAt: Date
    public let evidenceCompleteness: EvidenceCompleteness

    public init(
        medicine: Medicine,
        userProfile: UserHealthProfile,
        recentRecords: [MedicationRecord],
        scanEvent: MedicineScanEvent,
        assessedAt: Date,
        evidenceCompleteness: EvidenceCompleteness
    ) {
        self.medicine = medicine
        self.userProfile = userProfile
        self.recentRecords = recentRecords
        self.scanEvent = scanEvent
        self.assessedAt = assessedAt
        self.evidenceCompleteness = evidenceCompleteness
    }
}
