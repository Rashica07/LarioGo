//
//  ItineraryViewModel.swift
//  LarioGo
//

import Foundation
import LarioCore
import SwiftUI

/// Local storage for trips. Offline by design — a trip must open in a valley
/// with no signal, which is exactly when people look at them.
protocol ItineraryPersisting: Sendable {
    func load() -> [Itinerary]
    func save(_ itineraries: [Itinerary])
}

struct UserDefaultsItineraryPersistence: ItineraryPersisting {
    private let key = "LarioGo.itineraries.v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func load() -> [Itinerary] {
        guard let data = defaults.data(forKey: key) else { return [] }
        // Corrupt storage yields nothing rather than crashing at launch.
        return (try? JSONDecoder().decode([Itinerary].self, from: data)) ?? []
    }

    func save(_ itineraries: [Itinerary]) {
        guard let data = try? JSONEncoder().encode(itineraries) else { return }
        defaults.set(data, forKey: key)
    }
}

@MainActor
final class ItineraryViewModel: ObservableObject {

    @Published private(set) var trips: [Itinerary] = []
    /// Places referenced by any trip, cached so a saved trip renders offline.
    @Published private(set) var catalogue: [UUID: Place] = [:]
    @Published private(set) var isResolving = false

    private let persistence: any ItineraryPersisting
    private let placeService: any PlaceServing

    init(persistence: any ItineraryPersisting, placeService: any PlaceServing) {
        self.persistence = persistence
        self.placeService = placeService
        self.trips = persistence.load().sorted { $0.updatedAt > $1.updatedAt }
    }

    var isEmpty: Bool { trips.isEmpty }

    // MARK: - Trips

    @discardableResult
    func createTrip(named name: String) -> Itinerary {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trip = Itinerary(name: trimmed.isEmpty ? "My Trip" : trimmed)
        trips.insert(trip, at: 0)
        persist()
        return trip
    }

    func rename(_ trip: Itinerary, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let index = trips.firstIndex(where: { $0.id == trip.id }) else { return }
        trips[index].name = trimmed
        trips[index].updatedAt = Date()
        persist()
    }

    func delete(_ trip: Itinerary) {
        trips.removeAll { $0.id == trip.id }
        persist()
    }

    func trip(id: UUID) -> Itinerary? { trips.first { $0.id == id } }

    // MARK: - Stops

    /// Adds a place to a trip. Creates a trip first if none exists, so "Add to
    /// trip" never dead-ends on an empty state.
    @discardableResult
    func add(_ place: Place, to tripID: UUID?, on day: Date) -> Bool {
        let targetID: UUID
        if let tripID, trips.contains(where: { $0.id == tripID }) {
            targetID = tripID
        } else if let first = trips.first {
            targetID = first.id
        } else {
            targetID = createTrip(named: "My Trip").id
        }

        guard let index = trips.firstIndex(where: { $0.id == targetID }) else { return false }
        let added = trips[index].add(placeID: place.id, on: day)
        if added {
            catalogue[place.id] = place
            persist()
        }
        return added
    }

    func removeStop(_ stop: ItineraryStop, from tripID: UUID) {
        guard let index = trips.firstIndex(where: { $0.id == tripID }) else { return }
        trips[index].remove(stopID: stop.id)
        persist()
    }

    func move(in tripID: UUID, on day: Date, from source: IndexSet, to destination: Int) {
        guard let index = trips.firstIndex(where: { $0.id == tripID }),
              let first = source.first else { return }
        trips[index].move(on: day, from: first, to: destination)
        persist()
    }

    func contains(_ place: Place) -> Bool {
        trips.contains { $0.contains(placeID: place.id) }
    }

    // MARK: - Resolution

    /// Fetches any place a trip references but that is not cached yet.
    ///
    /// Cached entries are never refetched, so an offline launch still renders
    /// every trip that has been opened before.
    func resolveMissingPlaces() async {
        let referenced = Set(trips.flatMap { $0.stops.map(\.placeID) })
        let missing = referenced.subtracting(catalogue.keys)
        guard !missing.isEmpty else { return }

        isResolving = true
        defer { isResolving = false }

        for id in missing {
            // A failure here is not fatal: the stop simply stays unresolved and
            // is retried next time rather than being deleted.
            if let place = try? await placeService.place(id: id, from: nil) {
                catalogue[id] = place
            }
        }
    }

    func days(for trip: Itinerary) -> [Date] { trip.days }

    func resolved(_ trip: Itinerary) -> [Itinerary.ResolvedDay] {
        trip.resolve(using: catalogue)
    }

    func unresolvedCount(_ trip: Itinerary) -> Int {
        trip.unresolvedPlaceIDs(using: catalogue).count
    }

    private func persist() {
        trips.sort { $0.updatedAt > $1.updatedAt }
        persistence.save(trips)
    }
}
