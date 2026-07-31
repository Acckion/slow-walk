import Foundation
import SlowWalkClientCore
import Testing
@testable import SlowWalkApp

@MainActor
struct CapabilitySourceOfTruthTests {
    @Test func environmentHandsInjectedCatalogToSession() {
        let environment = AppEnvironment(
            clock: AppFixedClock(fixedDate: medicineTestDate),
            capabilities: TestCapabilityCatalogs.allMarked,
            assessmentRunner: ImmediateMedicineAssessmentRunner()
        )
        #expect(environment.capabilities == TestCapabilityCatalogs.allMarked)
        #expect(environment.companion.capabilities == environment.capabilities)
    }

    @Test func defaultEnvironmentUsesShippingCatalog() {
        let environment = AppEnvironment(
            clock: AppFixedClock(fixedDate: medicineTestDate),
            assessmentRunner: ImmediateMedicineAssessmentRunner()
        )
        #expect(environment.capabilities == .phase0)
        #expect(environment.companion.capabilities == .phase0)
    }

    @Test func sessionRetainsExactlyInjectedCatalog() {
        let session = CompanionSessionModel(
            records: RecordingCareRecordStore(),
            simulator: SpyScanSimulator(),
            plan: .demo,
            readDelay: ImmediateMedicineReadDelay(),
            assessmentRunner: ImmediateMedicineAssessmentRunner(),
            clock: AppFixedClock(fixedDate: medicineTestDate),
            capabilities: TestCapabilityCatalogs.allMarked
        )
        #expect(session.capabilities == TestCapabilityCatalogs.allMarked)
    }

    @Test func shippingAssessmentCapabilityIsDeviceLocal() {
        let status = CapabilityCatalog.phase0.status(
            of: .medicineRiskAssessment
        )
        #expect(status.availability == .deviceLocal)
        #expect(status.detail?.contains("设备内") == true)
    }

    @Test func recognitionRemainsExplicitlySimulated() {
        let status = CapabilityCatalog.phase0.status(of: .medicineRecognition)
        #expect(status.availability == .simulated)
        #expect(status.detail?.contains("不读取相机图片") == true)
    }

    @Test func serverRemainsOutsideDefaultRuntime() {
        let status = CapabilityCatalog.phase0.status(of: .serverDependency)
        #expect(status.availability == .unavailable)
        #expect(status.detail?.contains("不是本 App 的默认运行依赖") == true)
    }

    @Test func everyShippingCapabilityHasOneDisplayStatus() {
        let statuses = CapabilityCatalog.phase0.allStatuses
        #expect(statuses.count == AppCapability.allCases.count)
        #expect(Set(statuses.map(\.capability)) == Set(AppCapability.allCases))
    }

    @Test func missingCatalogEntryFailsClosed() {
        let catalog = CapabilityCatalog(availability: [:])
        for capability in AppCapability.allCases {
            #expect(catalog.availability(of: capability) == .unavailable)
        }
    }

    @Test func availabilityLabelsStayDistinct() {
        let labels = CapabilityAvailability.allCases.map(\.shortLabel)
        #expect(Set(labels).count == CapabilityAvailability.allCases.count)
    }

    @Test func capabilityCatalogCannotChangeCanonicalAssessmentState() {
        let state = CompanionFlowState.awaitingMedicineAssessment(
            MedicineAssessmentGateTests.makeGate(
                viewState: .assessing(startedAt: medicineTestDate)
            )
        )
        let shipping = CompanionCopy.situation(
            for: state,
            capabilities: .phase0
        )
        let injected = CompanionCopy.situation(
            for: state,
            capabilities: TestCapabilityCatalogs.allMarked
        )
        #expect(shipping == injected)
        #expect(shipping.contains(TestCapabilityCatalogs.marker) == false)
    }
}
