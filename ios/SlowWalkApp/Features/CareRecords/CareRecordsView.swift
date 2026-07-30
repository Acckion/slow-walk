import SwiftUI

/// The timeline of what happened while accompanying someone.
///
/// Records describe the process, not a diagnosis or prescription.
struct CareRecordsView: View {
    @Environment(AppEnvironment.self) private var environment

    private var events: [CareRecordEvent] {
        environment.careRecords.events
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                DemoDataBanner()

                if events.isEmpty {
                    emptyState
                } else {
                    ForEach(events) { event in
                        row(for: event)
                    }
                }

                // From the app-level capability source, not a fixed string: if
                // records ever become persistent, this line changes with the
                // table instead of being corrected here.
                Text(
                    environment.capabilities
                        .detail(of: .careRecordPersistence)
                        ?? "记录只保存在内存中，重新启动后会清空。"
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            .padding()
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("还没有记录")
                .font(.headline)
            Text("开始一次陪伴之后，这里会按时间记录每一步。")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func row(for event: CareRecordEvent) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(Self.timeFormatter.string(from: event.occurredAt))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(Self.description(for: event.kind))
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(Self.timeFormatter.string(from: event.occurredAt))，"
                + Self.description(for: event.kind)
        )
    }

    // MARK: - Wording

    /// Neutral, factual descriptions. Nothing here blames the person.
    static func description(for kind: CareRecordEventKind) -> String {
        switch kind {
        case .dayPlanItemStarted(let title):
            "开始今天的安排：\(title)"
        case .medicineAssessmentStarted:
            "开始使用预设文字进行设备内演示评估"
        case .medicineAssessmentNeedsConfirmation(let candidateCount):
            "设备内评估给出 \(candidateCount) 个候选药名，等待确认"
        case .medicineAssessmentRequiresSourceReview:
            "设备内评估提示信息来源仍需复核，未允许继续"
        case .medicineConfirmed(let medicineName):
            "已确认候选药名：\(medicineName)"
        case .careActionShown(let medicineName):
            "已显示\(medicineName)的设备内演示提示"
        case .medicineAssessmentFailed(let isRecoverable):
            isRecoverable
                ? "设备内演示评估没有完成，可以重试"
                : "设备内演示评估没有完成"
        case .companionFinished(let completion):
            switch completion {
            case .medicineReviewed:
                "陪伴结束：已查看用药提示"
            case .arrivedSafely:
                "陪伴结束：已安全到达"
            case .endedEarly:
                "陪伴结束：提前结束"
            }
        }
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}

#Preview {
    NavigationStack {
        CareRecordsView()
            .navigationTitle("守护记录")
    }
    .environment(AppEnvironment.preview())
}
