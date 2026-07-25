import Foundation

/// Invalid cross-platform client configuration.
///
/// These failures are deterministic programmer/configuration errors. They do
/// not contain OCR text, health data, or location samples.
public enum ClientCoreConfigurationError:
    Error,
    Sendable,
    Equatable
{
    case invalidConfidenceThreshold
    case invalidMaximumSampleCount
    case invalidMaximumSampleAge
    case invalidMinimumSampleCount
}
