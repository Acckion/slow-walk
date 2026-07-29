import SwiftUI
import SlowWalkDomain
import SlowWalkAPIContracts
import SlowWalkClientCore

@main
struct SlowWalkApp: App {
    /// The composition root, created once and shared with every feature.
    @State private var environment = AppEnvironment()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(environment)
        }
    }
}
