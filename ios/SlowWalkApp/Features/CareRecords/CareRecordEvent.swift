import Foundation

/// What happened during a companion session, in the order it happened.
///
/// Records describe the process of accompanying someone. They deliberately
/// carry no risk level and no medicine conclusion.
enum CareRecordEventKind: Equatable, Hashable {
    case dayPlanItemStarted(title: String)
    case medicineReadStarted(attemptNumber: Int)
    case medicineReadDidNotSucceed(MedicineReadSetback)
    /// A read that produced candidates. The count is recorded, never a
    /// conclusion about which medicine it is.
    case medicineReadFoundCandidates(candidateCount: Int)
    case medicineConfirmed(medicineName: String, origin: MedicineChoiceOrigin)
    case careActionShown(medicineName: String)
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
