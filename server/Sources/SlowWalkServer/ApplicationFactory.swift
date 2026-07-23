import Hummingbird
import SlowWalkDataInterfaces
import SlowWalkRiskEngine

public func makeSlowWalkApplication(
    configuration: SlowWalkServerConfiguration = .init(),
    riskEngine: any RiskAssessing = MedicationRiskEngine(),
    dateProvider: any DateProviding = SystemDateProvider(),
    uuidProvider: any UUIDProviding = SystemUUIDProvider()
) -> some ApplicationProtocol {
    let router = Router(context: SlowWalkRequestContext.self)
    router.middlewares.add(LogRequestsMiddleware(.info))

    router.get("/health") { _, _ in
        HealthResponseDTO()
    }

    let service = RiskAssessmentService(
        engine: riskEngine,
        dateProvider: dateProvider
    )
    let controller = RiskAssessmentController(
        service: service,
        uuidProvider: uuidProvider
    )
    router.post("/api/v1/risk/assess") { request, context in
        try await controller.handle(request: request, context: context)
    }

    return Application(
        router: router,
        configuration: .init(
            address: .hostname(configuration.host, port: configuration.port),
            serverName: configuration.serverName
        )
    )
}

public func runSlowWalkServer(
    configuration: SlowWalkServerConfiguration = .init()
) async throws {
    let application = makeSlowWalkApplication(configuration: configuration)
    try await application.runService()
}
