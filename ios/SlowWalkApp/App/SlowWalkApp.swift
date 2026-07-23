import SwiftUI

@main
struct SlowWalkApp: App {
    var body: some Scene {
        WindowGroup {
            FoundationPlaceholderView()
        }
    }
}

private struct FoundationPlaceholderView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "figure.walk")
                .font(.system(size: 48))
                .accessibilityHidden(true)

            Text("慢慢走 SlowWalk")
                .font(.title)
                .fontWeight(.semibold)

            Text("风险提示原型 · 非医疗诊断")
                .multilineTextAlignment(.center)
        }
        .padding()
        .accessibilityElement(children: .combine)
    }
}

