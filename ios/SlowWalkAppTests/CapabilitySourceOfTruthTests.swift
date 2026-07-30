import Foundation
import SlowWalkClientCore
import Testing

@testable import SlowWalkApp

@MainActor
struct CapabilitySourceOfTruthTests {
    @Test func environmentHandsItsCatalogToTheSession() {
        let catalog = Self.markedCatalog
        let environment = AppEnvironment(
            clock: AppFixedClock(
                fixedDate: Date(timeIntervalSince1970: 1_753_000_000)
            ),
            capabilities: catalog
        )

        #expect(environment.capabilities == catalog)
        #expect(environment.companion.capabilities == catalog)
    }

    @Test func todayAndCompanionUseTheSameCapabilityWording() {
        let catalog = Self.markedCatalog
        let environment = AppEnvironment(
            clock: AppFixedClock(
                fixedDate: Date(timeIntervalSince1970: 1_753_000_000)
            ),
            capabilities: catalog
        )
        let session = environment.companion
        #expect(session.startCompanion())

        let summary = TodayStatusSummary(
            state: session.state,
            medicineState: session.medicineState,
            capabilities: environment.capabilities
        )

        #expect(summary.situation == session.situation)
        #expect(summary.situation.contains(Self.marker))
    }

    @Test func defaultEnvironmentUsesTheCurrentDemoCatalog() {
        let environment = AppEnvironment(
            clock: AppFixedClock(
                fixedDate: Date(timeIntervalSince1970: 1_753_000_000)
            )
        )

        #expect(environment.capabilities == .currentDemo)
        #expect(environment.companion.capabilities == .currentDemo)
    }

    @Test func capabilityCatalogDoesNotGrantFlowPermission() {
        let environment = AppEnvironment(
            clock: AppFixedClock(
                fixedDate: Date(timeIntervalSince1970: 1_753_000_000)
            ),
            capabilities: Self.markedCatalog
        )
        let session = environment.companion

        #expect(session.startCompanion())
        session.beginMedicineAssessment()
        #expect(!session.acknowledgeCareAction())
        #expect(session.state == .medicineAssessment)
    }

    private static let marker = "注入目录标记"

    private static let markedCatalog = CapabilityCatalog(
        availability: [
            .medicineRecognition: .simulated,
            .medicineRiskAssessment: .deviceLocal,
        ],
        detail: [
            .medicineRecognition: "\(marker)：固定演示输入。",
            .medicineRiskAssessment: "\(marker)：设备内评估。",
        ]
    )
}
