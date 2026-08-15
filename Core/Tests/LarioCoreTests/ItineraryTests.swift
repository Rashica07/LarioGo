import XCTest
@testable import LarioCore

final class ItineraryTests: XCTestCase {

    let calendar = Calendar(identifier: .gregorian)

    func day(_ d: Int, hour: Int = 9) -> Date {
        var c = DateComponents()
        c.year = 2026; c.month = 7; c.day = d; c.hour = hour
        return Calendar(identifier: .gregorian).date(from: c)!
    }

    func makePlace(_ name: String, id: UUID = UUID()) -> Place {
        Place(
            id: id, kind: .attraction, name: name, category: .landmark,
            coordinate: Coordinate(latitude: 45.85, longitude: 9.39), region: "Lecco"
        )
    }

    // MARK: - Adding

    func testAddAppendsInOrder() {
        var trip = Itinerary(name: "Lecco Weekend")
        let a = UUID(), b = UUID(), c = UUID()

        trip.add(placeID: a, on: day(10), calendar: calendar)
        trip.add(placeID: b, on: day(10), calendar: calendar)
        trip.add(placeID: c, on: day(10), calendar: calendar)

        XCTAssertEqual(trip.stops(on: day(10), calendar: calendar).map(\.placeID), [a, b, c])
        XCTAssertEqual(trip.stops(on: day(10), calendar: calendar).map(\.order), [0, 1, 2])
    }

    func testAddNormalisesTimeToStartOfDay() {
        var trip = Itinerary(name: "T")
        trip.add(placeID: UUID(), on: day(10, hour: 23), calendar: calendar)
        let stop = trip.stops.first
        XCTAssertEqual(stop?.day, calendar.startOfDay(for: day(10)),
                       "Stops added late at night must not land on their own day bucket")
    }

    func testAddingSamePlaceTwiceOnSameDayIsRejected() {
        var trip = Itinerary(name: "T")
        let place = UUID()
        XCTAssertTrue(trip.add(placeID: place, on: day(10), calendar: calendar))
        XCTAssertFalse(trip.add(placeID: place, on: day(10), calendar: calendar))
        XCTAssertEqual(trip.stops.count, 1)
    }

    func testSamePlaceOnDifferentDaysIsAllowed() {
        var trip = Itinerary(name: "T")
        let place = UUID()
        XCTAssertTrue(trip.add(placeID: place, on: day(10), calendar: calendar))
        XCTAssertTrue(trip.add(placeID: place, on: day(11), calendar: calendar),
                      "Revisiting a place on another day is legitimate")
        XCTAssertEqual(trip.stops.count, 2)
    }

    func testDifferentTimesOnSameDayCountAsSameDay() {
        var trip = Itinerary(name: "T")
        let place = UUID()
        trip.add(placeID: place, on: day(10, hour: 8), calendar: calendar)
        XCTAssertFalse(trip.add(placeID: place, on: day(10, hour: 20), calendar: calendar))
    }

    // MARK: - Removing

    func testRemoveClosesOrderingGap() {
        var trip = Itinerary(name: "T")
        let a = UUID(), b = UUID(), c = UUID()
        trip.add(placeID: a, on: day(10), calendar: calendar)
        trip.add(placeID: b, on: day(10), calendar: calendar)
        trip.add(placeID: c, on: day(10), calendar: calendar)

        let middle = trip.stops(on: day(10), calendar: calendar)[1]
        XCTAssertTrue(trip.remove(stopID: middle.id, calendar: calendar))

        let remaining = trip.stops(on: day(10), calendar: calendar)
        XCTAssertEqual(remaining.map(\.placeID), [a, c])
        XCTAssertEqual(remaining.map(\.order), [0, 1], "Orders must stay contiguous after removal")
    }

    func testRemoveUnknownStopIsRejected() {
        var trip = Itinerary(name: "T")
        trip.add(placeID: UUID(), on: day(10), calendar: calendar)
        XCTAssertFalse(trip.remove(stopID: UUID(), calendar: calendar))
        XCTAssertEqual(trip.stops.count, 1)
    }

    // MARK: - Reordering

    func testMoveDownwards() {
        var trip = Itinerary(name: "T")
        let a = UUID(), b = UUID(), c = UUID()
        [a, b, c].forEach { trip.add(placeID: $0, on: day(10), calendar: calendar) }

        // Drag the first item to the end.
        XCTAssertTrue(trip.move(on: day(10), from: 0, to: 3, calendar: calendar))
        XCTAssertEqual(trip.stops(on: day(10), calendar: calendar).map(\.placeID), [b, c, a])
    }

    func testMoveUpwards() {
        var trip = Itinerary(name: "T")
        let a = UUID(), b = UUID(), c = UUID()
        [a, b, c].forEach { trip.add(placeID: $0, on: day(10), calendar: calendar) }

        XCTAssertTrue(trip.move(on: day(10), from: 2, to: 0, calendar: calendar))
        XCTAssertEqual(trip.stops(on: day(10), calendar: calendar).map(\.placeID), [c, a, b])
    }

    func testMoveToSamePositionIsANoOp() {
        var trip = Itinerary(name: "T")
        let a = UUID(), b = UUID()
        [a, b].forEach { trip.add(placeID: $0, on: day(10), calendar: calendar) }

        XCTAssertTrue(trip.move(on: day(10), from: 0, to: 0, calendar: calendar))
        XCTAssertEqual(trip.stops(on: day(10), calendar: calendar).map(\.placeID), [a, b])
    }

    func testMoveWithInvalidIndexIsRejected() {
        var trip = Itinerary(name: "T")
        trip.add(placeID: UUID(), on: day(10), calendar: calendar)
        XCTAssertFalse(trip.move(on: day(10), from: 5, to: 0, calendar: calendar))
        XCTAssertFalse(trip.move(on: day(10), from: 0, to: -1, calendar: calendar))
        XCTAssertFalse(trip.move(on: day(10), from: 0, to: 99, calendar: calendar))
    }

    func testMoveKeepsOrdersContiguous() {
        var trip = Itinerary(name: "T")
        (0..<5).forEach { _ in trip.add(placeID: UUID(), on: day(10), calendar: calendar) }
        trip.move(on: day(10), from: 4, to: 1, calendar: calendar)
        XCTAssertEqual(trip.stops(on: day(10), calendar: calendar).map(\.order), [0, 1, 2, 3, 4])
    }

    func testMoveDoesNotAffectOtherDays() {
        var trip = Itinerary(name: "T")
        let x = UUID(), y = UUID()
        trip.add(placeID: x, on: day(11), calendar: calendar)
        trip.add(placeID: y, on: day(11), calendar: calendar)
        let a = UUID(), b = UUID()
        trip.add(placeID: a, on: day(10), calendar: calendar)
        trip.add(placeID: b, on: day(10), calendar: calendar)

        trip.move(on: day(10), from: 0, to: 2, calendar: calendar)
        XCTAssertEqual(trip.stops(on: day(11), calendar: calendar).map(\.placeID), [x, y])
    }

    // MARK: - Rescheduling

    func testRescheduleMovesStopToAnotherDay() {
        var trip = Itinerary(name: "T")
        let a = UUID(), b = UUID()
        trip.add(placeID: a, on: day(10), calendar: calendar)
        trip.add(placeID: b, on: day(10), calendar: calendar)

        let first = trip.stops(on: day(10), calendar: calendar)[0]
        XCTAssertTrue(trip.reschedule(stopID: first.id, to: day(11), calendar: calendar))

        XCTAssertEqual(trip.stops(on: day(10), calendar: calendar).map(\.placeID), [b])
        XCTAssertEqual(trip.stops(on: day(11), calendar: calendar).map(\.placeID), [a])
        XCTAssertEqual(trip.stops(on: day(10), calendar: calendar).map(\.order), [0],
                       "The vacated day must re-index")
    }

    func testRescheduleToSameDayIsRejected() {
        var trip = Itinerary(name: "T")
        trip.add(placeID: UUID(), on: day(10), calendar: calendar)
        let stop = trip.stops[0]
        XCTAssertFalse(trip.reschedule(stopID: stop.id, to: day(10, hour: 22), calendar: calendar))
    }

    // MARK: - Days

    func testDaysAreSortedAndDeduplicated() {
        var trip = Itinerary(name: "T")
        trip.add(placeID: UUID(), on: day(12), calendar: calendar)
        trip.add(placeID: UUID(), on: day(10), calendar: calendar)
        trip.add(placeID: UUID(), on: day(10, hour: 18), calendar: calendar)
        trip.add(placeID: UUID(), on: day(11), calendar: calendar)

        XCTAssertEqual(trip.days.count, 3)
        XCTAssertEqual(trip.days, trip.days.sorted())
    }

    // MARK: - Resolution

    func testResolvePairsStopsWithPlaces() {
        let basilica = makePlace("Basilica")
        let erna = makePlace("Piani d'Erna")
        var trip = Itinerary(name: "T")
        trip.add(placeID: basilica.id, on: day(10), calendar: calendar)
        trip.add(placeID: erna.id, on: day(10), calendar: calendar)

        let catalogue = [basilica.id: basilica, erna.id: erna]
        let resolved = trip.resolve(using: catalogue, calendar: calendar)

        XCTAssertEqual(resolved.count, 1)
        XCTAssertEqual(resolved[0].entries.map(\.place.name), ["Basilica", "Piani d'Erna"])
    }

    func testResolveDropsMissingPlacesRatherThanFailing() {
        let known = makePlace("Known")
        var trip = Itinerary(name: "T")
        trip.add(placeID: known.id, on: day(10), calendar: calendar)
        trip.add(placeID: UUID(), on: day(10), calendar: calendar)  // deleted content

        let resolved = trip.resolve(using: [known.id: known], calendar: calendar)
        XCTAssertEqual(resolved[0].entries.map(\.place.name), ["Known"],
                       "One missing place must not empty the whole trip")
    }

    func testUnresolvedPlaceIDsAreReported() {
        let known = makePlace("Known")
        let ghost = UUID()
        var trip = Itinerary(name: "T")
        trip.add(placeID: known.id, on: day(10), calendar: calendar)
        trip.add(placeID: ghost, on: day(10), calendar: calendar)

        XCTAssertEqual(trip.unresolvedPlaceIDs(using: [known.id: known]), [ghost])
    }

    func testResolveGroupsByDayInOrder() {
        let a = makePlace("A"), b = makePlace("B")
        var trip = Itinerary(name: "T")
        trip.add(placeID: b.id, on: day(12), calendar: calendar)
        trip.add(placeID: a.id, on: day(10), calendar: calendar)

        let resolved = trip.resolve(using: [a.id: a, b.id: b], calendar: calendar)
        XCTAssertEqual(resolved.map(\.entries.first?.place.name), ["A", "B"])
    }

    // MARK: - Bookkeeping

    func testMutationsUpdateTimestamp() {
        let created = day(1)
        var trip = Itinerary(name: "T", createdAt: created, updatedAt: created)
        trip.add(placeID: UUID(), on: day(10), calendar: calendar, now: day(2))
        XCTAssertEqual(trip.updatedAt, day(2))
        XCTAssertEqual(trip.createdAt, created, "createdAt must never move")
    }

    func testContainsChecksAcrossAllDays() {
        var trip = Itinerary(name: "T")
        let place = UUID()
        trip.add(placeID: place, on: day(11), calendar: calendar)
        XCTAssertTrue(trip.contains(placeID: place))
        XCTAssertFalse(trip.contains(placeID: UUID()))
    }

    func testItineraryRoundTripsThroughJSON() throws {
        var trip = Itinerary(name: "Lake Como Trip")
        trip.add(placeID: UUID(), on: day(10), calendar: calendar)
        trip.add(placeID: UUID(), on: day(11), calendar: calendar)

        let data = try JSONEncoder().encode(trip)
        let decoded = try JSONDecoder().decode(Itinerary.self, from: data)
        XCTAssertEqual(decoded, trip, "Saved trips must survive a persistence round trip")
    }
}
