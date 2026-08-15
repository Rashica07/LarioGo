//
//  LarioGoTests.swift
//  LarioGoTests
//

import Foundation
import Testing
@testable import LarioGo

// MARK: - Seed content integrity

/// Lake Como sits roughly between 45.6–46.3 N and 9.0–9.6 E. Anything outside
/// that box is a typo'd coordinate that would drop a pin in the wrong country.
private let lakeComoLatitudes = 45.6...46.3
private let lakeComoLongitudes = 9.0...9.6

@Test("Seed sites have stable, unique identifiers")
func seedSiteIdentifiersAreStableAndUnique() {
    let first = TourismData.sites.map(\.id)
    let second = TourismData.sites.map(\.id)

    #expect(first == second, "Site IDs changed between reads — persisted itineraries and favourites will not resolve")
    #expect(Set(first).count == first.count, "Duplicate Site IDs in seed data")
    #expect(!first.isEmpty, "Seed data is empty")
}

@Test("Seed site identifiers are pinned, not freshly generated")
func seedSiteIdentifiersArePinned() {
    // Regression guard: `Site.id` defaults to `UUID()`. If a seed entry ever
    // omits an explicit id again, it mints a new identifier on every launch and
    // silently breaks anything persisted against it.
    let basilica = TourismData.sites.first { $0.name == "Basilica di San Nicolò" }
    #expect(basilica?.id == UUID(uuidString: "A1000000-0000-4000-8000-000000000001"))
}

@Test("Every seed site sits inside the Lake Como region")
func seedSiteCoordinatesAreInRegion() {
    for site in TourismData.sites {
        #expect(lakeComoLatitudes.contains(site.latitude), "\(site.name) latitude \(site.latitude) is outside the region")
        #expect(lakeComoLongitudes.contains(site.longitude), "\(site.name) longitude \(site.longitude) is outside the region")
    }
}

@Test("Every seed site has a usable rating")
func seedSiteRatingsAreValid() {
    for site in TourismData.sites {
        #expect((0.0...5.0).contains(site.rating), "\(site.name) has an out-of-range rating: \(site.rating)")
    }
}

@Test("Seed sites carry non-empty display copy")
func seedSitesHaveDisplayCopy() {
    for site in TourismData.sites {
        #expect(!site.name.isEmpty)
        #expect(!site.tagline.isEmpty, "\(site.name) has no tagline")
        #expect(!site.summary.isEmpty, "\(site.name) has no summary")
        #expect(!site.about.isEmpty, "\(site.name) has no about text")
        #expect(!site.visitDuration.isEmpty, "\(site.name) has no visit duration")
    }
}

@Test("Featured sites are a non-empty subset of all sites")
func featuredSitesAreConsistent() {
    let featured = TourismData.featuredSites
    #expect(!featured.isEmpty, "Explore's featured carousel would render empty")
    #expect(featured.allSatisfy(\.isFeatured))

    let allIDs = Set(TourismData.sites.map(\.id))
    #expect(featured.allSatisfy { allIDs.contains($0.id) })
}

@Test("Every site category is represented in seed content")
func everyCategoryHasContent() {
    // Explore renders a chip per category; a chip that filters to nothing is a
    // dead end for the user.
    let populated = Set(TourismData.sites.map(\.category))
    for category in SiteCategory.allCases {
        #expect(populated.contains(category), "No seed site for category \(category.rawValue)")
    }
}

// MARK: - Events

@Test("Seed events are uniquely identified and titled")
func seedEventsAreValid() {
    let events = TourismData.events
    #expect(!events.isEmpty)
    #expect(Set(events.map(\.id)).count == events.count, "Duplicate event IDs")
    for event in events {
        #expect(!event.title.isEmpty)
        #expect(!event.location.isEmpty)
        #expect(!event.category.isEmpty)
    }
}

@Test("Event day and month strings are formatted for the calendar card")
func eventDateStringsAreFormatted() {
    var components = DateComponents()
    components.year = 2026
    components.month = 7
    components.day = 4
    let date = Calendar.current.date(from: components)!

    let event = TourEvent(
        title: "Test", location: "Lecco", date: date,
        imageName: "none", category: "Culture"
    )

    #expect(event.dayString == "04", "EventCard expects a zero-padded day")
    #expect(event.monthString == event.monthString.uppercased(), "EventCard expects an uppercased month")
    // Not asserting an exact length: `TourEvent` uses an unpinned `DateFormatter`,
    // so the abbreviation follows the device locale. The fixed-width EventCard
    // assumes a short month — tracked as a known issue in LARIO_PROGRESS.md.
    #expect(!event.monthString.isEmpty)
    #expect(event.monthString.count <= 5, "EventCard's 76pt column cannot fit \(event.monthString)")
}

// MARK: - Tickets

@Test("Seed ticket passes are uniquely identified and priced")
func seedTicketsAreValid() {
    let tickets = TourismData.tickets
    #expect(!tickets.isEmpty)
    #expect(Set(tickets.map(\.id)).count == tickets.count, "Duplicate ticket IDs")
    for ticket in tickets {
        #expect(ticket.price > 0, "\(ticket.title) is free — likely a data error")
        #expect(!ticket.highlights.isEmpty, "\(ticket.title) has no highlights to display")
        #expect(!ticket.priceString.isEmpty)
    }
}

@Test("Ticket price strings render as euro currency")
func ticketPriceStringUsesEuro() {
    let ticket = TicketPass(
        title: "Test", subtitle: "Test", kind: .boat,
        price: 23.0, validity: "1 day", highlights: ["a"]
    )
    #expect(ticket.priceString.contains("23"), "Price string lost the amount: \(ticket.priceString)")
    #expect(ticket.priceString.contains("€"), "Price string is not euro-denominated: \(ticket.priceString)")
}
