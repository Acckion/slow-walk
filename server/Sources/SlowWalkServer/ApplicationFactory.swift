import Hummingbird
import SlowWalkAPIContracts
import SlowWalkDataInterfaces
import SlowWalkLocationRisk
import SlowWalkMedicineKnowledge
import SlowWalkMedicinePipeline
import SlowWalkRiskEngine

public func makeSlowWalkApplication(
    configuration: SlowWalkServerConfiguration = .init(),
    riskEngine: any RiskAssessing = MedicationRiskEngine(),
    dateProvider: any DateProviding = SystemDateProvider(),
    uuidProvider: any UUIDProviding = SystemUUIDProvider(),
    medicineCatalogLoader: any MedicineCatalogLoading =
        BundledDemoMedicineCatalogLoader(),
    medicineCache: any MedicineCache = InMemoryMedicineCache(),
    medicineKnowledgeSearcher:
        (any MedicineKnowledgeSearching)? = nil,
    locationRiskAssessor:
        (any LocationRiskAssessing)? = nil,
    locationRiskConfiguration:
        LocationRiskConfiguration = .demo
) throws -> some ApplicationProtocol {
    // Validate the bundled catalog at composition time. A missing or unsafe
    // resource prevents startup instead of silently serving an empty catalog.
    let medicineCatalog =
        try medicineCatalogLoader.loadCatalog()
    let configuredKnowledgeSearcher:
        any MedicineKnowledgeSearching
    if let medicineKnowledgeSearcher {
        configuredKnowledgeSearcher =
            medicineKnowledgeSearcher
    } else {
        let transport = DemoMockHTTPTransport(
            medicines: medicineCatalog.medicines,
            fetchedAt: dateProvider.now()
        )
        let sources: [any MedicineKnowledgeSource] = [
            try MockAuthoritativeMedicineSource(
                transport: transport,
                clock: dateProvider
            ),
            try MockSecondaryMedicineSource(
                transport: transport,
                clock: dateProvider
            ),
        ]
        configuredKnowledgeSearcher =
            try MedicineKnowledgeService(
                sources: sources,
                policy: .demo,
                clock: dateProvider
            )
    }

    let router = Router(context: SlowWalkRequestContext.self)
    router.middlewares.add(LogRequestsMiddleware(.info))

    router.get("/health") { _, _ in
        HealthResponseDTO()
    }

    let medicinePipeline = MedicinePipeline(
        catalogLoader: medicineCatalogLoader,
        cache: medicineCache,
        dateProvider: dateProvider,
        uuidProvider: uuidProvider,
        riskAssessor: riskEngine,
        knowledgeSearcher:
            configuredKnowledgeSearcher
    )
    let medicineController = MedicinePipelineController(
        pipeline: medicinePipeline,
        uuidProvider: uuidProvider,
        knowledgeSearcher:
            configuredKnowledgeSearcher
    )
    router.post(SlowWalkAPI.Endpoint.medicineSearch.path) {
        request,
        context in
        try await medicineController.search(
            request: request,
            context: context
        )
    }
    router.post(SlowWalkAPI.Endpoint.medicineResolve.path) {
        request,
        context in
        try await medicineController.resolve(
            request: request,
            context: context
        )
    }
    router.post(SlowWalkAPI.Endpoint.medicineAssess.path) {
        request,
        context in
        try await medicineController.assess(
            request: request,
            context: context
        )
    }

    let configuredLocationRiskAssessor:
        any LocationRiskAssessing =
        locationRiskAssessor
        ?? LocationRiskEngine(
            clock: dateProvider,
            configuration: locationRiskConfiguration
        )
    let locationController = LocationAssessmentController(
        assessor: configuredLocationRiskAssessor,
        validator: LocationAssessmentRequestValidator(
            configuration: locationRiskConfiguration
        ),
        dateProvider: dateProvider,
        uuidProvider: uuidProvider
    )
    router.post(SlowWalkAPI.Endpoint.locationAssess.path) {
        request,
        context in
        try await locationController.handle(
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
