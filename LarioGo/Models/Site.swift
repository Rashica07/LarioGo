//
//  Site.swift
//  LarioGo
//
//  Created by user on 29.6.26.
//


//
//  Site.swift
//  LarioGo
//

import Foundation
import CoreLocation

/// A point of interest around Lecco / Lake Como.
nonisolated struct Site: Identifiable, Hashable {
    let id: UUID
    let name: String
    let tagline: String
    let category: SiteCategory
    let summary: String
    let about: String
    let imageName: String
    let latitude: Double
    let longitude: Double
    let rating: Double
    /// Indicative visit duration, e.g. "1–2 h".
    let visitDuration: String
    let isFeatured: Bool

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    init(
        id: UUID = UUID(),
        name: String,
        tagline: String,
        category: SiteCategory,
        summary: String,
        about: String,
        imageName: String,
        latitude: Double,
        longitude: Double,
        rating: Double,
        visitDuration: String,
        isFeatured: Bool = false
    ) {
        self.id = id
        self.name = name
        self.tagline = tagline
        self.category = category
        self.summary = summary
        self.about = about
        self.imageName = imageName
        self.latitude = latitude
        self.longitude = longitude
        self.rating = rating
        self.visitDuration = visitDuration
        self.isFeatured = isFeatured
    }
}

nonisolated enum SiteCategory: String, CaseIterable, Identifiable, Hashable {
    case landmark = "Landmarks"
    case nature = "Nature"
    case culture = "Culture"
    case food = "Food & Wine"
    case viewpoint = "Viewpoints"

    var id: String { rawValue }

    /// SF Symbol representing the category.
    var symbol: String {
        switch self {
        case .landmark: return "building.columns.fill"
        case .nature: return "leaf.fill"
        case .culture: return "theatermasks.fill"
        case .food: return "fork.knife"
        case .viewpoint: return "mountain.2.fill"
        }
    }
}
