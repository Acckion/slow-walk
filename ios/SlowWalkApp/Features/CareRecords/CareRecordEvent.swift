import Foundation

/// What happened during a companion session, in the order it happened.
///
/// Records describe the process of accompanying someone. They deliberately
/// carry no risk level and no medicine conclusion.
enum CareRecordEventKind: Equatable, Hashable {
    case dayPlanItemStarted(title: String)
    case medicineAssessmentStarted
    /// Candidate identity stays in the short-lived coordinator context. The
    /// timeline records only how many choices were shown.
    case medicineAssessmentNeedsConfirmation(candidateCount: Int)
    case medicineAssessmentRequiresSourceReview
    case medicineConfirmed(medicineName: String)
    /// A care action was actually shown to the person.
    ///
    /// This may only be written by something that presented a real assessment
    /// result. It must never be written on the strength of a confirmed medicine
    /// name: that put a claim in the timeline that nothing had produced.
    case careActionShown(medicineName: String)
    case medicineAssessmentFailed(isRecoverable: Bool)
    case companionFinished(CompanionCompletion)
}

/// One recorded event, held in memory for the demo flow only.
///
/// This is not a persistence format. A versioned schema has to exist before
/// this type or `CareRecordEventKind` gains `Codable` or a SwiftData model,
/// and migration, privacy, retention and deletion settled along with it.
struct CareRecordEvent: Identifiable, Equatable, Hashable {
    let id: UUID
    let occurredAt: Date
    let kind: CareRecordEventKind

    init(id: UUID, occurredAt: Date, kind: CareRecordEventKind) {
        self.id = id
        self.occurredAt = occurredAt
        self.kind = kind
    }
}
