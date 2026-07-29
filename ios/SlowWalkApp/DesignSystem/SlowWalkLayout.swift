import SwiftUI

/// Shared dimensions for the app's readable, accessible layouts.
enum SlowWalkLayout {
    static let contentMaxWidth: CGFloat = 680
    static let minimumTapTarget: CGFloat = 44
    static let primaryActionMinimumHeight: CGFloat = 56
    static let cornerRadius: CGFloat = 8
}

private struct SlowWalkReadableContentModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(
                maxWidth: SlowWalkLayout.contentMaxWidth,
                alignment: .leading
            )
            .frame(maxWidth: .infinity, alignment: .center)
    }
}

extension View {
    /// Keeps reading lines comfortable on wide screens without constraining phones.
    func slowWalkReadableContent() -> some View {
        modifier(SlowWalkReadableContentModifier())
    }
}
