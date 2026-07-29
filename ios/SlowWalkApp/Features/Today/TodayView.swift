import SwiftUI

/// Today answers one question first: what needs doing now.
///
/// The page deliberately keeps one prominent focus panel and one primary
/// action. Medicines and outings remain supporting information beneath it.
struct TodayView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Moves the app to the Companion tab, either after Today has started a new
    /// session or to return to one already underway.
    let onStartCompanion: () -> Void

    private var plan: TodayPlan { environment.plan }

    private var summary: TodayStatusSummary {
        TodayStatusSummary(state: environment.companion.state)
    }

    /// The headline. Once a session has finished, the plan's opening line would
    /// contradict the status below it, so the finished state wins.
    private var mostImportantText: String {
        summary.hasFinishedSession ? summary.situation : plan.mostImportantThing
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                DemoDataBanner()
                greeting
                focusSection
                scheduleSection
                NotADiagnosisNotice()
            }
            .slowWalkReadableContent()
            .padding()
        }
    }

    // MARK: - Focus

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 4) {
            // The name is configurable and never invented; no family role is
            // assumed anywhere in the greeting.
            Text("您好，\(plan.preferredName)")
                .font(.title2)
                .fontWeight(.semibold)
                .accessibilityAddTraits(.isHeader)
            Text("今天我陪您一起完成。")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var focusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            focusPanel

            SlowWalkPrimaryActionButton(
                title: summary.primaryActionTitle,
                systemImage: "figure.walk",
                accessibilityHint: "进入陪伴流程，逐步完成今天的安排。",
                action: startOrContinueCompanion
            )
        }
    }

    private var focusPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("现在最重要的事", systemImage: "sun.max.fill")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            Text(mostImportantText)
                .font(.title3)
                .fontWeight(.semibold)
                .fixedSize(horizontal: false, vertical: true)

            if summary.isSessionUnderway || summary.hasFinishedSession {
                Divider()
                currentStatus
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            Color(uiColor: .secondarySystemGroupedBackground),
            in: RoundedRectangle(
                cornerRadius: SlowWalkLayout.cornerRadius,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: SlowWalkLayout.cornerRadius,
                style: .continuous
            )
            .stroke(Color(uiColor: .separator), lineWidth: 1)
        }
    }

    private var currentStatus: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("当前陪伴状态")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            Text(summary.stepLabel)
                .font(.body)
                .fontWeight(.semibold)
            Text(summary.situation)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
            Text(summary.nextStep)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(summary.accessibilityLabel)
        .accessibilityAddTraits(.isHeader)
    }

    /// Backs the primary action, which reads either "开始陪伴" or "继续陪伴".
    ///
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

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("今天的安排")
                .font(.title3)
                .fontWeight(.semibold)
                .accessibilityAddTraits(.isHeader)

            medicineSchedule

            if let outing = plan.outing {
                Divider()
                outingRow(outing)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var medicineSchedule: some View {
        if plan.medicines.isEmpty {
            Label("今天没有需要记录的用药。", systemImage: "checkmark.circle")
                .font(.body)
                .foregroundStyle(.secondary)
                .accessibilityElement(children: .combine)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(plan.medicines.enumerated()), id: \.element.id) { index, medicine in
                    medicineRow(medicine)
                    if index < plan.medicines.count - 1 {
                        Divider()
                    }
                }
            }
        }
    }

    private func medicineRow(_ medicine: TodayMedicineItem) -> some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    medicineIdentity(medicine)
                    medicineStatus(medicine)
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    medicineIdentity(medicine)
                    Spacer(minLength: 8)
                    medicineStatus(medicine)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(medicine.displayName)，\(medicine.timeOfDayDescription)，"
                + (medicine.isTakenToday ? "已完成" : "待完成")
        )
    }

    private func medicineIdentity(_ medicine: TodayMedicineItem) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: "pills")
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(medicine.displayName)
                    .font(.body)
                    .fontWeight(.semibold)
                Text(medicine.timeOfDayDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func medicineStatus(_ medicine: TodayMedicineItem) -> some View {
        Label(
            medicine.isTakenToday ? "已完成" : "待完成",
            systemImage: medicine.isTakenToday ? "checkmark.circle.fill" : "circle"
        )
        .font(.subheadline)
        .fontWeight(.medium)
        .foregroundStyle(.secondary)
    }

    private func outingRow(_ outing: TodayOutingItem) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "calendar.badge.clock")
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text("复诊或外出")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(outing.title)
                    .font(.body)
                    .fontWeight(.semibold)
                Text("\(outing.timeDescription) · \(outing.placeDescription)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "复诊或外出：\(outing.title)，\(outing.timeDescription)，\(outing.placeDescription)"
        )
    }
}

#Preview {
    NavigationStack {
        TodayView(onStartCompanion: {})
            .navigationTitle("今天")
    }
    .environment(AppEnvironment.preview())
}
