import SlowWalkAPIContracts
import SlowWalkClientCore
import SlowWalkDomain
import SwiftUI

struct CompanionView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.scenePhase) private var scenePhase
    @AccessibilityFocusState private var stepHasAccessibilityFocus: Bool
    @State private var isShowingEndConfirmation = false

    private var session: CompanionSessionModel { environment.companion }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                DemoDataBanner()
                CapabilityDisclosureView(catalog: session.capabilities)
                stepHeader
                    .accessibilityFocused($stepHasAccessibilityFocus)
                stepControls
                if session.canEndEarly {
                    endEarlyButton
                }
                NotADiagnosisNotice()
            }
            .padding()
        }
        .onChange(of: session.medicineState) {
            stepHasAccessibilityFocus = true
        }
        .onChange(of: scenePhase) {
            guard scenePhase != .active else { return }
            session.cancelPendingMedicineAssessment()
        }
        .alert("结束这次陪伴？", isPresented: $isShowingEndConfirmation) {
            Button("继续陪伴", role: .cancel) {}
            Button("结束陪伴", role: .destructive) {
                session.endEarly()
            }
        } message: {
            Text("当前进度会结束，并写入一条仅保存在内存中的记录。")
        }
    }

    private var stepHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(session.stepLabel)
                .font(.title2)
                .fontWeight(.semibold)
                .accessibilityAddTraits(.isHeader)

            Text(session.situation)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)

            Text(session.nextStep)
                .font(.body)
                .fontWeight(.medium)
                .fixedSize(horizontal: false, vertical: true)

            if let reason = session.reason {
                Text(reason)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            [session.stepLabel, session.situation, session.nextStep, session.reason]
                .compactMap(\.self)
                .joined(separator: " ")
        )
    }

    @ViewBuilder
    private var stepControls: some View {
        switch session.state {
        case .notStarted:
            primaryButton(CompanionCopy.startCompanionTitle) {
                session.startCompanion()
            }

        case .preDepartureCheck:
            primaryButton(CompanionCopy.beginMedicineAssessmentTitle) {
                session.beginMedicineAssessment()
            }

        case .medicineAssessment:
            medicineControls

        case .travelling:
            primaryButton(CompanionCopy.approachStopTitle) {
                session.approachStop()
            }

        case .approachingStop:
            primaryButton(CompanionCopy.arriveSafelyTitle) {
                session.arriveSafely()
            }

        case .completed:
            completedControls
        }
    }

    @ViewBuilder
    private var medicineControls: some View {
        switch session.medicineState {
        case .idle, .recognizing, .assessing:
            ProgressView("正在进行设备内演示评估")
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel("正在进行设备内演示评估，请稍等。")

        case .requiresMedicineConfirmation(let requirement):
            confirmationControls(requirement)

        case .result(let presentation):
            VStack(alignment: .leading, spacing: 16) {
                assessmentEvidence(presentation)
                CareActionPresentationSlot(presentation: presentation)
                primaryButton(
                    environment.plan.outing == nil
                        ? CompanionCopy.acknowledgeCareActionTitle
                        : CompanionCopy.continueToOutingTitle
                ) {
                    session.acknowledgeCareAction()
                }
            }

        case .failed(let failure):
            if failure.isRecoverable {
                primaryButton(CompanionCopy.retryMedicineAssessmentTitle) {
                    session.retryMedicineAssessment()
                }
            }

        case .cancelled:
            primaryButton(CompanionCopy.retryMedicineAssessmentTitle) {
                session.retryMedicineAssessment()
            }
        }
    }

    private func assessmentEvidence(
        _ presentation: MedicineAssessmentPresentation
    ) -> some View {
        let completeness = presentation.response.assessment?.evidenceCompleteness
        return Label {
            VStack(alignment: .leading, spacing: 4) {
                Text("评估资料：固定合成演示档案")
                if let completeness {
                    Text("证据完整度：\(evidenceCompletenessLabel(completeness))")
                        .foregroundStyle(.secondary)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "person.text.rectangle")
                .accessibilityHidden(true)
        }
        .font(.subheadline)
        .accessibilityElement(children: .combine)
    }

    private func evidenceCompletenessLabel(
        _ completeness: EvidenceCompleteness
    ) -> String {
        switch completeness {
        case .complete:
            "完整"
        case .partial:
            "部分"
        case .insufficient:
            "不足"
        }
    }

    @ViewBuilder
    private func confirmationControls(
        _ requirement: MedicineConfirmationRequirement
    ) -> some View {
        switch requirement.reason {
        case .serverRequiresConfirmation:
            VStack(alignment: .leading, spacing: 16) {
                if let response = requirement.response {
                    let presentation = MedicineAssessmentPresentation(
                        response: response
                    )
                    assessmentEvidence(presentation)
                    CareActionPresentationSlot(presentation: presentation)
                }
                Text("信息来源或证据仍需复核，不能仅通过选择药名解除这项提示。")
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
                secondaryButton(CompanionCopy.retryMedicineAssessmentTitle) {
                    session.retryMedicineAssessment()
                }
            }

        case .ambiguousMedicine, .unresolvedMedicine:
            let candidates = requirement.response?.resolution.candidates ?? []
            VStack(alignment: .leading, spacing: 12) {
                ForEach(candidates, id: \.medicine.id) { candidate in
                    Button {
                        session.confirmMedicine(candidate)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(candidate.medicine.canonicalName)
                                .font(.title3)
                            if let alias = candidate.matchedAlias {
                                Text("匹配文字：\(alias)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityHint("确认本次设备内解析给出的候选药名。")
                }

                secondaryButton(CompanionCopy.retryMedicineAssessmentTitle) {
                    session.retryMedicineAssessment()
                }
            }

        case .noRecognizedText:
            primaryButton(CompanionCopy.retryMedicineAssessmentTitle) {
                session.retryMedicineAssessment()
            }
        }
    }

    private var completedControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("这次陪伴的过程记录已保存在本次运行的内存中。")
                .font(.body)
            secondaryButton(CompanionCopy.startCompanionTitle) {
                session.startCompanion()
            }
        }
    }

    private var endEarlyButton: some View {
        Button(CompanionCopy.endEarlyTitle) {
            isShowingEndConfirmation = true
        }
        .font(.body)
        .padding(.vertical, 12)
        .frame(minWidth: 44, minHeight: 44, alignment: .leading)
        .accessibilityHint("打开确认对话框。")
    }

    private func primaryButton(
        _ title: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .accessibilityLabel(title)
    }

    private func secondaryButton(
        _ title: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.body)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(title)
    }
}

#Preview {
    NavigationStack {
        CompanionView()
            .navigationTitle("陪伴")
    }
    .environment(AppEnvironment.preview())
}
