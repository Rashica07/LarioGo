import Fluent
import Foundation

/// Development/demo content for the Lecco-first MVP.
///
/// **Attractions and landmarks are real, publicly documented places** — names,
/// locations and descriptions reflect genuine sites around Lecco and Lake Como.
///
/// **Dining and event entries are invented sample data.** They are plausible but
/// not real businesses, and must never be presented to users as verified
/// listings. Opening hours, contact details and reservation availability are
/// deliberately absent rather than fabricated. Replace this with licensed or
/// partner-supplied data before any public launch.
///
/// Guarded so it cannot double-insert if run twice.
struct SeedPlaces: AsyncMigration {
    func prepare(on database: Database) async throws {
        let existing = try await Place.query(on: database).count()
        guard existing == 0 else {
            database.logger.info("SeedPlaces skipped: places table already has \(existing) rows.")
            return
        }
        for place in Self.places {
            try await place.save(on: database)
        }
        database.logger.info("SeedPlaces inserted \(Self.places.count) rows.")
    }

    func revert(on database: Database) async throws {
        try await Place.query(on: database).delete()
    }

    /// Dates are relative to migration time so events are never all in the past.
    private static func daysFromNow(_ days: Int) -> Date {
        Date().addingTimeInterval(TimeInterval(days) * 86_400)
    }

    static var places: [Place] {
        [
            // MARK: - Lecco (MVP focus)
            Place(
                kind: .attraction,
                name: "Basilica di San Nicolò",
                tagline: "Lecco's soaring bell tower",
                summary: "The symbol of Lecco, with one of Italy's tallest bell towers.",
                about: "Rising 96 metres over the lakefront, the neogothic campanile of San Nicolò — locally called il matitone, the big pencil — is the unmistakable silhouette of Lecco. Inside, frescoes and side chapels trace centuries of local devotion.",
                category: .landmark,
                latitude: 45.8566, longitude: 9.3931,
                address: "Piazza San Nicolò, Lecco",
                region: "Lecco",
                imageNames: ["basilica_san_nicolo_lecco"],
                rating: 4.7, reviewCount: 1240,
                visitDuration: "30–45 min",
                tags: ["church", "architecture", "free", "city-centre"],
                isFeatured: true
            ),
            Place(
                kind: .attraction,
                name: "Piani d'Erna",
                tagline: "Alpine balcony over the lake",
                summary: "A cable-car ride to panoramic trails above Lecco.",
                about: "A short cable-car climb lifts you to roughly 1300 m, where meadows, family trails and mountain refuges open onto sweeping views of the Grigne massif and the Lecco branch of the lake.",
                category: .viewpoint,
                latitude: 45.8717, longitude: 9.4256,
                region: "Lecco",
                imageNames: ["alpine_meadow_lake_como"],
                rating: 4.8, reviewCount: 870,
                visitDuration: "Half day",
                tags: ["hiking", "cable-car", "family", "panorama"],
                isFeatured: true
            ),
            Place(
                kind: .attraction,
                name: "Lungolago di Lecco",
                tagline: "The promenade of Manzoni",
                summary: "Lakeside walk lined with cafés and Manzoni landmarks.",
                about: "The waterfront promenade stretches beneath the mountains, dotted with monuments to the author Alessandro Manzoni and views toward the Resegone. The heart of Lecco's evening passeggiata.",
                category: .culture,
                latitude: 45.8530, longitude: 9.3960,
                region: "Lecco",
                imageNames: ["lecco_lakefront_sunset"],
                rating: 4.6, reviewCount: 2100,
                visitDuration: "1 h",
                tags: ["walk", "free", "sunset", "family"],
                isFeatured: true
            ),
            Place(
                kind: .attraction,
                name: "Villa Manzoni",
                tagline: "The novelist's childhood home",
                summary: "Museum in the house where Alessandro Manzoni grew up.",
                about: "The neoclassical family residence of Alessandro Manzoni now holds a museum devoted to the writer and to Lecco's history, including manuscripts and period rooms.",
                category: .culture,
                latitude: 45.8489, longitude: 9.3897,
                address: "Via Guanella 1, Lecco",
                region: "Lecco",
                imageNames: [],
                rating: 4.4, reviewCount: 520,
                priceLevel: 1,
                visitDuration: "1–2 h",
                tags: ["museum", "literature", "indoor", "rainy-day"]
            ),
            Place(
                kind: .attraction,
                name: "Resegone Ridge",
                tagline: "The jagged crown of Lecco",
                summary: "Iconic toothed ridge with refuge hikes.",
                about: "Immortalised by Manzoni, the Resegone's saw-tooth profile dominates the skyline. Trails from the foothills lead to Rifugio Azzoni near the summit.",
                category: .trail,
                latitude: 45.8833, longitude: 9.4500,
                region: "Lecco",
                imageNames: ["resegone_mountain_ridge"],
                rating: 4.9, reviewCount: 640,
                visitDuration: "Full day",
                tags: ["hiking", "advanced", "panorama"]
            ),
            Place(
                kind: .attraction,
                name: "Ponte Azzone Visconti",
                tagline: "Fourteenth-century river crossing",
                summary: "Medieval bridge over the Adda at Lecco.",
                about: "Commissioned in the 1330s by Azzone Visconti, this fortified stone bridge still carries traffic over the Adda and frames one of the best views back toward the old town.",
                category: .landmark,
                latitude: 45.8556, longitude: 9.3861,
                region: "Lecco",
                imageNames: [],
                rating: 4.5, reviewCount: 410,
                visitDuration: "20 min",
                tags: ["bridge", "medieval", "free", "photo-spot"]
            ),

            // MARK: - Wider Lake Como (expansion proof)
            Place(
                kind: .attraction,
                name: "Villa Monastero",
                tagline: "Lakeside botanical gardens",
                summary: "Terraced gardens and a house museum on the water at Varenna.",
                about: "A former Cistercian monastery turned residence, with roughly two kilometres of lakeside garden paths weaving past citrus, cypress and statuary, and richly decorated period interiors.",
                category: .nature,
                latitude: 46.0103, longitude: 9.2847,
                address: "Viale Giovanni Polvani 4, Varenna",
                region: "Varenna",
                imageNames: ["varenna_lake_como_village"],
                rating: 4.8, reviewCount: 3400,
                priceLevel: 1,
                visitDuration: "2–3 h",
                tags: ["gardens", "museum", "ferry", "romantic"],
                isFeatured: true
            ),
            Place(
                kind: .attraction,
                name: "Abbazia di Piona",
                tagline: "Romanesque cloister on the shore",
                summary: "A serene 12th-century priory on a quiet peninsula.",
                about: "Set on the Olgiasca peninsula, this Cluniac priory is known for its Romanesque cloister, the herbal liqueurs distilled by the monks, and a contemplative stillness beside the water.",
                category: .culture,
                latitude: 46.1132, longitude: 9.3206,
                region: "Colico",
                imageNames: ["romanesque_abbey_cloister"],
                rating: 4.7, reviewCount: 980,
                visitDuration: "1 h",
                tags: ["abbey", "quiet", "architecture"]
            ),
            Place(
                kind: .attraction,
                name: "Villa del Balbianello",
                tagline: "Terraced villa on a wooded promontory",
                summary: "Loggia and gardens jutting into the lake at Lenno.",
                about: "An eighteenth-century villa on the tip of the Lavedo peninsula, famous for its arched loggia and sculpted terraces reaching down to the water. Reachable on foot or by boat.",
                category: .landmark,
                latitude: 45.9679, longitude: 9.2087,
                region: "Lenno",
                imageNames: [],
                rating: 4.8, reviewCount: 5200,
                priceLevel: 2,
                visitDuration: "2 h",
                tags: ["villa", "gardens", "boat", "romantic"]
            ),
            Place(
                kind: .attraction,
                name: "Bellagio Old Town",
                tagline: "Stepped lanes above the ferry pier",
                summary: "The much-photographed village at the fork of the lake.",
                about: "Bellagio's cobbled stairways climb between shuttered houses, silk shops and terraces, with ferry links across to Varenna and Menaggio.",
                category: .culture,
                latitude: 45.9862, longitude: 9.2610,
                region: "Bellagio",
                imageNames: [],
                rating: 4.7, reviewCount: 6100,
                visitDuration: "2–3 h",
                tags: ["village", "shopping", "ferry", "photo-spot"]
            ),
            Place(
                kind: .attraction,
                name: "Villa Carlotta",
                tagline: "Botanical garden and sculpture collection",
                summary: "Baroque villa with azaleas and Canova sculpture at Tremezzo.",
                about: "A seventeenth-century villa surrounded by botanical gardens famous for spring azaleas and rhododendrons, with a collection that includes work by Antonio Canova.",
                category: .nature,
                latitude: 45.9906, longitude: 9.2258,
                region: "Tremezzo",
                imageNames: [],
                rating: 4.7, reviewCount: 4300,
                priceLevel: 2,
                visitDuration: "2 h",
                tags: ["gardens", "art", "spring", "family"]
            ),
            Place(
                kind: .attraction,
                name: "Funicolare Como–Brunate",
                tagline: "Seven minutes to the balcony of the Alps",
                summary: "Historic funicular from Como up to the village of Brunate.",
                about: "Running since 1894, the funicular climbs some 500 metres to Brunate, where footpaths and terraces look back over Como and the southern basin of the lake.",
                category: .viewpoint,
                latitude: 45.8148, longitude: 9.0868,
                region: "Como",
                imageNames: [],
                rating: 4.5, reviewCount: 2800,
                priceLevel: 1,
                visitDuration: "Half day",
                tags: ["funicular", "panorama", "family"]
            ),
            Place(
                kind: .attraction,
                name: "Lido di Bellagio Beach",
                tagline: "Swimming and sun on the eastern shore",
                summary: "A lakeside beach club with loungers and shallow water.",
                category: .beach,
                latitude: 45.9812, longitude: 9.2566,
                region: "Bellagio",
                imageNames: [],
                rating: 4.2, reviewCount: 760,
                priceLevel: 2,
                visitDuration: "Half day",
                tags: ["swimming", "family", "summer"]
            ),

            // MARK: - Dining (SAMPLE DATA — not real businesses)
            Place(
                kind: .restaurant,
                name: "Trattoria del Lario",
                tagline: "Missoltini and perch risotto",
                summary: "Sample listing: traditional lake cuisine with a terrace view.",
                about: "Sample seed data, not a verified business. Illustrates a traditional Lariano menu — missoltini, risotto with perch, and Lombard whites — on a terrace above the water.",
                category: .food,
                latitude: 45.8512, longitude: 9.3905,
                region: "Lecco",
                imageNames: [],
                rating: 4.5, reviewCount: 320,
                priceLevel: 2,
                tags: ["sample-data", "local-cuisine", "terrace"],
                cuisines: ["Lombard", "Italian", "Seafood"],
                acceptsReservations: true
            ),
            Place(
                kind: .restaurant,
                name: "Osteria della Rocca",
                tagline: "Slow-cooked mountain plates",
                summary: "Sample listing: alpine cooking in the old town.",
                about: "Sample seed data, not a verified business. Represents a hearty mountain menu — polenta taragna, braised meats and local cheeses.",
                category: .food,
                latitude: 45.8571, longitude: 9.3902,
                region: "Lecco",
                imageNames: [],
                rating: 4.6, reviewCount: 210,
                priceLevel: 3,
                tags: ["sample-data", "mountain-cuisine", "dinner"],
                cuisines: ["Lombard", "Alpine"],
                acceptsReservations: true
            ),
            Place(
                kind: .restaurant,
                name: "Caffè del Molo",
                tagline: "Espresso by the ferry pier",
                summary: "Sample listing: café and pastries beside the water.",
                about: "Sample seed data, not a verified business. A budget café stop for breakfast or an aperitivo near the landing stage.",
                category: .food,
                latitude: 46.0095, longitude: 9.2841,
                region: "Varenna",
                imageNames: [],
                rating: 4.3, reviewCount: 540,
                priceLevel: 1,
                tags: ["sample-data", "coffee", "breakfast", "quick"],
                cuisines: ["Café", "Bakery"],
                acceptsReservations: false
            ),
            Place(
                kind: .restaurant,
                name: "Pizzeria Grigna",
                tagline: "Wood-fired, family-friendly",
                summary: "Sample listing: pizza a short walk from the promenade.",
                about: "Sample seed data, not a verified business. A casual, family-oriented pizzeria used to exercise cuisine and price filtering.",
                category: .food,
                latitude: 45.8548, longitude: 9.3944,
                region: "Lecco",
                imageNames: [],
                rating: 4.4, reviewCount: 890,
                priceLevel: 1,
                tags: ["sample-data", "pizza", "family", "casual"],
                cuisines: ["Pizza", "Italian"],
                acceptsReservations: false
            ),

            // MARK: - Events (SAMPLE DATA)
            Place(
                kind: .event,
                name: "Lake Como Sailing Cup",
                tagline: "Regatta on the Lecco branch",
                summary: "Sample event: two days of racing off the Lecco marina.",
                about: "Sample seed data, not a scheduled event. Used to exercise date filtering and the events feed.",
                category: .familyFriendly,
                latitude: 45.8497, longitude: 9.3972,
                region: "Lecco",
                imageNames: [],
                rating: 4.5, reviewCount: 120,
                tags: ["sample-data", "sport", "outdoor", "free"],
                isFeatured: true,
                startDate: daysFromNow(5), endDate: daysFromNow(6),
                organizer: "Sample Organizer"
            ),
            Place(
                kind: .event,
                name: "Manzoni Literary Nights",
                tagline: "Readings in the villa courtyard",
                summary: "Sample event: evening readings and talks.",
                about: "Sample seed data, not a scheduled event.",
                category: .culture,
                latitude: 45.8489, longitude: 9.3897,
                region: "Lecco",
                imageNames: [],
                rating: 4.6, reviewCount: 85,
                priceLevel: 1,
                tags: ["sample-data", "literature", "evening"],
                startDate: daysFromNow(12),
                organizer: "Sample Organizer"
            ),
            Place(
                kind: .event,
                name: "Alpine Cheese Fair",
                tagline: "Producers from the Valsassina",
                summary: "Sample event: tastings and stalls above Lecco.",
                about: "Sample seed data, not a scheduled event.",
                category: .food,
                latitude: 45.8717, longitude: 9.4256,
                region: "Lecco",
                imageNames: [],
                rating: 4.7, reviewCount: 140,
                tags: ["sample-data", "food", "family", "market"],
                startDate: daysFromNow(21), endDate: daysFromNow(22),
                organizer: "Sample Organizer"
            ),
            Place(
                kind: .experience,
                name: "Sunset Boat Tour",
                tagline: "Ninety minutes on the water",
                summary: "Sample experience: guided evening cruise from Lecco.",
                about: "Sample seed data, not a bookable product. Exercises the experience kind and the booking-capable path.",
                category: .nature,
                latitude: 45.8524, longitude: 9.3958,
                region: "Lecco",
                imageNames: [],
                rating: 4.8, reviewCount: 260,
                priceLevel: 3,
                visitDuration: "1.5 h",
                tags: ["sample-data", "boat", "sunset", "romantic"],
                isFeatured: true,
                startDate: daysFromNow(2),
                organizer: "Sample Operator"
            ),
        ]
    }
}
