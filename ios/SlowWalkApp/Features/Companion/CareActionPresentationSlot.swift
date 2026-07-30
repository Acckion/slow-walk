import SlowWalkAPIContracts
import SlowWalkClientCore
import SlowWalkDomain
import SwiftUI

/// Thin renderer for the canonical ActionCard returned by ClientCore.
///
/// Once the presentation package lands, this adapter can delegate directly to
/// its `MedicineActionCardView`. It deliberately owns no risk rules or parallel
/// medicine state.
struct CareActionPresentationSlot: View {
    let presentation: MedicineAssessmentPresentation

    private var card: SlowWalkDomain.ActionCard {
        presentation.response.actionCard
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(
                riskLabel,
                systemImage: Self.riskSystemImage(
                    for: presentation.risk.attention
                )
            )
            .font(.headline)

            Text(card.title)
                .font(.title3)
                .fontWeight(.semibold)

            Text(card.primaryInstruction)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)

            if !card.recommendedActions.isEmpty {
                Divider()
                Text("建议下一步")
                    .font(.headline)
                ForEach(card.recommendedActions, id: \.self) { action in
                    Label(action.slowWalkDisplayTitle, systemImage: "arrow.right.circle")
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if !card.warnings.isEmpty {
                Divider()
                Text("需要留意")
                    .font(.headline)
                ForEach(card.warnings, id: \.self) { warning in
                    Label(warning, systemImage: "exclamationmark.triangle")
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if !card.sourceReferences.isEmpty {
                Divider()
                Text("信息来源")
                    .font(.headline)
                ForEach(card.sourceReferences, id: \.self) { source in
                    Text("\(source.sourceName)：\(source.documentTitle)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Text(CompanionCopy.demoDataNotice)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.separator, lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
    }

    private var riskLabel: String {
        switch presentation.risk.attention {
        case .routine:
            "风险提示：常规查看"
        case .reviewRequired:
            "风险提示：需要复核"
        case .urgentAttention:
            "风险提示：尽快关注"
        case .immediateAttention:
            "风险提示：立即关注"
        }
    }

    static func riskSystemImage(
        for attention: RiskAttentionSemantics
    ) -> String {
        switch attention {
        case .routine:
            "checkmark.shield.fill"
        case .reviewRequired:
            "exclamationmark.triangle"
        case .urgentAttention:
            "exclamationmark.triangle.fill"
        case .immediateAttention:
            "exclamationmark.octagon.fill"
        }
    }
}

extension RecommendedAction {
    fileprivate var slowWalkDisplayTitle: String {
        switch self {
        case .followVerifiedSourceInformation:
            "按照已核验的信息查看"
        case .consultHealthcareProfessional:
            "咨询医生或药师"
        case .notifyFamilyMember:
            "联系家属共同确认"
        case .reviewMedicineSources:
            "核对药品信息来源"
        case .updateHealthProfile:
            "补充健康资料"
        case .retakeMedicinePhoto:
            "重新读取药盒信息"
        case .doNotTakeUntilMedicineConfirmed:
            "确认药品前先不要服用"
        case .reviewMedicationHistory:
            "核对既往用药记录"
        case .remeasureBodyMetrics:
            "重新测量身体指标"
        }
    }
}
