import Foundation

/// Four-level reminder severity used throughout the client, server, and API contract.
public enum RiskLevel: String, Codable, Sendable, CaseIterable, Hashable, Comparable {
    case green
    case yellow
    case orange
    case red

    public static func < (lhs: RiskLevel, rhs: RiskLevel) -> Bool {
        lhs.severityRank < rhs.severityRank
    }

    private var severityRank: Int {
        switch self {
        case .green:
            0
        case .yellow:
            1
        case .orange:
            2
        case .red:
            3
        }
    }
}
