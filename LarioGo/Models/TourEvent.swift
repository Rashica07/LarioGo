//
//  TourEvent.swift
//  LarioGo
//
//  Created by user on 29.6.26.
//


//
//  Event.swift
//  LarioGo
//

import Foundation

/// A time-bound event or experience promoted in the Explore feed.
nonisolated struct TourEvent: Identifiable, Hashable {
    let id: UUID
    let title: String
    let location: String
    let date: Date
    let imageName: String
    let category: String

    init(
        id: UUID = UUID(),
        title: String,
        location: String,
        date: Date,
        imageName: String,
        category: String
    ) {
        self.id = id
        self.title = title
        self.location = location
        self.date = date
        self.imageName = imageName
        self.category = category
    }

    var dayString: String {
        let f = DateFormatter()
        f.dateFormat = "dd"
        return f.string(from: date)
    }

    var monthString: String {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f.string(from: date).uppercased()
    }
}
