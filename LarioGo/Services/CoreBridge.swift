//
//  CoreBridge.swift
//  LarioGo
//
//  Adapters between LarioCore (Foundation-only, testable off Apple platforms)
//  and the Apple frameworks the UI needs. Keeping the conversions here is what
//  lets LarioCore stay compilable on Windows and Linux.
//

import CoreLocation
import Foundation
import LarioCore
import MapKit
import SwiftUI

// MARK: - Coordinates

extension Coordinate {
    var clCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    init(_ coordinate: CLLocationCoordinate2D) {
        self.init(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    init?(_ location: CLLocation?) {
        guard let location else { return nil }
        self.init(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
    }
}

extension CLLocationCoordinate2D {
    var coordinate: Coordinate { Coordinate(self) }
}

// MARK: - Map regions

extension BoundingBox {
    /// The visible map rectangle, for "search this area".
    init(_ region: MKCoordinateRegion) {
        let halfLatitude = region.span.latitudeDelta / 2
        let halfLongitude = region.span.longitudeDelta / 2
        self.init(
            minLatitude: region.center.latitude - halfLatitude,
            maxLatitude: region.center.latitude + halfLatitude,
            minLongitude: region.center.longitude - halfLongitude,
            maxLongitude: region.center.longitude + halfLongitude
        )
    }

    var region: MKCoordinateRegion {
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: (minLatitude + maxLatitude) / 2,
                longitude: (minLongitude + maxLongitude) / 2
            ),
            span: MKCoordinateSpan(
                latitudeDelta: max(0.001, maxLatitude - minLatitude),
                longitudeDelta: max(0.001, maxLongitude - minLongitude)
            )
        )
    }
}

extension MKCoordinateRegion {
    /// Default framing for the MVP: the Lecco branch, with the wider lake in view.
    static let lakeComo = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 45.92, longitude: 9.36),
        span: MKCoordinateSpan(latitudeDelta: 0.55, longitudeDelta: 0.55)
    )
}

// MARK: - Presentation

extension PlaceCategory {
    /// SF Symbol for the category. Every case is spelled out rather than
    /// defaulted, so adding a category is a compile error here instead of a
    /// silently generic pin on the map.
    var symbol: String {
        switch self {
        case .landmark: return "building.columns.fill"
        case .nature: return "leaf.fill"
        case .culture: return "theatermasks.fill"
        case .food: return "fork.knife"
        case .viewpoint: return "mountain.2.fill"
        case .nightlife: return "wineglass.fill"
        case .familyFriendly: return "figure.2.and.child.holdinghands"
        case .beach: return "beach.umbrella.fill"
        case .trail: return "figure.hiking"
        case .shopping: return "bag.fill"
        }
    }

    var displayName: String {
        switch self {
        case .landmark: return "Landmarks"
        case .nature: return "Nature"
        case .culture: return "Culture"
        case .food: return "Food & Wine"
        case .viewpoint: return "Viewpoints"
        case .nightlife: return "Nightlife"
        case .familyFriendly: return "Family"
        case .beach: return "Beaches"
        case .trail: return "Trails"
        case .shopping: return "Shopping"
        }
    }
}

extension PlaceKind {
    var symbol: String {
        switch self {
        case .attraction: return "star.fill"
        case .restaurant: return "fork.knife"
        case .event: return "calendar"
        case .experience: return "ticket.fill"
        }
    }

    var displayName: String {
        switch self {
        case .attraction: return "Attractions"
        case .restaurant: return "Dining"
        case .event: return "Events"
        case .experience: return "Experiences"
        }
    }
}

extension Place {
    /// Localised price string, e.g. "€€".
    var priceDisplay: String? { priceLevel?.symbol }

    /// Rating formatted for display, or nil when unrated.
    ///
    /// Unrated must render as "New", never as 0.0 — a zero reads as terrible
    /// rather than absent.
    var ratingDisplay: String? {
        rating.map { String(format: "%.1f", $0) }
    }

    /// Whether the UI should mark this as sample content.
    var isSampleContent: Bool { tags.contains("sample-data") }
}

extension PlaceResult {
    var mapAnnotationCoordinate: CLLocationCoordinate2D { place.coordinate.clCoordinate }
}

// MARK: - Dates

enum EventDateFormatter {
    /// Cached and locale-pinned to the user's locale once, rather than built per
    /// call. `TourEvent` allocated a fresh DateFormatter on every access, which
    /// is expensive inside a scrolling list (see Bug #8).
    private static let day: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("d")
        return formatter
    }()

    private static let month: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMM")
        return formatter
    }()

    private static let full: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    static func dayNumber(_ date: Date) -> String { day.string(from: date) }
    static func monthAbbreviation(_ date: Date) -> String { month.string(from: date).uppercased() }
    static func full(_ date: Date) -> String { full.string(from: date) }

    /// Relative phrasing for the events feed: "Today", "Tomorrow", "In 3 days".
    static func relative(_ date: Date, from now: Date = Date(), calendar: Calendar = .current) -> String {
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInTomorrow(date) { return "Tomorrow" }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now),
                                           to: calendar.startOfDay(for: date)).day ?? 0
        if days < 0 { return "Ended" }
        if days < 7 { return "In \(days) days" }
        return full.string(from: date)
    }
}
