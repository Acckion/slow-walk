import Foundation
import SlowWalkAPIContracts
import SlowWalkDomain

public protocol MedicineAssessmentRequesting: Sendable {
    func assess(
        request: MedicineAssessmentRequestDTO
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
