public struct SlowWalkServerConfiguration: Sendable, Equatable {
    public let host: String
    public let port: Int
    public let serverName: String

    public init(
        host: String = "127.0.0.1",
        port: Int = 8080,
        serverName: String = "slow-walk-server"
    ) {
        self.host = host
        self.port = port
        self.serverName = serverName
    }
}
