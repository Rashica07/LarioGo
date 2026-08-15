import Foundation

/// Shared behaviour for mock services: latency, injected failures, empty mode.
struct MockGate: Sendable {
    let behaviour: MockBehaviour
    /// Injected so failure injection is deterministic in tests.
    let randomValue: @Sendable () -> Double

    init(behaviour: MockBehaviour, randomValue: @escaping @Sendable () -> Double = { Double.random(in: 0..<1) }) {
        self.behaviour = behaviour
        self.randomValue = randomValue
    }

    /// Applies latency then decides whether this request should fail.
    func pass() async throws {
        if behaviour.latency > 0 {
            try await Task.sleep(nanoseconds: UInt64(behaviour.latency * 1_000_000_000))
        }
        // Cancellation must win over injected failure so a cancelled request
        // reports as cancelled rather than as a fake network error.
        try Task.checkCancellation()

        if let forced = behaviour.forcedError {
            throw forced.serviceError
        }
        if behaviour.failureRate > 0, randomValue() < behaviour.failureRate {
            throw ServiceError.offline
        }
    }
}

// MARK: - Places

public struct MockPlaceService: PlaceServing {
    private let gate: MockGate
    private let allPlaces: [Place]
    private let now: @Sendable () -> Date

    public init(
        behaviour: MockBehaviour = .realistic,
        places: [Place] = MockCatalog.places,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.gate = MockGate(behaviour: behaviour)
        self.allPlaces = behaviour.returnsEmptyResults ? [] : places
        self.now = now
    }

    /// Deterministic variant for tests: no randomness, no clock.
    public init(behaviour: MockBehaviour, places: [Place], randomValue: @escaping @Sendable () -> Double, now: @escaping @Sendable () -> Date) {
        self.gate = MockGate(behaviour: behaviour, randomValue: randomValue)
        self.allPlaces = behaviour.returnsEmptyResults ? [] : places
        self.now = now
    }

    public func places(matching query: PlaceQuery, page: Int, per: Int) async throws -> PlacePage {
        try await gate.pass()
        // Reuses the same engine the live path will feed, so mock and API
        // results order identically.
        let all = PlaceSearch.run(query: query, over: allPlaces, now: now())
        let start = max(0, (page - 1) * per)
        let slice = start < all.count ? Array(all[start..<min(start + per, all.count)]) : []
        return PlacePage(results: slice, page: page, per: per, total: all.count)
    }

    public func place(id: UUID, from origin: Coordinate?) async throws -> Place {
        try await gate.pass()
        guard let place = allPlaces.first(where: { $0.id == id }) else {
            throw ServiceError.notFound
        }
        return place
    }

    public func discoveryFeed(near origin: Coordinate?) async throws -> DiscoveryFeed {
        try await gate.pass()
        let moment = now()

        func run(_ query: PlaceQuery, limit: Int) -> [PlaceResult] {
            var query = query
            query.origin = origin
            return Array(PlaceSearch.run(query: query, over: allPlaces, now: moment).prefix(limit))
        }

        let upcoming = PlaceQuery(
            kinds: [.event, .experience],
            origin: origin,
            // "This week" — the question the events tab exists to answer.
            dateRange: moment...moment.addingTimeInterval(7 * 86_400),
            sort: .relevance
        )

        return DiscoveryFeed(
            featured: run(PlaceQuery(featuredOnly: true, sort: .rating), limit: 8),
            // Nearby only means anything once we know where the user is.
            nearby: origin == nil ? [] : run(PlaceQuery(sort: .distance), limit: 12),
            topRated: run(PlaceQuery(minimumRating: 4.5, sort: .rating), limit: 12),
            happeningSoon: Array(PlaceSearch.run(query: upcoming, over: allPlaces, now: moment).prefix(10)),
            restaurants: run(PlaceQuery(kinds: [.restaurant], sort: .rating), limit: 12)
        )
    }
}

// MARK: - Auth

/// In-memory accounts. Accepts any password for the seeded personas so a tester
/// can sign in as one without a credential list, and rejects unknown emails so
/// the signed-out and error paths still work.
public actor MockAuthService: AuthServing {
    private let gate: MockGate
    private var profiles: [String: UserProfile]
    private let sessionLifetime: TimeInterval
    private let now: @Sendable () -> Date

    public init(
        behaviour: MockBehaviour = .realistic,
        profiles: [UserProfile] = MockCatalog.profiles,
        sessionLifetime: TimeInterval = 7 * 86_400,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.gate = MockGate(behaviour: behaviour)
        self.profiles = Dictionary(
            profiles.map { ($0.email.lowercased(), $0) }, uniquingKeysWith: { first, _ in first }
        )
        self.sessionLifetime = sessionLifetime
        self.now = now
    }

    public func register(email: String, password: String, displayName: String) async throws -> AuthSession {
        try await gate.pass()
        let key = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !key.isEmpty, key.contains("@") else {
            throw ServiceError.server(status: 400, message: "Enter a valid email address.")
        }
        guard password.count >= 8 else {
            throw ServiceError.server(status: 400, message: "Password must be at least 8 characters.")
        }
        guard profiles[key] == nil else {
            throw ServiceError.server(status: 409, message: "An account with that email already exists.")
        }
        let profile = UserProfile(
            id: UUID(), email: key,
            displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
            joinedAt: now()
        )
        profiles[key] = profile
        return session(for: profile)
    }

    public func login(email: String, password: String) async throws -> AuthSession {
        try await gate.pass()
        let key = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let profile = profiles[key] else {
            throw ServiceError.unauthorized
        }
        return session(for: profile)
    }

    public func currentUser(token: String) async throws -> UserProfile {
        try await gate.pass()
        guard let profile = profiles.values.first(where: { token.hasSuffix($0.id.uuidString) }) else {
            throw ServiceError.unauthorized
        }
        return profile
    }

    /// Not a real JWT — mock tokens only need to round-trip to a profile.
    private func session(for profile: UserProfile) -> AuthSession {
        AuthSession(
            token: "mock-token.\(profile.id.uuidString)",
            expiresAt: now().addingTimeInterval(sessionLifetime),
            user: profile
        )
    }
}

// MARK: - Favorites

public actor MockFavoriteService: FavoriteServing {
    private let gate: MockGate
    private var stored: [UUID: Favorite]
    private let now: @Sendable () -> Date

    public init(
        behaviour: MockBehaviour = .realistic,
        seeded: [Favorite] = MockCatalog.sampleFavorites,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.gate = MockGate(behaviour: behaviour)
        self.stored = Dictionary(seeded.map { ($0.placeID, $0) }, uniquingKeysWith: { first, _ in first })
        self.now = now
    }

    public func favorites() async throws -> [Favorite] {
        try await gate.pass()
        return stored.values.sorted { $0.savedAt > $1.savedAt }
    }

    public func add(placeID: UUID) async throws {
        try await gate.pass()
        stored[placeID] = Favorite(placeID: placeID, savedAt: now())
    }

    public func remove(placeID: UUID) async throws {
        try await gate.pass()
        stored.removeValue(forKey: placeID)
    }
}

// MARK: - Itineraries

public actor MockItineraryService: ItineraryServing {
    private let gate: MockGate
    private var stored: [UUID: Itinerary]

    public init(
        behaviour: MockBehaviour = .realistic,
        seeded: [Itinerary]? = nil
    ) {
        self.gate = MockGate(behaviour: behaviour)
        let trips = seeded ?? [MockCatalog.sampleItinerary()]
        self.stored = Dictionary(trips.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    public func itineraries() async throws -> [Itinerary] {
        try await gate.pass()
        return stored.values.sorted { $0.updatedAt > $1.updatedAt }
    }

    public func itinerary(id: UUID) async throws -> Itinerary {
        try await gate.pass()
        guard let trip = stored[id] else { throw ServiceError.notFound }
        return trip
    }

    public func save(_ itinerary: Itinerary) async throws {
        try await gate.pass()
        stored[itinerary.id] = itinerary
    }

    public func delete(id: UUID) async throws {
        try await gate.pass()
        guard stored.removeValue(forKey: id) != nil else { throw ServiceError.notFound }
    }
}
