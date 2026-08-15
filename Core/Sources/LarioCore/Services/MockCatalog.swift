import Foundation

/// The bundled content set used whenever ``DataSourceMode/mock`` is active.
///
/// Deliberately large. Every screen, filter, sort and empty state needs enough
/// variety to be exercised honestly: multiple regions, all four kinds, every
/// category, the full price range, rated and unrated entries, events spread
/// across past/soon/far-future, and places with and without images.
///
/// ## Truthfulness
/// Attractions and landmarks are **real, publicly documented places** — names,
/// coordinates and descriptions reflect genuine sites around Lecco and Lake Como.
/// Everything with a `sample-data` tag — all dining, events, experiences and
/// operators — is **invented**. It is plausible but not real, and the UI must
/// label it as sample content while ``AppConfiguration/mustLabelContentAsSample``
/// is true. Hours, phone numbers and booking availability are left absent rather
/// than fabricated.
public enum MockCatalog {

    /// Deterministic identifier for mock content.
    ///
    /// Mock IDs must be stable across launches: favourites and itineraries are
    /// persisted by identifier, so `UUID()` here would silently orphan
    /// everything the user saved the moment the app restarted.
    public static func stableID(_ index: Int) -> UUID {
        let hex = String(format: "%012X", index)
        return UUID(uuidString: "5EED0000-0000-4000-8000-\(hex)")!
    }

    // MARK: - Places

    public static let places: [Place] = {
        var index = 0
        func next() -> UUID { index += 1; return stableID(index) }

        func place(
            _ name: String,
            _ kind: PlaceKind,
            _ category: PlaceCategory,
            lat: Double, lon: Double,
            region: String,
            tagline: String = "",
            summary: String = "",
            about: String = "",
            rating: Double? = nil,
            reviews: Int = 0,
            price: PriceLevel? = nil,
            duration: String? = nil,
            images: [String] = [],
            tags: [String] = [],
            featured: Bool = false,
            cuisines: [String] = [],
            reservations: Bool = false,
            startsInDays: Int? = nil,
            endsInDays: Int? = nil,
            organizer: String? = nil,
            address: String? = nil
        ) -> Place {
            Place(
                id: next(), kind: kind, name: name,
                tagline: tagline, summary: summary, about: about,
                category: category,
                coordinate: Coordinate(latitude: lat, longitude: lon),
                address: address, region: region,
                imageNames: images, rating: rating, reviewCount: reviews,
                priceLevel: price, visitDuration: duration,
                tags: tags, isFeatured: featured,
                dining: cuisines.isEmpty && !reservations
                    ? nil
                    : DiningDetails(cuisines: cuisines, acceptsReservations: reservations),
                schedule: startsInDays.map {
                    EventSchedule(
                        startDate: referenceDate.addingTimeInterval(TimeInterval($0) * 86_400),
                        endDate: endsInDays.map { referenceDate.addingTimeInterval(TimeInterval($0) * 86_400) },
                        organizer: organizer
                    )
                }
            )
        }

        return [
            // ===== LECCO — attractions (real places) =====
            place("Basilica di San Nicolò", .attraction, .landmark, lat: 45.8566, lon: 9.3931,
                  region: "Lecco", tagline: "Lecco's soaring bell tower",
                  summary: "The symbol of Lecco, with one of Italy's tallest bell towers.",
                  about: "Rising 96 metres over the lakefront, the neogothic campanile of San Nicolò — locally called il matitone, the big pencil — is the unmistakable silhouette of Lecco.",
                  rating: 4.7, reviews: 1240, duration: "30–45 min",
                  images: ["basilica_san_nicolo_lecco"],
                  tags: ["church", "architecture", "free", "city-centre", "rainy-day"],
                  featured: true, address: "Piazza San Nicolò, Lecco"),
            place("Piani d'Erna", .attraction, .viewpoint, lat: 45.8717, lon: 9.4256,
                  region: "Lecco", tagline: "Alpine balcony over the lake",
                  summary: "A cable-car ride to panoramic trails above Lecco.",
                  about: "A short cable-car climb lifts you to roughly 1300 m, where meadows, family trails and mountain refuges open onto sweeping views of the Grigne massif.",
                  rating: 4.8, reviews: 870, duration: "Half day",
                  images: ["alpine_meadow_lake_como"],
                  tags: ["hiking", "cable-car", "family", "panorama"], featured: true),
            place("Lungolago di Lecco", .attraction, .culture, lat: 45.8530, lon: 9.3960,
                  region: "Lecco", tagline: "The promenade of Manzoni",
                  summary: "Lakeside walk lined with cafés and Manzoni landmarks.",
                  about: "The waterfront promenade stretches beneath the mountains, dotted with monuments to Alessandro Manzoni and views toward the Resegone.",
                  rating: 4.6, reviews: 2100, duration: "1 h",
                  images: ["lecco_lakefront_sunset"],
                  tags: ["walk", "free", "sunset", "family", "accessible"], featured: true),
            place("Villa Manzoni", .attraction, .culture, lat: 45.8489, lon: 9.3897,
                  region: "Lecco", tagline: "The novelist's childhood home",
                  summary: "Museum in the house where Alessandro Manzoni grew up.",
                  about: "The neoclassical family residence now holds a museum devoted to the writer and to Lecco's history.",
                  rating: 4.4, reviews: 520, price: .budget, duration: "1–2 h",
                  tags: ["museum", "literature", "indoor", "rainy-day"],
                  address: "Via Guanella 1, Lecco"),
            place("Resegone Ridge", .attraction, .trail, lat: 45.8833, lon: 9.4500,
                  region: "Lecco", tagline: "The jagged crown of Lecco",
                  summary: "Iconic toothed ridge with refuge hikes.",
                  about: "Immortalised by Manzoni, the Resegone's saw-tooth profile dominates the skyline. Trails lead to Rifugio Azzoni near the summit.",
                  rating: 4.9, reviews: 640, duration: "Full day",
                  images: ["resegone_mountain_ridge"],
                  tags: ["hiking", "advanced", "panorama"]),
            place("Ponte Azzone Visconti", .attraction, .landmark, lat: 45.8556, lon: 9.3861,
                  region: "Lecco", tagline: "Fourteenth-century river crossing",
                  summary: "Medieval bridge over the Adda at Lecco.",
                  about: "Commissioned in the 1330s by Azzone Visconti, this fortified stone bridge still carries traffic over the Adda.",
                  rating: 4.5, reviews: 410, duration: "20 min",
                  tags: ["bridge", "medieval", "free", "photo-spot"]),
            place("Torre Viscontea", .attraction, .landmark, lat: 45.8560, lon: 9.3918,
                  region: "Lecco", tagline: "What remains of the old castle",
                  summary: "Medieval tower in the centre of Lecco.",
                  rating: 4.2, reviews: 300, price: .budget, duration: "45 min",
                  tags: ["tower", "history", "indoor", "rainy-day"]),
            place("Monte Barro Park", .attraction, .nature, lat: 45.8339, lon: 9.3711,
                  region: "Lecco", tagline: "Regional park above the lake",
                  summary: "Botanical trails and archaeology on a low summit.",
                  rating: 4.5, reviews: 380, duration: "Half day",
                  tags: ["hiking", "nature", "family", "free"]),
            place("Lecco Rock Climbing Crags", .attraction, .trail, lat: 45.8760, lon: 9.4030,
                  region: "Lecco", tagline: "Birthplace of the Ragni di Lecco",
                  summary: "Historic limestone climbing above the town.",
                  rating: 4.7, reviews: 190, duration: "Half day",
                  tags: ["climbing", "advanced", "outdoor"]),
            place("Spiaggia di Rivabella", .attraction, .beach, lat: 45.8698, lon: 9.3872,
                  region: "Lecco", tagline: "Town beach on the Lecco branch",
                  summary: "Grassy lakeside beach a short ride from the centre.",
                  rating: 4.1, reviews: 460, duration: "Half day",
                  tags: ["swimming", "family", "summer", "free"]),

            // ===== VARENNA / BELLAGIO / CENTRAL LAKE (real places) =====
            place("Villa Monastero", .attraction, .nature, lat: 46.0103, lon: 9.2847,
                  region: "Varenna", tagline: "Lakeside botanical gardens",
                  summary: "Terraced gardens and a house museum on the water.",
                  about: "A former Cistercian monastery turned residence, with two kilometres of lakeside garden paths and richly decorated period interiors.",
                  rating: 4.8, reviews: 3400, price: .budget, duration: "2–3 h",
                  images: ["varenna_lake_como_village"],
                  tags: ["gardens", "museum", "ferry", "romantic"], featured: true),
            place("Castello di Vezio", .attraction, .viewpoint, lat: 46.0164, lon: 9.2941,
                  region: "Varenna", tagline: "Ruined castle above Varenna",
                  summary: "Hilltop ruin with falconry and lake panoramas.",
                  rating: 4.6, reviews: 1500, price: .budget, duration: "1–2 h",
                  tags: ["castle", "panorama", "family", "hiking"]),
            place("Passerella Ponte del Diavolo", .attraction, .culture, lat: 46.0096, lon: 9.2860,
                  region: "Varenna", tagline: "The lovers' walk",
                  summary: "Waterside walkway linking the ferry pier to the village.",
                  rating: 4.5, reviews: 2200, duration: "20 min",
                  tags: ["walk", "free", "romantic", "accessible"]),
            place("Bellagio Old Town", .attraction, .culture, lat: 45.9862, lon: 9.2610,
                  region: "Bellagio", tagline: "Stepped lanes above the ferry pier",
                  summary: "The much-photographed village at the fork of the lake.",
                  rating: 4.7, reviews: 6100, duration: "2–3 h",
                  tags: ["village", "shopping", "ferry", "photo-spot"], featured: true),
            place("Villa Melzi Gardens", .attraction, .nature, lat: 45.9799, lon: 9.2549,
                  region: "Bellagio", tagline: "Neoclassical gardens on the shore",
                  summary: "Waterfront gardens with camellias and a Japanese garden.",
                  rating: 4.6, reviews: 2900, price: .budget, duration: "1–2 h",
                  tags: ["gardens", "spring", "romantic"]),
            place("Punta Spartivento", .attraction, .viewpoint, lat: 45.9906, lon: 9.2588,
                  region: "Bellagio", tagline: "Where the lake splits in two",
                  summary: "The northern tip of the Bellagio promontory.",
                  rating: 4.7, reviews: 1800, duration: "30 min",
                  tags: ["panorama", "free", "photo-spot", "accessible"]),
            place("Villa del Balbianello", .attraction, .landmark, lat: 45.9679, lon: 9.2087,
                  region: "Lenno", tagline: "Terraced villa on a wooded promontory",
                  summary: "Loggia and gardens jutting into the lake.",
                  rating: 4.8, reviews: 5200, price: .moderate, duration: "2 h",
                  tags: ["villa", "gardens", "boat", "romantic"], featured: true),
            place("Villa Carlotta", .attraction, .nature, lat: 45.9906, lon: 9.2258,
                  region: "Tremezzo", tagline: "Botanical garden and sculpture",
                  summary: "Baroque villa famous for spring azaleas.",
                  rating: 4.7, reviews: 4300, price: .moderate, duration: "2 h",
                  tags: ["gardens", "art", "spring", "family"]),
            place("Abbazia di Piona", .attraction, .culture, lat: 46.1132, lon: 9.3206,
                  region: "Colico", tagline: "Romanesque cloister on the shore",
                  summary: "A serene 12th-century priory on a quiet peninsula.",
                  rating: 4.7, reviews: 980, duration: "1 h",
                  images: ["romanesque_abbey_cloister"],
                  tags: ["abbey", "quiet", "architecture"]),
            place("Greenway del Lago di Como", .attraction, .trail, lat: 45.9781, lon: 9.1897,
                  region: "Colonno", tagline: "Ten kilometres of shoreline path",
                  summary: "Waymarked walking route through lakeside villages.",
                  rating: 4.6, reviews: 720, duration: "Half day",
                  tags: ["walking", "free", "family", "villages"]),

            // ===== COMO (real places) =====
            place("Funicolare Como–Brunate", .attraction, .viewpoint, lat: 45.8148, lon: 9.0868,
                  region: "Como", tagline: "Seven minutes to the balcony of the Alps",
                  summary: "Historic funicular from Como up to Brunate.",
                  rating: 4.5, reviews: 2800, price: .budget, duration: "Half day",
                  tags: ["funicular", "panorama", "family"]),
            place("Duomo di Como", .attraction, .landmark, lat: 45.8110, lon: 9.0838,
                  region: "Como", tagline: "Gothic and Renaissance cathedral",
                  summary: "Como's cathedral, built across four centuries.",
                  rating: 4.7, reviews: 4100, duration: "45 min",
                  tags: ["church", "architecture", "free", "rainy-day"]),
            place("Tempio Voltiano", .attraction, .culture, lat: 45.8123, lon: 9.0745,
                  region: "Como", tagline: "Museum to the inventor of the battery",
                  summary: "Neoclassical rotunda devoted to Alessandro Volta.",
                  rating: 4.3, reviews: 900, price: .budget, duration: "45 min",
                  tags: ["museum", "science", "indoor", "rainy-day"]),
            place("Villa Olmo", .attraction, .landmark, lat: 45.8206, lon: 9.0670,
                  region: "Como", tagline: "Neoclassical villa and public park",
                  summary: "Exhibition venue with lakeside gardens open to all.",
                  rating: 4.5, reviews: 1600, duration: "1–2 h",
                  tags: ["villa", "gardens", "free", "family"]),
            place("Faro Voltiano di Brunate", .attraction, .viewpoint, lat: 45.8256, lon: 9.1006,
                  region: "Brunate", tagline: "Lighthouse above the lake",
                  summary: "Climbable tower with views to the Alps on clear days.",
                  rating: 4.4, reviews: 640, price: .budget, duration: "1 h",
                  tags: ["panorama", "hiking", "photo-spot"]),
            place("Menaggio Lakefront", .attraction, .culture, lat: 46.0206, lon: 9.2394,
                  region: "Menaggio", tagline: "Promenade and piazza on the west shore",
                  summary: "Ferry hub with a wide waterfront and mountain backdrop.",
                  rating: 4.5, reviews: 1300, duration: "1 h",
                  tags: ["walk", "ferry", "free", "family"]),
            place("Cernobbio Waterfront", .attraction, .culture, lat: 45.8419, lon: 9.0765,
                  region: "Cernobbio", tagline: "Elegant village near Villa d'Este",
                  summary: "Lakeside square and promenade north of Como.",
                  rating: 4.4, reviews: 980, duration: "1 h",
                  tags: ["walk", "free", "elegant"]),
            place("Orrido di Bellano", .attraction, .nature, lat: 46.0430, lon: 9.3025,
                  region: "Bellano", tagline: "Gorge walkway over a torrent",
                  summary: "Suspended walkways through a narrow river gorge.",
                  rating: 4.5, reviews: 1700, price: .budget, duration: "45 min",
                  tags: ["gorge", "family", "unusual", "rainy-day"]),

            // Unrated and image-less entries, so those UI paths get exercised.
            place("Sentiero del Viandante", .attraction, .trail, lat: 45.9500, lon: 9.3800,
                  region: "Lecco", tagline: "Ancient trail along the eastern shore",
                  summary: "Historic long-distance path linking lakeside villages.",
                  duration: "Full day", tags: ["hiking", "free", "long-distance"]),
            place("Chiesa di Santa Marta", .attraction, .culture, lat: 45.8551, lon: 9.3906,
                  region: "Lecco", tagline: "Small baroque church",
                  summary: "A quiet stop in the old centre.",
                  duration: "15 min", tags: ["church", "quiet", "free"]),

            // ===== DINING — SAMPLE DATA (invented) =====
            place("Trattoria del Lario", .restaurant, .food, lat: 45.8512, lon: 9.3905,
                  region: "Lecco", tagline: "Missoltini and perch risotto",
                  summary: "Sample listing: traditional lake cuisine with a terrace view.",
                  about: "Sample seed data, not a verified business.",
                  rating: 4.5, reviews: 320, price: .moderate,
                  tags: ["sample-data", "local-cuisine", "terrace"],
                  cuisines: ["Lombard", "Italian", "Seafood"], reservations: true),
            place("Osteria della Rocca", .restaurant, .food, lat: 45.8571, lon: 9.3902,
                  region: "Lecco", tagline: "Slow-cooked mountain plates",
                  summary: "Sample listing: alpine cooking in the old town.",
                  about: "Sample seed data, not a verified business.",
                  rating: 4.6, reviews: 210, price: .upscale,
                  tags: ["sample-data", "mountain-cuisine", "dinner"],
                  cuisines: ["Lombard", "Alpine"], reservations: true),
            place("Pizzeria Grigna", .restaurant, .food, lat: 45.8548, lon: 9.3944,
                  region: "Lecco", tagline: "Wood-fired, family-friendly",
                  summary: "Sample listing: pizza near the promenade.",
                  about: "Sample seed data, not a verified business.",
                  rating: 4.4, reviews: 890, price: .budget,
                  tags: ["sample-data", "pizza", "family", "casual"],
                  cuisines: ["Pizza", "Italian"]),
            place("Caffè del Molo", .restaurant, .food, lat: 46.0095, lon: 9.2841,
                  region: "Varenna", tagline: "Espresso by the ferry pier",
                  summary: "Sample listing: café and pastries beside the water.",
                  about: "Sample seed data, not a verified business.",
                  rating: 4.3, reviews: 540, price: .budget,
                  tags: ["sample-data", "coffee", "breakfast", "quick"],
                  cuisines: ["Café", "Bakery"]),
            place("Ristorante Punta Blu", .restaurant, .food, lat: 45.9871, lon: 9.2601,
                  region: "Bellagio", tagline: "Tasting menus over the water",
                  summary: "Sample listing: fine dining on the promontory.",
                  about: "Sample seed data, not a verified business.",
                  rating: 4.9, reviews: 150, price: .luxury,
                  tags: ["sample-data", "fine-dining", "romantic", "view"],
                  cuisines: ["Italian", "Contemporary"], reservations: true),
            place("Gelateria Lariana", .restaurant, .food, lat: 45.8535, lon: 9.3952,
                  region: "Lecco", tagline: "Artisan gelato on the promenade",
                  summary: "Sample listing: gelato and granita.",
                  about: "Sample seed data, not a verified business.",
                  rating: 4.7, reviews: 1450, price: .budget,
                  tags: ["sample-data", "gelato", "family", "quick"],
                  cuisines: ["Gelato", "Dessert"]),
            place("Enoteca Cinque Terre di Lario", .restaurant, .nightlife, lat: 45.8558, lon: 9.3929,
                  region: "Lecco", tagline: "Regional wines by the glass",
                  summary: "Sample listing: wine bar with small plates.",
                  about: "Sample seed data, not a verified business.",
                  rating: 4.5, reviews: 380, price: .moderate,
                  tags: ["sample-data", "wine", "aperitivo", "evening"],
                  cuisines: ["Wine Bar", "Italian"], reservations: true),
            place("Bar Centrale Menaggio", .restaurant, .food, lat: 46.0201, lon: 9.2390,
                  region: "Menaggio", tagline: "All-day café on the square",
                  summary: "Sample listing: coffee, sandwiches and aperitivo.",
                  about: "Sample seed data, not a verified business.",
                  rating: 4.2, reviews: 610, price: .budget,
                  tags: ["sample-data", "coffee", "casual", "quick"],
                  cuisines: ["Café", "Italian"]),
            place("Agriturismo Valsassina", .restaurant, .food, lat: 45.9120, lon: 9.4420,
                  region: "Valsassina", tagline: "Farm table above the valley",
                  summary: "Sample listing: cheese, salumi and polenta.",
                  about: "Sample seed data, not a verified business.",
                  rating: 4.8, reviews: 260, price: .moderate,
                  tags: ["sample-data", "farm", "family", "view"],
                  cuisines: ["Lombard", "Farm-to-table"], reservations: true),
            place("Sushi Lario", .restaurant, .food, lat: 45.8544, lon: 9.3897,
                  region: "Lecco", tagline: "Something other than risotto",
                  summary: "Sample listing: Japanese in the centre.",
                  about: "Sample seed data, not a verified business.",
                  rating: 4.0, reviews: 190, price: .moderate,
                  tags: ["sample-data", "japanese", "dinner"],
                  cuisines: ["Japanese", "Sushi"], reservations: true),

            // ===== EVENTS & EXPERIENCES — SAMPLE DATA (invented) =====
            place("Sunset Boat Tour", .experience, .nature, lat: 45.8524, lon: 9.3958,
                  region: "Lecco", tagline: "Ninety minutes on the water",
                  summary: "Sample experience: guided evening cruise from Lecco.",
                  about: "Sample seed data, not a bookable product.",
                  rating: 4.8, reviews: 260, price: .upscale, duration: "1.5 h",
                  tags: ["sample-data", "boat", "sunset", "romantic"],
                  featured: true, startsInDays: 1, organizer: "Sample Operator"),
            place("Lake Como Sailing Cup", .event, .familyFriendly, lat: 45.8497, lon: 9.3972,
                  region: "Lecco", tagline: "Regatta on the Lecco branch",
                  summary: "Sample event: two days of racing off the marina.",
                  about: "Sample seed data, not a scheduled event.",
                  rating: 4.5, reviews: 120,
                  tags: ["sample-data", "sport", "outdoor", "free"],
                  featured: true, startsInDays: 5, endsInDays: 6, organizer: "Sample Organizer"),
            place("Manzoni Literary Nights", .event, .culture, lat: 45.8489, lon: 9.3897,
                  region: "Lecco", tagline: "Readings in the villa courtyard",
                  summary: "Sample event: evening readings and talks.",
                  about: "Sample seed data, not a scheduled event.",
                  rating: 4.6, reviews: 85, price: .budget,
                  tags: ["sample-data", "literature", "evening"],
                  startsInDays: 12, organizer: "Sample Organizer"),
            place("Alpine Cheese Fair", .event, .food, lat: 45.8717, lon: 9.4256,
                  region: "Lecco", tagline: "Producers from the Valsassina",
                  summary: "Sample event: tastings and stalls above Lecco.",
                  about: "Sample seed data, not a scheduled event.",
                  rating: 4.7, reviews: 140,
                  tags: ["sample-data", "food", "family", "market"],
                  startsInDays: 21, endsInDays: 22, organizer: "Sample Organizer"),
            place("Varenna Music Evenings", .event, .culture, lat: 46.0103, lon: 9.2847,
                  region: "Varenna", tagline: "Chamber music in the gardens",
                  summary: "Sample event: open-air concert series.",
                  about: "Sample seed data, not a scheduled event.",
                  rating: 4.8, reviews: 200, price: .moderate,
                  tags: ["sample-data", "music", "evening", "romantic"],
                  startsInDays: 9, endsInDays: 11, organizer: "Sample Organizer"),
            place("Guided Via Ferrata", .experience, .trail, lat: 45.8790, lon: 9.4100,
                  region: "Lecco", tagline: "Cabled route with a mountain guide",
                  summary: "Sample experience: half-day guided climb.",
                  about: "Sample seed data, not a bookable product.",
                  rating: 4.9, reviews: 95, price: .upscale, duration: "Half day",
                  tags: ["sample-data", "climbing", "advanced", "guide"],
                  startsInDays: 3, organizer: "Sample Operator"),
            place("Silk Workshop Tour", .experience, .culture, lat: 45.8100, lon: 9.0820,
                  region: "Como", tagline: "How Como silk is made",
                  summary: "Sample experience: guided workshop visit.",
                  about: "Sample seed data, not a bookable product.",
                  rating: 4.4, reviews: 130, price: .moderate, duration: "2 h",
                  tags: ["sample-data", "craft", "indoor", "rainy-day"],
                  startsInDays: 4, organizer: "Sample Operator"),
            place("Winter Christmas Market", .event, .shopping, lat: 45.8540, lon: 9.3950,
                  region: "Lecco", tagline: "Stalls along the lakefront",
                  summary: "Sample event: seasonal market.",
                  about: "Sample seed data, not a scheduled event.",
                  rating: 4.1, reviews: 60,
                  tags: ["sample-data", "market", "family", "winter"],
                  startsInDays: 120, endsInDays: 140, organizer: "Sample Organizer"),
            // A finished event, so "past" filtering has something to exclude.
            place("Spring Regatta (past)", .event, .familyFriendly, lat: 45.8500, lon: 9.3960,
                  region: "Lecco", tagline: "Already finished",
                  summary: "Sample event in the past, for testing date filters.",
                  about: "Sample seed data, not a scheduled event.",
                  rating: 4.3, reviews: 70,
                  tags: ["sample-data", "sport", "past"],
                  startsInDays: -30, endsInDays: -29, organizer: "Sample Organizer"),
        ]
    }()

    /// Fixed reference point so mock event dates are deterministic within a run.
    public static let referenceDate = Date()

    /// Lookup keyed by identifier, for resolving favourites and itineraries.
    public static let catalogue: [UUID: Place] = Dictionary(
        places.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }
    )

    // MARK: - Profiles

    /// Test personas covering the audiences in the product brief: independent
    /// travellers, couples, families and groups, plus a signed-out state.
    ///
    /// All invented. No real person's data appears here.
    public static let profiles: [UserProfile] = [
        UserProfile(
            id: stableID(9001), email: "sample.traveller@example.com",
            displayName: "Alpine Traveller",
            joinedAt: referenceDate.addingTimeInterval(-180 * 86_400),
            homeRegion: "Milan, Italy"
        ),
        UserProfile(
            id: stableID(9002), email: "sample.family@example.com",
            displayName: "Ferrante Family",
            joinedAt: referenceDate.addingTimeInterval(-45 * 86_400),
            homeRegion: "Munich, Germany"
        ),
        UserProfile(
            id: stableID(9003), email: "sample.couple@example.com",
            displayName: "Jo & Sam",
            joinedAt: referenceDate.addingTimeInterval(-12 * 86_400),
            homeRegion: "Manchester, UK"
        ),
        UserProfile(
            id: stableID(9004), email: "sample.hiker@example.com",
            displayName: "Solo Hiker",
            joinedAt: referenceDate.addingTimeInterval(-400 * 86_400),
            homeRegion: "Lyon, France"
        ),
        UserProfile(
            id: stableID(9005), email: "sample.foodie@example.com",
            displayName: "Foodie On Tour",
            joinedAt: referenceDate.addingTimeInterval(-3 * 86_400),
            homeRegion: "Barcelona, Spain"
        ),
        // Single-word name and a brand-new account, to exercise initials and
        // "joined today" formatting.
        UserProfile(
            id: stableID(9006), email: "sample.newcomer@example.com",
            displayName: "Newcomer",
            joinedAt: referenceDate,
            homeRegion: nil
        ),
    ]

    public static var defaultProfile: UserProfile { profiles[0] }

    // MARK: - Saved content

    /// A pre-populated trip, so itinerary screens have something to show without
    /// the tester having to build one first.
    public static func sampleItinerary(calendar: Calendar = .current) -> Itinerary {
        var trip = Itinerary(
            id: stableID(9101),
            name: "Three Days Around Lecco",
            createdAt: referenceDate.addingTimeInterval(-7 * 86_400),
            updatedAt: referenceDate
        )
        let day1 = referenceDate.addingTimeInterval(86_400)
        let day2 = referenceDate.addingTimeInterval(2 * 86_400)
        let day3 = referenceDate.addingTimeInterval(3 * 86_400)

        func add(_ name: String, on day: Date, note: String? = nil) {
            guard let place = places.first(where: { $0.name == name }) else { return }
            trip.add(placeID: place.id, on: day, note: note, calendar: calendar, now: referenceDate)
        }

        add("Basilica di San Nicolò", on: day1, note: "Start early, before the crowds")
        add("Lungolago di Lecco", on: day1)
        add("Trattoria del Lario", on: day1, note: "Booked for 20:00")
        add("Piani d'Erna", on: day2, note: "Cable car — check the weather")
        add("Agriturismo Valsassina", on: day2)
        add("Villa Monastero", on: day3, note: "Ferry from Lecco")
        add("Caffè del Molo", on: day3)
        return trip
    }

    /// A handful of pre-saved favourites across different kinds.
    public static var sampleFavorites: [Favorite] {
        let names = ["Piani d'Erna", "Villa Monastero", "Trattoria del Lario", "Sunset Boat Tour"]
        return names.enumerated().compactMap { offset, name in
            guard let place = places.first(where: { $0.name == name }) else { return nil }
            return Favorite(
                placeID: place.id,
                savedAt: referenceDate.addingTimeInterval(TimeInterval(-offset) * 3_600)
            )
        }
    }
}
