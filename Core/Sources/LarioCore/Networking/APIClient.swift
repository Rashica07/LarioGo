import Foundation

#if canImport(FoundationNetworking)
// swift-corelibs-foundation splits URLSession into a separate module on Linux
// and Windows. Without this the package builds on Apple platforms only, which
// would defeat the point of keeping LarioCore platform-independent.
import FoundationNetworking
#endif

/// The subset of URLSession the client needs.
///
/// An abstraction so transport behaviour — status mapping, retries, token
/// refresh — can be tested without a network or a live server.
public protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

public struct URLSessionTransport: HTTPTransport {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ServiceError.unknown("Response was not HTTP.")
        }
        return (data, http)
    }
}

/// Supplies the bearer token for authenticated requests, and is told when the
/// server rejects it so the app can clear a dead session.
public protocol TokenProviding: Sendable {
    func currentToken() async -> String?
    func tokenRejected() async
}

/// No authentication. Discovery endpoints are public.
public struct NoTokenProvider: TokenProviding {
    public init() {}
    public func currentToken() async -> String? { nil }
    public func tokenRejected() async {}
}

public enum HTTPMethod: String, Sendable {
    case get = "GET", post = "POST", patch = "PATCH", delete = "DELETE"
}

/// Centralised API access.
///
/// Every request in the app goes through here: no `URLSession` in views, no
/// duplicated status-code handling, one place that knows about auth and retries.
public struct APIClient: Sendable {
    public let baseURL: URL
    private let transport: any HTTPTransport
    private let tokenProvider: any TokenProviding
    private let maxRetries: Int
    /// Injected so retry backoff does not make tests slow.
    private let sleep: @Sendable (TimeInterval) async throws -> Void

    public init(
        baseURL: URL,
        transport: any HTTPTransport = URLSessionTransport(),
        tokenProvider: any TokenProviding = NoTokenProvider(),
        maxRetries: Int = 2,
        sleep: @escaping @Sendable (TimeInterval) async throws -> Void = { seconds in
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        }
    ) {
        self.baseURL = baseURL
        self.transport = transport
        self.tokenProvider = tokenProvider
        self.maxRetries = maxRetries
        self.sleep = sleep
    }

    // MARK: - Coding

    /// Matches the Vapor backend, which encodes dates as ISO-8601.
    public static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]

        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let text = try container.decode(String.self)
            // Fractional seconds are present or absent depending on the value,
            // so try both rather than failing the whole response on a mismatch.
            if let date = withFraction.date(from: text) ?? plain.date(from: text) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "Unrecognised date format: \(text)"
            )
        }
        return decoder
    }

    public static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    // MARK: - Requests

    public func get<Response: Decodable>(
        _ path: String,
        query: [String: String?] = [:],
        as type: Response.Type = Response.self
    ) async throws -> Response {
        try await send(path, method: .get, query: query, body: Optional<Empty>.none)
    }

    public func post<Body: Encodable, Response: Decodable>(
        _ path: String,
        body: Body,
        as type: Response.Type = Response.self
    ) async throws -> Response {
        try await send(path, method: .post, query: [:], body: body)
    }

    public func delete(_ path: String) async throws {
        _ = try await send(path, method: .delete, query: [:], body: Optional<Empty>.none) as EmptyResponse
    }

    private struct Empty: Encodable {}
    /// Decodes any body, including none, for requests whose result is ignored.
    private struct EmptyResponse: Decodable {
        init() {}
        init(from decoder: Decoder) throws {}
    }

    private func send<Body: Encodable, Response: Decodable>(
        _ path: String,
        method: HTTPMethod,
        query: [String: String?],
        body: Body?
    ) async throws -> Response {
        var attempt = 0
        while true {
            do {
                return try await perform(path, method: method, query: query, body: body)
            } catch let error as ServiceError {
                attempt += 1
                // Only retry what could plausibly succeed on a second try, and
                // never retry a non-idempotent method — a retried POST can
                // create a duplicate booking.
                guard error.isRetryable, method == .get, attempt <= maxRetries else {
                    throw error
                }
                // Exponential backoff: 0.5s, then 1s.
                try await sleep(0.5 * pow(2, Double(attempt - 1)))
            }
        }
    }

    private func perform<Body: Encodable, Response: Decodable>(
        _ path: String,
        method: HTTPMethod,
        query: [String: String?],
        body: Body?
    ) async throws -> Response {
        guard var components = URLComponents(
            url: baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        ) else {
            throw ServiceError.unknown("Could not build a URL for \(path).")
        }

        let items = query.compactMap { key, value in
            value.map { URLQueryItem(name: key, value: $0) }
        }.sorted { $0.name < $1.name }   // stable ordering keeps tests readable
        if !items.isEmpty { components.queryItems = items }

        guard let url = components.url else {
            throw ServiceError.unknown("Could not build a URL for \(path).")
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 20

        if let body {
            request.httpBody = try Self.makeEncoder().encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if let token = await tokenProvider.currentToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let data: Data
        let response: HTTPURLResponse
        do {
            (data, response) = try await transport.send(request)
        } catch let error as ServiceError {
            throw error
        } catch is CancellationError {
            throw ServiceError.cancelled
        } catch let error as URLError {
            throw Self.mapURLError(error)
        } catch {
            throw ServiceError.unknown(error.localizedDescription)
        }

        switch response.statusCode {
        case 200..<300:
            if Response.self == EmptyResponse.self { return EmptyResponse() as! Response }
            do {
                return try Self.makeDecoder().decode(Response.self, from: data)
            } catch {
                throw ServiceError.decoding(String(describing: error))
            }
        case 401:
            // Tell the session holder before surfacing, so the app can clear a
            // dead token rather than retrying with it forever.
            await tokenProvider.tokenRejected()
            throw ServiceError.unauthorized
        case 404:
            throw ServiceError.notFound
        case 429:
            let retryAfter = response.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init)
            throw ServiceError.rateLimited(retryAfter: retryAfter)
        default:
            throw ServiceError.server(
                status: response.statusCode,
                message: Self.serverMessage(from: data)
            )
        }
    }

    /// Vapor's error middleware returns `{"error": true, "reason": "..."}`.
    static func serverMessage(from data: Data) -> String? {
        struct VaporError: Decodable { let reason: String? }
        return (try? JSONDecoder().decode(VaporError.self, from: data))?.reason
    }

    static func mapURLError(_ error: URLError) -> ServiceError {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed,
             .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed:
            return .offline
        case .timedOut:
            return .timedOut
        case .cancelled:
            return .cancelled
        default:
            return .unknown(error.localizedDescription)
        }
    }
}
