import XCTest
@testable import LarioCore

final class MockServiceTests: XCTestCase {

    // MARK: - Catalogue integrity

    func testCatalogueIsSubstantial() {
        // The brief asks for a large mock set so every screen and filter has
        // something to work with.
        XCTAssertGreaterThanOrEqual(MockCatalog.places.count, 40)
    }

    func testMockIDsAreStableAcrossReads() {
        // Regression guard, same class of bug as the seed-ID one: favourites and
        // itineraries persist by identifier, so these must not be regenerated.
        XCTAssertEqual(MockCatalog.places.map(\.id), MockCatalog.places.map(\.id))
        XCTAssertEqual(MockCatalog.stableID(1), MockCatalog.stableID(1))
        XCTAssertNotEqual(MockCatalog.stableID(1), MockCatalog.stableID(2))
    }

    func testMockIDsAreUnique() {
        let ids = MockCatalog.places.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func testEveryKindIsRepresented() {
        let kinds = Set(MockCatalog.places.map(\.kind))
        for kind in PlaceKind.allCases {
            XCTAssertTrue(kinds.contains(kind), "No mock content for kind \(kind)")
        }
    }

    func testEveryCoordinateIsInRegion() {
        for place in MockCatalog.places {
            XCTAssertTrue(place.coordinate.isPlausibleForLakeComo,
                          "\(place.name) is outside the Lake Como area")
        }
    }

    func testInventedContentIsLabelledAsSample() {
        // Dining, events and experiences are invented. Each must carry the
        // sample-data tag so the UI can label it and it is never mistaken for a
        // verified listing.
        let invented = MockCatalog.places.filter {
            $0.kind == .restaurant || $0.kind == .event || $0.kind == .experience
        }
        XCTAssertFalse(invented.isEmpty)
        for place in invented {
            XCTAssertTrue(place.tags.contains("sample-data"),
                          "\(place.name) is invented content but is not tagged sample-data")
        }
    }

    func testInventedContentDoesNotFabricateContactDetails() {
        for place in MockCatalog.places where place.tags.contains("sample-data") {
            XCTAssertNil(place.phone, "\(place.name) fabricates a phone number")
            XCTAssertNil(place.website, "\(place.name) fabricates a website")
        }
    }

    func testCatalogueLookupCoversEveryPlace() {
        XCTAssertEqual(MockCatalog.catalogue.count, MockCatalog.places.count)
    }

    func testThereAreUnratedAndImagelessEntries() {
        // Those UI paths need content to exercise them.
        XCTAssertTrue(MockCatalog.places.contains { $0.rating == nil })
        XCTAssertTrue(MockCatalog.places.contains { $0.imageNames.isEmpty })
    }

    // MARK: - Profiles

    func testProfilesCoverTheAudiences() {
        XCTAssertGreaterThanOrEqual(MockCatalog.profiles.count, 5)
        XCTAssertEqual(Set(MockCatalog.profiles.map(\.id)).count, MockCatalog.profiles.count)
    }

    func testProfileInitials() {
        XCTAssertEqual(UserProfile.initials(from: "Alpine Traveller"), "AT")
        XCTAssertEqual(UserProfile.initials(from: "Newcomer"), "N")
        XCTAssertEqual(UserProfile.initials(from: "Jo & Sam"), "J&")
        XCTAssertEqual(UserProfile.initials(from: "   "), "?", "An avatar must never be blank")
    }

    func testProfilesUseExampleAddresses() {
        // example.com is reserved for documentation, so no real inbox is implied.
        for profile in MockCatalog.profiles {
            XCTAssertTrue(profile.email.hasSuffix("@example.com"), "\(profile.email) is not a reserved test address")
        }
    }

    // MARK: - Sample saved content

    func testSampleItineraryResolvesAgainstTheCatalogue() {
        let trip = MockCatalog.sampleItinerary(calendar: Calendar(identifier: .gregorian))
        XCTAssertFalse(trip.isEmpty)
        XCTAssertTrue(trip.unresolvedPlaceIDs(using: MockCatalog.catalogue).isEmpty,
                      "The sample trip references places that are not in the catalogue")
        XCTAssertGreaterThanOrEqual(trip.days.count, 3)
    }

    func testSampleFavoritesResolve() {
        let favorites = MockCatalog.sampleFavorites
        XCTAssertFalse(favorites.isEmpty)
        for favorite in favorites {
            XCTAssertNotNil(MockCatalog.catalogue[favorite.placeID])
        }
    }

    // MARK: - Configuration toggle

    func testMockModeUsesNoNetwork() {
        XCTAssertFalse(DataSourceMode.mock.usesNetwork)
        XCTAssertTrue(DataSourceMode.live.usesNetwork)
        XCTAssertTrue(DataSourceMode.liveWithMockFallback.usesNetwork)
    }

    func testOnlyLiveServesVerifiedContent() {
        XCTAssertFalse(DataSourceMode.mock.servesVerifiedContent)
        XCTAssertTrue(DataSourceMode.live.servesVerifiedContent)
        XCTAssertFalse(DataSourceMode.liveWithMockFallback.servesVerifiedContent,
                       "Fallback can serve invented content, so it is not verified")
    }

    func testSampleLabellingFollowsTheMode() {
        XCTAssertTrue(AppConfiguration(dataSource: .mock).mustLabelContentAsSample)
        XCTAssertTrue(AppConfiguration(dataSource: .liveWithMockFallback).mustLabelContentAsSample)
        XCTAssertFalse(AppConfiguration.live(baseURL: URL(string: "https://example.com")!).mustLabelContentAsSample)
    }

    func testDefaultConfigurationIsMock() {
        // Until v1.0 has real content and sponsors.
        XCTAssertEqual(AppConfiguration.current.dataSource, .mock)
    }

    func testLiveModeWithoutBaseURLFailsValidation() {
        let config = AppConfiguration(dataSource: .live, apiBaseURL: nil)
        XCTAssertThrowsError(try config.validate()) { error in
            XCTAssertEqual(error as? AppConfiguration.ConfigurationError, .missingBaseURL(mode: .live))
        }
    }

    func testMockModeValidatesWithoutABaseURL() {
        XCTAssertNoThrow(try AppConfiguration(dataSource: .mock).validate())
    }

    // MARK: - Mock behaviour

    func testPlacesAreReturnedAndPaged() async throws {
        let service = MockPlaceService(behaviour: .immediate)
        let first = try await service.places(matching: PlaceQuery(sort: .name), page: 1, per: 10)
        XCTAssertEqual(first.results.count, 10)
        XCTAssertEqual(first.total, MockCatalog.places.count)
        XCTAssertTrue(first.hasNextPage)

        let second = try await service.places(matching: PlaceQuery(sort: .name), page: 2, per: 10)
        XCTAssertTrue(Set(first.results.map(\.id)).isDisjoint(with: Set(second.results.map(\.id))))
    }

    func testPageBeyondEndIsEmpty() async throws {
        let service = MockPlaceService(behaviour: .immediate)
        let page = try await service.places(matching: PlaceQuery(), page: 999, per: 10)
        XCTAssertTrue(page.results.isEmpty)
        XCTAssertFalse(page.hasNextPage)
    }

    func testEmptyBehaviourReturnsNothing() async throws {
        let service = MockPlaceService(behaviour: .empty)
        let page = try await service.places(matching: PlaceQuery(), page: 1, per: 10)
        XCTAssertTrue(page.results.isEmpty, "Empty mode must exercise the empty state")
        XCTAssertEqual(page.total, 0)
    }

    func testForcedErrorIsThrown() async {
        let service = MockPlaceService(behaviour: .alwaysOffline)
        do {
            _ = try await service.places(matching: PlaceQuery(), page: 1, per: 10)
            XCTFail("Expected the forced error")
        } catch {
            XCTAssertEqual(error as? ServiceError, .offline)
        }
    }

    func testFailureRateIsDeterministicWhenRandomnessIsInjected() async {
        // Always "rolls" below the failure rate, so this must fail every time.
        let service = MockPlaceService(
            behaviour: MockBehaviour(failureRate: 0.5),
            places: MockCatalog.places,
            randomValue: { 0.0 },
            now: { Date() }
        )
        do {
            _ = try await service.places(matching: PlaceQuery(), page: 1, per: 5)
            XCTFail("Expected an injected failure")
        } catch {
            XCTAssertEqual(error as? ServiceError, .offline)
        }
    }

    func testFailureRateDoesNotFireWhenRollIsHigh() async throws {
        let service = MockPlaceService(
            behaviour: MockBehaviour(failureRate: 0.5),
            places: MockCatalog.places,
            randomValue: { 0.99 },
            now: { Date() }
        )
        let page = try await service.places(matching: PlaceQuery(), page: 1, per: 5)
        XCTAssertEqual(page.results.count, 5)
    }

    func testUnknownPlaceIsNotFound() async {
        let service = MockPlaceService(behaviour: .immediate)
        do {
            _ = try await service.place(id: UUID(), from: nil)
            XCTFail("Expected notFound")
        } catch {
            XCTAssertEqual(error as? ServiceError, .notFound)
        }
    }

    // MARK: - Discovery feed

    func testDiscoveryFeedIsPopulated() async throws {
        let service = MockPlaceService(behaviour: .immediate)
        let feed = try await service.discoveryFeed(near: Coordinate(latitude: 45.8566, longitude: 9.3931))

        XCTAssertFalse(feed.isEmpty)
        XCTAssertFalse(feed.featured.isEmpty, "Explore's hero carousel would be empty")
        XCTAssertFalse(feed.nearby.isEmpty)
        XCTAssertFalse(feed.topRated.isEmpty)
        XCTAssertFalse(feed.restaurants.isEmpty)
    }

    func testNearbyIsEmptyWithoutLocation() async throws {
        let service = MockPlaceService(behaviour: .immediate)
        let feed = try await service.discoveryFeed(near: nil)
        XCTAssertTrue(feed.nearby.isEmpty, "\"Nearby\" is meaningless with no location")
        XCTAssertFalse(feed.featured.isEmpty, "The rest of the feed should still work")
    }

    func testNearbyIsOrderedByDistance() async throws {
        let service = MockPlaceService(behaviour: .immediate)
        let feed = try await service.discoveryFeed(near: Coordinate(latitude: 45.8566, longitude: 9.3931))
        let distances = feed.nearby.compactMap(\.distance)
        XCTAssertEqual(distances, distances.sorted())
    }

    func testHappeningSoonExcludesFinishedEvents() async throws {
        let service = MockPlaceService(behaviour: .immediate)
        let feed = try await service.discoveryFeed(near: nil)
        XCTAssertFalse(feed.happeningSoon.contains { $0.place.name.contains("past") },
                       "A finished event must not appear under \"happening soon\"")
    }

    // MARK: - Auth

    func testLoginSucceedsForASeededPersona() async throws {
        let service = MockAuthService(behaviour: .immediate)
        let session = try await service.login(email: "sample.traveller@example.com", password: "anything")
        XCTAssertEqual(session.user.displayName, "Alpine Traveller")
        XCTAssertTrue(session.isValid())
    }

    func testLoginIsCaseInsensitive() async throws {
        let service = MockAuthService(behaviour: .immediate)
        _ = try await service.login(email: "SAMPLE.Traveller@Example.com", password: "x")
    }

    func testLoginFailsForUnknownAccount() async {
        let service = MockAuthService(behaviour: .immediate)
        do {
            _ = try await service.login(email: "nobody@example.com", password: "x")
            XCTFail("Expected unauthorized")
        } catch {
            XCTAssertEqual(error as? ServiceError, .unauthorized)
        }
    }

    func testRegisterRejectsDuplicateAndShortPassword() async {
        let service = MockAuthService(behaviour: .immediate)
        do {
            _ = try await service.register(email: "sample.traveller@example.com", password: "longenough", displayName: "Dup")
            XCTFail("Expected a conflict")
        } catch {
            XCTAssertEqual(error as? ServiceError, .server(status: 409, message: "An account with that email already exists."))
        }
        do {
            _ = try await service.register(email: "fresh@example.com", password: "short", displayName: "Short")
            XCTFail("Expected a validation error")
        } catch {
            XCTAssertEqual(error as? ServiceError, .server(status: 400, message: "Password must be at least 8 characters."))
        }
    }

    func testRegisterThenFetchCurrentUser() async throws {
        let service = MockAuthService(behaviour: .immediate)
        let session = try await service.register(email: "new@example.com", password: "longenough", displayName: "New Person")
        let profile = try await service.currentUser(token: session.token)
        XCTAssertEqual(profile.email, "new@example.com")
    }

    func testExpiredSessionIsInvalid() {
        let session = AuthSession(
            token: "t", expiresAt: Date().addingTimeInterval(-60),
            user: MockCatalog.defaultProfile
        )
        XCTAssertFalse(session.isValid())
    }

    // MARK: - Favorites and itineraries

    func testFavoriteServiceRoundTrip() async throws {
        let service = MockFavoriteService(behaviour: .immediate, seeded: [])
        let place = MockCatalog.places[0].id

        try await service.add(placeID: place)
        var all = try await service.favorites()
        XCTAssertEqual(all.map(\.placeID), [place])

        try await service.remove(placeID: place)
        all = try await service.favorites()
        XCTAssertTrue(all.isEmpty)
    }

    func testSeededFavoritesAreNewestFirst() async throws {
        let service = MockFavoriteService(behaviour: .immediate)
        let all = try await service.favorites()
        XCTAssertEqual(all.map(\.savedAt), all.map(\.savedAt).sorted(by: >))
    }

    func testItineraryServiceRoundTrip() async throws {
        let service = MockItineraryService(behaviour: .immediate)
        let trips = try await service.itineraries()
        XCTAssertFalse(trips.isEmpty, "A pre-populated trip should exist for testing")

        let id = trips[0].id
        var trip = try await service.itinerary(id: id)
        trip.name = "Renamed"
        try await service.save(trip)
        // XCTAssertEqual takes autoclosures, which cannot be async — the await
        // has to be hoisted out rather than written inline.
        let reloadedName = try await service.itinerary(id: id).name
        XCTAssertEqual(reloadedName, "Renamed")

        try await service.delete(id: id)
        do {
            _ = try await service.itinerary(id: id)
            XCTFail("Expected notFound after deletion")
        } catch {
            XCTAssertEqual(error as? ServiceError, .notFound)
        }
    }

    // MARK: - Errors

    func testErrorMessagesAreUserFacing() {
        for error in [ServiceError.offline, .timedOut, .notFound, .unauthorized, .server(status: 500, message: "stack trace")] {
            XCTAssertFalse(error.userMessage.isEmpty)
            XCTAssertFalse(error.userMessage.contains("stack trace"), "Server detail leaked into user copy")
        }
    }

    func testRetryabilityIsClassifiedSensibly() {
        XCTAssertTrue(ServiceError.offline.isRetryable)
        XCTAssertTrue(ServiceError.timedOut.isRetryable)
        XCTAssertFalse(ServiceError.notFound.isRetryable)
        XCTAssertFalse(ServiceError.unauthorized.isRetryable, "Retrying without new credentials cannot help")
    }
}
