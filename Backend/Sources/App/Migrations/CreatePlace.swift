import Fluent
import FluentPostgresDriver
import SQLKit

struct CreatePlace: AsyncMigration {
    func prepare(on database: Database) async throws {
        let kind = try await database.enum(PlaceKind.name)
            .case("attraction").case("restaurant").case("event").case("experience")
            .create()

        let category = try await database.enum(PlaceCategory.name)
            .case("landmark").case("nature").case("culture").case("food").case("viewpoint")
            .case("nightlife").case("familyFriendly").case("beach").case("trail").case("shopping")
            .create()

        try await database.schema(Place.schema)
            .id()
            .field("kind", kind, .required)
            .field("name", .string, .required)
            .field("tagline", .string, .required)
            .field("summary", .string, .required)
            .field("about", .string, .required)
            .field("category", category, .required)
            .field("latitude", .double, .required)
            .field("longitude", .double, .required)
            .field("address", .string)
            .field("region", .string, .required)
            .field("image_names", .array(of: .string), .required)
            .field("rating", .double)
            .field("review_count", .int, .required)
            .field("price_level", .int)
            .field("visit_duration", .string)
            .field("website", .string)
            .field("phone", .string)
            .field("tags", .array(of: .string), .required)
            .field("is_featured", .bool, .required)
            .field("cuisines", .array(of: .string), .required)
            .field("accepts_reservations", .bool, .required)
            .field("start_date", .datetime)
            .field("end_date", .datetime)
            .field("organizer", .string)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()

        // Indexes for the filters every discovery request uses. Without these,
        // each list request is a sequential scan.
        if let sql = database as? SQLDatabase {
            try await sql.raw("CREATE INDEX IF NOT EXISTS places_kind_idx ON places (kind)").run()
            try await sql.raw("CREATE INDEX IF NOT EXISTS places_category_idx ON places (category)").run()
            try await sql.raw("CREATE INDEX IF NOT EXISTS places_region_idx ON places (region)").run()
            try await sql.raw("CREATE INDEX IF NOT EXISTS places_rating_idx ON places (rating)").run()
            try await sql.raw("CREATE INDEX IF NOT EXISTS places_start_date_idx ON places (start_date)").run()
            // Bounding-box prefilter for proximity search.
            try await sql.raw("CREATE INDEX IF NOT EXISTS places_lat_lon_idx ON places (latitude, longitude)").run()
        }
    }

    func revert(on database: Database) async throws {
        try await database.schema(Place.schema).delete()
        try await database.enum(PlaceKind.name).delete()
        try await database.enum(PlaceCategory.name).delete()
    }
}
