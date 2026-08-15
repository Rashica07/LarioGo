// URL/URLSession are Sendable on Apple platforms but not in
// swift-corelibs-foundation, which is what CI builds against.
@preconcurrency import Foundation

/// Where the app gets its content.
///
/// **This toggle is intentional and stays until further notice.** LarioGo ships
/// with a large mock catalogue so the whole product can be exercised — every
/// screen, filter, empty state and failure path — without a backend, real
/// listings, or signed sponsors. It flips to `.live` when v1.0 has licensed
/// content and real partner data.
///
/// Do not delete this on the grounds that "the API works now". Mock mode is how
/// demos, screenshots, offline development and UI tests stay reliable.
public enum DataSourceMode: String, CaseIterable, Sendable, Codable {
    /// Bundled catalogue. No network at all.
    case mock
    /// The real backend.
    case live
    /// Live backend, falling back to mock when it cannot be reached.
    ///
    /// Useful for demos on unreliable connections. Never appropriate for
    /// release: silently serving invented restaurants when the API is down
    /// would present sample data as real listings.
    case liveWithMockFallback

    public var usesNetwork: Bool { self != .mock }

    public var canFallBackToMock: Bool { self == .liveWithMockFallback }

    public var displayName: String {
        switch self {
        case .mock: return "Mock data"
        case .live: return "Live API"
        case .liveWithMockFallback: return "Live with mock fallback"
        }
    }

    /// Whether content from this mode may be presented as verified real-world
    /// information. Mock content must always be labelled as sample data.
    public var servesVerifiedContent: Bool { self == .live }
}

/// How mock services behave, so failure paths can be exercised deliberately.
///
/// Every screen needs a loading, empty and error state. Without a way to force
/// them, those states get written once and never looked at again.
public struct MockBehaviour: Hashable, Sendable, Codable {
    /// Artificial delay per request, to make loading states visible.
    public var latency: TimeInterval
    /// Fraction of requests that fail, 0...1.
    public var failureRate: Double
    /// When set, every request fails with this error.
    public var forcedError: ForcedError?
    /// Serve an empty catalogue, to exercise empty states.
    public var returnsEmptyResults: Bool

    public init(
        latency: TimeInterval = 0,
        failureRate: Double = 0,
        forcedError: ForcedError? = nil,
        returnsEmptyResults: Bool = false
    ) {
        self.latency = latency
        self.failureRate = failureRate
        self.forcedError = forcedError
        self.returnsEmptyResults = returnsEmptyResults
    }

    public enum ForcedError: String, CaseIterable, Sendable, Codable {
        case offline, timedOut, unauthorized, server, notFound

        public var serviceError: ServiceError {
            switch self {
            case .offline: return .offline
            case .timedOut: return .timedOut
            case .unauthorized: return .unauthorized
            case .server: return .server(status: 500, message: nil)
            case .notFound: return .notFound
            }
        }
    }

    /// Instant and reliable. The default for tests.
    public static let immediate = MockBehaviour()

    /// Realistic pacing, for demos and for seeing loading states.
    public static let realistic = MockBehaviour(latency: 0.4)

    /// Flaky, for exercising retry and error handling.
    public static let unreliable = MockBehaviour(latency: 0.3, failureRate: 0.35)

    public static let alwaysOffline = MockBehaviour(forcedError: .offline)

    public static let empty = MockBehaviour(returnsEmptyResults: true)
}

/// Runtime configuration.
///
/// A value type rather than a global. The app holds one and injects it, so tests
/// and previews can construct any combination without mutating shared state.
public struct AppConfiguration: Sendable {
    public var dataSource: DataSourceMode
    public var mockBehaviour: MockBehaviour
    public var apiBaseURL: URL?

    public init(
        dataSource: DataSourceMode = .mock,
        mockBehaviour: MockBehaviour = .realistic,
        apiBaseURL: URL? = nil
    ) {
        self.dataSource = dataSource
        self.mockBehaviour = mockBehaviour
        self.apiBaseURL = apiBaseURL
    }

    /// Whether the UI must label content as sample data.
    ///
    /// True whenever content could have come from the mock catalogue — including
    /// fallback mode, where the user cannot otherwise tell.
    public var mustLabelContentAsSample: Bool {
        !dataSource.servesVerifiedContent
    }

    /// The default until v1.0 has real content and sponsors.
    public static let current = AppConfiguration(dataSource: .mock, mockBehaviour: .realistic)

    /// Deterministic and instant, for unit tests.
    public static let testing = AppConfiguration(dataSource: .mock, mockBehaviour: .immediate)

    /// Points at a live backend. Requires a base URL.
    public static func live(baseURL: URL) -> AppConfiguration {
        AppConfiguration(dataSource: .live, mockBehaviour: .immediate, apiBaseURL: baseURL)
    }

    /// Validation so a misconfigured build fails loudly at startup rather than
    /// on the first request the user makes.
    public func validate() throws {
        if dataSource.usesNetwork && apiBaseURL == nil {
            throw ConfigurationError.missingBaseURL(mode: dataSource)
        }
    }

    public enum ConfigurationError: Error, Equatable, CustomStringConvertible {
        case missingBaseURL(mode: DataSourceMode)

        public var description: String {
            switch self {
            case .missingBaseURL(let mode):
                return "Data source is \(mode.rawValue) but no apiBaseURL was configured."
            }
        }
    }
}
