import SlowWalkClientCore
import SlowWalkDomain
import SwiftUI

/// The medicine assessment page.
///
/// It renders exactly one canonical `MedicineDisplayState`. Notably absent:
/// no `dynamicTypeSize` clamp anywhere, so Accessibility text sizes work; and
/// no `accessibilityElement(children: .combine)` on any container that holds
/// the retry or confirm Button.
public struct MedicineAssessmentView: View {
    private let state: MedicineDisplayState
    private let retryAction: (() -> Void)?
    private let confirmAction: (() -> Void)?

    public init(
        state: MedicineDisplayState,
        retryAction: (() -> Void)? = nil,
        confirmAction: (() -> Void)? = nil
    ) {
        self.state = state
        self.retryAction = retryAction
        self.confirmAction = confirmAction
    }

    public var body: some View {
        Form {
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        switch state.variant {
        case .idle:
            lifecycleSection(
                MedicinePresentationCopy.idleText,
                systemImage: "hourglass"
            )

        case .recognizing:
            progressSection(
                MedicinePresentationCopy.recognizingText
            )

        case .assessing:
            progressSection(
                MedicinePresentationCopy.assessingText
            )

        case .cancelled:
            lifecycleSection(
                MedicinePresentationCopy.cancelledText,
                systemImage: "xmark.circle"
            )

        case .timeout, .failed:
            failureContent

        case .normal,
             .ambiguous,
             .healthWarning,
             .knowledgeWarning,
             .redRisk,
             .elevatedRisk:
            resultContent
        }
    }

    // MARK: - Result

    @ViewBuilder
    private var resultContent: some View {
        if let actionCard = state.actionCard {
            MedicineActionCardView(
                actionCard: actionCard,
                requiresMedicineConfirmation:
                    state.requiresMedicineConfirmation,
                demoDisclaimer: state.demoDisclaimer,
                confirmAction: confirmAction
            )
        } else {
            // A confirmation can be required with no response at all. The page
            // must not fabricate a card, a level, or an instruction.
            Section {
                Label {
                    Text(
                        MedicinePresentationCopy
                            .confirmationRequiredHeading
                    )
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "questionmark.circle")
                        .accessibilityHidden(true)
                }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)

                Text(
                    MedicinePresentationCopy
                        .noResultAvailableText
                )
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            if let confirmAction {
                Section {
                    Button(action: confirmAction) {
                        Label(
                            MedicinePresentationCopy
                                .confirmMedicineButtonTitle,
                            systemImage: "checkmark.circle"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .medicineMinimumHitTarget()
                    .accessibilityHint(
                        MedicinePresentationCopy
                            .confirmMedicineAccessibilityHint
                    )
                }
            }
        }
    }

    // MARK: - Failure

    @ViewBuilder
    private var failureContent: some View {
        Section {
            // Text siblings each stay their own element; the Button below is
            // never merged into them.
            if let failure = state.failure {
                Label {
                    Text(
                        MedicinePresentationCopy
                            .failureName(
                                failure.failure.kind
                            )
                    )
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .accessibilityHidden(true)
                }
                .accessibilityElement(children: .combine)
            }

            Text(
                MedicinePresentationCopy
                    .noResultAvailableText
            )
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }

        if state.failure?.allowsRetry == true,
           let retryAction
        {
            Section {
                Button(action: retryAction) {
                    Label(
                        MedicinePresentationCopy.retryButtonTitle,
                        systemImage: "arrow.clockwise"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .medicineMinimumHitTarget()
                .accessibilityHint(
                    MedicinePresentationCopy
                        .retryAccessibilityHint
                )
            }
        }
    }

    // MARK: - Support

    private func lifecycleSection(
        _ text: String,
        systemImage: String
    ) -> some View {
        Section {
            Label {
                Text(text)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: systemImage)
                    .accessibilityHidden(true)
            }
            .accessibilityElement(children: .combine)
        }
    }

    private func progressSection(
        _ text: String
    ) -> some View {
        Section {
            HStack(spacing: 12) {
                ProgressView()
                    .accessibilityHidden(true)

                Text(text)
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(text)
        }
    }
}
