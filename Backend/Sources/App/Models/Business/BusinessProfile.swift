import Fluent
import Vapor

/// Business-supplied information layered on top of a catalogue listing.
///
/// WHY THIS IS A SEPARATE TABLE AND NOT COLUMNS ON `Place`.
///
/// `Place` rows for the Lecco area were imported from OpenStreetMap and are
/// governed by the Open Database Licence. Letting a restaurateur edit that row
/// in place would mix ODbL-derived data with proprietary data in the same
/// fields, and we would no longer be able to say which is which — which is
/// exactly what the licence requires us to be able to say, and what we would
/// need in order to contribute corrections back upstream.
///
/// So the imported record stays untouched and authoritative about provenance,
/// and everything a business tells us lives here. The read path merges the two:
/// a published overlay value wins, otherwise the catalogue value shows, and the
/// response reports which fields came from where.
///
/// Every field is optional on purpose. A business that only ever fixes its
/// opening hours should not have to restate its own name to do it.
final class BusinessProfile: Model, @unchecked Sendable {
    static let schema = "business_profiles"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "organization_id")
    var organization: Organization

    @Parent(key: "place_id")
    var place: Place

    /// Draft edits are visible only inside the portal. Publishing requires the
    /// organisation to be verified — see `canPublish` on `VerificationState`.
    @Field(key: "is_published")
    var isPublished: Bool

    @OptionalField(key: "name")
    var name: String?

    @OptionalField(key: "summary")
    var summary: String?

    @OptionalField(key: "about")
    var about: String?

    @OptionalField(key: "address")
    var address: String?

    @OptionalField(key: "phone")
    var phone: String?

    @OptionalField(key: "website")
    var website: String?

    /// Opening hours in OpenStreetMap syntax ("Mo-Fr 09:00-18:00; Sa off").
    /// Reusing that grammar rather than inventing one keeps the door open to
    /// contributing corrections back to OSM, where the listing came from.
    @OptionalField(key: "opening_hours")
    var openingHours: String?

    @OptionalField(key: "price_level")
    var priceLevel: Int?

    @Field(key: "cuisines")
    var cuisines: [String]

    /// What the business offers: "terrazza", "accessibile in sedia a rotelle",
    /// "menù senza glutine". Free-form for now; a controlled vocabulary can be
    /// layered on later without a migration, because the column is already a
    /// list of strings.
    @Field(key: "services")
    var services: [String]

    @Field(key: "photo_urls")
    var photoUrls: [String]

    /// Whether the business takes reservations through Traversar. Distinct from
    /// the catalogue's `acceptsReservations`, which only records that the place
    /// takes bookings *somehow*.
    @Field(key: "accepts_reservations")
    var acceptsReservations: Bool

    /// Guests per sitting, used later to bound availability. Null means "no
    /// limit declared", not "zero".
    @OptionalField(key: "capacity")
    var capacity: Int?

    @OptionalField(key: "published_at")
    var publishedAt: Date?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() {}

    init(id: UUID? = nil, organizationID: UUID, placeID: UUID) {
        self.id = id
        self.$organization.id = organizationID
        self.$place.id = placeID
        self.isPublished = false
        self.cuisines = []
        self.services = []
        self.photoUrls = []
        self.acceptsReservations = false
    }

    /// Which fields the business has actually filled in.
    ///
    /// Drives the completeness indicator in the portal. Counting only fields a
    /// business can realistically supply, so the figure is reachable — a
    /// progress bar that stops at 70% however hard you try is worse than none.
    var filledFields: (filled: Int, total: Int) {
        let checks: [Bool] = [
            !(name ?? "").isEmpty,
            !(summary ?? "").isEmpty,
            !(about ?? "").isEmpty,
            !(address ?? "").isEmpty,
            !(phone ?? "").isEmpty,
            !(website ?? "").isEmpty,
            !(openingHours ?? "").isEmpty,
            priceLevel != nil,
            !services.isEmpty,
            !photoUrls.isEmpty,
        ]
        return (checks.filter { $0 }.count, checks.count)
    }

    var completeness: Int {
        let (filled, total) = filledFields
        guard total > 0 else { return 0 }
        return Int((Double(filled) / Double(total) * 100).rounded())
    }
}
