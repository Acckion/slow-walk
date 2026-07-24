import Hummingbird
import SlowWalkDataInterfaces
import SlowWalkMedicinePipeline
import SlowWalkRiskEngine

public func makeSlowWalkApplication(
    configuration: SlowWalkServerConfiguration = .init(),
    riskEngine: any RiskAssessing = MedicationRiskEngine(),
    dateProvider: any DateProviding = SystemDateProvider(),
    uuidProvider: any UUIDProviding = SystemUUIDProvider(),
    medicineCatalogLoader: any MedicineCatalogLoading =
        BundledDemoMedicineCatalogLoader(),
    medicineCache: any MedicineCache = InMemoryMedicineCache()
) throws -> some ApplicationProtocol {
    // Validate the bundled catalog at composition time. A missing or unsafe
    // resource prevents startup instead of silently serving an empty catalog.
    _ = try medicineCatalogLoader.loadCatalog()

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

    let medicinePipeline = MedicinePipeline(
        catalogLoader: medicineCatalogLoader,
        cache: medicineCache,
        dateProvider: dateProvider,
        uuidProvider: uuidProvider,
        riskAssessor: riskEngine
    )
    let medicineController = MedicinePipelineController(
        pipeline: medicinePipeline,
        uuidProvider: uuidProvider
    )
    router.post("/api/v1/medicine/resolve") { request, context in
        try await medicineController.resolve(
            request: request,
            context: context
        )
    }
    router.post("/api/v1/medicine/assess") { request, context in
        try await medicineController.assess(
            request: request,
            context: context
        )
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
    let application = try makeSlowWalkApplication(
        configuration: configuration
    )
    try await application.runService()
}
