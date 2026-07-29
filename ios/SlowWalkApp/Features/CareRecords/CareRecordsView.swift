import SwiftUI

/// The timeline of what happened while accompanying someone.
///
/// Records describe the process, not a medical outcome. A read that did not
/// succeed is recorded as an event with a recovery path, never as a conclusion
/// about a medicine.
struct CareRecordsView: View {
    @Environment(AppEnvironment.self) private var environment

    private var events: [CareRecordEvent] {
        environment.careRecords.events
    }

    var body: some View {
        List {
            Section {
                DemoDataBanner()
                    .slowWalkReadableContent()
            }

            if events.isEmpty {
                Section {
                    ContentUnavailableView(
                        "还没有记录",
                        systemImage: "clock.badge.questionmark",
                        description: Text("开始一次陪伴之后，这里会按时间记录每一步。")
                    )
                    .slowWalkReadableContent()
                }
            } else {
                Section {
                    ForEach(events) { event in
                        row(for: event)
                            .slowWalkReadableContent()
                    }
                } header: {
                    sectionHeader("陪伴过程")
                }
            }

            Section {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("记录保存在本次运行中")
                            .font(.headline)
                        Text("本阶段记录只保存在内存中，重新启动后会清空。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "internaldrive")
                        .foregroundStyle(.tint)
                }
                .slowWalkReadableContent()
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(
                    "记录保存在本次运行中。本阶段记录只保存在内存中，重新启动后会清空。"
                )
            } header: {
                sectionHeader("记录说明")
            }
        }
        .listStyle(.insetGrouped)
    }

    private func row(for event: CareRecordEvent) -> some View {
        let time = event.occurredAt.formatted(Self.timeStyle)

        return Label {
            VStack(alignment: .leading, spacing: 4) {
                Text(time)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(Self.description(for: event.kind))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } icon: {
            Image(systemName: Self.systemImage(for: event.kind))
                .foregroundStyle(.tint)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(time)，\(Self.description(for: event.kind))")
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .accessibilityAddTraits(.isHeader)
    }

    private static func systemImage(for kind: CareRecordEventKind) -> String {
        switch kind {
        case .dayPlanItemStarted:
            "calendar.badge.clock"
        case .medicineReadStarted:
            "camera.viewfinder"
        case .medicineReadDidNotSucceed:
            "arrow.clockwise.circle"
        case .medicineReadFoundCandidates:
            "list.bullet.rectangle"
        case .medicineConfirmed:
            "checkmark.circle"
        case .careActionShown:
            "rectangle.and.text.magnifyingglass"
        case .companionFinished:
            "flag.checkered"
        }
    }

    // MARK: - Wording

    /// Neutral, factual descriptions. Nothing here blames the person.
    static func description(for kind: CareRecordEventKind) -> String {
        switch kind {
        case let .dayPlanItemStarted(title):
            "开始今天的安排：\(title)"
        case let .medicineReadStarted(attemptNumber):
            attemptNumber == 1
                ? "开始读取药盒"
                : "第 \(attemptNumber) 次读取药盒"
        case let .medicineReadDidNotSucceed(setback):
            switch setback {
            case .textNotLegible:
                "这次没有看清药盒上的字，已提供重试方式"
            case .noMedicineNameFound:
                "这次没有找到药名，已提供重试方式"
            }
        case let .medicineReadFoundCandidates(candidateCount):
            "这次读到 \(candidateCount) 个相近的药名，等待确认"
        case let .medicineConfirmed(medicineName, origin):
            switch origin {
            case .readFromPhoto:
                "已确认药名：\(medicineName)（照片读取后确认）"
            case .chosenFromFrequentList:
                "已确认药名：\(medicineName)（从常用药名选择）"
            }
        case let .careActionShown(medicineName):
            "已显示\(medicineName)的用药提示占位（正式提示卡尚未接入）"
        case let .companionFinished(completion):
            switch completion {
            case .arrivedSafely:
                "陪伴结束：已安全到达"
            case .endedEarly:
                "陪伴结束：提前结束"
            }
        }
    }

    private static let timeStyle = Date.FormatStyle(date: .omitted, time: .shortened)
}

#Preview {
    NavigationStack {
        CareRecordsView()
            .navigationTitle("守护记录")
    }
    .environment(AppEnvironment.preview())
}
