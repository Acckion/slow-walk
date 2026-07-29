import SwiftUI

/// Today answers one question first: what needs doing now.
struct TodayView: View {
    @Environment(AppEnvironment.self) private var environment

    /// Moves the app to the Companion tab, either after Today has started a new
    /// session or to return to one already underway.
    let onStartCompanion: () -> Void

    private var plan: TodayPlan { environment.plan }

    private var summary: TodayStatusSummary {
        TodayStatusSummary(state: environment.companion.state)
    }

    /// Once a session has finished, the plan's opening line would contradict
    /// the current status, so the finished state wins.
    private var mostImportantText: String {
        summary.hasFinishedSession ? summary.situation : plan.mostImportantThing
    }

    var body: some View {
        List {
            Section {
                DemoDataBanner()
                    .slowWalkReadableContent()
            }

            Section {
                Label {
                    Text("今天我陪您一起完成。")
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "sun.max")
                        .foregroundStyle(.tint)
                }
                .slowWalkReadableContent()
            } header: {
                Text("您好，\(plan.preferredName)")
                    .accessibilityAddTraits(.isHeader)
            }

            Section("现在最重要的事") {
                Label {
                    Text(mostImportantText)
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "flag.fill")
                        .foregroundStyle(.tint)
                }
                .slowWalkReadableContent()

                if summary.isSessionUnderway || summary.hasFinishedSession {
                    LabeledContent("当前步骤", value: summary.stepLabel)
                        .slowWalkReadableContent()

                    Label(summary.situation, systemImage: "info.circle")
                        .fixedSize(horizontal: false, vertical: true)
                        .slowWalkReadableContent()

                    Label(summary.nextStep, systemImage: "arrow.forward.circle")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .slowWalkReadableContent()
                }

                Button(action: startOrContinueCompanion) {
                    Label(summary.primaryActionTitle, systemImage: "figure.walk")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityHint("进入陪伴流程，逐步完成今天的安排。")
                .slowWalkReadableContent()
            }

            Section("今天的安排") {
                medicineSchedule

                if let outing = plan.outing {
                    outingRow(outing)
                }
            }

            Section("安全提醒") {
                NotADiagnosisNotice()
                    .slowWalkReadableContent()
            }
        }
        .listStyle(.insetGrouped)
    }

    /// A session underway is only navigated to, since starting is refused from
    /// every active step. Otherwise the tab changes only if one really started.
    private func startOrContinueCompanion() {
        if summary.isSessionUnderway {
            onStartCompanion()
            return
        }
        guard environment.companion.startCompanion() else { return }
        onStartCompanion()
    }

    // MARK: - Today's schedule

    @ViewBuilder
    private var medicineSchedule: some View {
        if plan.medicines.isEmpty {
            Label("今天没有需要记录的用药。", systemImage: "checkmark.circle")
                .foregroundStyle(.secondary)
                .slowWalkReadableContent()
        } else {
            ForEach(plan.medicines) { medicine in
                medicineRow(medicine)
            }
        }
    }

    private func medicineRow(_ medicine: TodayMedicineItem) -> some View {
        LabeledContent {
            Label(
                medicine.isTakenToday ? "已完成" : "待完成",
                systemImage: medicine.isTakenToday ? "checkmark.circle.fill" : "circle"
            )
            .foregroundStyle(.secondary)
        } label: {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(medicine.displayName)
                        .fontWeight(.semibold)
                    Text(medicine.timeOfDayDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "pills")
                    .foregroundStyle(.tint)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(medicine.displayName)，\(medicine.timeOfDayDescription)，"
                + (medicine.isTakenToday ? "已完成" : "待完成")
        )
        .slowWalkReadableContent()
    }

    private func outingRow(_ outing: TodayOutingItem) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(outing.title)
                    .fontWeight(.semibold)
                Text("\(outing.timeDescription) · \(outing.placeDescription)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } icon: {
            Image(systemName: "calendar.badge.clock")
                .foregroundStyle(.tint)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "复诊或外出：\(outing.title)，\(outing.timeDescription)，\(outing.placeDescription)"
        )
        .slowWalkReadableContent()
    }
}

#Preview {
    NavigationStack {
        TodayView(onStartCompanion: {})
            .navigationTitle("今天")
    }
    .environment(AppEnvironment.preview())
}
