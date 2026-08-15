import Fluent
import Vapor

/// Discovery content: attractions, restaurants, events and experiences.
///
/// One table with a `kind` discriminator rather than four near-identical tables.
/// They share every discovery concern — geosearch, text search, rating, images,
/// favourites, itinerary membership — so splitting them would mean maintaining
/// four copies of the same query logic. `/attractions`, `/restaurants` and
/// `/events` are views over this table.
///
/// Mirrors `LarioCore.Place` so the client decodes the API straight into the
/// domain model.
final class Place: Model, @unchecked Sendable {
    static let schema = "places"

    @ID(key: .id)
    var id: UUID?

    @Enum(key: "kind")
    var kind: PlaceKind

    @Field(key: "name")
    var name: String

    @Field(key: "tagline")
    var tagline: String

    @Field(key: "summary")
    var summary: String

    @Field(key: "about")
    var about: String

    @Enum(key: "category")
    var category: PlaceCategory

    @Field(key: "latitude")
    var latitude: Double

    @Field(key: "longitude")
    var longitude: Double

    @OptionalField(key: "address")
    var address: String?

    /// Free text ("Lecco", "Varenna"). Deliberately not an enum: the MVP starts
    /// in Lecco and expands across Lake Como, and a migration per new town would
    /// be friction for no benefit.
    @Field(key: "region")
    var region: String

    @Field(key: "image_names")
    var imageNames: [String]

    @OptionalField(key: "rating")
    var rating: Double?

    @Field(key: "review_count")
    var reviewCount: Int

    /// 1–4, matching the €–€€€€ scale. Nil where price is not meaningful.
    @OptionalField(key: "price_level")
    var priceLevel: Int?

    @OptionalField(key: "visit_duration")
    var visitDuration: String?

    @OptionalField(key: "website")
    var website: String?

    @OptionalField(key: "phone")
    var phone: String?

    @Field(key: "tags")
    var tags: [String]

    @Field(key: "is_featured")
    var isFeatured: Bool

    // Dining
    @Field(key: "cuisines")
    var cuisines: [String]

    @Field(key: "accepts_reservations")
    var acceptsReservations: Bool

    // Event / experience scheduling
    @OptionalField(key: "start_date")
    var startDate: Date?

    @OptionalField(key: "end_date")
    var endDate: Date?

    @OptionalField(key: "organizer")
    var organizer: String?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        kind: PlaceKind,
        name: String,
        tagline: String = "",
        summary: String = "",
        about: String = "",
        category: PlaceCategory,
        latitude: Double,
        longitude: Double,
        address: String? = nil,
        region: String,
        imageNames: [String] = [],
        rating: Double? = nil,
        reviewCount: Int = 0,
        priceLevel: Int? = nil,
        visitDuration: String? = nil,
        website: String? = nil,
        phone: String? = nil,
        tags: [String] = [],
        isFeatured: Bool = false,
        cuisines: [String] = [],
        acceptsReservations: Bool = false,
        startDate: Date? = nil,
        endDate: Date? = nil,
        organizer: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.name = name
        self.tagline = tagline
        self.summary = summary
        self.about = about
        self.category = category
        self.latitude = latitude
        self.longitude = longitude
        self.address = address
        self.region = region
        self.imageNames = imageNames
        self.rating = rating
        self.reviewCount = reviewCount
        self.priceLevel = priceLevel
        self.visitDuration = visitDuration
        self.website = website
        self.phone = phone
        self.tags = tags
        self.isFeatured = isFeatured
        self.cuisines = cuisines
        self.acceptsReservations = acceptsReservations
        self.startDate = startDate
        self.endDate = endDate
        self.organizer = organizer
    }
}

// MARK: - Enums

enum PlaceKind: String, Codable, CaseIterable {
    case attraction, restaurant, event, experience

    static let name = "place_kind"
}

enum PlaceCategory: String, Codable, CaseIterable {
    case landmark, nature, culture, food, viewpoint
    case nightlife, familyFriendly, beach, trail, shopping

    static let name = "place_category"
}

// MARK: - Geo

extension Place {
    /// Great-circle distance in metres from a coordinate.
    ///
    /// Duplicated from `LarioCore.Coordinate` rather than shared, because the
    /// backend package cannot depend on the iOS-side package without coupling
    /// deployment to the app's release cycle. Kept identical deliberately —
    /// both use haversine with `atan2`, which unlike `asin` cannot return NaN
    /// for antipodal points.
    func distance(fromLatitude lat: Double, longitude lon: Double) -> Double {
        let earthRadius = 6_371_008.8
        let lat1 = lat * .pi / 180
        let lat2 = latitude * .pi / 180
        let deltaLat = (latitude - lat) * .pi / 180
        let deltaLon = (longitude - lon) * .pi / 180

        let sinLat = sin(deltaLat / 2)
        let sinLon = sin(deltaLon / 2)
        let a = sinLat * sinLat + cos(lat1) * cos(lat2) * sinLon * sinLon
        return earthRadius * 2 * atan2(sqrt(a), sqrt(max(0, 1 - a)))
    }
}
