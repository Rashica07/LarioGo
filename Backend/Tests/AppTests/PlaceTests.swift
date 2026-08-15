@testable import App
import XCTVapor

final class PlaceTests: XCTestCase {
    var app: Application!

    // Lecco, Basilica di San Nicolò.
    let leccoLat = 45.8566
    let leccoLon = 9.3931

    override func setUp() async throws {
        app = try await Application.make(.testing)
        try await configure(app)
        // Replace seed content with a controlled fixture set so assertions are
        // exact rather than dependent on however much seed data exists.
        try await Place.query(on: app.db).delete()
        for place in Self.fixtures { try await place.save(on: app.db) }
    }

    override func tearDown() async throws {
        // Async counterpart of `Application.make`.
        try await app.asyncShutdown()
        app = nil
    }

    // MARK: - Fixtures

    static var fixtures: [Place] {
        [
            Place(
                kind: .attraction, name: "Basilica di San Nicolo",
                tagline: "Bell tower", summary: "Landmark church",
                category: .landmark,
                latitude: 45.8566, longitude: 9.3931, region: "Lecco",
                rating: 4.7, reviewCount: 1200,
                tags: ["church", "free"], isFeatured: true
            ),
            Place(
                kind: .attraction, name: "Resegone Ridge",
                summary: "Mountain ridge", category: .trail,
                latitude: 45.8833, longitude: 9.4500, region: "Lecco",
                rating: 4.9, reviewCount: 600,
                tags: ["hiking"]
            ),
            Place(
                kind: .attraction, name: "Villa Monastero",
                summary: "Gardens on the water", category: .nature,
                // ~19 km from Lecco.
                latitude: 46.0103, longitude: 9.2847, region: "Varenna",
                rating: 4.8, reviewCount: 3400, priceLevel: 1
            ),
            Place(
                kind: .restaurant, name: "Trattoria del Lario",
                summary: "Lake cuisine", category: .food,
                latitude: 45.8512, longitude: 9.3905, region: "Lecco",
                rating: 4.5, reviewCount: 320, priceLevel: 2,
                cuisines: ["Lombard", "Seafood"], acceptsReservations: true
            ),
            Place(
                kind: .restaurant, name: "Pizzeria Grigna",
                summary: "Wood fired", category: .food,
                latitude: 45.8548, longitude: 9.3944, region: "Lecco",
                rating: 4.4, reviewCount: 890, priceLevel: 1,
                cuisines: ["Pizza"], acceptsReservations: false
            ),
            Place(
                kind: .restaurant, name: "Osteria Costosa",
                summary: "Fine dining", category: .food,
                latitude: 45.8570, longitude: 9.3900, region: "Lecco",
                rating: 4.9, reviewCount: 150, priceLevel: 4,
                cuisines: ["Lombard"], acceptsReservations: true
            ),
            Place(
                kind: .event, name: "Sailing Cup",
                summary: "Regatta", category: .familyFriendly,
                latitude: 45.8497, longitude: 9.3972, region: "Lecco",
                rating: 4.5, reviewCount: 120,
                startDate: Date().addingTimeInterval(5 * 86_400),
                endDate: Date().addingTimeInterval(6 * 86_400)
            ),
            Place(
                kind: .event, name: "Winter Market",
                summary: "Stalls", category: .shopping,
                latitude: 45.8540, longitude: 9.3950, region: "Lecco",
                rating: 4.1, reviewCount: 60,
                startDate: Date().addingTimeInterval(120 * 86_400)
            ),
            Place(
                kind: .attraction, name: "Unrated Viewpoint",
                summary: "New listing", category: .viewpoint,
                latitude: 45.8600, longitude: 9.3900, region: "Lecco",
                rating: nil, reviewCount: 0
            ),
        ]
    }

    // MARK: - Helpers

    func page(_ res: XCTHTTPResponse) throws -> Page<PlaceResponse> {
        try res.content.decode(Page<PlaceResponse>.self)
    }

    // MARK: - Kind routing

    func testAttractionsEndpointReturnsOnlyAttractions() async throws {
        try await app.test(.GET, "api/v1/attractions", afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
            let body = try self.page(res)
            XCTAssertFalse(body.items.isEmpty)
            XCTAssertTrue(body.items.allSatisfy { $0.kind == "attraction" })
        })
    }

    func testRestaurantsEndpointReturnsOnlyRestaurants() async throws {
        try await app.test(.GET, "api/v1/restaurants", afterResponse: { res async throws in
            let body = try self.page(res)
            XCTAssertEqual(body.items.count, 3)
            XCTAssertTrue(body.items.allSatisfy { $0.kind == "restaurant" })
        })
    }

    func testEventsEndpointIncludesExperiences() async throws {
        try await app.test(.GET, "api/v1/events", afterResponse: { res async throws in
            let body = try self.page(res)
            XCTAssertTrue(body.items.allSatisfy { $0.kind == "event" || $0.kind == "experience" })
        })
    }

    func testPlacesEndpointReturnsEveryKind() async throws {
        try await app.test(.GET, "api/v1/places?per=100", afterResponse: { res async throws in
            let body = try self.page(res)
            XCTAssertEqual(body.items.count, Self.fixtures.count)
        })
    }

    // MARK: - Detail

    func testShowReturnsASinglePlace() async throws {
        let place = try await Place.query(on: app.db).filter(\.$name == "Resegone Ridge").first()
        let id = try XCTUnwrap(place?.requireID())

        try await app.test(.GET, "api/v1/places/\(id)", afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
            let body = try res.content.decode(PlaceResponse.self)
            XCTAssertEqual(body.name, "Resegone Ridge")
        })
    }

    func testShowReturns404ForUnknownID() async throws {
        try await app.test(.GET, "api/v1/places/\(UUID())", afterResponse: { res async throws in
            XCTAssertEqual(res.status, .notFound)
        })
    }

    func testShowReturns400ForMalformedID() async throws {
        try await app.test(.GET, "api/v1/places/not-a-uuid", afterResponse: { res async throws in
            XCTAssertEqual(res.status, .badRequest)
        })
    }

    func testShowIncludesDistanceWhenOriginGiven() async throws {
        let place = try await Place.query(on: app.db).filter(\.$name == "Villa Monastero").first()
        let id = try XCTUnwrap(place?.requireID())

        try await app.test(.GET, "api/v1/places/\(id)?lat=\(leccoLat)&lon=\(leccoLon)", afterResponse: { res async throws in
            let body = try res.content.decode(PlaceResponse.self)
            let distance = try XCTUnwrap(body.distance)
            XCTAssertEqual(distance, 19_300, accuracy: 500, "Lecco to Varenna is roughly 19 km")
        })
    }

    func testDistanceIsAbsentWithoutOrigin() async throws {
        try await app.test(.GET, "api/v1/attractions", afterResponse: { res async throws in
            let body = try self.page(res)
            XCTAssertTrue(body.items.allSatisfy { $0.distance == nil },
                          "Distance must be absent, never a placeholder like 0")
        })
    }

    // MARK: - Filtering

    func testCategoryFilter() async throws {
        try await app.test(.GET, "api/v1/places?category=food&per=100", afterResponse: { res async throws in
            let body = try self.page(res)
            XCTAssertEqual(body.items.count, 3)
            XCTAssertTrue(body.items.allSatisfy { $0.category == "food" })
        })
    }

    func testRegionFilter() async throws {
        try await app.test(.GET, "api/v1/places?region=Varenna&per=100", afterResponse: { res async throws in
            let body = try self.page(res)
            XCTAssertEqual(body.items.map(\.name), ["Villa Monastero"])
        })
    }

    func testMinimumRatingExcludesUnratedPlaces() async throws {
        try await app.test(.GET, "api/v1/places?minRating=4.0&per=100", afterResponse: { res async throws in
            let body = try self.page(res)
            XCTAssertFalse(body.items.contains { $0.name == "Unrated Viewpoint" },
                           "An unrated place must not satisfy a rating floor")
            XCTAssertTrue(body.items.allSatisfy { ($0.rating ?? 0) >= 4.0 })
        })
    }

    func testMaximumPriceKeepsPlacesWithoutAPrice() async throws {
        try await app.test(.GET, "api/v1/places?maxPrice=2&per=100", afterResponse: { res async throws in
            let body = try self.page(res)
            XCTAssertFalse(body.items.contains { $0.name == "Osteria Costosa" },
                           "A level-4 place must be excluded by maxPrice=2")
            XCTAssertTrue(body.items.contains { $0.name == "Resegone Ridge" },
                          "A place with no price level must not be hidden by a price filter")
        })
    }

    func testCuisineFilterIsCaseInsensitive() async throws {
        try await app.test(.GET, "api/v1/restaurants?cuisine=lombard&per=100", afterResponse: { res async throws in
            let body = try self.page(res)
            XCTAssertEqual(Set(body.items.map(\.name)), ["Trattoria del Lario", "Osteria Costosa"])
        })
    }

    func testTagFilter() async throws {
        try await app.test(.GET, "api/v1/places?tag=hiking&per=100", afterResponse: { res async throws in
            let body = try self.page(res)
            XCTAssertEqual(body.items.map(\.name), ["Resegone Ridge"])
        })
    }

    func testFeaturedFilter() async throws {
        try await app.test(.GET, "api/v1/places?featured=true&per=100", afterResponse: { res async throws in
            let body = try self.page(res)
            XCTAssertEqual(body.items.map(\.name), ["Basilica di San Nicolo"])
        })
    }

    func testTextSearchMatchesName() async throws {
        try await app.test(.GET, "api/v1/places?search=Resegone&per=100", afterResponse: { res async throws in
            let body = try self.page(res)
            XCTAssertEqual(body.items.map(\.name), ["Resegone Ridge"])
        })
    }

    func testTextSearchReturnsEmptyRatherThanEverything() async throws {
        try await app.test(.GET, "api/v1/places?search=helsinki&per=100", afterResponse: { res async throws in
            let body = try self.page(res)
            XCTAssertTrue(body.items.isEmpty)
            XCTAssertEqual(body.metadata.total, 0)
        })
    }

    // MARK: - Geosearch

    func testRadiusExcludesDistantPlaces() async throws {
        try await app.test(.GET, "api/v1/places?lat=\(leccoLat)&lon=\(leccoLon)&radius=5000&per=100", afterResponse: { res async throws in
            let body = try self.page(res)
            XCTAssertFalse(body.items.contains { $0.name == "Villa Monastero" },
                           "Varenna is ~19 km away and must fall outside a 5 km radius")
            XCTAssertTrue(body.items.contains { $0.name == "Basilica di San Nicolo" })
        })
    }

    func testRadiusIncludesEverythingWhenWideEnough() async throws {
        try await app.test(.GET, "api/v1/places?lat=\(leccoLat)&lon=\(leccoLon)&radius=50000&per=100", afterResponse: { res async throws in
            let body = try self.page(res)
            XCTAssertEqual(body.items.count, Self.fixtures.count)
        })
    }

    func testResultsAreSortedByDistanceWhenOriginGiven() async throws {
        try await app.test(.GET, "api/v1/places?lat=\(leccoLat)&lon=\(leccoLon)&per=100", afterResponse: { res async throws in
            let body = try self.page(res)
            let distances = body.items.compactMap(\.distance)
            XCTAssertEqual(distances.count, body.items.count, "Every item should carry a distance")
            XCTAssertEqual(distances, distances.sorted(), "Proximity is the default order once location is known")
        })
    }

    // MARK: - Sorting

    func testSortByRatingDescending() async throws {
        try await app.test(.GET, "api/v1/places?sort=rating&per=100", afterResponse: { res async throws in
            let body = try self.page(res)
            let ratings = body.items.map { $0.rating ?? -1 }
            XCTAssertEqual(ratings, ratings.sorted(by: >))
        })
    }

    func testSortByNameAscending() async throws {
        try await app.test(.GET, "api/v1/places?sort=name&per=100", afterResponse: { res async throws in
            let body = try self.page(res)
            let names = body.items.map(\.name)
            XCTAssertEqual(names, names.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending })
        })
    }

    func testSortByStartDate() async throws {
        try await app.test(.GET, "api/v1/events?sort=startDate&per=100", afterResponse: { res async throws in
            let body = try self.page(res)
            XCTAssertEqual(body.items.map(\.name), ["Sailing Cup", "Winter Market"])
        })
    }

    // MARK: - Date filtering

    func testStartsBeforeFiltersOutDistantEvents() async throws {
        let cutoff = ISO8601DateFormatter().string(from: Date().addingTimeInterval(30 * 86_400))
        try await app.test(.GET, "api/v1/events?startsBefore=\(cutoff)&per=100", afterResponse: { res async throws in
            let body = try self.page(res)
            XCTAssertEqual(body.items.map(\.name), ["Sailing Cup"],
                           "An event 120 days out must not appear in the next 30 days")
        })
    }

    // MARK: - Pagination

    func testPaginationSplitsResults() async throws {
        try await app.test(.GET, "api/v1/places?per=2&page=1&sort=name", afterResponse: { res async throws in
            let body = try self.page(res)
            XCTAssertEqual(body.items.count, 2)
            XCTAssertEqual(body.metadata.total, Self.fixtures.count)
            XCTAssertTrue(body.metadata.hasNextPage)
        })
    }

    func testSecondPageReturnsDifferentItems() async throws {
        var firstPage: [String] = []
        try await app.test(.GET, "api/v1/places?per=3&page=1&sort=name", afterResponse: { res async throws in
            firstPage = try self.page(res).items.map(\.name)
        })
        try await app.test(.GET, "api/v1/places?per=3&page=2&sort=name", afterResponse: { res async throws in
            let secondPage = try self.page(res).items.map(\.name)
            XCTAssertTrue(Set(firstPage).isDisjoint(with: Set(secondPage)),
                          "Pages must not overlap")
        })
    }

    func testPageBeyondEndIsEmptyNotAnError() async throws {
        try await app.test(.GET, "api/v1/places?per=10&page=99", afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
            let body = try self.page(res)
            XCTAssertTrue(body.items.isEmpty)
            XCTAssertFalse(body.metadata.hasNextPage)
        })
    }

    func testPaginationWorksOnTheDistanceSortedPath() async throws {
        try await app.test(.GET, "api/v1/places?lat=\(leccoLat)&lon=\(leccoLon)&per=2&page=2", afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
            let body = try self.page(res)
            XCTAssertEqual(body.items.count, 2)
            XCTAssertEqual(body.metadata.total, Self.fixtures.count)
        })
    }

    // MARK: - Validation

    func testRejectsUnknownCategory() async throws {
        try await app.test(.GET, "api/v1/places?category=teleportation", afterResponse: { res async throws in
            XCTAssertEqual(res.status, .badRequest)
        })
    }

    func testRejectsUnknownKind() async throws {
        try await app.test(.GET, "api/v1/places?kind=spaceship", afterResponse: { res async throws in
            XCTAssertEqual(res.status, .badRequest)
        })
    }

    func testRejectsLatitudeWithoutLongitude() async throws {
        try await app.test(.GET, "api/v1/places?lat=45.85", afterResponse: { res async throws in
            XCTAssertEqual(res.status, .badRequest, "lat and lon are meaningless individually")
        })
    }

    func testRejectsOutOfRangeCoordinates() async throws {
        try await app.test(.GET, "api/v1/places?lat=999&lon=9.39", afterResponse: { res async throws in
            XCTAssertEqual(res.status, .badRequest)
        })
    }

    func testRejectsRadiusWithoutOrigin() async throws {
        try await app.test(.GET, "api/v1/places?radius=1000", afterResponse: { res async throws in
            XCTAssertEqual(res.status, .badRequest)
        })
    }

    func testRejectsDistanceSortWithoutOrigin() async throws {
        try await app.test(.GET, "api/v1/places?sort=distance", afterResponse: { res async throws in
            XCTAssertEqual(res.status, .badRequest)
        })
    }

    func testRejectsOutOfRangeRating() async throws {
        try await app.test(.GET, "api/v1/places?minRating=9", afterResponse: { res async throws in
            XCTAssertEqual(res.status, .badRequest)
        })
    }

    func testRejectsExcessivePageSize() async throws {
        try await app.test(.GET, "api/v1/places?per=100000", afterResponse: { res async throws in
            XCTAssertEqual(res.status, .badRequest, "A client must not be able to request the whole table")
        })
    }

    func testRejectsZeroPage() async throws {
        try await app.test(.GET, "api/v1/places?page=0", afterResponse: { res async throws in
            XCTAssertEqual(res.status, .badRequest)
        })
    }

    // MARK: - Access

    func testDiscoveryDoesNotRequireAuthentication() async throws {
        // A tourist should see what is nearby before creating an account.
        try await app.test(.GET, "api/v1/attractions", afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
        })
    }
}
