import Foundation

/// Errors any service can surface, independent of transport.
///
/// Views switch on these, so a mock and a live backend produce identical error
/// states and the UI never needs to know which one it is talking to.
public enum ServiceError: Error, Equatable, Sendable {
    case offline
    case timedOut
    case notFound
    case unauthorized
    case rateLimited(retryAfter: TimeInterval?)
    case server(status: Int, message: String?)
    case decoding(String)
    case cancelled
    case unknown(String)

    /// Copy suitable for showing a user. Deliberately free of jargon and of any
    /// server detail that would leak implementation.
    public var userMessage: String {
        switch self {
        case .offline:
            return "You're offline. Saved places and trips still work."
        case .timedOut:
            return "That took too long. Check your connection and try again."
        case .notFound:
            return "We couldn't find that any more. It may have been removed."
        case .unauthorized:
            return "Please sign in again to continue."
        case .rateLimited:
            return "Too many requests just now. Try again in a moment."
        case .server:
            return "Something went wrong on our side. Please try again."
        case .decoding:
            return "We couldn't read the response. Please try again."
        case .cancelled:
            return "Cancelled."
        case .unknown:
            return "Something went wrong. Please try again."
        }
    }

    /// Whether retrying the same request could plausibly succeed.
    public var isRetryable: Bool {
        switch self {
        case .offline, .timedOut, .rateLimited, .server:
            return true
        case .notFound, .unauthorized, .decoding, .cancelled, .unknown:
            return false
        }
    }
}

// MARK: - Discovery

public protocol PlaceServing: Sendable {
    /// Places matching `query`, already filtered, ranked and paged.
    func places(matching query: PlaceQuery, page: Int, per: Int) async throws -> PlacePage
    /// A single place. `origin` populates distance when known.
    func place(id: UUID, from origin: Coordinate?) async throws -> Place
    /// Everything needed to render the discovery home in one call.
    func discoveryFeed(near origin: Coordinate?) async throws -> DiscoveryFeed
}

public struct PlacePage: Hashable, Sendable {
    public let results: [PlaceResult]
    public let page: Int
    public let per: Int
    public let total: Int

    public init(results: [PlaceResult], page: Int, per: Int, total: Int) {
        self.results = results
        self.page = page
        self.per = per
        self.total = total
    }

    public var totalPages: Int {
        per > 0 ? Int((Double(total) / Double(per)).rounded(.up)) : 0
    }
    public var hasNextPage: Bool { page < totalPages }
}

/// The "what can I do right now?" payload.
public struct DiscoveryFeed: Hashable, Sendable {
    public let featured: [PlaceResult]
    public let nearby: [PlaceResult]
    public let topRated: [PlaceResult]
    public let happeningSoon: [PlaceResult]
    public let restaurants: [PlaceResult]

    public init(
        featured: [PlaceResult] = [],
        nearby: [PlaceResult] = [],
        topRated: [PlaceResult] = [],
        happeningSoon: [PlaceResult] = [],
        restaurants: [PlaceResult] = []
    ) {
        self.featured = featured
        self.nearby = nearby
        self.topRated = topRated
        self.happeningSoon = happeningSoon
        self.restaurants = restaurants
    }

    public var isEmpty: Bool {
        featured.isEmpty && nearby.isEmpty && topRated.isEmpty
            && happeningSoon.isEmpty && restaurants.isEmpty
    }
}

// MARK: - Accounts

public protocol AuthServing: Sendable {
    func register(email: String, password: String, displayName: String) async throws -> AuthSession
    func login(email: String, password: String) async throws -> AuthSession
    func currentUser(token: String) async throws -> UserProfile
}

public struct AuthSession: Hashable, Sendable, Codable {
    public let token: String
    public let expiresAt: Date
    public let user: UserProfile

    public init(token: String, expiresAt: Date, user: UserProfile) {
        self.token = token
        self.expiresAt = expiresAt
        self.user = user
    }

    public func isValid(at date: Date = Date()) -> Bool { expiresAt > date }
}

public struct UserProfile: Identifiable, Hashable, Sendable, Codable {
    public let id: UUID
    public let email: String
    public let displayName: String
    public let joinedAt: Date?
    /// Home town or country, used for light personalisation.
    public let homeRegion: String?
    public let avatarInitials: String

    public init(
        id: UUID,
        email: String,
        displayName: String,
        joinedAt: Date? = nil,
        homeRegion: String? = nil,
        avatarInitials: String? = nil
    ) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.joinedAt = joinedAt
        self.homeRegion = homeRegion
        self.avatarInitials = avatarInitials ?? UserProfile.initials(from: displayName)
    }

    /// Up to two initials. Falls back to the email so an avatar is never blank.
    public static func initials(from name: String) -> String {
        let parts = name.split(whereSeparator: { $0.isWhitespace }).prefix(2)
        let letters = parts.compactMap { $0.first }.map(String.init)
        return letters.isEmpty ? "?" : letters.joined().uppercased()
    }
}

// MARK: - Saved content

public protocol FavoriteServing: Sendable {
    func favorites() async throws -> [Favorite]
    func add(placeID: UUID) async throws
    func remove(placeID: UUID) async throws
}

public protocol ItineraryServing: Sendable {
    func itineraries() async throws -> [Itinerary]
    func itinerary(id: UUID) async throws -> Itinerary
    func save(_ itinerary: Itinerary) async throws
    func delete(id: UUID) async throws
}
