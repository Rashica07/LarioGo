import Foundation

/// A WGS-84 coordinate.
///
/// Deliberately not `CLLocationCoordinate2D`: CoreLocation is Apple-only, and
/// keeping the domain free of it is what allows this logic to be compiled and
/// tested on Windows. The iOS layer bridges the two in one small extension.
public struct Coordinate: Hashable, Sendable, Codable {
    public let latitude: Double
    public let longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    /// Whether the values are within valid WGS-84 bounds.
    ///
    /// `(0, 0)` is technically valid — it is in the Gulf of Guinea — so this
    /// cannot catch a "missing coordinate" that defaulted to zero. Use
    /// ``isPlausibleForLakeComo`` for that.
    public var isValid: Bool {
        latitude >= -90 && latitude <= 90 && longitude >= -180 && longitude <= 180
    }
}

// MARK: - Distance

extension Coordinate {
    /// Mean Earth radius in metres (IUGG).
    static let earthRadiusMetres = 6_371_008.8

    /// Great-circle distance in metres via the haversine formula.
    ///
    /// Haversine assumes a sphere, so it carries up to ~0.5% error versus a
    /// geodesic calculation. Over the Lake Como region that is a couple of
    /// metres across a 40 km span — irrelevant for "how far is this café", and
    /// far cheaper than Vincenty.
    public func distance(to other: Coordinate) -> Double {
        let lat1 = latitude * .pi / 180
        let lat2 = other.latitude * .pi / 180
        let deltaLat = (other.latitude - latitude) * .pi / 180
        let deltaLon = (other.longitude - longitude) * .pi / 180

        let sinLat = sin(deltaLat / 2)
        let sinLon = sin(deltaLon / 2)
        let a = sinLat * sinLat + cos(lat1) * cos(lat2) * sinLon * sinLon

        // atan2 rather than asin: stable for antipodal points, where floating
        // point can push `a` marginally above 1 and make asin return NaN.
        let c = 2 * atan2(sqrt(a), sqrt(max(0, 1 - a)))
        return Self.earthRadiusMetres * c
    }

    /// Distance in kilometres.
    public func distanceInKilometres(to other: Coordinate) -> Double {
        distance(to: other) / 1000
    }
}

// MARK: - Regional sanity

extension Coordinate {
    /// Bounding box covering Lake Como and the Lecco branch, generously padded.
    ///
    /// Used to catch swapped or mistyped seed coordinates, which otherwise show
    /// up as a pin in the sea rather than as a test failure.
    public static let lakeComoBounds = BoundingBox(
        minLatitude: 45.6, maxLatitude: 46.3,
        minLongitude: 8.9, maxLongitude: 9.7
    )

    public var isPlausibleForLakeComo: Bool {
        Self.lakeComoBounds.contains(self)
    }
}

public struct BoundingBox: Hashable, Sendable, Codable {
    public let minLatitude: Double
    public let maxLatitude: Double
    public let minLongitude: Double
    public let maxLongitude: Double

    public init(minLatitude: Double, maxLatitude: Double, minLongitude: Double, maxLongitude: Double) {
        self.minLatitude = minLatitude
        self.maxLatitude = maxLatitude
        self.minLongitude = minLongitude
        self.maxLongitude = maxLongitude
    }

    public func contains(_ coordinate: Coordinate) -> Bool {
        coordinate.latitude >= minLatitude && coordinate.latitude <= maxLatitude
            && coordinate.longitude >= minLongitude && coordinate.longitude <= maxLongitude
    }
}

// MARK: - Formatting

extension Double {
    /// Human-facing distance string, e.g. "250 m", "1.4 km", "12 km".
    ///
    /// Thresholds match how people actually talk about walking distance: metres
    /// under a kilometre, one decimal up to ten, whole numbers beyond.
    public func formattedAsDistance() -> String {
        guard self.isFinite, self >= 0 else { return "—" }
        if self < 1000 {
            return "\(Int(self.rounded())) m"
        }
        let km = self / 1000
        if km < 10 {
            return String(format: "%.1f km", km)
        }
        return "\(Int(km.rounded())) km"
    }
}
