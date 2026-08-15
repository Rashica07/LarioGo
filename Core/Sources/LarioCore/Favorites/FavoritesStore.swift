import Foundation

/// A saved place, with the moment it was saved.
public struct Favorite: Identifiable, Hashable, Sendable, Codable {
    public let placeID: UUID
    public let savedAt: Date

    public var id: UUID { placeID }

    public init(placeID: UUID, savedAt: Date) {
        self.placeID = placeID
        self.savedAt = savedAt
    }
}

/// Where favourites are kept between launches.
///
/// An abstraction rather than a direct `UserDefaults` call so the rules can be
/// tested without touching disk, and so a future backend sync is a new
/// conformance instead of a rewrite.
public protocol FavoritesPersistence: Sendable {
    func load() throws -> [Favorite]
    func save(_ favorites: [Favorite]) throws
}

/// In-memory persistence, for tests and previews.
public final class InMemoryFavoritesPersistence: FavoritesPersistence, @unchecked Sendable {
    private var storage: [Favorite]
    private let lock = NSLock()

    public init(initial: [Favorite] = []) {
        self.storage = initial
    }

    public func load() throws -> [Favorite] {
        lock.lock(); defer { lock.unlock() }
        return storage
    }

    public func save(_ favorites: [Favorite]) throws {
        lock.lock(); defer { lock.unlock() }
        storage = favorites
    }
}

/// Favourite bookkeeping.
///
/// Offline-first by design: every operation resolves against local state and
/// persists immediately, so saving a place works in a valley with no signal.
/// Backend sync, when it exists, reconciles afterwards rather than gating the tap.
public struct FavoritesStore: Sendable {
    private var favorites: [UUID: Favorite]
    private let persistence: FavoritesPersistence

    public init(persistence: FavoritesPersistence) throws {
        self.persistence = persistence
        let loaded = try persistence.load()
        // Later entries win if storage was ever corrupted with duplicates.
        self.favorites = Dictionary(
            loaded.map { ($0.placeID, $0) },
            uniquingKeysWith: { first, second in first.savedAt >= second.savedAt ? first : second }
        )
    }

    // MARK: - Queries

    public var count: Int { favorites.count }
    public var isEmpty: Bool { favorites.isEmpty }

    public func isFavorite(_ placeID: UUID) -> Bool {
        favorites[placeID] != nil
    }

    /// Most recently saved first — what a "Saved" list should show.
    public var all: [Favorite] {
        favorites.values.sorted { $0.savedAt > $1.savedAt }
    }

    public var placeIDs: Set<UUID> { Set(favorites.keys) }

    /// Favourites resolved against a catalogue, newest first.
    ///
    /// Places that no longer exist are skipped rather than rendered as blanks.
    public func resolved(using catalogue: [UUID: Place]) -> [Place] {
        all.compactMap { catalogue[$0.placeID] }
    }

    // MARK: - Mutations

    /// Adds a favourite. Returns false if it was already saved.
    @discardableResult
    public mutating func add(_ placeID: UUID, at date: Date = Date()) throws -> Bool {
        guard favorites[placeID] == nil else { return false }
        favorites[placeID] = Favorite(placeID: placeID, savedAt: date)
        try persist()
        return true
    }

    /// Removes a favourite. Returns false if it was not saved.
    @discardableResult
    public mutating func remove(_ placeID: UUID) throws -> Bool {
        guard favorites.removeValue(forKey: placeID) != nil else { return false }
        try persist()
        return true
    }

    /// Flips the saved state. Returns the state after the change.
    @discardableResult
    public mutating func toggle(_ placeID: UUID, at date: Date = Date()) throws -> Bool {
        if isFavorite(placeID) {
            try remove(placeID)
            return false
        }
        try add(placeID, at: date)
        return true
    }

    public mutating func removeAll() throws {
        favorites.removeAll()
        try persist()
    }

    private func persist() throws {
        try persistence.save(all)
    }
}
