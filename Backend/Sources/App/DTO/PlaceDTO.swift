import Vapor

// MARK: - Response

struct PlaceResponse: Content {
    let id: UUID
    let kind: String
    let name: String
    let tagline: String
    let summary: String
    let about: String
    let category: String
    let coordinate: CoordinateResponse
    let address: String?
    let region: String
    let imageNames: [String]
    let rating: Double?
    let reviewCount: Int
    let priceLevel: Int?
    let visitDuration: String?
    let website: String?
    let phone: String?
    let tags: [String]
    let isFeatured: Bool
    let dining: DiningResponse?
    let schedule: ScheduleResponse?
    /// Metres from the request's `lat`/`lon`. Absent when none was supplied —
    /// never a placeholder like 0 or -1, which clients render as real values.
    let distance: Double?
    let createdAt: Date?
    let updatedAt: Date?
}

struct CoordinateResponse: Content {
    let latitude: Double
    let longitude: Double
}

struct DiningResponse: Content {
    let cuisines: [String]
    let acceptsReservations: Bool
}

struct ScheduleResponse: Content {
    let startDate: Date
    let endDate: Date?
    let organizer: String?
}

extension Place {
    func response(distanceFrom origin: (lat: Double, lon: Double)? = nil) throws -> PlaceResponse {
        PlaceResponse(
            id: try requireID(),
            kind: kind.rawValue,
            name: name,
            tagline: tagline,
            summary: summary,
            about: about,
            category: category.rawValue,
            coordinate: CoordinateResponse(latitude: latitude, longitude: longitude),
            address: address,
            region: region,
            imageNames: imageNames,
            rating: rating,
            reviewCount: reviewCount,
            priceLevel: priceLevel,
            visitDuration: visitDuration,
            website: website,
            phone: phone,
            tags: tags,
            isFeatured: isFeatured,
            dining: kind == .restaurant || !cuisines.isEmpty
                ? DiningResponse(cuisines: cuisines, acceptsReservations: acceptsReservations)
                : nil,
            schedule: startDate.map {
                ScheduleResponse(startDate: $0, endDate: endDate, organizer: organizer)
            },
            distance: origin.map { distance(fromLatitude: $0.lat, longitude: $0.lon) },
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

// MARK: - Pagination

/// Envelope for every list endpoint.
///
/// A bare array leaves the client unable to tell "no more results" from "the
/// page happened to be short", so paging state is explicit.
struct Page<T: Content>: Content {
    let items: [T]
    let metadata: PageMetadata

    init(items: [T], page: Int, per: Int, total: Int) {
        self.items = items
        self.metadata = PageMetadata(page: page, per: per, total: total)
    }
}

struct PageMetadata: Content {
    let page: Int
    let per: Int
    let total: Int
    let totalPages: Int
    let hasNextPage: Bool

    init(page: Int, per: Int, total: Int) {
        self.page = page
        self.per = per
        self.total = total
        self.totalPages = per > 0 ? Int((Double(total) / Double(per)).rounded(.up)) : 0
        self.hasNextPage = page < totalPages
    }
}

// MARK: - Query

/// Parsed and validated discovery filters.
///
/// Built from query parameters by hand rather than `Content` decoding so that a
/// bad value produces a clear 400 instead of a silent default — a client asking
/// for `minRating=banana` should be told, not quietly served everything.
struct PlaceListQuery {
    var kinds: [PlaceKind] = []
    var category: PlaceCategory?
    var search: String?
    var minimumRating: Double?
    var maximumPriceLevel: Int?
    var cuisine: String?
    var region: String?
    var tag: String?
    var featuredOnly = false
    var origin: (lat: Double, lon: Double)?
    var radius: Double?
    var startsAfter: Date?
    var startsBefore: Date?
    var sort: PlaceSortOption = .relevance
    var page = 1
    var per = 20

    /// Hard ceiling so a client cannot ask for the entire table in one request.
    static let maximumPer = 100

    static func decode(from req: Request, defaultKinds: [PlaceKind] = []) throws -> PlaceListQuery {
        var query = PlaceListQuery()
        query.kinds = defaultKinds

        if let raw: String = req.query["kind"] {
            let kinds = raw.split(separator: ",").map(String.init).compactMap(PlaceKind.init(rawValue:))
            guard kinds.count == raw.split(separator: ",").count else {
                throw Abort(.badRequest, reason: "Unknown kind. Valid values: \(PlaceKind.allCases.map(\.rawValue).joined(separator: ", ")).")
            }
            query.kinds = kinds
        }

        if let raw: String = req.query["category"] {
            guard let category = PlaceCategory(rawValue: raw) else {
                throw Abort(.badRequest, reason: "Unknown category. Valid values: \(PlaceCategory.allCases.map(\.rawValue).joined(separator: ", ")).")
            }
            query.category = category
        }

        if let search: String = req.query["search"] {
            let trimmed = search.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { query.search = trimmed }
        }

        if let rating: Double = req.query["minRating"] {
            guard (0...5).contains(rating) else {
                throw Abort(.badRequest, reason: "minRating must be between 0 and 5.")
            }
            query.minimumRating = rating
        }

        if let price: Int = req.query["maxPrice"] {
            guard (1...4).contains(price) else {
                throw Abort(.badRequest, reason: "maxPrice must be between 1 and 4.")
            }
            query.maximumPriceLevel = price
        }

        query.cuisine = req.query["cuisine"]
        query.region = req.query["region"]
        query.tag = req.query["tag"]
        query.featuredOnly = (req.query["featured"] ?? "") == "true"

        // Latitude and longitude are meaningless individually.
        let lat: Double? = req.query["lat"]
        let lon: Double? = req.query["lon"]
        switch (lat, lon) {
        case let (lat?, lon?):
            guard (-90...90).contains(lat), (-180...180).contains(lon) else {
                throw Abort(.badRequest, reason: "lat must be -90..90 and lon must be -180..180.")
            }
            query.origin = (lat, lon)
        case (nil, nil):
            break
        default:
            throw Abort(.badRequest, reason: "lat and lon must be supplied together.")
        }

        if let radius: Double = req.query["radius"] {
            guard radius > 0 else { throw Abort(.badRequest, reason: "radius must be positive.") }
            guard query.origin != nil else {
                throw Abort(.badRequest, reason: "radius requires lat and lon.")
            }
            query.radius = radius
        }

        query.startsAfter = req.query["startsAfter"]
        query.startsBefore = req.query["startsBefore"]

        if let raw: String = req.query["sort"] {
            guard let sort = PlaceSortOption(rawValue: raw) else {
                throw Abort(.badRequest, reason: "Unknown sort. Valid values: \(PlaceSortOption.allCases.map(\.rawValue).joined(separator: ", ")).")
            }
            guard sort != .distance || query.origin != nil else {
                throw Abort(.badRequest, reason: "sort=distance requires lat and lon.")
            }
            query.sort = sort
        } else if query.origin != nil {
            // Proximity is the natural default once we know where the user is.
            query.sort = .distance
        }

        if let page: Int = req.query["page"] {
            guard page >= 1 else { throw Abort(.badRequest, reason: "page must be 1 or greater.") }
            query.page = page
        }

        if let per: Int = req.query["per"] {
            guard per >= 1, per <= Self.maximumPer else {
                throw Abort(.badRequest, reason: "per must be between 1 and \(Self.maximumPer).")
            }
            query.per = per
        }

        return query
    }
}

enum PlaceSortOption: String, CaseIterable {
    case relevance, distance, rating, priceLowToHigh, name, startDate
}
