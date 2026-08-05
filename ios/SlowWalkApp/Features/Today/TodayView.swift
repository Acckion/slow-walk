import SwiftUI

/// Today answers one question first: what needs doing now.
struct TodayView: View {
    @Environment(AppEnvironment.self) private var environment

    /// Moves the app to the Companion tab after a successful start or resume.
    let onStartCompanion: () -> Void

    private var plan: TodayPlan { environment.plan }

    private var summary: TodayStatusSummary {
        TodayStatusSummary(
            state: environment.companion.state,
            capabilities: environment.capabilities
        )
    }

    private var mostImportantText: String {
        summary.hasFinishedSession ? summary.situation : plan.mostImportantThing
    }

    var body: some View {
        List {
            Section {
                TodayTaskOverviewCard(plan: plan)
                    .slowWalkReadableContent()
            }

            Section("现在最重要的事") {
                Button(action: startOrContinueCompanion) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: mostImportantSystemImage)
                            .foregroundStyle(mostImportantTint)
                            .font(.title3)
                            .frame(width: 28)
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(mostImportantText)
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)

                            Text(summary.nextStep)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)

                            Text(summary.primaryActionTitle)
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(mostImportantTint)
                        }

                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(minHeight: SlowWalkLayout.minimumTapTarget)
                .accessibilityLabel(
                    "现在最重要的事。\(mostImportantText)。"
                        + "\(summary.nextStep)。\(summary.primaryActionTitle)"
                )
                .accessibilityHint("进入陪伴页面。")
                .slowWalkReadableContent()
            }
        }
        .listStyle(.insetGrouped)
    }

    private var mostImportantSystemImage: String {
        if summary.hasFinishedSession {
            "checkmark.circle.fill"
        } else if summary.isSessionUnderway {
            "figure.walk"
        } else {
            "flag.fill"
        }
    }

    private var mostImportantTint: Color {
        if summary.hasFinishedSession {
            .green
        } else if summary.isSessionUnderway {
            .orange
        } else {
            .accentColor
        }
    }

    private func startOrContinueCompanion() {
        if summary.isSessionUnderway {
            onStartCompanion()
            return
        }
        guard environment.companion.startCompanion() else { return }
        onStartCompanion()
    }
}

private struct TodayOverviewGoal: Identifiable {
    let id: String
    let title: String
    let systemImage: String
    let tint: Color
    let progress: Double
    let statusText: String
}

private struct TodayTaskOverviewCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let plan: TodayPlan

    private let ringRadii: [CGFloat] = [102, 76, 50]
    private let ringWidths: [CGFloat] = [20, 20, 20]

    private var completedMedicineCount: Int {
        plan.medicines.filter(\.isTakenToday).count
    }

    private var pendingTaskCount: Int {
        plan.pendingMedicines.count + (plan.outing == nil ? 0 : 1)
    }

    private var totalTaskCount: Int {
        plan.medicines.count + (plan.outing == nil ? 0 : 1)
    }

    private var completedTaskCount: Int {
        totalTaskCount - pendingTaskCount
    }

    private var goals: [TodayOverviewGoal] {
        let medicineTotal = plan.medicines.count
        let medicineProgress = medicineTotal == 0
            ? 1
            : Double(completedMedicineCount) / Double(medicineTotal)

        return [
            TodayOverviewGoal(
                id: "medicine",
                title: "用药",
                systemImage: "pills.fill",
                tint: completedMedicineCount == medicineTotal ? .green : .orange,
                progress: medicineProgress,
                statusText: medicineTotal == 0
                    ? "无"
                    : "\(completedMedicineCount)/\(medicineTotal)"
            ),
            TodayOverviewGoal(
                id: "outing",
                title: "出行",
                systemImage: "calendar",
                tint: plan.outing == nil ? .green : .blue,
                progress: plan.outing == nil ? 1 : 0,
                statusText: plan.outing == nil ? "无" : "1项"
            ),
            TodayOverviewGoal(
                id: "tasks",
                title: "待办",
                systemImage: "checklist.checked",
                tint: pendingTaskCount == 0 ? .green : .accentColor,
                progress: totalTaskCount == 0
                    ? 1
                    : Double(completedTaskCount) / Double(totalTaskCount),
                statusText: totalTaskCount == 0
                    ? "无"
                    : "\(completedTaskCount)/\(totalTaskCount)"
            ),
        ]
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("今日待办")
                        .font(.headline)
                    Text("您好，\(plan.preferredName)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(pendingTaskCount == 0 ? "已完成" : "\(pendingTaskCount)项待完成")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(pendingTaskCount == 0 ? .green : .secondary)
            }

            let maxRadius = ringRadii[0]
            let maxWidth = ringWidths[0]
            ZStack(alignment: .top) {
                ForEach(Array(goals.enumerated()), id: \.element.id) {
                    index, goal in
                    let radius = ringRadii[min(index, ringRadii.count - 1)]
                    let width = ringWidths[min(index, ringWidths.count - 1)]
                    TodaySemiRingSegment(
                        progress: goal.progress,
                        tint: goal.tint,
                        lineWidth: width,
                        radius: radius
                    )
                    .alignmentGuide(.top) { dimensions in
                        dimensions[.bottom]
                    }
                }
            }
            .frame(
                width: maxRadius * 2 + maxWidth,
                height: maxRadius + maxWidth
            )
            .clipShape(Rectangle())
            .accessibilityHidden(true)

            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(goals) { goal in
                        accessibilityGoalRow(goal)
                    }
                }
            } else {
                HStack(alignment: .top) {
                    ForEach(goals) { goal in
                        compactGoalCell(goal)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    private func compactGoalCell(_ goal: TodayOverviewGoal) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: goal.systemImage)
                    .font(.subheadline)
                    .foregroundStyle(goal.tint)
                    .accessibilityHidden(true)
                Text(goal.title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Text(goal.statusText)
                .font(.callout.weight(.semibold))
                .foregroundStyle(goal.tint)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(goal.title)，\(goal.statusText)")
    }

    private func accessibilityGoalRow(_ goal: TodayOverviewGoal) -> some View {
        HStack(spacing: 8) {
            Image(systemName: goal.systemImage)
                .foregroundStyle(goal.tint)
                .accessibilityHidden(true)
            Text(goal.title)
            Spacer()
            Text(goal.statusText)
                .fontWeight(.semibold)
                .foregroundStyle(goal.tint)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(goal.title)，\(goal.statusText)")
    }
}

private struct TodaySemiRingSegment: View {
    let progress: Double
    let tint: Color
    let lineWidth: CGFloat
    let radius: CGFloat

    var body: some View {
        ZStack {
            TodaySemiCircle()
                .stroke(
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round
                    )
                )
                .foregroundStyle(tint.opacity(0.12))
            TodaySemiCircle()
                .trim(from: 0, to: progress)
                .stroke(
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round
                    )
                )
                .foregroundStyle(tint)
        }
        .frame(width: radius * 2, height: radius)
    }
}

private struct TodaySemiCircle: Shape {
    nonisolated func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.maxY)
        let radius = min(rect.width, rect.height * 2) / 2
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(180),
            endAngle: .degrees(360),
            clockwise: false
        )
        return path
    }
}

#Preview("Light") {
    NavigationStack {
        TodayView(onStartCompanion: {})
            .navigationTitle("今天")
    }
    .environment(AppEnvironment.preview())
}

#Preview("Dark AX5") {
    NavigationStack {
        TodayView(onStartCompanion: {})
            .navigationTitle("今天")
    }
    .environment(AppEnvironment.preview())
    .preferredColorScheme(.dark)
    .dynamicTypeSize(.accessibility5)
}
