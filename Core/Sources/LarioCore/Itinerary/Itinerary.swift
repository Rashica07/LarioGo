import Foundation

/// One stop on a trip.
public struct ItineraryStop: Identifiable, Hashable, Sendable, Codable {
    public let id: UUID
    /// The place this stop refers to. Stored by identifier, not by value, so a
    /// saved trip picks up corrected content the next time it is opened.
    public let placeID: UUID
    /// Day the stop belongs to, normalised to the start of that day.
    public var day: Date
    /// Position within the day. Contiguous from 0 after any mutation.
    public var order: Int
    public var note: String?

    public init(
        id: UUID = UUID(),
        placeID: UUID,
        day: Date,
        order: Int,
        note: String? = nil
    ) {
        self.id = id
        self.placeID = placeID
        self.day = day
        self.order = order
        self.note = note
    }
}

/// A saved trip.
///
/// A value type with pure mutations: no persistence, no notifications, no
/// singleton. Storage is the app's concern, which keeps the ordering rules —
/// the part that actually breaks — testable in isolation.
public struct Itinerary: Identifiable, Hashable, Sendable, Codable {
    public let id: UUID
    public var name: String
    public private(set) var stops: [ItineraryStop]
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        stops: [ItineraryStop] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.stops = stops
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // MARK: - Queries

    /// Distinct days in the trip, earliest first.
    public var days: [Date] {
        Array(Set(stops.map(\.day))).sorted()
    }

    /// Stops for a day, in order.
    public func stops(on day: Date, calendar: Calendar = .current) -> [ItineraryStop] {
        let target = calendar.startOfDay(for: day)
        return stops
            .filter { calendar.startOfDay(for: $0.day) == target }
            .sorted { $0.order < $1.order }
    }

    public var isEmpty: Bool { stops.isEmpty }

    public func contains(placeID: UUID) -> Bool {
        stops.contains { $0.placeID == placeID }
    }

    // MARK: - Mutations

    /// Appends a place to the end of a day.
    ///
    /// Adding the same place to the same day twice is a no-op — it is almost
    /// always a double tap, not an intent to visit twice. The same place on a
    /// *different* day is allowed.
    @discardableResult
    public mutating func add(
        placeID: UUID,
        on day: Date,
        note: String? = nil,
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> Bool {
        let normalizedDay = calendar.startOfDay(for: day)
        let existing = stops(on: normalizedDay, calendar: calendar)
        guard !existing.contains(where: { $0.placeID == placeID }) else { return false }

        stops.append(ItineraryStop(
            placeID: placeID,
            day: normalizedDay,
            order: existing.count,
            note: note
        ))
        updatedAt = now
        return true
    }

    /// Removes a stop and closes the gap it leaves in that day's ordering.
    @discardableResult
    public mutating func remove(
        stopID: UUID,
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> Bool {
        guard let index = stops.firstIndex(where: { $0.id == stopID }) else { return false }
        let day = stops[index].day
        stops.remove(at: index)
        reindex(day: day, calendar: calendar)
        updatedAt = now
        return true
    }

    /// Moves a stop within its day, from one visible position to another.
    ///
    /// Indices are positions in the day's ordered list, which is what a
    /// drag-to-reorder gesture produces.
    @discardableResult
    public mutating func move(
        on day: Date,
        from source: Int,
        to destination: Int,
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> Bool {
        var ordered = stops(on: day, calendar: calendar)
        guard ordered.indices.contains(source) else { return false }
        // `destination == count` is valid: it means "past the last item".
        guard destination >= 0, destination <= ordered.count else { return false }

        let moved = ordered.remove(at: source)
        let target = destination > source ? destination - 1 : destination
        ordered.insert(moved, at: min(target, ordered.count))

        apply(ordered: ordered, on: day, calendar: calendar)
        updatedAt = now
        return true
    }

    /// Moves a stop to a different day, appending it there.
    @discardableResult
    public mutating func reschedule(
        stopID: UUID,
        to day: Date,
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> Bool {
        guard let index = stops.firstIndex(where: { $0.id == stopID }) else { return false }
        let previousDay = stops[index].day
        let newDay = calendar.startOfDay(for: day)
        guard calendar.startOfDay(for: previousDay) != newDay else { return false }

        stops[index].day = newDay
        stops[index].order = stops(on: newDay, calendar: calendar).count
        reindex(day: previousDay, calendar: calendar)
        reindex(day: newDay, calendar: calendar)
        updatedAt = now
        return true
    }

    // MARK: - Ordering maintenance

    /// Rewrites a day's `order` values to be contiguous from zero.
    private mutating func reindex(day: Date, calendar: Calendar) {
        let ordered = stops(on: day, calendar: calendar)
        apply(ordered: ordered, on: day, calendar: calendar)
    }

    private mutating func apply(ordered: [ItineraryStop], on day: Date, calendar: Calendar) {
        let target = calendar.startOfDay(for: day)
        for (position, stop) in ordered.enumerated() {
            guard let index = stops.firstIndex(where: { $0.id == stop.id }) else { continue }
            stops[index].order = position
            stops[index].day = target
        }
    }
}

// MARK: - Resolution

extension Itinerary {
    /// A day's stops paired with their places, ready to render.
    public struct ResolvedDay: Identifiable, Hashable, Sendable {
        public let day: Date
        public let entries: [(stop: ItineraryStop, place: Place)]

        public var id: Date { day }

        public static func == (lhs: ResolvedDay, rhs: ResolvedDay) -> Bool {
            lhs.day == rhs.day && lhs.entries.map(\.stop) == rhs.entries.map(\.stop)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(day)
            hasher.combine(entries.map(\.stop))
        }
    }

    /// Pairs stops with places from `catalogue`, grouped by day.
    ///
    /// Stops whose place is missing are dropped rather than faulted: content can
    /// legitimately disappear, and a trip that fails to load entirely because one
    /// café closed would be far worse than one that shows the rest.
    public func resolve(
        using catalogue: [UUID: Place],
        calendar: Calendar = .current
    ) -> [ResolvedDay] {
        days.map { day in
            let entries = stops(on: day, calendar: calendar).compactMap { stop in
                catalogue[stop.placeID].map { (stop: stop, place: $0) }
            }
            return ResolvedDay(day: day, entries: entries)
        }
    }

    /// Identifiers referenced by the trip that are absent from `catalogue`.
    public func unresolvedPlaceIDs(using catalogue: [UUID: Place]) -> [UUID] {
        stops.map(\.placeID).filter { catalogue[$0] == nil }
    }
}
