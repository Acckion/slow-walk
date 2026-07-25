import Foundation
import SlowWalkDomain

public struct LocationActionCardFactory: Sendable {
    public init() {}

    public func makeCard(
        from assessment: LocationAssessment
    ) -> LocationActionCard {
        let content = content(for: assessment)
        let positiveCodes: Set<LocationRiskReasonCode> = [
            .arrivedAtDestination,
            .approachingDestination,
            .progressingTowardDestination,
        ]
        let reasonWarnings = assessment.reasons
            .filter {
                !positiveCodes.contains($0.code)
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
        for assessment: LocationAssessment
    ) -> (
        title: String,
        primaryInstruction: String
    ) {
        let reasonCodes = Set(
            assessment.reasons.map(\.code)
        )

        if assessment.level == .red {
            return (
                "需要位置安全协助",
                "检测到多个独立行为风险，请停在安全位置并联系家属或工作人员。"
            )
        }
        if assessment.level == .orange {
            return (
                "请确认行进方向",
                "检测到行为风险或严重数据质量问题，请停在安全位置重新确认。"
            )
        }
        if reasonCodes.contains(
            .locationAccuracyInsufficient
        ) {
            return (
                "定位精度不足",
                "请停在安全位置，等待更可靠的定位后重新评估。"
            )
        }
        if reasonCodes.contains(
            .locationTrendIndeterminate
        ) || reasonCodes.contains(
            .insufficientLocationHistory
        ) {
            return (
                "行进趋势无法确认",
                "当前样本不足以确认正在接近目的地，请重新定位。"
            )
        }
        if reasonCodes.contains(.arrivedAtDestination) {
            return (
                "已到达目的地范围",
                "请根据现场标识确认最终位置。"
            )
        }
        if reasonCodes.contains(.approachingDestination) {
            return (
                "正在接近目的地",
                "距离持续减小且已接近目的地，请留意现场标识。"
            )
        }
        if reasonCodes.contains(
            .progressingTowardDestination
        ) {
            return (
                "正在向目的地前进",
                "可靠样本显示距离持续减小，请继续留意行进方向。"
            )
        }

        return (
            "请重新确认定位",
            "当前证据不足以确认位置状态，请在安全位置重新定位。"
        )
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
