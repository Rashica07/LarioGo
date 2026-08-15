//
//  FavoritesViewModel.swift
//  LarioGo
//

import Foundation
import LarioCore
import SwiftUI

/// Favourites, stored on the device.
///
/// Offline-first: saving resolves against local state and persists immediately,
/// so the heart still works in a valley with no signal. Backend sync, when it
/// exists, reconciles afterwards rather than gating the tap.
@MainActor
final class FavoritesViewModel: ObservableObject {

    @Published private(set) var favorites: [Favorite] = []
    @Published private(set) var resolved: [Place] = []
    @Published private(set) var state: LoadState<[Place]> = .idle

    private var store: FavoritesStore?
    private let persistence: any FavoritesPersistence
    private let placeService: any PlaceServing

    init(persistence: any FavoritesPersistence, placeService: any PlaceServing) {
        self.persistence = persistence
        self.placeService = placeService
    }

    var count: Int { favorites.count }
    var isEmpty: Bool { favorites.isEmpty }

    func isFavorite(_ placeID: UUID) -> Bool {
        store?.isFavorite(placeID) ?? false
    }

    // MARK: - Loading

    func load() async {
        state = .loading
        do {
            let store = try FavoritesStore(persistence: persistence)
            self.store = store
            favorites = store.all

            guard !favorites.isEmpty else {
                resolved = []
                state = .loaded([])
                return
            }
            resolved = try await resolvePlaces(for: favorites)
            state = .loaded(resolved)
        } catch let error as ServiceError {
            // Saved IDs are already on disk; only the display data failed to
            // load, so keep whatever was resolved previously.
            state = .failed(error)
        } catch {
            state = .failed(.unknown(error.localizedDescription))
        }
    }

    /// Fetches each saved place.
    ///
    /// A place that no longer exists is dropped rather than failing the whole
    /// screen — content legitimately disappears, and one closed café must not
    /// blank the user's entire saved list.
    private func resolvePlaces(for favorites: [Favorite]) async throws -> [Place] {
        var places: [Place] = []
        var missing: [UUID] = []

        for favorite in favorites {
            do {
                places.append(try await placeService.place(id: favorite.placeID, from: nil))
            } catch ServiceError.notFound {
                missing.append(favorite.placeID)
            }
            // Any other error propagates: an offline failure is not the same as
            // "this place is gone", and must not silently delete saved items.
        }

        // Prune references to content that is genuinely gone, so the list does
        // not keep trying to load it on every launch.
        if !missing.isEmpty, var store {
            for id in missing { try? store.remove(id) }
            self.store = store
            self.favorites = store.all
        }
        return places
    }

    // MARK: - Mutating

    /// Flips saved state. Returns the state afterwards, for the button.
    @discardableResult
    func toggle(_ place: Place) async -> Bool {
        guard var store else { return false }
        let isNowFavorite: Bool
        do {
            isNowFavorite = try store.toggle(place.id)
        } catch {
            return store.isFavorite(place.id)
        }
        self.store = store
        favorites = store.all

        if isNowFavorite {
            if !resolved.contains(where: { $0.id == place.id }) {
                resolved.insert(place, at: 0)
            }
        } else {
            resolved.removeAll { $0.id == place.id }
        }
        state = .loaded(resolved)
        return isNowFavorite
    }

    func remove(_ place: Place) async {
        guard var store else { return }
        try? store.remove(place.id)
        self.store = store
        favorites = store.all
        resolved.removeAll { $0.id == place.id }
        state = .loaded(resolved)
    }
}

// MARK: - Persistence

/// Stores favourites in `UserDefaults`.
///
/// Appropriate here in a way it is not for the session token: a list of saved
/// place identifiers is not a credential, and it needs to be readable quickly
/// at launch without a Keychain round-trip.
struct UserDefaultsFavoritesPersistence: FavoritesPersistence {
    private let key = "LarioGo.favorites.v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() throws -> [Favorite] {
        guard let data = defaults.data(forKey: key) else { return [] }
        // Corrupt storage returns empty rather than throwing: losing the saved
        // list is bad, but a launch crash is worse.
        return (try? JSONDecoder().decode([Favorite].self, from: data)) ?? []
    }

    func save(_ favorites: [Favorite]) throws {
        defaults.set(try JSONEncoder().encode(favorites), forKey: key)
    }
}
