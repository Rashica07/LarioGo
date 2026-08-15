import Fluent
import Vapor

struct PlaceController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        // Spec-mandated URLs. Each is a view over `places` filtered by kind,
        // so there is exactly one implementation of search, geo and paging.
        routes.get("attractions", use: listAttractions)
        routes.get("attractions", ":placeID", use: show)
        routes.get("restaurants", use: listRestaurants)
        routes.get("restaurants", ":placeID", use: show)
        routes.get("events", use: listEvents)
        routes.get("events", ":placeID", use: show)
        // Cross-kind discovery, used by the map and the search tab.
        routes.get("places", use: listAll)
        routes.get("places", ":placeID", use: show)
    }

    // MARK: - List endpoints

    @Sendable
    func listAttractions(req: Request) async throws -> Page<PlaceResponse> {
        try await list(req: req, defaultKinds: [.attraction])
    }

    @Sendable
    func listRestaurants(req: Request) async throws -> Page<PlaceResponse> {
        try await list(req: req, defaultKinds: [.restaurant])
    }

    @Sendable
    func listEvents(req: Request) async throws -> Page<PlaceResponse> {
        try await list(req: req, defaultKinds: [.event, .experience])
    }

    @Sendable
    func listAll(req: Request) async throws -> Page<PlaceResponse> {
        try await list(req: req, defaultKinds: [])
    }

    // MARK: - Detail

    @Sendable
    func show(req: Request) async throws -> PlaceResponse {
        guard let id = req.parameters.get("placeID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid place identifier.")
        }
        guard let place = try await Place.find(id, on: req.db) else {
            throw Abort(.notFound, reason: "No place with that identifier.")
        }

        // Detail views show "1.2 km away" too, so honour lat/lon here as well.
        let lat: Double? = req.query["lat"]
        let lon: Double? = req.query["lon"]
        let origin: (lat: Double, lon: Double)? = (lat != nil && lon != nil) ? (lat!, lon!) : nil
        return try place.response(distanceFrom: origin)
    }

    // MARK: - Shared listing

    private func list(req: Request, defaultKinds: [PlaceKind]) async throws -> Page<PlaceResponse> {
        let query = try PlaceListQuery.decode(from: req, defaultKinds: defaultKinds)
        let builder = Place.query(on: req.db)

        if !query.kinds.isEmpty {
            builder.filter(\.$kind ~~ query.kinds)
        }
        if let category = query.category {
            builder.filter(\.$category == category)
        }
        if let region = query.region {
            builder.filter(\.$region == region)
        }
        if query.featuredOnly {
            builder.filter(\.$isFeatured == true)
        }
        if let minimumRating = query.minimumRating {
            // An unrated place cannot satisfy a rating floor; `>=` on NULL is
            // already false in SQL, which is the behaviour we want.
            builder.filter(\.$rating >= minimumRating)
        }
        if let maximumPrice = query.maximumPriceLevel {
            // Unpriced places are kept: most attractions have no price level and
            // hiding them from a global price filter would surprise the user.
            builder.group(.or) { group in
                group.filter(\.$priceLevel <= maximumPrice)
                group.filter(\.$priceLevel == .null)
            }
        }
        if let search = query.search {
            builder.group(.or) { group in
                group.filter(\.$name ~~ search)
                group.filter(\.$tagline ~~ search)
                group.filter(\.$summary ~~ search)
                group.filter(\.$about ~~ search)
                group.filter(\.$region ~~ search)
            }
        }
        if let startsAfter = query.startsAfter {
            builder.filter(\.$startDate >= startsAfter)
        }
        if let startsBefore = query.startsBefore {
            builder.filter(\.$startDate <= startsBefore)
        }

        // Proximity: prefilter with an indexable bounding box, then measure
        // exactly. The box is a superset of the circle, so nothing inside the
        // radius is lost — the exact haversine check below removes the corners.
        if let origin = query.origin, let radius = query.radius {
            let box = BoundingBox(centerLatitude: origin.lat, centerLongitude: origin.lon, radiusMetres: radius)
            builder.filter(\.$latitude >= box.minLatitude)
            builder.filter(\.$latitude <= box.maxLatitude)
            builder.filter(\.$longitude >= box.minLongitude)
            builder.filter(\.$longitude <= box.maxLongitude)
        }

        // Distance and text relevance cannot be expressed in this query builder,
        // so those two sorts are resolved in memory. That requires loading the
        // filtered set, which is acceptable for a single region's content
        // (hundreds of rows) and is why `fetchCap` exists. Moving to PostGIS and
        // a tsvector index is the scaling path when coverage grows; the API
        // contract does not change when that happens.
        let needsInMemoryWork = query.origin != nil
            || query.sort == .distance
            || query.sort == .relevance
            || query.cuisine != nil
            || query.tag != nil

        if !needsInMemoryWork {
            applyDatabaseSort(query.sort, to: builder)
            let total = try await builder.copy().count()
            let items = try await builder
                .range(((query.page - 1) * query.per)..<(query.page * query.per))
                .all()
            return Page(
                items: try items.map { try $0.response() },
                page: query.page, per: query.per, total: total
            )
        }

        var places = try await builder.limit(Self.fetchCap).all()

        if let radius = query.radius, let origin = query.origin {
            places = places.filter { $0.distance(fromLatitude: origin.lat, longitude: origin.lon) <= radius }
        }
        if let cuisine = query.cuisine?.lowercased() {
            places = places.filter { $0.cuisines.contains { $0.lowercased() == cuisine } }
        }
        if let tag = query.tag?.lowercased() {
            places = places.filter { $0.tags.contains { $0.lowercased() == tag } }
        }

        places = sortInMemory(places, query: query)

        let total = places.count
        let start = (query.page - 1) * query.per
        let pageItems = start < total ? Array(places[start..<min(start + query.per, total)]) : []

        return Page(
            items: try pageItems.map { try $0.response(distanceFrom: query.origin) },
            page: query.page, per: query.per, total: total
        )
    }

    /// Ceiling on rows pulled into memory for distance/relevance work.
    ///
    /// Exceeding this would silently truncate results, so it is set far above
    /// the expected content volume for the Lake Como region and should be
    /// replaced by PostGIS before coverage approaches it.
    private static let fetchCap = 5_000

    private func applyDatabaseSort(_ sort: PlaceSortOption, to builder: QueryBuilder<Place>) {
        switch sort {
        case .rating:
            builder.sort(\.$rating, .descending).sort(\.$reviewCount, .descending)
        case .priceLowToHigh:
            builder.sort(\.$priceLevel, .ascending).sort(\.$name, .ascending)
        case .name:
            builder.sort(\.$name, .ascending)
        case .startDate:
            builder.sort(\.$startDate, .ascending)
        case .relevance, .distance:
            // Handled in memory; ordered here only so paging stays stable.
            builder.sort(\.$isFeatured, .descending).sort(\.$rating, .descending)
        }
    }

    private func sortInMemory(_ places: [Place], query: PlaceListQuery) -> [Place] {
        switch query.sort {
        case .distance:
            guard let origin = query.origin else { return places }
            return places.sorted {
                $0.distance(fromLatitude: origin.lat, longitude: origin.lon)
                    < $1.distance(fromLatitude: origin.lat, longitude: origin.lon)
            }
        case .rating:
            return places.sorted { ($0.rating ?? -1, $0.reviewCount) > ($1.rating ?? -1, $1.reviewCount) }
        case .priceLowToHigh:
            return places.sorted { ($0.priceLevel ?? .max) < ($1.priceLevel ?? .max) }
        case .name:
            return places.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .startDate:
            return places.sorted { ($0.startDate ?? .distantFuture) < ($1.startDate ?? .distantFuture) }
        case .relevance:
            let terms = (query.search ?? "").lowercased()
                .split(whereSeparator: { $0.isWhitespace || $0.isPunctuation })
                .map(String.init)
            return places.sorted { relevance($0, terms: terms) > relevance($1, terms: terms) }
        }
    }

    /// Weighted match score, mirroring `LarioCore.PlaceSearch` so mock-backed and
    /// API-backed results order the same way.
    private func relevance(_ place: Place, terms: [String]) -> Double {
        guard !terms.isEmpty else {
            return (place.rating ?? 0) + (place.isFeatured ? 1 : 0)
        }
        let name = place.name.lowercased()
        var score = 0.0
        for term in terms {
            if name == term { score += 100 }
            else if name.hasPrefix(term) { score += 60 }
            else if name.contains(term) { score += 40 }
            if place.tags.contains(where: { $0.lowercased() == term }) { score += 25 }
            if place.cuisines.contains(where: { $0.lowercased().contains(term) }) { score += 20 }
            if place.tagline.lowercased().contains(term) { score += 10 }
            if place.summary.lowercased().contains(term) { score += 5 }
        }
        score += place.rating ?? 0
        if place.isFeatured { score += 1 }
        return score
    }
}

// MARK: - Bounding box

/// Latitude/longitude box enclosing a circle, used as an indexable prefilter.
struct BoundingBox {
    let minLatitude: Double
    let maxLatitude: Double
    let minLongitude: Double
    let maxLongitude: Double

    init(centerLatitude: Double, centerLongitude: Double, radiusMetres: Double) {
        let metresPerDegreeLatitude = 111_320.0
        let deltaLat = radiusMetres / metresPerDegreeLatitude

        // A degree of longitude narrows towards the poles. Guard the cosine
        // against zero so a near-polar query widens the box rather than
        // dividing by ~0 and producing infinities.
        let cosLat = max(0.01, cos(centerLatitude * .pi / 180))
        let deltaLon = radiusMetres / (metresPerDegreeLatitude * cosLat)

        self.minLatitude = max(-90, centerLatitude - deltaLat)
        self.maxLatitude = min(90, centerLatitude + deltaLat)
        self.minLongitude = max(-180, centerLongitude - deltaLon)
        self.maxLongitude = min(180, centerLongitude + deltaLon)
    }
}
