import Foundation

public struct LocationActionCardFactory: Sendable {
    public init() {}

    public func makeCard(
        from assessment: LocationAssessment
    ) -> LocationActionCard {
        let content = content(for: assessment.level)
        let reasonWarnings = assessment.reasons
            .filter {
                $0.code != .arrivedAtDestination
                    && $0.code
                    != .progressingTowardDestination
            }
            .map(\.message)
        let warnings = unique(
            LocationRiskConfiguration.notices
                + [
                    "This demo does not provide formal map navigation or an absolute location-safety guarantee.",
                ]
                + reasonWarnings
        )
        let distanceText = assessment
            .distanceToDestinationMeters
            .map {
                "\(Int(max($0, 0).rounded())) m"
            }

        return LocationActionCard(
            title: content.title,
            primaryInstruction:
                content.primaryInstruction,
            warnings: warnings,
            recommendedActions:
                assessment.recommendedActions,
            riskLevel: assessment.level,
            distanceText: distanceText,
            generatedAt: assessment.assessedAt
        )
    }

    private func content(
        for level: LocationRiskLevel
    ) -> (
        title: String,
        primaryInstruction: String
    ) {
        switch level {
        case .green:
            return (
                "已接近或到达目的地",
                "请根据现场标识确认位置。"
            )
        case .yellow:
            return (
                "请重新确认定位",
                "定位信号较弱，请停在安全位置重新确认。"
            )
        case .orange:
            return (
                "请确认行进方向",
                "您似乎长时间停留或持续远离目的地，请确认方向。"
            )
        case .red:
            return (
                "需要位置安全协助",
                "当前出现多项高风险位置异常，建议联系家属或工作人员。"
            )
        }
    }

    private func unique(
        _ values: [String]
    ) -> [String] {
        var seen = Set<String>()
        return values.filter {
            seen.insert($0).inserted
        }
    }
}
