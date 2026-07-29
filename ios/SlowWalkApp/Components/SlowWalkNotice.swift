import SwiftUI

/// A solid, high-contrast callout for factual context and safety boundaries.
struct SlowWalkNotice: View {
    let title: String
    let message: String
    let systemImage: String
    let accessibilityLabel: String?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(
        title: String,
        message: String,
        systemImage: String,
        accessibilityLabel: String? = nil
    ) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
        self.accessibilityLabel = accessibilityLabel
    }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    noticeIcon
                    noticeText
                }
            } else {
                HStack(alignment: .top, spacing: 12) {
                    noticeIcon
                    noticeText
                }
            }
        }
        .padding(12)
        .background(
            Color(uiColor: .secondarySystemBackground),
            in: RoundedRectangle(cornerRadius: SlowWalkLayout.cornerRadius)
        )
        .overlay {
            RoundedRectangle(cornerRadius: SlowWalkLayout.cornerRadius)
                .stroke(.separator, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel ?? "\(title)。\(message)")
    }

    private var noticeIcon: some View {
        Image(systemName: systemImage)
            .font(.title3)
            .foregroundStyle(.tint)
            .frame(
                width: SlowWalkLayout.minimumTapTarget,
                height: SlowWalkLayout.minimumTapTarget,
                alignment: .top
            )
            .accessibilityHidden(true)
    }

    private var noticeText: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)

            Text(message)
                .font(.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview("Light") {
    SlowWalkNotice(
        title: "使用说明",
        message: "SlowWalk 提供风险提示，不做医疗诊断。",
        systemImage: "shield.lefthalf.filled"
    )
    .padding()
}

#Preview("Dark AX5") {
    SlowWalkNotice(
        title: "使用说明",
        message: "SlowWalk 提供风险提示，不做医疗诊断。",
        systemImage: "shield.lefthalf.filled"
    )
    .padding()
    .preferredColorScheme(.dark)
    .dynamicTypeSize(.accessibility5)
}
