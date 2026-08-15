import XCTest
@testable import LarioCore

final class FavoritesStoreTests: XCTestCase {

    func date(_ day: Int) -> Date {
        var c = DateComponents()
        c.year = 2026; c.month = 7; c.day = day
        return Calendar(identifier: .gregorian).date(from: c)!
    }

    func makePlace(_ name: String, id: UUID = UUID()) -> Place {
        Place(
            id: id, kind: .attraction, name: name, category: .landmark,
            coordinate: Coordinate(latitude: 45.85, longitude: 9.39), region: "Lecco"
        )
    }

    // MARK: - Basics

    func testStartsEmpty() throws {
        let store = try FavoritesStore(persistence: InMemoryFavoritesPersistence())
        XCTAssertTrue(store.isEmpty)
        XCTAssertEqual(store.count, 0)
    }

    func testAddMarksAsFavorite() throws {
        var store = try FavoritesStore(persistence: InMemoryFavoritesPersistence())
        let place = UUID()

        XCTAssertTrue(try store.add(place))
        XCTAssertTrue(store.isFavorite(place))
        XCTAssertEqual(store.count, 1)
    }

    func testAddingTwiceIsIdempotent() throws {
        var store = try FavoritesStore(persistence: InMemoryFavoritesPersistence())
        let place = UUID()

        XCTAssertTrue(try store.add(place))
        XCTAssertFalse(try store.add(place), "Re-adding should report no change")
        XCTAssertEqual(store.count, 1)
    }

    func testRemove() throws {
        var store = try FavoritesStore(persistence: InMemoryFavoritesPersistence())
        let place = UUID()
        try store.add(place)

        XCTAssertTrue(try store.remove(place))
        XCTAssertFalse(store.isFavorite(place))
        XCTAssertFalse(try store.remove(place), "Removing what is not there should report no change")
    }

    func testToggleReturnsResultingState() throws {
        var store = try FavoritesStore(persistence: InMemoryFavoritesPersistence())
        let place = UUID()

        XCTAssertTrue(try store.toggle(place), "First toggle should save")
        XCTAssertTrue(store.isFavorite(place))
        XCTAssertFalse(try store.toggle(place), "Second toggle should unsave")
        XCTAssertFalse(store.isFavorite(place))
    }

    func testRemoveAll() throws {
        var store = try FavoritesStore(persistence: InMemoryFavoritesPersistence())
        try store.add(UUID())
        try store.add(UUID())

        try store.removeAll()
        XCTAssertTrue(store.isEmpty)
    }

    // MARK: - Ordering

    func testAllIsNewestFirst() throws {
        var store = try FavoritesStore(persistence: InMemoryFavoritesPersistence())
        let oldest = UUID(), middle = UUID(), newest = UUID()

        try store.add(oldest, at: date(1))
        try store.add(newest, at: date(3))
        try store.add(middle, at: date(2))

        XCTAssertEqual(store.all.map(\.placeID), [newest, middle, oldest])
    }

    // MARK: - Persistence

    func testFavoritesSurviveReload() throws {
        let persistence = InMemoryFavoritesPersistence()
        let place = UUID()

        var store = try FavoritesStore(persistence: persistence)
        try store.add(place, at: date(1))

        // A new store over the same storage is what a relaunch looks like.
        let reloaded = try FavoritesStore(persistence: persistence)
        XCTAssertTrue(reloaded.isFavorite(place))
        XCTAssertEqual(reloaded.count, 1)
    }

    func testRemovalIsPersisted() throws {
        let persistence = InMemoryFavoritesPersistence()
        let place = UUID()

        var store = try FavoritesStore(persistence: persistence)
        try store.add(place)
        try store.remove(place)

        let reloaded = try FavoritesStore(persistence: persistence)
        XCTAssertFalse(reloaded.isFavorite(place), "A removal must not come back after relaunch")
    }

    func testDuplicatesInStorageAreCollapsedOnLoad() throws {
        // Simulates storage corrupted by an earlier bug or a bad sync merge.
        let place = UUID()
        let persistence = InMemoryFavoritesPersistence(initial: [
            Favorite(placeID: place, savedAt: date(1)),
            Favorite(placeID: place, savedAt: date(5)),
        ])

        let store = try FavoritesStore(persistence: persistence)
        XCTAssertEqual(store.count, 1)
        XCTAssertEqual(store.all.first?.savedAt, date(5), "The most recent save should win")
    }

    // MARK: - Resolution

    func testResolvedReturnsPlacesNewestFirst() throws {
        let basilica = makePlace("Basilica")
        let erna = makePlace("Piani d'Erna")
        var store = try FavoritesStore(persistence: InMemoryFavoritesPersistence())
        try store.add(basilica.id, at: date(1))
        try store.add(erna.id, at: date(2))

        let catalogue = [basilica.id: basilica, erna.id: erna]
        XCTAssertEqual(store.resolved(using: catalogue).map(\.name), ["Piani d'Erna", "Basilica"])
    }

    func testResolvedSkipsDeletedPlaces() throws {
        let known = makePlace("Known")
        var store = try FavoritesStore(persistence: InMemoryFavoritesPersistence())
        try store.add(known.id, at: date(1))
        try store.add(UUID(), at: date(2))  // content since removed

        let resolved = store.resolved(using: [known.id: known])
        XCTAssertEqual(resolved.map(\.name), ["Known"],
                       "A deleted place must not render as a blank row")
    }

    func testPlaceIDsExposesTheFullSet() throws {
        var store = try FavoritesStore(persistence: InMemoryFavoritesPersistence())
        let a = UUID(), b = UUID()
        try store.add(a)
        try store.add(b)
        XCTAssertEqual(store.placeIDs, Set([a, b]))
    }

    // MARK: - Codable

    func testFavoriteRoundTripsThroughJSON() throws {
        let favorite = Favorite(placeID: UUID(), savedAt: date(4))
        let data = try JSONEncoder().encode(favorite)
        let decoded = try JSONDecoder().decode(Favorite.self, from: data)
        XCTAssertEqual(decoded, favorite)
    }
}
