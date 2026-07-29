import Foundation
import Hummingbird
import HummingbirdTesting
import SlowWalkAPIContracts
import SlowWalkDataInterfaces
import SlowWalkDomain
import SlowWalkMedicineKnowledge
@testable import SlowWalkServer
import XCTest

/// Golden tests: every JSON fixture response must equal the response that the
/// real server pipeline produces for the same fixture request.
///
/// The actual value comes from the live composition root
/// (`makeSlowWalkApplication`) driven through the Hummingbird test client:
/// resolver, health-context validation, risk engine, action-card factory,
/// medicine pipeline, knowledge service, and the controller's response
/// mapping all run in their production form. The expected value comes from
/// the versioned fixture. Nothing is derived from the fixture response, and
/// no production algorithm is reimplemented here.
///
/// Determinism is injected only at the documented boundaries: a fixed clock,
/// a fixed fallback UUID, and the existing demo mock knowledge transport.
/// All timestamps in the responses are therefore controlled, so the
/// comparison is a complete DTO equality with no normalization of any field.
final class MedicineDemoFixtureGoldenTests: XCTestCase {
    private static let onlineFixtureFiles = [
        "medicine-normal.json",
        "medicine-ambiguous.json",
        "medicine-health-warning.json",
        "medicine-red-risk.json",
    ]

    func testOnlineFixturesMatchLivePipeline() async throws {
        for filename in Self.onlineFixtureFiles {
            let fixture = try DemoFixtureSupport.load(filename)
            let actual = try await MedicineDemoFixtureGoldenHarness
                .runOnlineAssessment(request: fixture.request)
            XCTAssertEqual(
                actual,
                fixture.response,
                "Live pipeline output drifted from \(filename). " +
                    "Regenerate the fixture from a real pipeline run " +
                    "instead of editing the expected values by hand."
            )
        }
    }

    func testKnowledgeWarningFixtureMatchesLivePipeline() async throws {
        let fixture = try DemoFixtureSupport.load(
            "medicine-source-warning.json"
        )
        let actual = try await MedicineDemoFixtureGoldenHarness
            .runStaleOfflineAssessment(request: fixture.request)
        XCTAssertEqual(
            actual,
            fixture.response,
            "Live pipeline output drifted from " +
                "medicine-source-warning.json. Regenerate the fixture " +
                "from a real pipeline run instead of editing the " +
                "expected values by hand."
        )
    }
}

/// Live-pipeline harness shared by the golden tests.
///
/// The harness is intentionally reusable for isolated manual mutation probes.
enum MedicineDemoFixtureGoldenHarness {
    /// Matches the timestamps used by the fixture requests: the assessment
    /// runs five minutes after the profile/body-metrics timestamps.
    static let onlineNow = goldenDate("2026-07-25T08:00:00Z")

    /// Twenty minutes later than `onlineNow`: past the 15 minute knowledge
    /// cache TTL but inside the 24 hour offline grace period, so an offline
    /// source outage deterministically yields the stale-offline path.
    static let staleOfflineNow = goldenDate("2026-07-25T08:20:00Z")

    /// Runs one assessment against a fresh application instance whose
    /// knowledge sources are online. A fresh instance means fresh caches,
    /// so the first request deterministically reports cache misses.
    static func runOnlineAssessment(
        request: MedicineAssessmentRequestDTO
    ) async throws -> MedicineAssessmentResponseDTO {
        let app = try makeSlowWalkApplication(
            configuration: .init(port: 0),
            dateProvider: FixedDateProvider(fixedDate: onlineNow),
            uuidProvider: FixedUUIDProvider(
                fixedUUID: goldenFallbackUUID()
            )
        )
        return try await postAssessment(app: app, request: request)
    }

    /// Reproduces the `knowledgeWarning` scenario through the real
    /// knowledge service and cache:
    ///
    /// 1. With sources online, the fixture request is assessed once so the
    ///    real `InMemoryMedicineKnowledgeCache` stores the entry.
    /// 2. The clock advances past the cache TTL and the controllable demo
    ///    transport starts failing with `HTTPTransportError.networkFailure`.
    /// 3. The same request is assessed again; the real service falls back
    ///    to the stale offline cache path.
    static func runStaleOfflineAssessment(
        request: MedicineAssessmentRequestDTO
    ) async throws -> MedicineAssessmentResponseDTO {
        let catalog = try BundledDemoMedicineCatalogLoader().loadCatalog()
        let clock = GoldenMutableClock(onlineNow)
        let transport = GoldenControllableTransport(
            medicines: catalog.medicines,
            fetchedAt: onlineNow
        )
        let knowledgeService = try MedicineKnowledgeService(
            sources: [
                MockAuthoritativeMedicineSource(
                    transport: transport,
                    clock: clock
                ),
                MockSecondaryMedicineSource(
                    transport: transport,
                    clock: clock
                ),
            ],
            policy: .demo,
            clock: clock
        )
        let app = try makeSlowWalkApplication(
            configuration: .init(port: 0),
            dateProvider: clock,
            uuidProvider: FixedUUIDProvider(
                fixedUUID: goldenFallbackUUID()
            ),
            medicineKnowledgeSearcher: knowledgeService
        )

        _ = try await postAssessment(app: app, request: request)

        clock.set(staleOfflineNow)
        await transport.setOffline(true)
        return try await postAssessment(app: app, request: request)
    }

    private static func postAssessment(
        app: some ApplicationProtocol,
        request: MedicineAssessmentRequestDTO
    ) async throws -> MedicineAssessmentResponseDTO {
        let box = GoldenResultBox()
        try await app.test(.router) { client in
            try await client.execute(
                uri: SlowWalkAPI.Endpoint.medicineAssess.path,
                method: .post,
                headers: [.contentType: "application/json"],
                body: ByteBuffer(
                    bytes: try SlowWalkJSONCoding.makeEncoder()
                        .encode(request)
                )
            ) { response in
                box.status = response.status
                let data = Data(response.body.readableBytesView)
                if response.status == .ok {
                    box.response = try SlowWalkJSONCoding.makeDecoder()
                        .decode(
                            MedicineAssessmentResponseDTO.self,
                            from: data
                        )
                } else {
                    box.errorBody = String(data: data, encoding: .utf8)
                }
            }
        }
        guard let response = box.response else {
            throw GoldenHarnessError.requestRejected(
                status: box.status,
                body: box.errorBody
            )
        }
        return response
    }

    private static func goldenDate(_ value: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        guard let date = formatter.date(from: value) else {
            fatalError("Invalid golden-test date constant: \(value)")
        }
        return date
    }

    private static func goldenFallbackUUID() -> UUID {
        guard let uuid = UUID(
            uuidString: "00000000-0000-0000-0000-000000000099"
        ) else {
            fatalError("Invalid golden-test UUID constant.")
        }
        return uuid
    }
}

enum GoldenHarnessError: Error, CustomStringConvertible {
    case requestRejected(status: HTTPResponse.Status?, body: String?)

    var description: String {
        switch self {
        case let .requestRejected(status, body):
            return """
                The live pipeline rejected the fixture request. \
                HTTP status: \(String(describing: status)). \
                Body: \(body ?? "<none>")
                """
        }
    }
}

private final class GoldenResultBox: @unchecked Sendable {
    var response: MedicineAssessmentResponseDTO?
    var status: HTTPResponse.Status?
    var errorBody: String?
}

/// Deterministic two-value clock for the stale-offline scenario. The test
/// sets both values explicitly; nothing reads the wall clock.
final class GoldenMutableClock: DateProviding, @unchecked Sendable {
    private let lock = NSLock()
    private var current: Date

    init(_ date: Date) {
        current = date
    }

    func set(_ date: Date) {
        lock.lock()
        current = date
        lock.unlock()
    }

    func now() -> Date {
        lock.lock()
        defer { lock.unlock() }
        return current
    }
}

/// Test-only transport switch: online it delegates to the existing
/// `DemoMockHTTPTransport`; offline it fails deterministically.
actor GoldenControllableTransport: HTTPTransporting {
    private var offline = false
    private let online: DemoMockHTTPTransport

    init(medicines: [Medicine], fetchedAt: Date) {
        online = DemoMockHTTPTransport(
            medicines: medicines,
            fetchedAt: fetchedAt
        )
    }

    func setOffline(_ value: Bool) {
        offline = value
    }

    func send(
        _ request: HTTPTransportRequest
    ) async throws -> HTTPTransportResponse {
        if offline {
            throw HTTPTransportError.networkFailure
        }
        return try await online.send(request)
    }
}
