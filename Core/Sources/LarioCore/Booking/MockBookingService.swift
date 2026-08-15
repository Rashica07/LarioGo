import Foundation

/// In-memory bookings for mock mode.
///
/// Mirrors the real server's behaviour rather than always succeeding: it
/// validates, it can decline, and it refuses to cancel something already
/// finished. A mock that always says yes hides exactly the paths that break.
public actor MockBookingService: BookingServing {
    private let gate: MockGate
    private var stored: [UUID: Booking] = [:]
    private let now: @Sendable () -> Date
    private let placeName: @Sendable (UUID) -> String

    /// Party sizes above this are declined, so the decline path is reachable
    /// in mock mode without needing a backend.
    private let capacityLimit: Int

    public init(
        behaviour: MockBehaviour = .realistic,
        seeded: [Booking]? = nil,
        capacityLimit: Int = 12,
        now: @escaping @Sendable () -> Date = { Date() },
        placeName: @escaping @Sendable (UUID) -> String = { id in
            MockCatalog.catalogue[id]?.name ?? "Reserved place"
        }
    ) {
        self.gate = MockGate(behaviour: behaviour)
        self.capacityLimit = capacityLimit
        self.now = now
        self.placeName = placeName

        let initial = seeded ?? Self.sampleBookings(now: now())
        self.stored = Dictionary(initial.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    public func create(_ request: BookingRequest) async throws -> Booking {
        try await gate.pass()

        if let error = request.validate(now: now()) {
            throw ServiceError.server(status: 400, message: error.message)
        }

        // The venue can say no. Confirmations are not automatic.
        let status: BookingStatus = request.partySize > capacityLimit ? .declined : .confirmed
        guard status != .declined else {
            throw ServiceError.server(
                status: 409,
                message: "That party size isn't available at this time. Try a smaller group or another slot."
            )
        }

        let booking = Booking(
            id: UUID(),
            placeID: request.placeID,
            placeName: placeName(request.placeID),
            startDate: request.startDate,
            partySize: request.partySize,
            status: .confirmed,
            // No money moves through the app. Restaurants are pay-at-venue.
            paymentStatus: .notRequired,
            paymentMethod: .venue,
            note: request.note,
            reference: Self.makeReference(),
            createdAt: now()
        )
        stored[booking.id] = booking
        return booking
    }

    public func bookings() async throws -> [Booking] {
        try await gate.pass()
        return stored.values.sorted { $0.startDate < $1.startDate }
    }

    public func booking(id: UUID) async throws -> Booking {
        try await gate.pass()
        guard let booking = stored[id] else { throw ServiceError.notFound }
        return booking
    }

    public func cancel(id: UUID) async throws -> Booking {
        try await gate.pass()
        guard let existing = stored[id] else { throw ServiceError.notFound }
        guard existing.isCancellable(at: now()) else {
            throw ServiceError.server(status: 409, message: "This booking can no longer be cancelled.")
        }

        let cancelled = Booking(
            id: existing.id,
            placeID: existing.placeID,
            placeName: existing.placeName,
            startDate: existing.startDate,
            partySize: existing.partySize,
            status: .cancelled,
            paymentStatus: existing.paymentStatus == .paid ? .refunded : existing.paymentStatus,
            paymentMethod: existing.paymentMethod,
            note: existing.note,
            reference: existing.reference,
            createdAt: existing.createdAt
        )
        stored[id] = cancelled
        return cancelled
    }

    /// Human-quotable reference, in the shape a venue would read back.
    private static func makeReference() -> String {
        let alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"   // no O/0, I/1
        return "LG-" + String((0..<6).compactMap { _ in alphabet.randomElement() })
    }

    /// One upcoming and one past booking, so both list sections have content.
    private static func sampleBookings(now: Date) -> [Booking] {
        guard let restaurant = MockCatalog.places.first(where: { $0.kind == .restaurant }) else {
            return []
        }
        return [
            Booking(
                id: MockCatalog.stableID(9201),
                placeID: restaurant.id,
                placeName: restaurant.name,
                startDate: now.addingTimeInterval(2 * 86_400),
                partySize: 2,
                status: .confirmed,
                paymentStatus: .notRequired,
                paymentMethod: .venue,
                note: "Window table if possible",
                reference: "LG-SAMPLE",
                createdAt: now.addingTimeInterval(-86_400)
            ),
            Booking(
                id: MockCatalog.stableID(9202),
                placeID: restaurant.id,
                placeName: restaurant.name,
                startDate: now.addingTimeInterval(-10 * 86_400),
                partySize: 4,
                status: .completed,
                paymentStatus: .notRequired,
                paymentMethod: .venue,
                note: nil,
                reference: "LG-PASTXX",
                createdAt: now.addingTimeInterval(-12 * 86_400)
            ),
        ]
    }
}
