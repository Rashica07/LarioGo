//
//  TourismData.swift
//  LarioGo
//
//  Created by user on 29.6.26.
//


//
//  TourismData.swift
//  LarioGo
//
//  Mock, Supabase-ready data layer. Replace `load*` bodies with network
//  calls when the backend tables are populated; the view models stay intact.
//

import Foundation

/// Static seed content for the Lecco / Lake Como MVP.
nonisolated enum TourismData {
    static let sites: [Site] = [
        Site(
            name: "Basilica di San Nicolò",
            tagline: "Lecco's soaring bell tower",
            category: .landmark,
            summary: "The symbol of Lecco, with one of Italy's tallest bell towers.",
            about: "Rising 96 metres over the lakefront, the neogothic campanile of San Nicolò — affectionately called \"il matitone\" (the big pencil) — is the unmistakable silhouette of Lecco. Inside, frescoes and side chapels trace centuries of local devotion.",
            imageName: "basilica_san_nicolo_lecco",
            latitude: 45.8566, longitude: 9.3931,
            rating: 4.7, visitDuration: "30–45 min", isFeatured: true
        ),
        Site(
            name: "Piani d'Erna",
            tagline: "Alpine balcony over the lake",
            category: .viewpoint,
            summary: "A cable-car ride to panoramic trails above Lecco.",
            about: "A short funicular climb lifts you to 1300 m where meadows, family trails and mountain refuges open onto sweeping views of the Grigne massif and the branch of Lake Como. A favourite escape for hikers and families alike.",
            imageName: "alpine_meadow_lake_como",
            latitude: 45.8717, longitude: 9.4256,
            rating: 4.8, visitDuration: "Half day", isFeatured: true
        ),
        Site(
            name: "Lungolago di Lecco",
            tagline: "The promenade of Manzoni",
            category: .culture,
            summary: "Lakeside walk lined with cafés and Manzoni landmarks.",
            about: "The elegant waterfront promenade stretches beneath the mountains, dotted with monuments to author Alessandro Manzoni, gelaterie and views toward the Resegone. The beating heart of Lecco's evening passeggiata.",
            imageName: "lecco_lakefront_sunset",
            latitude: 45.8530, longitude: 9.3960,
            rating: 4.6, visitDuration: "1 h", isFeatured: true
        ),
        Site(
            name: "Abbazia di Piona",
            tagline: "Romanesque cloister on the shore",
            category: .culture,
            summary: "A serene 12th-century abbey on a quiet peninsula.",
            about: "Set on the Olgiasca peninsula, this Cluniac priory enchants with its Romanesque cloister, herbal liqueurs distilled by the monks, and a contemplative stillness beside the water.",
            imageName: "romanesque_abbey_cloister",
            latitude: 46.1132, longitude: 9.3206,
            rating: 4.7, visitDuration: "1 h"
        ),
        Site(
            name: "Resegone Ridge",
            tagline: "The jagged crown of Lecco",
            category: .nature,
            summary: "Iconic toothed ridge with refuge hikes.",
            about: "Immortalised by Manzoni, the Resegone's saw-tooth profile dominates the skyline. Trails from the foothills lead to Rifugio Azzoni at the summit for unforgettable sunrise panoramas.",
            imageName: "resegone_mountain_ridge",
            latitude: 45.8833, longitude: 9.4500,
            rating: 4.9, visitDuration: "Full day"
        ),
        Site(
            name: "Varenna & Villa Monastero",
            tagline: "Lakeside botanical gardens",
            category: .nature,
            summary: "Romantic village with terraced gardens on the water.",
            about: "A short ferry away, Varenna charms with pastel houses and the botanical gardens of Villa Monastero, where two kilometres of lakeside paths weave past citrus, cypress and statuary.",
            imageName: "varenna_lake_como_village",
            latitude: 46.0103, longitude: 9.2847,
            rating: 4.8, visitDuration: "2–3 h"
        ),
        Site(
            name: "Trattoria del Lago",
            tagline: "Missoltini & local risotto",
            category: .food,
            summary: "Traditional lake cuisine with a terrace view.",
            about: "Sample missoltini (sun-dried lake shad), risotto with perch and crisp Lombard whites on a terrace overlooking the water — a taste of authentic Lariano hospitality.",
            imageName: "photorealistic_rustic_italian",
            latitude: 45.8512, longitude: 9.3905,
            rating: 4.5, visitDuration: "1–2 h"
        ),
    ]

    static let events: [TourEvent] = [
        TourEvent(title: "Lake Como Sailing Cup", location: "Lecco Marina", date: date(7, 12), imageName: "site_lungolago", category: "Sport"),
        TourEvent(title: "Manzoni Literary Nights", location: "Villa Manzoni", date: date(7, 18), imageName: "site_lungolago", category: "Culture"),
        TourEvent(title: "Sunset Ferry Concert", location: "Varenna Pier", date: date(7, 24), imageName: "site_varenna", category: "Music"),
        TourEvent(title: "Alpine Cheese Fair", location: "Piani d'Erna", date: date(8, 2), imageName: "site_erna", category: "Food"),
    ]

    static let tickets: [TicketPass] = [
        TicketPass(title: "Lake Como Ferry Day Pass", subtitle: "Hop-on hop-off across the lake", kind: .boat, price: 23.0, validity: "Valid 1 day", highlights: ["All central-lake routes", "Varenna · Bellagio · Menaggio", "Unlimited rides"]),
        TicketPass(title: "Lecco City Bus 24h", subtitle: "Unlimited urban transit", kind: .bus, price: 4.5, validity: "Valid 24 h", highlights: ["All city lines", "Airport shuttle add-on", "Contactless boarding"]),
        TicketPass(title: "Piani d'Erna Funicular", subtitle: "Return cable-car ticket", kind: .cable, price: 12.0, validity: "Round trip", highlights: ["Scenic ascent to 1300 m", "Skip-the-line entry", "Family bundle available"]),
        TicketPass(title: "LarioGo City Pass", subtitle: "Transit + museums + ferry", kind: .combo, price: 39.0, validity: "Valid 3 days", highlights: ["All transport included", "6 partner museums", "10% dining discounts"]),
    ]

    static var featuredSites: [Site] { sites.filter(\.isFeatured) }

    private static func date(_ month: Int, _ day: Int) -> Date {
        var c = DateComponents()
        c.year = 2026; c.month = month; c.day = day
        return Calendar.current.date(from: c) ?? Date()
    }
}
