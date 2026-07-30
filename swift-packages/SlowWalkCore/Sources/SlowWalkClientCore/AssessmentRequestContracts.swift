import Foundation
import SlowWalkAPIContracts
import SlowWalkDomain

public protocol MedicineAssessmentRequesting: Sendable {
    func assess(
        request: MedicineAssessmentRequestDTO
    ) async throws -> MedicineAssessmentResponseDTO
}

/// Confirms one candidate from the immediately preceding assessment.
///
/// The command carries only stable identity. A conforming use case must keep
/// the original resolution context and reject IDs that were not offered; the
/// selected display name must never be submitted as replacement OCR text.
public struct MedicineCandidateConfirmationCommand:
    Sendable,
    Equatable,
    Hashable
{
    public let originalRequestID: UUID
    public let candidateID: String

    public init(originalRequestID: UUID, candidateID: String) {
        self.originalRequestID = originalRequestID
        self.candidateID = candidateID
    }
}

public protocol MedicineCandidateConfirming: Sendable {
    func confirmMedicine(
        command: MedicineCandidateConfirmationCommand
    ) async throws -> MedicineAssessmentResponseDTO
}

public protocol LocationAssessmentRequesting: Sendable {
    func assess(
        request: LocationAssessmentRequestDTO
    ) async throws -> LocationAssessmentResponseDTO
}

public protocol MedicineAssessmentRequestBuilding:
    Sendable
{
    func makeRequest(
        input: MedicineRecognitionInput,
        userProfile: UserHealthProfileDTO,
        recentRecords: [MedicationRecordDTO],
        requestID: UUID,
        apiVersion: String
    ) -> MedicineAssessmentRequestDTO
}

public struct MedicineAssessmentRequestBuilder:
    MedicineAssessmentRequestBuilding,
    Sendable
{
    public init() {}

    public func makeRequest(
        input: MedicineRecognitionInput,
        userProfile: UserHealthProfileDTO,
        recentRecords: [MedicationRecordDTO],
        requestID: UUID,
        apiVersion: String
    ) -> MedicineAssessmentRequestDTO {
        MedicineAssessmentRequestDTO(
            input: input,
            userProfile: userProfile,
            recentRecords: recentRecords,
            requestID: requestID,
            apiVersion: apiVersion
        )
    }
}
