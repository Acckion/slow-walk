import SlowWalkServer

@main
enum SlowWalkServerMain {
    static func main() async throws {
        try await runSlowWalkServer()
    }
}
