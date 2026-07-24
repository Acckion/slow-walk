import Foundation
import SlowWalkDataInterfaces
import SlowWalkDomain
import SlowWalkMedicineKnowledge
import XCTest

final class HTTPMedicineKnowledgeSourceTests:
    XCTestCase,
    @unchecked Sendable
{
    func testSearchUsesNormalizedQueryAndJSONAcceptHeader()
        async throws
    {
        let response = try validHTTPResponse()
        let transport = MockHTTPTransport { _ in response }
        let source = try makeSource(transport: transport)

        let result = try await source.search(
            query: MedicineKnowledgeSourceQuery(
                normalizedQuery: "acetaminophen"
            )
        )
        let requests = await transport.requests()
        let request = try XCTUnwrap(requests.first)

        XCTAssertEqual(
            URLComponents(
                url: request.url,
                resolvingAgainstBaseURL: false
            )?.queryItems?.first?.value,
            "acetaminophen"
        )
        XCTAssertEqual(request.headers["Accept"], "application/json")
        XCTAssertEqual(result.records.count, 1)
        XCTAssertEqual(result.validationStatus, .valid)
    }

    func testConditionalHeadersAndNotModifiedResponse()
        async throws
    {
        let transport = MockHTTPTransport { _ in
            HTTPTransportResponse(
                statusCode: 304,
                headers: [
                    "ETag": #""etag-v1""#,
                    "Last-Modified":
                        "Thu, 24 Jul 2025 00:00:00 GMT",
                ]
            )
        }
        let source = try makeSource(transport: transport)

        let result = try await source.search(
            query: MedicineKnowledgeSourceQuery(
                normalizedQuery: "acetaminophen",
                validationMetadata:
                    MedicineSourceValidationMetadata(
                        etag: #""etag-v0""#,
                        lastModified:
                            "Wed, 23 Jul 2025 00:00:00 GMT",
                        dataVersion: testVersion
                    )
            )
        )
        let requests = await transport.requests()
        let request = try XCTUnwrap(requests.first)

        XCTAssertEqual(
            request.headers["If-None-Match"],
            #""etag-v0""#
        )
        XCTAssertEqual(
            request.headers["If-Modified-Since"],
            "Wed, 23 Jul 2025 00:00:00 GMT"
        )
        XCTAssertEqual(result.validationStatus, .notModified)
        XCTAssertEqual(
            result.validationMetadata.etag,
            #""etag-v1""#
        )
    }

    func testTimeoutMapsToStableKnowledgeError() async throws {
        let transport = MockHTTPTransport { _ in
            throw HTTPTransportError.timeout
        }
        let source = try makeSource(transport: transport)

        await assertThrows(
            .knowledgeSourceTimeout(
                sourceIdentifier: testSourceID
            )
        ) {
            try await source.search(
                query: .init(
                    normalizedQuery: "acetaminophen"
                )
            )
        }
    }

    func testInvalidJSONIsRejected() async throws {
        let source = try makeSource(
            transport: MockHTTPTransport { _ in
                HTTPTransportResponse(
                    statusCode: 200,
                    headers: [
                        "Content-Type": "application/json",
                    ],
                    body: Data("{".utf8)
                )
            }
        )

        await assertInvalidResponse(from: source)
    }

    func testWrongContentTypeIsRejected() async throws {
        let source = try makeSource(
            transport: MockHTTPTransport { _ in
                HTTPTransportResponse(
                    statusCode: 200,
                    headers: ["Content-Type": "text/html"],
                    body: Data("not json".utf8)
                )
            }
        )

        await assertInvalidResponse(from: source)
    }

    func testEmptyResponseIsRejected() async throws {
        let source = try makeSource(
            transport: MockHTTPTransport { _ in
                HTTPTransportResponse(
                    statusCode: 200,
                    headers: [
                        "Content-Type": "application/json",
                    ]
                )
            }
        )

        await assertInvalidResponse(from: source)
    }

    func testOversizedResponseIsRejected() async throws {
        let source = try makeSource(
            transport: MockHTTPTransport { _ in
                HTTPTransportResponse(
                    statusCode: 200,
                    headers: [
                        "Content-Type": "application/json",
                    ],
                    body: Data(repeating: 1, count: 65)
                )
            },
            maximumResponseBytes: 64
        )

        await assertInvalidResponse(from: source)
    }

    func testCancellationMapsWithoutRetry() async throws {
        let transport = SequenceHTTPTransport(
            steps: [
                .failure(.cancelled),
                .response(try validHTTPResponse()),
            ]
        )
        let source = try makeSource(
            transport: transport,
            retryPolicy: HTTPRetryPolicy(
                maximumAttempts: 2,
                retryableStatusCodes: []
            )
        )

        await assertThrows(.requestCancelled) {
            try await source.search(
                query: .init(
                    normalizedQuery: "acetaminophen"
                )
            )
        }
        let requestCount = await transport.requestCount()
        XCTAssertEqual(requestCount, 1)
    }

    func testRetryPolicyRetriesTransientTimeout()
        async throws
    {
        let transport = SequenceHTTPTransport(
            steps: [
                .failure(.timeout),
                .response(try validHTTPResponse()),
            ]
        )
        let source = try makeSource(
            transport: transport,
            retryPolicy: HTTPRetryPolicy(
                maximumAttempts: 2,
                retryableStatusCodes: []
            )
        )

        let result = try await source.search(
            query: .init(
                normalizedQuery: "acetaminophen"
            )
        )

        XCTAssertEqual(result.records.count, 1)
        let requestCount = await transport.requestCount()
        XCTAssertEqual(requestCount, 2)
    }

    func testNonSuccessStatusIsUnavailable() async throws {
        let source = try makeSource(
            transport: MockHTTPTransport { _ in
                HTTPTransportResponse(statusCode: 503)
            }
        )

        await assertThrows(
            .knowledgeSourceUnavailable(
                sourceIdentifier: testSourceID
            )
        ) {
            try await source.search(
                query: .init(
                    normalizedQuery: "acetaminophen"
                )
            )
        }
    }

    private func assertInvalidResponse(
        from source: HTTPMedicineKnowledgeSource
    ) async {
        await assertThrows(
            .invalidSourceResponse(
                sourceIdentifier: testSourceID
            )
        ) {
            try await source.search(
                query: .init(
                    normalizedQuery: "acetaminophen"
                )
            )
        }
    }

    private func assertThrows(
        _ expected: MedicineKnowledgeError,
        operation: () async throws -> Void
    ) async {
        do {
            try await operation()
            XCTFail("Expected MedicineKnowledgeError.")
        } catch let error as MedicineKnowledgeError {
            XCTAssertEqual(error, expected)
        } catch {
            XCTFail("Unexpected error: \(type(of: error))")
        }
    }

    private func makeSource(
        transport: any HTTPTransporting,
        maximumResponseBytes: Int = 512 * 1_024,
        retryPolicy: HTTPRetryPolicy = HTTPRetryPolicy(
            maximumAttempts: 1,
            retryableStatusCodes: []
        )
    ) throws -> HTTPMedicineKnowledgeSource {
        try HTTPMedicineKnowledgeSource(
            configuration:
                HTTPMedicineKnowledgeSourceConfiguration(
                    identifier: testSourceID,
                    displayName: "Test source",
                    priority: 100,
                    isAuthoritative: true,
                    supportedDataVersion: testVersion,
                    baseURL: URL(
                        string: "https://source.demo.invalid/api/v1/"
                    )!,
                    documentTitle:
                        MedicineKnowledgeSafety.demoDisclaimer,
                    maximumResponseBytes:
                        maximumResponseBytes,
                    retryPolicy: retryPolicy
                ),
            transport: transport,
            clock: FixedClock(fixedDate: testHTTPDate)
        )
    }

    private func validHTTPResponse()
        throws -> HTTPTransportResponse
    {
        let reference = testSourceReference()
        let payload = MedicineKnowledgeHTTPPayload(
            sourceIdentifier: testSourceID,
            sourceReference: reference,
            sourceDocumentVersion: testVersion,
            fetchedAt: testHTTPDate,
            completeness: 1,
            validationStatus: .valid,
            records: [
                MedicineKnowledgeRecord(
                    canonicalMedicineIdentifier:
                        "medicine-acetaminophen",
                    canonicalName: "Acetaminophen",
                    aliases: ["Paracetamol"],
                    activeIngredientIDs: ["acetaminophen"],
                    category: .analgesic,
                    warnings: [
                        MedicineKnowledgeSafety
                            .demoDisclaimer,
                    ],
                    contraindicationTags: [],
                    dosageTextFromSource: nil,
                    sourceIdentifier: testSourceID,
                    sourceReference: reference,
                    sourceDocumentVersion: testVersion,
                    fetchedAt: testHTTPDate,
                    completeness: 1,
                    validationStatus: .valid
                ),
            ]
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return HTTPTransportResponse(
            statusCode: 200,
            headers: [
                "Content-Type": "application/json; charset=utf-8",
                "ETag": #""etag-v1""#,
                "Last-Modified":
                    "Thu, 24 Jul 2025 00:00:00 GMT",
            ],
            body: try encoder.encode(payload)
        )
    }

    private func testSourceReference() -> SourceReference {
        SourceReference(
            sourceName: "Test source",
            documentTitle:
                MedicineKnowledgeSafety.demoDisclaimer,
            optionalURL: nil,
            retrievedAt: testHTTPDate,
            versionOrDate: testVersion
        )
    }
}

private actor SequenceHTTPTransport: HTTPTransporting {
    enum Step: Sendable {
        case response(HTTPTransportResponse)
        case failure(HTTPTransportError)
    }

    private var steps: [Step]
    private var count = 0

    init(steps: [Step]) {
        self.steps = steps
    }

    func send(
        _ request: HTTPTransportRequest
    ) async throws -> HTTPTransportResponse {
        count += 1
        guard !steps.isEmpty else {
            throw HTTPTransportError.networkFailure
        }
        switch steps.removeFirst() {
        case .response(let response):
            return response
        case .failure(let error):
            throw error
        }
    }

    func requestCount() -> Int {
        count
    }
}

private let testSourceID = "test-http-source"
private let testVersion = "test-source-v1"
private let testHTTPDate = Date(
    timeIntervalSince1970: 1_753_315_200
)
