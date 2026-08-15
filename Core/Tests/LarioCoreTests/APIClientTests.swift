import XCTest
@testable import LarioCore

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Records requests and replays scripted responses.
final class StubTransport: HTTPTransport, @unchecked Sendable {
    struct Reply {
        let status: Int
        let body: Data
        let headers: [String: String]
        let error: Error?

        static func ok(_ json: String) -> Reply {
            Reply(status: 200, body: Data(json.utf8), headers: [:], error: nil)
        }
        static func status(_ code: Int, json: String = "{}", headers: [String: String] = [:]) -> Reply {
            Reply(status: code, body: Data(json.utf8), headers: headers, error: nil)
        }
        static func failure(_ error: Error) -> Reply {
            Reply(status: 0, body: Data(), headers: [:], error: error)
        }
    }

    private let lock = NSLock()
    private var replies: [Reply]
    private(set) var requests: [URLRequest] = []

    init(replies: [Reply]) { self.replies = replies }
    convenience init(reply: Reply) { self.init(replies: [reply]) }

    var requestCount: Int { lock.lock(); defer { lock.unlock() }; return requests.count }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        lock.lock()
        requests.append(request)
        // The last reply repeats, so retry tests do not need to pad the script.
        let reply = replies.count > 1 ? replies.removeFirst() : (replies.first ?? .ok("{}"))
        lock.unlock()

        if let error = reply.error { throw error }
        let response = HTTPURLResponse(
            url: request.url!, statusCode: reply.status,
            httpVersion: nil, headerFields: reply.headers
        )!
        return (reply.body, response)
    }
}

struct StubTokenProvider: TokenProviding, @unchecked Sendable {
    let token: String?
    let onRejected: @Sendable () -> Void

    init(token: String?, onRejected: @escaping @Sendable () -> Void = {}) {
        self.token = token
        self.onRejected = onRejected
    }

    func currentToken() async -> String? { token }
    func tokenRejected() async { onRejected() }
}

final class APIClientTests: XCTestCase {

    let baseURL = URL(string: "https://api.example.com")!

    func makeClient(
        _ transport: StubTransport,
        tokenProvider: any TokenProviding = NoTokenProvider(),
        maxRetries: Int = 2
    ) -> APIClient {
        APIClient(
            baseURL: baseURL, transport: transport, tokenProvider: tokenProvider,
            maxRetries: maxRetries,
            // No real waiting in tests.
            sleep: { _ in }
        )
    }

    struct Sample: Decodable, Equatable { let value: String }

    // MARK: - Success

    func testDecodesASuccessfulResponse() async throws {
        let transport = StubTransport(reply: .ok(#"{"value":"hello"}"#))
        let client = makeClient(transport)
        let result: Sample = try await client.get("api/v1/thing")
        XCTAssertEqual(result, Sample(value: "hello"))
    }

    func testBuildsPathAndSortedQuery() async throws {
        let transport = StubTransport(reply: .ok(#"{"value":"x"}"#))
        let client = makeClient(transport)
        _ = try await client.get("api/v1/places", query: ["per": "20", "lat": "45.8"]) as Sample

        let url = try XCTUnwrap(transport.requests.first?.url)
        XCTAssertEqual(url.path, "/api/v1/places")
        XCTAssertEqual(url.query, "lat=45.8&per=20", "Query order should be stable")
    }

    func testOmitsNilQueryValues() async throws {
        let transport = StubTransport(reply: .ok(#"{"value":"x"}"#))
        let client = makeClient(transport)
        _ = try await client.get("api/v1/places", query: ["lat": nil, "per": "10"]) as Sample

        let url = try XCTUnwrap(transport.requests.first?.url)
        XCTAssertEqual(url.query, "per=10")
    }

    // MARK: - Auth

    func testAttachesBearerTokenWhenAvailable() async throws {
        let transport = StubTransport(reply: .ok(#"{"value":"x"}"#))
        let client = makeClient(transport, tokenProvider: StubTokenProvider(token: "abc123"))
        _ = try await client.get("api/v1/auth/me") as Sample

        XCTAssertEqual(
            transport.requests.first?.value(forHTTPHeaderField: "Authorization"),
            "Bearer abc123"
        )
    }

    func testSendsNoAuthorizationHeaderWithoutAToken() async throws {
        let transport = StubTransport(reply: .ok(#"{"value":"x"}"#))
        let client = makeClient(transport)
        _ = try await client.get("api/v1/places") as Sample

        XCTAssertNil(transport.requests.first?.value(forHTTPHeaderField: "Authorization"))
    }

    func testUnauthorizedNotifiesTheTokenProvider() async {
        let rejected = Expectation()
        let transport = StubTransport(reply: .status(401))
        let client = makeClient(
            transport,
            tokenProvider: StubTokenProvider(token: "stale", onRejected: { rejected.fulfill() })
        )

        do {
            _ = try await client.get("api/v1/auth/me") as Sample
            XCTFail("Expected unauthorized")
        } catch {
            XCTAssertEqual(error as? ServiceError, .unauthorized)
        }
        XCTAssertTrue(rejected.isFulfilled, "A dead token must be reported so the app can clear it")
    }

    /// Minimal thread-safe flag; XCTestExpectation is awkward from async code.
    final class Expectation: @unchecked Sendable {
        private let lock = NSLock()
        private var fulfilled = false
        func fulfill() { lock.lock(); fulfilled = true; lock.unlock() }
        var isFulfilled: Bool { lock.lock(); defer { lock.unlock() }; return fulfilled }
    }

    // MARK: - Status mapping

    func testNotFoundMapsToNotFound() async {
        let client = makeClient(StubTransport(reply: .status(404)))
        do {
            _ = try await client.get("api/v1/places/x") as Sample
            XCTFail("Expected notFound")
        } catch {
            XCTAssertEqual(error as? ServiceError, .notFound)
        }
    }

    func testRateLimitCarriesRetryAfter() async {
        let client = makeClient(
            StubTransport(reply: .status(429, headers: ["Retry-After": "30"])),
            maxRetries: 0
        )
        do {
            _ = try await client.get("api/v1/places") as Sample
            XCTFail("Expected rateLimited")
        } catch {
            XCTAssertEqual(error as? ServiceError, .rateLimited(retryAfter: 30))
        }
    }

    func testServerErrorExtractsVaporReason() async {
        let client = makeClient(
            StubTransport(reply: .status(500, json: #"{"error":true,"reason":"boom"}"#)),
            maxRetries: 0
        )
        do {
            _ = try await client.get("api/v1/places") as Sample
            XCTFail("Expected server error")
        } catch {
            XCTAssertEqual(error as? ServiceError, .server(status: 500, message: "boom"))
        }
    }

    func testServerDetailNeverReachesTheUser() {
        let error = ServiceError.server(status: 500, message: "NullPointerException at line 42")
        XCTAssertFalse(error.userMessage.contains("NullPointer"))
    }

    func testMalformedJSONIsADecodingError() async {
        let client = makeClient(StubTransport(reply: .ok("not json at all")))
        do {
            _ = try await client.get("api/v1/places") as Sample
            XCTFail("Expected a decoding error")
        } catch {
            guard case .decoding = (error as? ServiceError) else {
                return XCTFail("Expected .decoding, got \(error)")
            }
        }
    }

    func testOfflineURLErrorMapsToOffline() async {
        let client = makeClient(
            StubTransport(reply: .failure(URLError(.notConnectedToInternet))),
            maxRetries: 0
        )
        do {
            _ = try await client.get("api/v1/places") as Sample
            XCTFail("Expected offline")
        } catch {
            XCTAssertEqual(error as? ServiceError, .offline)
        }
    }

    func testTimeoutMapsToTimedOut() async {
        let client = makeClient(StubTransport(reply: .failure(URLError(.timedOut))), maxRetries: 0)
        do {
            _ = try await client.get("api/v1/places") as Sample
            XCTFail("Expected timedOut")
        } catch {
            XCTAssertEqual(error as? ServiceError, .timedOut)
        }
    }

    // MARK: - Retries

    func testRetriesRetryableGetAndSucceeds() async throws {
        let transport = StubTransport(replies: [
            .failure(URLError(.networkConnectionLost)),
            .ok(#"{"value":"recovered"}"#),
        ])
        let client = makeClient(transport)
        let result: Sample = try await client.get("api/v1/places")

        XCTAssertEqual(result, Sample(value: "recovered"))
        XCTAssertEqual(transport.requestCount, 2)
    }

    func testStopsAfterMaxRetries() async {
        let transport = StubTransport(reply: .failure(URLError(.notConnectedToInternet)))
        let client = makeClient(transport, maxRetries: 2)
        do {
            _ = try await client.get("api/v1/places") as Sample
            XCTFail("Expected failure")
        } catch {
            XCTAssertEqual(error as? ServiceError, .offline)
        }
        XCTAssertEqual(transport.requestCount, 3, "One initial attempt plus two retries")
    }

    func testDoesNotRetryNonRetryableStatuses() async {
        let transport = StubTransport(reply: .status(404))
        let client = makeClient(transport)
        _ = try? await client.get("api/v1/places") as Sample
        XCTAssertEqual(transport.requestCount, 1, "A 404 will not become a 200")
    }

    func testDoesNotRetryPOST() async {
        // A retried POST can create a duplicate account or booking.
        struct Body: Encodable { let email: String }
        let transport = StubTransport(reply: .failure(URLError(.networkConnectionLost)))
        let client = makeClient(transport)
        _ = try? await client.post("api/v1/auth/register", body: Body(email: "a@b.com")) as Sample
        XCTAssertEqual(transport.requestCount, 1, "Non-idempotent requests must never be retried")
    }

    // MARK: - Dates

    func testDecodesISO8601WithAndWithoutFractionalSeconds() throws {
        struct Holder: Decodable { let when: Date }
        let decoder = APIClient.makeDecoder()

        let plain = try decoder.decode(Holder.self, from: Data(#"{"when":"2026-08-15T10:00:00Z"}"#.utf8))
        let fractional = try decoder.decode(Holder.self, from: Data(#"{"when":"2026-08-15T10:00:00.500Z"}"#.utf8))

        XCTAssertEqual(fractional.when.timeIntervalSince(plain.when), 0.5, accuracy: 0.01)
    }

    func testRejectsAnUnparseableDate() {
        struct Holder: Decodable { let when: Date }
        XCTAssertThrowsError(
            try APIClient.makeDecoder().decode(Holder.self, from: Data(#"{"when":"yesterday"}"#.utf8))
        )
    }
}

// MARK: - Service mapping

final class APIServiceMappingTests: XCTestCase {

    func testChoosesTheCollectionEndpointMatchingTheKinds() {
        XCTAssertEqual(APIPlaceService.path(for: [.attraction]), "api/v1/attractions")
        XCTAssertEqual(APIPlaceService.path(for: [.restaurant]), "api/v1/restaurants")
        XCTAssertEqual(APIPlaceService.path(for: [.event, .experience]), "api/v1/events")
        XCTAssertEqual(APIPlaceService.path(for: []), "api/v1/places")
        XCTAssertEqual(APIPlaceService.path(for: [.attraction, .restaurant]), "api/v1/places")
    }

    func testDoesNotSendKindWhenThePathImpliesIt() {
        let query = PlaceQuery(kinds: [.restaurant])
        let parameters = APIPlaceService.parameters(for: query, page: 1, per: 20)
        XCTAssertNil(parameters["kind"] ?? nil, "The restaurants endpoint already filters by kind")
    }

    func testSendsKindOnTheGenericEndpoint() {
        let query = PlaceQuery(kinds: [.attraction, .restaurant])
        let parameters = APIPlaceService.parameters(for: query, page: 1, per: 20)
        XCTAssertEqual(parameters["kind"] ?? nil, "attraction,restaurant")
    }

    func testMapsFiltersToQueryParameters() {
        var query = PlaceQuery(text: "piona", minimumRating: 4.5, maximumPriceLevel: .moderate)
        query.origin = Coordinate(latitude: 45.85, longitude: 9.39)
        query.maximumDistance = 5000
        query.featuredOnly = true
        query.sort = .distance

        let parameters = APIPlaceService.parameters(for: query, page: 2, per: 30)
        XCTAssertEqual(parameters["search"] ?? nil, "piona")
        XCTAssertEqual(parameters["minRating"] ?? nil, "4.5")
        XCTAssertEqual(parameters["maxPrice"] ?? nil, "2")
        XCTAssertEqual(parameters["featured"] ?? nil, "true")
        XCTAssertEqual(parameters["radius"] ?? nil, "5000.0")
        XCTAssertEqual(parameters["sort"] ?? nil, "distance")
        XCTAssertEqual(parameters["page"] ?? nil, "2")
        XCTAssertEqual(parameters["per"] ?? nil, "30")
        XCTAssertNotNil(parameters["lat"] ?? nil)
    }

    func testBlankSearchTextIsNotSent() {
        let parameters = APIPlaceService.parameters(for: PlaceQuery(text: "   "), page: 1, per: 20)
        XCTAssertNil(parameters["search"] ?? nil)
    }

    func testUnknownEnumValuesDecodeToASafeDefault() throws {
        // A server that adds a new category must not blank the map for clients
        // already in the App Store.
        let json = """
        {"id":"\(UUID().uuidString)","kind":"teleporter","name":"X","tagline":"","summary":"",
         "about":"","category":"interdimensional","coordinate":{"latitude":45.8,"longitude":9.4},
         "address":null,"region":"Lecco","imageNames":[],"rating":null,"reviewCount":0,
         "priceLevel":null,"visitDuration":null,"website":null,"phone":null,"tags":[],
         "isFeatured":false,"dining":null,"schedule":null,"distance":null,
         "createdAt":null,"updatedAt":null}
        """
        let dto = try APIClient.makeDecoder().decode(PlaceDTO.self, from: Data(json.utf8))
        XCTAssertEqual(dto.place.kind, .attraction)
        XCTAssertEqual(dto.place.category, .landmark)
    }
}

// MARK: - Fallback and factory

final class FallbackServiceTests: XCTestCase {

    struct FailingService: PlaceServing {
        let error: ServiceError
        func places(matching query: PlaceQuery, page: Int, per: Int) async throws -> PlacePage { throw error }
        func place(id: UUID, from origin: Coordinate?) async throws -> Place { throw error }
        func discoveryFeed(near origin: Coordinate?) async throws -> DiscoveryFeed { throw error }
    }

    func testFallsBackWhenTheNetworkFails() async throws {
        let service = FallbackPlaceService(
            primary: FailingService(error: .offline),
            fallback: MockPlaceService(behaviour: .immediate)
        )
        let page = try await service.places(matching: PlaceQuery(), page: 1, per: 5)
        XCTAssertEqual(page.results.count, 5, "Mock content should cover for an offline API")
    }

    func testDoesNotMaskNotFound() async {
        // Substituting invented content for "this no longer exists" would be
        // actively misleading.
        let service = FallbackPlaceService(
            primary: FailingService(error: .notFound),
            fallback: MockPlaceService(behaviour: .immediate)
        )
        do {
            _ = try await service.place(id: UUID(), from: nil)
            XCTFail("Expected notFound to pass through")
        } catch {
            XCTAssertEqual(error as? ServiceError, .notFound)
        }
    }

    func testDoesNotMaskUnauthorized() async {
        let service = FallbackPlaceService(
            primary: FailingService(error: .unauthorized),
            fallback: MockPlaceService(behaviour: .immediate)
        )
        do {
            _ = try await service.places(matching: PlaceQuery(), page: 1, per: 5)
            XCTFail("Expected unauthorized to pass through")
        } catch {
            XCTAssertEqual(error as? ServiceError, .unauthorized)
        }
    }

    func testFactoryBuildsMockServicesByDefault() throws {
        let factory = try ServiceFactory(configuration: .testing)
        XCTAssertTrue(factory.places is MockPlaceService)
    }

    func testFactoryRejectsLiveWithoutABaseURL() {
        XCTAssertThrowsError(
            try ServiceFactory(configuration: AppConfiguration(dataSource: .live, apiBaseURL: nil))
        )
    }

    func testFactoryWrapsLiveServiceForFallbackMode() throws {
        let config = AppConfiguration(
            dataSource: .liveWithMockFallback,
            apiBaseURL: URL(string: "https://api.example.com")!
        )
        let factory = try ServiceFactory(configuration: config)
        XCTAssertTrue(factory.places is FallbackPlaceService)
    }
}
