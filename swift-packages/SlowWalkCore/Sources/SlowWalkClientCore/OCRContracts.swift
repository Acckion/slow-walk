import Foundation
import SlowWalkDomain

/// A normalized, top-left-origin rectangle produced by a platform OCR adapter.
///
/// Coordinates are intentionally plain `Double` values so Vision/CoreGraphics
/// types do not cross the Client Core boundary.
public struct OCRBoundingRegion:
    Codable,
    Sendable,
    Equatable,
    Hashable
{
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(
        x: Double,
        y: Double,
        width: Double,
        height: Double
    ) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

/// Platform-neutral image orientation understood by future Apple adapters.
public enum OCRImageOrientation:
    String,
    Codable,
    Sendable,
    CaseIterable,
    Hashable
{
    case up
    case down
    case left
    case right
    case upMirrored = "up_mirrored"
    case downMirrored = "down_mirrored"
    case leftMirrored = "left_mirrored"
    case rightMirrored = "right_mirrored"
}

/// Image bytes and capture metadata supplied to an OCR adapter.
///
/// The bytes are never retained in a view state or medicine request.
public struct OCRImageInput:
    Codable,
    Sendable,
    Equatable,
    Hashable
{
    public let data: Data
    public let orientation: OCRImageOrientation
    public let capturedAt: Date

    public init(
        data: Data,
        orientation: OCRImageOrientation,
        capturedAt: Date
    ) {
        self.data = data
        self.orientation = orientation
        self.capturedAt = capturedAt
    }
}

/// One raw text observation returned by platform OCR.
public struct RecognizedTextObservation:
    Codable,
    Sendable,
    Equatable,
    Hashable
{
    public let text: String
    public let confidence: Double
    public let boundingRegion: OCRBoundingRegion?
    public let languageCode: String?
    public let observedAt: Date

    public init(
        text: String,
        confidence: Double,
        boundingRegion: OCRBoundingRegion?,
        languageCode: String?,
        observedAt: Date
    ) {
        self.text = text
        self.confidence = confidence
        self.boundingRegion = boundingRegion
        self.languageCode = languageCode
        self.observedAt = observedAt
    }
}

/// Apple/platform adapters implement recognition only.
///
/// Implementations must not resolve medicines, choose candidates, or assess
/// health risk.
public protocol MedicineTextRecognizing: Sendable {
    func recognizeText(
        in input: OCRImageInput
    ) async throws -> [RecognizedTextObservation]
}

/// Explicit handling for observations below the configured confidence floor.
public enum LowConfidenceObservationHandling:
    String,
    Codable,
    Sendable,
    CaseIterable,
    Hashable
{
    case discard
    case retainAsEvidence = "retain_as_evidence"
}

public struct MedicineRecognitionMappingConfiguration:
    Sendable,
    Equatable,
    Hashable
{
    public let minimumConfidence: Double
    public let lowConfidenceHandling:
        LowConfidenceObservationHandling

    public init(
        minimumConfidence: Double,
        lowConfidenceHandling:
            LowConfidenceObservationHandling
    ) throws {
        guard minimumConfidence.isFinite,
              (0 ... 1).contains(minimumConfidence)
        else {
            throw ClientCoreConfigurationError
                .invalidConfidenceThreshold
        }
        self.minimumConfidence = minimumConfidence
        self.lowConfidenceHandling = lowConfidenceHandling
    }
}

/// Deterministic, side-effect-free OCR observation mapper.
public struct MedicineRecognitionInputMapper: Sendable {
    public let configuration:
        MedicineRecognitionMappingConfiguration

    public init(
        configuration:
            MedicineRecognitionMappingConfiguration
    ) {
        self.configuration = configuration
    }

    public func map(
        observations: [RecognizedTextObservation],
        capturedAt: Date
    ) -> MedicineRecognitionInput {
        let mapped = observations.compactMap {
            observation -> MappedObservation? in
            let text = observation.text.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            guard !text.isEmpty else {
                return nil
            }

            let confidence = Self.normalizedConfidence(
                observation.confidence
            )
            if configuration.lowConfidenceHandling == .discard,
               confidence < configuration.minimumConfidence
            {
                return nil
            }

            return MappedObservation(
                observation: observation,
                trimmedText: text,
                normalizedConfidence: confidence
            )
        }
        .sorted(by: Self.isOrderedBefore)

        let rawConfidence: Double?
        if mapped.isEmpty {
            rawConfidence = nil
        } else {
            rawConfidence = mapped.reduce(0) {
                $0 + $1.normalizedConfidence
            } / Double(mapped.count)
        }

        let languageCode = mapped.lazy
            .compactMap {
                $0.observation.languageCode?
                    .trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
            }
            .first(where: { !$0.isEmpty })

        return MedicineRecognitionInput(
            recognizedTexts: mapped.map(\.trimmedText),
            capturedAt: capturedAt,
            languageCode: languageCode,
            rawConfidence: rawConfidence
        )
    }

    private static func normalizedConfidence(
        _ confidence: Double
    ) -> Double {
        guard confidence.isFinite else {
            return 0
        }
        return min(max(confidence, 0), 1)
    }

    private static func isOrderedBefore(
        _ lhs: MappedObservation,
        _ rhs: MappedObservation
    ) -> Bool {
        switch (
            lhs.observation.boundingRegion,
            rhs.observation.boundingRegion
        ) {
        case let (left?, right?):
            for (leftValue, rightValue) in [
                (left.y, right.y),
                (left.x, right.x),
                (left.height, right.height),
                (left.width, right.width),
            ] {
                let comparison = compare(
                    leftValue,
                    rightValue
                )
                if comparison != 0 {
                    return comparison < 0
                }
            }
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        case (nil, nil):
            break
        }

        if lhs.observation.observedAt
            != rhs.observation.observedAt
        {
            return lhs.observation.observedAt
                < rhs.observation.observedAt
        }
        if lhs.trimmedText != rhs.trimmedText {
            return lhs.trimmedText < rhs.trimmedText
        }
        let leftLanguage =
            lhs.observation.languageCode ?? ""
        let rightLanguage =
            rhs.observation.languageCode ?? ""
        if leftLanguage != rightLanguage {
            return leftLanguage < rightLanguage
        }
        return compare(
            lhs.normalizedConfidence,
            rhs.normalizedConfidence
        ) < 0
    }

    private static func compare(
        _ lhs: Double,
        _ rhs: Double
    ) -> Int {
        if lhs == rhs {
            return 0
        }
        if lhs.isNaN || rhs.isNaN {
            if lhs.bitPattern == rhs.bitPattern {
                return 0
            }
            return lhs.bitPattern < rhs.bitPattern ? -1 : 1
        }
        return lhs < rhs ? -1 : 1
    }
}

private struct MappedObservation: Sendable {
    let observation: RecognizedTextObservation
    let trimmedText: String
    let normalizedConfidence: Double
}
