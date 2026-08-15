import XCTest
@testable import LarioCore

final class PlaceSearchTests: XCTestCase {

    // MARK: - Fixtures

    let lecco = Coordinate(latitude: 45.8566, longitude: 9.3931)

    func makePlace(
        name: String,
        kind: PlaceKind = .attraction,
        category: PlaceCategory = .landmark,
        coordinate: Coordinate? = nil,
        rating: Double? = 4.5,
        reviewCount: Int = 100,
        priceLevel: PriceLevel? = nil,
        cuisines: [String] = [],
        tags: [String] = [],
        tagline: String = "",
        summary: String = "",
        featured: Bool = false,
        schedule: EventSchedule? = nil
    ) -> Place {
        Place(
            id: UUID(),
            kind: kind,
            name: name,
            tagline: tagline,
            summary: summary,
            category: category,
            coordinate: coordinate ?? lecco,
            region: "Lecco",
            rating: rating,
            reviewCount: reviewCount,
            priceLevel: priceLevel,
            tags: tags,
            isFeatured: featured,
            dining: cuisines.isEmpty ? nil : DiningDetails(cuisines: cuisines),
            schedule: schedule
        )
    }

    func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var c = DateComponents()
        c.year = year; c.month = month; c.day = day; c.hour = 12
        return Calendar(identifier: .gregorian).date(from: c)!
    }

    // MARK: - Empty query

    func testEmptyQueryReturnsEverything() {
        let places = [makePlace(name: "A"), makePlace(name: "B"), makePlace(name: "C")]
        let results = PlaceSearch.run(query: PlaceQuery(), over: places)
        XCTAssertEqual(results.count, 3)
    }

    func testEmptyQueryIsReportedAsEmpty() {
        XCTAssertTrue(PlaceQuery().isEmpty)
        XCTAssertFalse(PlaceQuery(text: "abbey").isEmpty)
        XCTAssertFalse(PlaceQuery(categories: [.food]).isEmpty)
        // Sort alone is not a narrowing filter.
        XCTAssertTrue(PlaceQuery(sort: .rating).isEmpty)
    }

    func testActiveFilterCountExcludesText() {
        var query = PlaceQuery(text: "pizza")
        XCTAssertEqual(query.activeFilterCount, 0)
        query.categories = [.food]
        query.minimumRating = 4.0
        XCTAssertEqual(query.activeFilterCount, 2)
    }

    // MARK: - Text matching

    func testTextMatchesName() {
        let places = [makePlace(name: "Abbazia di Piona"), makePlace(name: "Resegone Ridge")]
        let results = PlaceSearch.run(query: PlaceQuery(text: "piona"), over: places)
        XCTAssertEqual(results.map(\.place.name), ["Abbazia di Piona"])
    }

    func testTextIsDiacriticInsensitive() {
        let places = [makePlace(name: "Basilica di San Nicolò")]
        let results = PlaceSearch.run(query: PlaceQuery(text: "nicolo"), over: places)
        XCTAssertEqual(results.count, 1, "Accent-stripped search should match")
    }

    func testTextIsCaseInsensitive() {
        let places = [makePlace(name: "Varenna")]
        XCTAssertEqual(PlaceSearch.run(query: PlaceQuery(text: "VARENNA"), over: places).count, 1)
    }

    func testAllTermsMustMatch() {
        let places = [
            makePlace(name: "Lakeside Trattoria", summary: "Fresh perch risotto"),
            makePlace(name: "Mountain Trattoria", summary: "Alpine cheese"),
        ]
        // Both terms present only in the first.
        let results = PlaceSearch.run(query: PlaceQuery(text: "trattoria perch"), over: places)
        XCTAssertEqual(results.map(\.place.name), ["Lakeside Trattoria"])
    }

    func testPunctuationIsIgnored() {
        let places = [makePlace(name: "Piani d'Erna")]
        XCTAssertEqual(PlaceSearch.run(query: PlaceQuery(text: "piani erna"), over: places).count, 1)
    }

    func testSearchMatchesTagsAndCuisine() {
        let places = [
            makePlace(name: "Osteria", kind: .restaurant, cuisines: ["Lombard"], tags: ["family"]),
        ]
        XCTAssertEqual(PlaceSearch.run(query: PlaceQuery(text: "lombard"), over: places).count, 1)
        XCTAssertEqual(PlaceSearch.run(query: PlaceQuery(text: "family"), over: places).count, 1)
    }

    func testNoMatchReturnsEmpty() {
        let places = [makePlace(name: "Varenna")]
        XCTAssertTrue(PlaceSearch.run(query: PlaceQuery(text: "helsinki"), over: places).isEmpty)
    }

    // MARK: - Relevance ranking

    func testNameMatchOutranksDescriptionMatch() {
        let named = makePlace(name: "Piona Abbey")
        let mentioned = makePlace(name: "Lake Cruise", summary: "Sails past Piona every hour")
        let results = PlaceSearch.run(
            query: PlaceQuery(text: "piona", sort: .relevance),
            over: [mentioned, named]
        )
        XCTAssertEqual(results.first?.place.name, "Piona Abbey")
    }

    func testExactNameOutranksPrefix() {
        let exact = makePlace(name: "Varenna", rating: 4.0)
        let prefix = makePlace(name: "Varenna Ferry Pier", rating: 5.0)
        let results = PlaceSearch.run(
            query: PlaceQuery(text: "varenna", sort: .relevance),
            over: [prefix, exact]
        )
        XCTAssertEqual(results.first?.place.name, "Varenna",
                       "An exact name match should win even with a lower rating")
    }

    func testRelevanceWithoutTextFallsBackToQuality() {
        let good = makePlace(name: "A", rating: 4.9)
        let poor = makePlace(name: "B", rating: 3.0)
        let results = PlaceSearch.run(query: PlaceQuery(sort: .relevance), over: [poor, good])
        XCTAssertEqual(results.first?.place.name, "A")
    }

    // MARK: - Filters

    func testKindFilter() {
        let places = [
            makePlace(name: "Museum", kind: .attraction),
            makePlace(name: "Osteria", kind: .restaurant),
        ]
        let results = PlaceSearch.run(query: PlaceQuery(kinds: [.restaurant]), over: places)
        XCTAssertEqual(results.map(\.place.name), ["Osteria"])
    }

    func testCategoryFilter() {
        let places = [
            makePlace(name: "Ridge", category: .nature),
            makePlace(name: "Church", category: .landmark),
        ]
        let results = PlaceSearch.run(query: PlaceQuery(categories: [.nature]), over: places)
        XCTAssertEqual(results.map(\.place.name), ["Ridge"])
    }

    func testMinimumRatingExcludesLowerRated() {
        let places = [makePlace(name: "Great", rating: 4.8), makePlace(name: "Poor", rating: 3.2)]
        let results = PlaceSearch.run(query: PlaceQuery(minimumRating: 4.5), over: places)
        XCTAssertEqual(results.map(\.place.name), ["Great"])
    }

    func testMinimumRatingExcludesUnratedPlaces() {
        let places = [makePlace(name: "Unrated", rating: nil), makePlace(name: "Rated", rating: 4.6)]
        let results = PlaceSearch.run(query: PlaceQuery(minimumRating: 4.0), over: places)
        XCTAssertEqual(results.map(\.place.name), ["Rated"],
                       "An unrated place must not satisfy a rating floor")
    }

    func testMaximumPriceExcludesPricier() {
        let places = [
            makePlace(name: "Cheap", priceLevel: .budget),
            makePlace(name: "Fancy", priceLevel: .luxury),
        ]
        let results = PlaceSearch.run(query: PlaceQuery(maximumPriceLevel: .moderate), over: places)
        XCTAssertEqual(results.map(\.place.name), ["Cheap"])
    }

    func testMaximumPriceKeepsPlacesWithoutAPrice() {
        // Attractions usually have no price level; a global price filter should
        // not silently hide them.
        let places = [makePlace(name: "Viewpoint", priceLevel: nil)]
        let results = PlaceSearch.run(query: PlaceQuery(maximumPriceLevel: .budget), over: places)
        XCTAssertEqual(results.count, 1)
    }

    func testCuisineFilter() {
        let places = [
            makePlace(name: "Pizzeria", kind: .restaurant, cuisines: ["Pizza", "Italian"]),
            makePlace(name: "Sushi Bar", kind: .restaurant, cuisines: ["Japanese"]),
        ]
        let results = PlaceSearch.run(query: PlaceQuery(cuisines: ["italian"]), over: places)
        XCTAssertEqual(results.map(\.place.name), ["Pizzeria"],
                       "Cuisine matching should be case-insensitive")
    }

    func testFeaturedOnlyFilter() {
        let places = [makePlace(name: "Star", featured: true), makePlace(name: "Ordinary")]
        let results = PlaceSearch.run(query: PlaceQuery(featuredOnly: true), over: places)
        XCTAssertEqual(results.map(\.place.name), ["Star"])
    }

    // MARK: - Distance

    func testDistanceFilterExcludesFarPlaces() {
        let near = makePlace(name: "Near", coordinate: lecco)
        let far = makePlace(name: "Far", coordinate: Coordinate(latitude: 46.0103, longitude: 9.2847))
        let query = PlaceQuery(origin: lecco, maximumDistance: 5_000)
        let results = PlaceSearch.run(query: query, over: [near, far])
        XCTAssertEqual(results.map(\.place.name), ["Near"])
    }

    func testDistanceFilterIgnoredWithoutOrigin() {
        let far = makePlace(name: "Far", coordinate: Coordinate(latitude: 46.0103, longitude: 9.2847))
        let query = PlaceQuery(maximumDistance: 100)
        XCTAssertEqual(PlaceSearch.run(query: query, over: [far]).count, 1,
                       "Without an origin there is nothing to measure from")
    }

    func testResultsCarryDistanceOnlyWhenOriginGiven() {
        let places = [makePlace(name: "A")]
        XCTAssertNil(PlaceSearch.run(query: PlaceQuery(), over: places).first?.distance)
        XCTAssertNotNil(PlaceSearch.run(query: PlaceQuery(origin: lecco), over: places).first?.distance)
    }

    // MARK: - Sorting

    func testSortByDistance() {
        let near = makePlace(name: "Near", coordinate: lecco)
        let mid = makePlace(name: "Mid", coordinate: Coordinate(latitude: 45.90, longitude: 9.40))
        let far = makePlace(name: "Far", coordinate: Coordinate(latitude: 46.01, longitude: 9.28))
        let query = PlaceQuery(origin: lecco, sort: .distance)
        let results = PlaceSearch.run(query: query, over: [far, near, mid])
        XCTAssertEqual(results.map(\.place.name), ["Near", "Mid", "Far"])
    }

    func testSortByDistancePushesUnknownDistancesLast() {
        // No origin means no distances at all; ordering must stay deterministic
        // rather than crashing or randomising.
        let results = PlaceSearch.run(
            query: PlaceQuery(sort: .distance),
            over: [makePlace(name: "B"), makePlace(name: "A")]
        )
        XCTAssertEqual(results.map(\.place.name), ["A", "B"])
    }

    func testSortByRating() {
        let places = [
            makePlace(name: "Mid", rating: 4.0),
            makePlace(name: "Best", rating: 4.9),
            makePlace(name: "Worst", rating: 3.1),
        ]
        let results = PlaceSearch.run(query: PlaceQuery(sort: .rating), over: places)
        XCTAssertEqual(results.map(\.place.name), ["Best", "Mid", "Worst"])
    }

    func testSortByRatingBreaksTiesOnReviewCount() {
        let places = [
            makePlace(name: "Few", rating: 4.5, reviewCount: 3),
            makePlace(name: "Many", rating: 4.5, reviewCount: 900),
        ]
        let results = PlaceSearch.run(query: PlaceQuery(sort: .rating), over: places)
        XCTAssertEqual(results.map(\.place.name), ["Many", "Few"])
    }

    func testSortByRatingPutsUnratedLast() {
        let places = [makePlace(name: "Unrated", rating: nil), makePlace(name: "Rated", rating: 2.0)]
        let results = PlaceSearch.run(query: PlaceQuery(sort: .rating), over: places)
        XCTAssertEqual(results.map(\.place.name), ["Rated", "Unrated"])
    }

    func testSortByPriceAscendingWithUnpricedLast() {
        let places = [
            makePlace(name: "Unpriced", priceLevel: nil),
            makePlace(name: "Luxury", priceLevel: .luxury),
            makePlace(name: "Budget", priceLevel: .budget),
        ]
        let results = PlaceSearch.run(query: PlaceQuery(sort: .priceLowToHigh), over: places)
        XCTAssertEqual(results.map(\.place.name), ["Budget", "Luxury", "Unpriced"])
    }

    func testSortByNameIsAlphabetical() {
        let places = [makePlace(name: "Zebra"), makePlace(name: "apple"), makePlace(name: "Mango")]
        let results = PlaceSearch.run(query: PlaceQuery(sort: .name), over: places)
        XCTAssertEqual(results.map(\.place.name), ["apple", "Mango", "Zebra"],
                       "Name sort should be case-insensitive")
    }

    func testSortingIsStableForIdenticalInputs() {
        let places = [makePlace(name: "A", rating: 4.0), makePlace(name: "B", rating: 4.0)]
        let first = PlaceSearch.run(query: PlaceQuery(sort: .rating), over: places).map(\.place.name)
        let second = PlaceSearch.run(query: PlaceQuery(sort: .rating), over: places).map(\.place.name)
        XCTAssertEqual(first, second, "Repeated identical queries must not reorder results")
    }

    // MARK: - Dates

    func testDateRangeFiltersEvents() {
        let inRange = makePlace(
            name: "Festival", kind: .event,
            schedule: EventSchedule(startDate: date(2026, 7, 15))
        )
        let outOfRange = makePlace(
            name: "Old Concert", kind: .event,
            schedule: EventSchedule(startDate: date(2026, 3, 1))
        )
        let query = PlaceQuery(dateRange: date(2026, 7, 1)...date(2026, 7, 31))
        let results = PlaceSearch.run(query: query, over: [inRange, outOfRange])
        XCTAssertEqual(results.map(\.place.name), ["Festival"])
    }

    func testDateRangeMatchesMultiDayEventOverlap() {
        // Runs 10–20 July; the user asked about 18–25 July. It overlaps.
        let event = makePlace(
            name: "Sailing Week", kind: .event,
            schedule: EventSchedule(startDate: date(2026, 7, 10), endDate: date(2026, 7, 20))
        )
        let query = PlaceQuery(dateRange: date(2026, 7, 18)...date(2026, 7, 25))
        XCTAssertEqual(PlaceSearch.run(query: query, over: [event]).count, 1)
    }

    func testDateRangeDoesNotHideAttractions() {
        // An attraction has no schedule and is open regardless of the dates the
        // user picked; filtering it out would empty the map.
        let attraction = makePlace(name: "Basilica", kind: .attraction)
        let query = PlaceQuery(dateRange: date(2026, 7, 1)...date(2026, 7, 31))
        XCTAssertEqual(PlaceSearch.run(query: query, over: [attraction]).count, 1)
    }

    func testDateRangeExcludesEventsWithoutASchedule() {
        let broken = makePlace(name: "Mystery Event", kind: .event, schedule: nil)
        let query = PlaceQuery(dateRange: date(2026, 7, 1)...date(2026, 7, 31))
        XCTAssertTrue(PlaceSearch.run(query: query, over: [broken]).isEmpty)
    }

    // MARK: - Combined

    func testFiltersCombineConjunctively() {
        let match = makePlace(
            name: "Lakeside Osteria", kind: .restaurant, category: .food,
            coordinate: lecco, rating: 4.7, priceLevel: .moderate, cuisines: ["Lombard"]
        )
        let wrongKind = makePlace(name: "Lakeside Museum", kind: .attraction, rating: 4.9)
        let tooExpensive = makePlace(
            name: "Lakeside Fine Dining", kind: .restaurant, category: .food,
            rating: 4.8, priceLevel: .luxury, cuisines: ["Lombard"]
        )
        let tooFar = makePlace(
            name: "Lakeside Grill", kind: .restaurant, category: .food,
            coordinate: Coordinate(latitude: 46.01, longitude: 9.28),
            rating: 4.6, priceLevel: .budget, cuisines: ["Lombard"]
        )

        let query = PlaceQuery(
            text: "lakeside",
            kinds: [.restaurant],
            minimumRating: 4.5,
            maximumPriceLevel: .moderate,
            cuisines: ["lombard"],
            origin: lecco,
            maximumDistance: 5_000,
            sort: .rating
        )

        let results = PlaceSearch.run(query: query, over: [match, wrongKind, tooExpensive, tooFar])
        XCTAssertEqual(results.map(\.place.name), ["Lakeside Osteria"])
    }
}
