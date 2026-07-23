import Hummingbird
import SlowWalkAPIContracts

public struct HealthResponseDTO: Codable, Sendable, Equatable, ResponseEncodable {
    public let status: String
    public let service: String
    public let apiVersion: String

    public init(
        status: String = "ok",
        service: String = "slow-walk-server",
        apiVersion: String = SlowWalkAPI.version
    ) {
        self.status = status
        self.service = service
        self.apiVersion = apiVersion
    }
}
