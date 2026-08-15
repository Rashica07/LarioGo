import Foundation

// MARK: - Wire format

/// Mirrors the backend's `PlaceResponse`.
///
/// Kept separate from `Place` on purpose: the domain model should not change
/// shape because the API did. Anything unrecognised decodes to a safe default
/// rather than failing the whole response — one new category value on the server
/// must not blank the map for every shipped client.
struct PlaceDTO: Decodable {
    let id: UUID
    let kind: String
    let name: String
    let tagline: String
    let summary: String
    let about: String
    let category: String
    let coordinate: CoordinateDTO
    let address: String?
    let region: String
    let imageNames: [String]
    let rating: Double?
    let reviewCount: Int
    let priceLevel: Int?
    let visitDuration: String?
    let website: String?
    let phone: String?
    let tags: [String]
    let isFeatured: Bool
    let dining: DiningDTO?
    let schedule: ScheduleDTO?
    let distance: Double?
    let createdAt: Date?
    let updatedAt: Date?

    struct CoordinateDTO: Decodable {
        let latitude: Double
        let longitude: Double
    }
    struct DiningDTO: Decodable {
        let cuisines: [String]
        let acceptsReservations: Bool
    }
    struct ScheduleDTO: Decodable {
        let startDate: Date
        let endDate: Date?
        let organizer: String?
    }

    var place: Place {
        Place(
            id: id,
            kind: PlaceKind(rawValue: kind) ?? .attraction,
            name: name, tagline: tagline, summary: summary, about: about,
            category: PlaceCategory(rawValue: category) ?? .landmark,
            coordinate: Coordinate(latitude: coordinate.latitude, longitude: coordinate.longitude),
            address: address, region: region, imageNames: imageNames,
            rating: rating, reviewCount: reviewCount,
            priceLevel: priceLevel.flatMap(PriceLevel.init(rawValue:)),
            visitDuration: visitDuration,
            website: website.flatMap(URL.init(string:)),
            phone: phone, tags: tags, isFeatured: isFeatured,
            dining: dining.map { DiningDetails(cuisines: $0.cuisines, acceptsReservations: $0.acceptsReservations) },
            schedule: schedule.map { EventSchedule(startDate: $0.startDate, endDate: $0.endDate, organizer: $0.organizer) },
            createdAt: createdAt, updatedAt: updatedAt
        )
    }

    var result: PlaceResult { PlaceResult(place: place, distance: distance) }
}

struct PageDTO<Item: Decodable>: Decodable {
    let items: [Item]
    let metadata: Metadata

    struct Metadata: Decodable {
        let page: Int
        let per: Int
        let total: Int
    }
}

struct AuthResponseDTO: Decodable {
    let token: String
    let expiresIn: Int
    let user: UserDTO
}

struct UserDTO: Decodable {
    let id: UUID
    let email: String
    let displayName: String
    let createdAt: Date?

    var profile: UserProfile {
        UserProfile(id: id, email: email, displayName: displayName, joinedAt: createdAt)
    }
}

// MARK: - Places

public struct APIPlaceService: PlaceServing {
    private let client: APIClient

    public init(client: APIClient) {
        self.client = client
    }

    public func places(matching query: PlaceQuery, page: Int, per: Int) async throws -> PlacePage {
        let response: PageDTO<PlaceDTO> = try await client.get(
            Self.path(for: query.kinds),
            query: Self.parameters(for: query, page: page, per: per)
        )
        return PlacePage(
            results: response.items.map(\.result),
            page: response.metadata.page,
            per: response.metadata.per,
            total: response.metadata.total
        )
    }

    public func place(id: UUID, from origin: Coordinate?) async throws -> Place {
        let dto: PlaceDTO = try await client.get(
            "api/v1/places/\(id.uuidString)",
            query: [
                "lat": origin.map { String($0.latitude) },
                "lon": origin.map { String($0.longitude) },
            ]
        )
        return dto.place
    }

    public func discoveryFeed(near origin: Coordinate?) async throws -> DiscoveryFeed {
        // Five independent reads, so run them concurrently rather than paying
        // five round trips in sequence on a phone connection.
        async let featured = section(PlaceQuery(featuredOnly: true, sort: .rating), origin: origin, limit: 8)
        async let nearby = origin == nil
            ? emptySection()
            : section(PlaceQuery(sort: .distance), origin: origin, limit: 12)
        async let topRated = section(PlaceQuery(minimumRating: 4.5, sort: .rating), origin: origin, limit: 12)
        async let restaurants = section(PlaceQuery(kinds: [.restaurant], sort: .rating), origin: origin, limit: 12)
        async let soon = upcoming(origin: origin, limit: 10)

        return DiscoveryFeed(
            featured: try await featured,
            nearby: try await nearby,
            topRated: try await topRated,
            happeningSoon: try await soon,
            restaurants: try await restaurants
        )
    }

    private func emptySection() async throws -> [PlaceResult] { [] }

    private func section(_ query: PlaceQuery, origin: Coordinate?, limit: Int) async throws -> [PlaceResult] {
        var query = query
        query.origin = origin
        return try await places(matching: query, page: 1, per: limit).results
    }

    private func upcoming(origin: Coordinate?, limit: Int) async throws -> [PlaceResult] {
        let now = Date()
        var query = PlaceQuery(kinds: [.event, .experience], origin: origin, sort: .relevance)
        query.dateRange = now...now.addingTimeInterval(7 * 86_400)
        return try await places(matching: query, page: 1, per: limit).results
    }

    /// Uses the collection endpoint matching the requested kinds, so the server
    /// filters rather than the client over-fetching and discarding.
    static func path(for kinds: Set<PlaceKind>) -> String {
        if kinds == [.attraction] { return "api/v1/attractions" }
        if kinds == [.restaurant] { return "api/v1/restaurants" }
        if kinds == [.event] || kinds == [.experience] || kinds == [.event, .experience] {
            return "api/v1/events"
        }
        return "api/v1/places"
    }

    static func parameters(for query: PlaceQuery, page: Int, per: Int) -> [String: String?] {
        var parameters: [String: String?] = [
            "page": String(page),
            "per": String(per),
            "sort": query.sort.wireValue,
        ]

        // Only send `kind` when the chosen path does not already imply it.
        if path(for: query.kinds) == "api/v1/places", !query.kinds.isEmpty {
            parameters["kind"] = query.kinds.map(\.rawValue).sorted().joined(separator: ",")
        }
        if let category = query.categories.first, query.categories.count == 1 {
            parameters["category"] = category.rawValue
        }
        if !query.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parameters["search"] = query.text
        }
        if let rating = query.minimumRating { parameters["minRating"] = String(rating) }
        if let price = query.maximumPriceLevel { parameters["maxPrice"] = String(price.rawValue) }
        if let cuisine = query.cuisines.first, query.cuisines.count == 1 {
            parameters["cuisine"] = cuisine
        }
        if query.featuredOnly { parameters["featured"] = "true" }
        if let origin = query.origin {
            parameters["lat"] = String(origin.latitude)
            parameters["lon"] = String(origin.longitude)
        }
        if let radius = query.maximumDistance { parameters["radius"] = String(radius) }
        if let range = query.dateRange {
            let formatter = ISO8601DateFormatter()
            parameters["startsAfter"] = formatter.string(from: range.lowerBound)
            parameters["startsBefore"] = formatter.string(from: range.upperBound)
        }
        return parameters
    }
}

extension PlaceSort {
    /// The backend accepts the same names, except `relevance`, which it also
    /// understands. Kept explicit so a rename on either side is a compile error
    /// rather than a silently ignored parameter.
    var wireValue: String {
        switch self {
        case .relevance: return "relevance"
        case .distance: return "distance"
        case .rating: return "rating"
        case .priceLowToHigh: return "priceLowToHigh"
        case .name: return "name"
        }
    }
}

// MARK: - Auth

public struct APIAuthService: AuthServing {
    private let client: APIClient

    public init(client: APIClient) {
        self.client = client
    }

    public func register(email: String, password: String, displayName: String) async throws -> AuthSession {
        struct Body: Encodable {
            let email: String, password: String, displayName: String
        }
        let response: AuthResponseDTO = try await client.post(
            "api/v1/auth/register",
            body: Body(email: email, password: password, displayName: displayName)
        )
        return response.session
    }

    public func login(email: String, password: String) async throws -> AuthSession {
        struct Body: Encodable { let email: String, password: String }
        let response: AuthResponseDTO = try await client.post(
            "api/v1/auth/login",
            body: Body(email: email, password: password)
        )
        return response.session
    }

    public func currentUser(token: String) async throws -> UserProfile {
        let dto: UserDTO = try await client.get("api/v1/auth/me")
        return dto.profile
    }
}

extension AuthResponseDTO {
    var session: AuthSession {
        AuthSession(
            token: token,
            expiresAt: Date().addingTimeInterval(TimeInterval(expiresIn)),
            user: user.profile
        )
    }
}

// MARK: - Fallback

/// Serves from `primary`, dropping to `fallback` when the network fails.
///
/// Only used in ``DataSourceMode/liveWithMockFallback``. It never masks a
/// *semantic* failure — a 404 or a 401 passes straight through, because
/// substituting invented content for "this no longer exists" or "please sign in"
/// would be actively misleading.
public struct FallbackPlaceService: PlaceServing {
    private let primary: any PlaceServing
    private let fallback: any PlaceServing

    public init(primary: any PlaceServing, fallback: any PlaceServing) {
        self.primary = primary
        self.fallback = fallback
    }

    private func attempt<T>(
        _ operation: () async throws -> T,
        orFallBackTo recovery: () async throws -> T
    ) async throws -> T {
        do {
            return try await operation()
        } catch let error as ServiceError where error.isRetryable {
            return try await recovery()
        }
    }

    public func places(matching query: PlaceQuery, page: Int, per: Int) async throws -> PlacePage {
        try await attempt(
            { try await primary.places(matching: query, page: page, per: per) },
            orFallBackTo: { try await fallback.places(matching: query, page: page, per: per) }
        )
    }

    public func place(id: UUID, from origin: Coordinate?) async throws -> Place {
        try await attempt(
            { try await primary.place(id: id, from: origin) },
            orFallBackTo: { try await fallback.place(id: id, from: origin) }
        )
    }

    public func discoveryFeed(near origin: Coordinate?) async throws -> DiscoveryFeed {
        try await attempt(
            { try await primary.discoveryFeed(near: origin) },
            orFallBackTo: { try await fallback.discoveryFeed(near: origin) }
        )
    }
}

// MARK: - Factory

/// Builds the service set for a configuration.
///
/// One place decides mock versus live, so no view or view model ever has to.
public struct ServiceFactory: Sendable {
    public let configuration: AppConfiguration
    public let places: any PlaceServing
    public let auth: any AuthServing

    public init(
        configuration: AppConfiguration,
        transport: (any HTTPTransport)? = nil,
        tokenProvider: any TokenProviding = NoTokenProvider()
    ) throws {
        try configuration.validate()
        self.configuration = configuration

        switch configuration.dataSource {
        case .mock:
            self.places = MockPlaceService(behaviour: configuration.mockBehaviour)
            self.auth = MockAuthService(behaviour: configuration.mockBehaviour)

        case .live, .liveWithMockFallback:
            // validate() has already guaranteed the URL is present.
            guard let baseURL = configuration.apiBaseURL else {
                throw AppConfiguration.ConfigurationError.missingBaseURL(mode: configuration.dataSource)
            }
            let client = APIClient(
                baseURL: baseURL,
                transport: transport ?? URLSessionTransport(),
                tokenProvider: tokenProvider
            )
            let live = APIPlaceService(client: client)
            self.places = configuration.dataSource.canFallBackToMock
                ? FallbackPlaceService(
                    primary: live,
                    fallback: MockPlaceService(behaviour: .immediate)
                  )
                : live
            self.auth = APIAuthService(client: client)
        }
    }
}
