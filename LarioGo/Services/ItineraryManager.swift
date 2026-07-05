//
//  ItineraryManager.swift
//  LarioGo
//
//  Created by Antigravity on 5.7.26.
//

import Foundation
import Combine

public struct ItineraryItem: Codable, Identifiable, Hashable {
    public var id = UUID()
    public let siteID: UUID
    public var date: Date

    public init(siteID: UUID, date: Date) {
        self.siteID = siteID
        self.date = date
    }
}

@MainActor
public final class ItineraryManager: ObservableObject {
    public static let shared = ItineraryManager()
    
    @Published public private(set) var items: [ItineraryItem] = []
    
    private let saveKey = "LarioGo_Itinerary_Persisted"
    
    private init() {
        load()
    }
    
    public func add(siteID: UUID, date: Date) {
        // Remove existing entry for the same site to avoid duplicates, updating date instead
        items.removeAll { $0.siteID == siteID }
        items.append(ItineraryItem(siteID: siteID, date: date))
        // Sort itinerary items chronologically
        items.sort { $0.date < $1.date }
        save()
    }
    
    public func remove(itemID: UUID) {
        items.removeAll { $0.id == itemID }
        save()
    }
    
    public func clear() {
        items.removeAll()
        save()
    }
    
    private func save() {
        if let encoded = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(encoded, forKey: saveKey)
        }
    }
    
    private func load() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([ItineraryItem].self, from: data) {
            self.items = decoded.sorted { $0.date < $1.date }
        }
    }
}
