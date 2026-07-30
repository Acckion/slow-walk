import Testing

@testable import SlowWalkApp

@MainActor
struct CapabilityStatusTests {
    @Test func shippingCatalogMatchesTheImplementedBoundaries() {
        let catalog = CapabilityCatalog.currentDemo

        #expect(catalog.availability(of: .medicineRecognition) == .simulated)
        #expect(catalog.availability(of: .medicineRiskAssessment) == .deviceLocal)
        #expect(catalog.availability(of: .visionOCR) == .unavailable)
        #expect(catalog.availability(of: .coreLocation) == .unavailable)
        #expect(catalog.availability(of: .arrivalReminder) == .unavailable)
        #expect(catalog.availability(of: .careRecordPersistence) == .unavailable)
        #expect(catalog.availability(of: .trustedContacts) == .unavailable)
        #expect(catalog.availability(of: .serverDependency) == .unavailable)
    }

    @Test func noCapabilityClaimsToBeOnline() {
        #expect(
            CapabilityCatalog.currentDemo.allStatuses.allSatisfy {
                $0.availability != .online
            }
        )
    }

    @Test func serverIsExplicitlyOptionalForTheApp() {
        let status = CapabilityCatalog.currentDemo.status(of: .serverDependency)

        #expect(status.availability == .unavailable)
        #expect(status.detail?.contains("不是本 App 的默认运行依赖") == true)
    }

    @Test func everyCapabilityHasDisplayWording() {
        let statuses = CapabilityCatalog.currentDemo.allStatuses

        #expect(statuses.count == AppCapability.allCases.count)
        #expect(statuses.allSatisfy { !$0.displayName.isEmpty })
        #expect(statuses.allSatisfy { $0.detail?.isEmpty == false })
    }

    @Test func unlistedCapabilityDefaultsToUnavailable() {
        let empty = CapabilityCatalog(availability: [:])

        #expect(
            AppCapability.allCases.allSatisfy {
                empty.availability(of: $0) == .unavailable
            }
        )
    }

    @Test func availabilityLabelsAreDistinctAndNonempty() {
        let labels = CapabilityAvailability.allCases.map(\.shortLabel)

        #expect(Set(labels).count == CapabilityAvailability.allCases.count)
        #expect(labels.allSatisfy { !$0.isEmpty })
    }

    @Test func implementationSemanticsDistinguishSimulatedFromReal() {
        #expect(CapabilityAvailability.simulated.isImplemented)
        #expect(!CapabilityAvailability.simulated.isRealImplementation)
        #expect(CapabilityAvailability.deviceLocal.isImplemented)
        #expect(CapabilityAvailability.deviceLocal.isRealImplementation)
        #expect(CapabilityAvailability.online.isImplemented)
        #expect(CapabilityAvailability.online.isRealImplementation)
        #expect(!CapabilityAvailability.unavailable.isImplemented)
        #expect(!CapabilityAvailability.unavailable.isRealImplementation)
    }

    @Test func summaryLineCarriesNameStateAndDetail() {
        let status = CapabilityCatalog.currentDemo.status(
            of: .medicineRiskAssessment
        )

        #expect(status.summaryLine.contains(status.displayName))
        #expect(status.summaryLine.contains(status.shortLabel))
        #expect(status.detail.map(status.summaryLine.contains) == true)
    }
}
