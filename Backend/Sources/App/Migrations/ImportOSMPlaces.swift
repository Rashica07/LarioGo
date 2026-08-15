import Fluent
import Foundation
import Vapor

/// Imports real places exported from OpenStreetMap by `tools/import_osm.py`.
///
/// Licence: the data is ODbL. Commercial use is permitted, attribution to
/// "© OpenStreetMap contributors" is required wherever it is shown, and derived
/// databases are share-alike. The iOS app carries that credit in
/// `AttributionView`; any other surface serving this data must do the same.
///
/// Ratings are deliberately left null. Real ratings belong to whoever collected
/// them, so LarioGo's must come from LarioGo's own users. An unrated place
/// renders as "New" rather than as zero stars.
struct ImportOSMPlaces: AsyncMigration {

    /// Shape written by the importer.
    struct Document: Codable {
        let source: String
        let licence: String
        let attribution: String
        let count: Int
        let places: [ImportedPlace]
    }

    struct ImportedPlace: Codable {
        let osmType: String?
        let osmId: Int?
        let kind: String
        let category: String
        let name: String
        let summary: String
        let about: String
        let latitude: Double
        let longitude: Double
        let address: String?
        let region: String
        let website: String?
        let phone: String?
        let openingHours: String?
        let cuisines: [String]
        let acceptsReservations: Bool
        let tags: [String]
        let completeness: Int?
    }

    func prepare(on database: Database) async throws {
        guard let document = try Self.loadDocument(logger: database.logger) else {
            database.logger.notice("ImportOSMPlaces: no export found; skipping.")
            return
        }

        // Idempotent: importing twice would duplicate every place. Keyed on the
        // OSM identifier carried in tags rather than on name, since two real
        // churches can share a name.
        let existing = try await Place.query(on: database)
            .filter(\.$region != "")
            .all()
        let alreadyImported = Set(
            existing.compactMap { place in
                place.tags.first { $0.hasPrefix("osm:") }
            }
        )

        var inserted = 0
        for imported in document.places {
            guard let kind = PlaceKind(rawValue: imported.kind),
                  let category = PlaceCategory(rawValue: imported.category) else {
                continue
            }

            let osmTag = imported.osmId.map { "osm:\(imported.osmType ?? "node")/\($0)" }
            if let osmTag, alreadyImported.contains(osmTag) { continue }

            var tags = imported.tags
            if let osmTag { tags.append(osmTag) }
            // Marks provenance so the UI can credit the source per place, and so
            // a future re-import can find exactly these rows.
            tags.append("source:openstreetmap")

            let place = Place(
                kind: kind,
                name: imported.name,
                tagline: "",
                summary: imported.summary,
                about: imported.about,
                category: category,
                latitude: imported.latitude,
                longitude: imported.longitude,
                address: imported.address,
                region: imported.region,
                imageNames: [],
                // Never invented. See the type doc above.
                rating: nil,
                reviewCount: 0,
                priceLevel: nil,
                visitDuration: nil,
                website: imported.website,
                phone: imported.phone,
                tags: tags,
                isFeatured: false,
                cuisines: imported.cuisines,
                acceptsReservations: imported.acceptsReservations
            )
            try await place.save(on: database)
            inserted += 1
        }

        database.logger.notice("ImportOSMPlaces: inserted \(inserted) places from \(document.source) (\(document.licence)).")
    }

    func revert(on database: Database) async throws {
        // Only removes what this migration added, leaving hand-authored or
        // partner-supplied content alone.
        try await Place.query(on: database)
            .filter(\.$tags, .custom("@>"), ["source:openstreetmap"])
            .delete()
    }

    /// Looks for the export next to the executable and in the source tree, so it
    /// works both in a container and when run from a checkout.
    static func loadDocument(logger: Logger) throws -> Document? {
        let candidates = [
            "Resources/osm-places.json",
            "Backend/Resources/osm-places.json",
            "./osm-places.json",
        ]
        for path in candidates {
            let url = URL(fileURLWithPath: path)
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            let data = try Data(contentsOf: url)
            logger.notice("ImportOSMPlaces: reading \(path)")
            return try JSONDecoder().decode(Document.self, from: data)
        }
        return nil
    }
}
