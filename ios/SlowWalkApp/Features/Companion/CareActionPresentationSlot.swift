import SwiftUI

/// Reserved position for the real medicine action card.
///
/// The formal `MedicineActionCard` is owned by `SlowWalkPresentation` and is
/// being built separately. This slot exists so the companion flow can reach the
/// step that shows a care action without this module inventing a second,
/// competing version of it.
///
/// Deliberately absent, and to remain absent, so the two do not diverge:
/// - risk levels, severity semantics, and any colour mapping
/// - warnings, dosage, and source references
/// - medicine wording drawn from a knowledge source
///
/// When `SlowWalkPresentation` is added to the app target, replace the body of
/// this view with the real card and pass it the confirmed medicine plus the
/// assessment response. Nothing else in the flow should need to change.
struct CareActionPresentationSlot: View {
    let confirmedMedicine: ConfirmedMedicine

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("用药提示占位", systemImage: "rectangle.dashed")
                .font(.headline)
                .foregroundStyle(.primary)

            Text("已确认：\(confirmedMedicine.candidate.displayName)")
                .font(.title3)
                .fontWeight(.semibold)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            Text("正式的用药提示卡由 SlowWalkPresentation 提供，本阶段尚未接入。")
                .font(.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Text("这里不显示风险等级、剂量或用药结论。")
                .font(.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(CompanionCopy.demoDataNotice)
                    Text("演示数据，不用于临床用途")
                }
                .font(.callout)
                .fontWeight(.semibold)
                .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
            }
            .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            Color(uiColor: .secondarySystemBackground),
            in: RoundedRectangle(cornerRadius: SlowWalkLayout.cornerRadius)
        )
        .overlay {
            RoundedRectangle(cornerRadius: SlowWalkLayout.cornerRadius)
                .strokeBorder(
                    .separator,
                    style: StrokeStyle(lineWidth: 1, dash: [6, 4])
                )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            """
            用药提示占位。已确认 \(confirmedMedicine.candidate.displayName)。
            正式提示卡尚未接入，此处不显示风险等级、剂量或用药结论。
            演示数据，不用于临床用途。
            """
        )
    }
}

#Preview {
    CareActionPresentationSlot(
        confirmedMedicine: ConfirmedMedicine(
            candidate: MedicineCandidate.demoCandidates[0],
            origin: .readFromPhoto
        )
    )
    .padding()
}

#Preview("Dark AX5") {
    CareActionPresentationSlot(
        confirmedMedicine: ConfirmedMedicine(
            candidate: MedicineCandidate.demoCandidates[0],
            origin: .readFromPhoto
        )
    )
    .padding()
    .preferredColorScheme(.dark)
    .dynamicTypeSize(.accessibility5)
}
