import Foundation

/// What kind of thing a ``Place`` is.
///
/// Discovery treats attractions, restaurants, events and experiences uniformly —
/// they share a map, a search index, favourites and itineraries — so they are one
/// type with a discriminator rather than four parallel hierarchies. Kind-specific
/// data hangs off the optional detail structs.
public enum PlaceKind: String, CaseIterable, Hashable, Sendable, Codable {
    case attraction
    case restaurant
    case event
    case experience
}

/// Broad discovery category, used for the filter chips.
public enum PlaceCategory: String, CaseIterable, Hashable, Sendable, Codable {
    case landmark
    case nature
    case culture
    case food
    case viewpoint
    case nightlife
    case familyFriendly
    case beach
    case trail
    case shopping
}

/// Indicative cost, mapped to the usual €–€€€€ scale.
public enum PriceLevel: Int, CaseIterable, Hashable, Sendable, Codable, Comparable {
    case budget = 1
    case moderate = 2
    case upscale = 3
    case luxury = 4

    public static func < (lhs: PriceLevel, rhs: PriceLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var symbol: String { String(repeating: "€", count: rawValue) }
}

/// A destination within the coverage area. Lecco first, wider Lake Como next —
/// hence a `region` field rather than anything Lecco-specific baked into the model.
public struct Place: Identifiable, Hashable, Sendable, Codable {
    public let id: UUID
    public let kind: PlaceKind
    public let name: String
    public let tagline: String
    public let summary: String
    public let about: String
    public let category: PlaceCategory
    public let coordinate: Coordinate
    public let address: String?
    public let region: String
    public let imageNames: [String]
    public let rating: Double?
    public let reviewCount: Int
    public let priceLevel: PriceLevel?
    public let visitDuration: String?
    public let website: URL?
    public let phone: String?
    public let tags: [String]
    public let isFeatured: Bool
    public let dining: DiningDetails?
    public let schedule: EventSchedule?
    public let createdAt: Date?
    public let updatedAt: Date?

    public init(
        id: UUID,
        kind: PlaceKind,
        name: String,
        tagline: String = "",
        summary: String = "",
        about: String = "",
        category: PlaceCategory,
        coordinate: Coordinate,
        address: String? = nil,
        region: String,
        imageNames: [String] = [],
        rating: Double? = nil,
        reviewCount: Int = 0,
        priceLevel: PriceLevel? = nil,
        visitDuration: String? = nil,
        website: URL? = nil,
        phone: String? = nil,
        tags: [String] = [],
        isFeatured: Bool = false,
        dining: DiningDetails? = nil,
        schedule: EventSchedule? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.kind = kind
        self.name = name
        self.tagline = tagline
        self.summary = summary
        self.about = about
        self.category = category
        self.coordinate = coordinate
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
        self.dining = dining
        self.schedule = schedule
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Primary image, if any.
    public var primaryImageName: String? { imageNames.first }
}

/// Restaurant/café specifics.
public struct DiningDetails: Hashable, Sendable, Codable {
    public let cuisines: [String]
    public let acceptsReservations: Bool

    public init(cuisines: [String] = [], acceptsReservations: Bool = false) {
        self.cuisines = cuisines
        self.acceptsReservations = acceptsReservations
    }
}

/// Event/experience timing.
public struct EventSchedule: Hashable, Sendable, Codable {
    public let startDate: Date
    public let endDate: Date?
    public let organizer: String?

    public init(startDate: Date, endDate: Date? = nil, organizer: String? = nil) {
        self.startDate = startDate
        self.endDate = endDate
        self.organizer = organizer
    }

    /// Whether the event is running at `date`.
    ///
    /// A single-day event with no end date counts as occurring for the whole of
    /// its start day, so an afternoon festival still appears in "today".
    public func isOccurring(on date: Date, calendar: Calendar = .current) -> Bool {
        if let endDate {
            return date >= startDate && date <= endDate
        }
        return calendar.isDate(date, inSameDayAs: startDate)
    }

    /// Whether the event has finished before `date`.
    public func hasEnded(by date: Date, calendar: Calendar = .current) -> Bool {
        if let endDate { return endDate < date }
        guard let endOfDay = calendar.date(
            byAdding: .day, value: 1,
            to: calendar.startOfDay(for: startDate)
        ) else {
            return startDate < date
        }
        return endOfDay <= date
    }
}
