import SwiftUI

/// The single prominent action used to advance a screen or companion step.
struct SlowWalkPrimaryActionButton: View {
    let title: String
    let systemImage: String?
    let accessibilityHint: String?
    let action: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(
        title: String,
        systemImage: String? = nil,
        accessibilityHint: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.accessibilityHint = accessibilityHint
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Group {
                if let systemImage {
                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(spacing: 8) {
                            Image(systemName: systemImage)
                                .accessibilityHidden(true)
                            Text(title)
                        }
                    } else {
                        Label(title, systemImage: systemImage)
                    }
                } else {
                    Text(title)
                }
            }
            .font(.headline)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
            .frame(minHeight: SlowWalkLayout.primaryActionMinimumHeight)
            .padding(.horizontal, 12)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .accessibilityLabel(title)
        .accessibilityHint(accessibilityHint ?? "")
    }
}

#Preview("Default") {
    SlowWalkPrimaryActionButton(
        title: "开始陪伴",
        systemImage: "figure.walk",
        accessibilityHint: "进入陪伴流程。",
        action: {}
    )
    .padding()
}

#Preview("AX5") {
    SlowWalkPrimaryActionButton(
        title: "继续今天的陪伴",
        systemImage: "figure.walk",
        action: {}
    )
    .padding()
    .dynamicTypeSize(.accessibility5)
}

