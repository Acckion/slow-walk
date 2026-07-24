import Foundation
import Hummingbird
import SlowWalkAPIContracts

/// Per-request Hummingbird context using the API contract's canonical JSON coders.
public struct SlowWalkRequestContext: RequestContext {
    public typealias Source = ApplicationRequestContextSource
    public typealias Decoder = JSONDecoder
    public typealias Encoder = JSONEncoder

    public var coreContext: CoreRequestContextStorage

    public init(source: Source) {
        coreContext = .init(source: source)
    }

    public var requestDecoder: JSONDecoder {
        SlowWalkJSONCoding.makeDecoder()
    }

    public var responseEncoder: JSONEncoder {
        SlowWalkJSONCoding.makeEncoder()
    }
}
