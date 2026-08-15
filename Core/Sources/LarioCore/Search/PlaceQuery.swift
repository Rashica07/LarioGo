import Foundation

/// How a result set should be ordered.
public enum PlaceSort: String, CaseIterable, Hashable, Sendable, Codable {
    /// Best textual match, then rating. Only meaningful with search text.
    case relevance
    case distance
    case rating
    case priceLowToHigh
    case name
}

/// A discovery request: everything the user has narrowed by.
///
/// One value object rather than a pile of function arguments, so the same query
/// can be built by the search screen, the map filters, or a deep link, and then
/// executed identically.
public struct PlaceQuery: Hashable, Sendable {
    public var text: String
    public var kinds: Set<PlaceKind>
    public var categories: Set<PlaceCategory>
    public var minimumRating: Double?
    public var maximumPriceLevel: PriceLevel?
    public var cuisines: Set<String>
    /// Where the user is. Required for distance filtering and sorting.
    public var origin: Coordinate?
    /// Metres. Ignored when `origin` is nil.
    public var maximumDistance: Double?
    public var featuredOnly: Bool
    /// Restricts events/experiences to those occurring in the range.
    public var dateRange: ClosedRange<Date>?
    public var sort: PlaceSort

    public init(
        text: String = "",
        kinds: Set<PlaceKind> = [],
        categories: Set<PlaceCategory> = [],
        minimumRating: Double? = nil,
        maximumPriceLevel: PriceLevel? = nil,
        cuisines: Set<String> = [],
        origin: Coordinate? = nil,
        maximumDistance: Double? = nil,
        featuredOnly: Bool = false,
        dateRange: ClosedRange<Date>? = nil,
        sort: PlaceSort = .relevance
    ) {
        self.text = text
        self.kinds = kinds
        self.categories = categories
        self.minimumRating = minimumRating
        self.maximumPriceLevel = maximumPriceLevel
        self.cuisines = cuisines
        self.origin = origin
        self.maximumDistance = maximumDistance
        self.featuredOnly = featuredOnly
        self.dateRange = dateRange
        self.sort = sort
    }

    /// Whether the query narrows anything at all. Used to decide between
    /// "no results" and "start typing" empty states.
    public var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && kinds.isEmpty
            && categories.isEmpty
            && minimumRating == nil
            && maximumPriceLevel == nil
            && cuisines.isEmpty
            && maximumDistance == nil
            && !featuredOnly
            && dateRange == nil
    }

    /// Number of active narrowing filters, for the "Filters (3)" badge.
    /// Text is excluded — it is the search field, not a filter chip.
    public var activeFilterCount: Int {
        var count = 0
        if !kinds.isEmpty { count += 1 }
        if !categories.isEmpty { count += 1 }
        if minimumRating != nil { count += 1 }
        if maximumPriceLevel != nil { count += 1 }
        if !cuisines.isEmpty { count += 1 }
        if maximumDistance != nil { count += 1 }
        if featuredOnly { count += 1 }
        if dateRange != nil { count += 1 }
        return count
    }
}

/// A place paired with its computed distance from the query origin.
public struct PlaceResult: Identifiable, Hashable, Sendable {
    public let place: Place
    /// Metres from the query origin, or nil when no origin was supplied.
    public let distance: Double?

    public var id: UUID { place.id }

    public init(place: Place, distance: Double?) {
        self.place = place
        self.distance = distance
    }

    public var formattedDistance: String? {
        distance.map { $0.formattedAsDistance() }
    }
}
