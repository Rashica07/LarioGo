import XCTest
@testable import LarioCore

final class CoordinateTests: XCTestCase {

    // Real landmarks, so the expected distances are independently checkable.
    let lecco = Coordinate(latitude: 45.8566, longitude: 9.3931)      // Basilica di San Nicolò
    let varenna = Coordinate(latitude: 46.0103, longitude: 9.2847)    // Villa Monastero
    let bellagio = Coordinate(latitude: 45.9862, longitude: 9.2610)

    func testDistanceToSelfIsZero() {
        XCTAssertEqual(lecco.distance(to: lecco), 0, accuracy: 0.001)
    }

    func testDistanceIsSymmetric() {
        XCTAssertEqual(
            lecco.distance(to: varenna),
            varenna.distance(to: lecco),
            accuracy: 0.001
        )
    }

    func testKnownDistanceLeccoToVarenna() {
        // ~19.3 km straight line. Allow 300 m for the spherical approximation.
        let metres = lecco.distance(to: varenna)
        XCTAssertEqual(metres, 19_300, accuracy: 300)
    }

    func testKnownDistanceVarennaToBellagio() {
        // ~3.4 km across the lake.
        XCTAssertEqual(varenna.distance(to: bellagio), 3_400, accuracy: 250)
    }

    func testKilometresMatchesMetres() {
        XCTAssertEqual(
            lecco.distanceInKilometres(to: varenna),
            lecco.distance(to: varenna) / 1000,
            accuracy: 0.0001
        )
    }

    func testAntipodalPointsDoNotProduceNaN() {
        // asin-based haversine can go NaN here; atan2 must not.
        let north = Coordinate(latitude: 45, longitude: 0)
        let antipode = Coordinate(latitude: -45, longitude: 180)
        let distance = north.distance(to: antipode)
        XCTAssertFalse(distance.isNaN, "Antipodal distance produced NaN")
        XCTAssertEqual(distance, .pi * Coordinate.earthRadiusMetres, accuracy: 1)
    }

    func testValidityBounds() {
        XCTAssertTrue(Coordinate(latitude: 0, longitude: 0).isValid)
        XCTAssertTrue(Coordinate(latitude: -90, longitude: 180).isValid)
        XCTAssertFalse(Coordinate(latitude: 91, longitude: 0).isValid)
        XCTAssertFalse(Coordinate(latitude: 0, longitude: 181).isValid)
    }

    func testLakeComoPlausibility() {
        XCTAssertTrue(lecco.isPlausibleForLakeComo)
        XCTAssertTrue(varenna.isPlausibleForLakeComo)
        // Null Island is "valid" but is not in Lombardy — this is the check
        // that catches a coordinate that defaulted to zero.
        XCTAssertFalse(Coordinate(latitude: 0, longitude: 0).isPlausibleForLakeComo)
        // Swapped lat/long for Lecco lands in Somalia.
        XCTAssertFalse(Coordinate(latitude: 9.3931, longitude: 45.8566).isPlausibleForLakeComo)
    }

    // MARK: - Formatting

    func testDistanceFormatting() {
        XCTAssertEqual(Double(0).formattedAsDistance(), "0 m")
        XCTAssertEqual(Double(250).formattedAsDistance(), "250 m")
        XCTAssertEqual(Double(999).formattedAsDistance(), "999 m")
        XCTAssertEqual(Double(1000).formattedAsDistance(), "1.0 km")
        XCTAssertEqual(Double(1449).formattedAsDistance(), "1.4 km")
        XCTAssertEqual(Double(9949).formattedAsDistance(), "9.9 km")
        XCTAssertEqual(Double(12_300).formattedAsDistance(), "12 km")
    }

    func testDistanceFormattingRejectsGarbage() {
        XCTAssertEqual(Double.nan.formattedAsDistance(), "—")
        XCTAssertEqual(Double.infinity.formattedAsDistance(), "—")
        XCTAssertEqual(Double(-5).formattedAsDistance(), "—")
    }

    // MARK: - Codable

    func testCoordinateRoundTripsThroughJSON() throws {
        let data = try JSONEncoder().encode(lecco)
        let decoded = try JSONDecoder().decode(Coordinate.self, from: data)
        XCTAssertEqual(decoded, lecco)
    }
}
