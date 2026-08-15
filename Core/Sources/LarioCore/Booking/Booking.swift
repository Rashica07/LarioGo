import Foundation

/// Payment state, deliberately provider-independent.
///
/// No payment SDK is referenced anywhere in this project, and none should be.
/// This models the *state* a booking is in so the UI and the backend can agree
/// without either knowing who eventually processes money. Apple Pay / PassKit
/// is the intended route if online payment is ever added.
public enum PaymentStatus: String, CaseIterable, Hashable, Sendable, Codable {
    /// Payment will never be taken through the app — pay at the venue.
    case notRequired
    case unpaid
    case pending
    case paid
    case failed
    case refunded

    public var isSettled: Bool { self == .paid || self == .notRequired || self == .refunded }

    public var displayName: String {
        switch self {
        case .notRequired: return "Pay at venue"
        case .unpaid: return "Payment due"
        case .pending: return "Payment processing"
        case .paid: return "Paid"
        case .failed: return "Payment failed"
        case .refunded: return "Refunded"
        }
    }
}

public enum PaymentMethod: String, CaseIterable, Hashable, Sendable, Codable {
    case none
    case applePay
    case card
    case venue

    public var displayName: String {
        switch self {
        case .none: return "No payment"
        case .applePay: return "Apple Pay"
        case .card: return "Card"
        case .venue: return "Pay at venue"
        }
    }
}

public enum BookingStatus: String, CaseIterable, Hashable, Sendable, Codable {
    case pending
    case confirmed
    case cancelled
    case completed
    case declined

    public var isActive: Bool { self == .pending || self == .confirmed }

    public var displayName: String {
        switch self {
        case .pending: return "Awaiting confirmation"
        case .confirmed: return "Confirmed"
        case .cancelled: return "Cancelled"
        case .completed: return "Completed"
        case .declined: return "Declined"
        }
    }
}

/// A reservation against a place.
///
/// Server-owned: the client proposes a booking, the server decides. Status and
/// payment state here are a *copy* of the server's answer and must never be
/// mutated locally to make the UI look better.
public struct Booking: Identifiable, Hashable, Sendable, Codable {
    public let id: UUID
    public let placeID: UUID
    /// Denormalised for the history list, so past bookings still render when
    /// the place has since been removed from the catalogue.
    public let placeName: String
    public let startDate: Date
    public let partySize: Int
    public let status: BookingStatus
    public let paymentStatus: PaymentStatus
    public let paymentMethod: PaymentMethod
    public let note: String?
    public let reference: String
    public let createdAt: Date

    public init(
        id: UUID,
        placeID: UUID,
        placeName: String,
        startDate: Date,
        partySize: Int,
        status: BookingStatus,
        paymentStatus: PaymentStatus = .notRequired,
        paymentMethod: PaymentMethod = .venue,
        note: String? = nil,
        reference: String,
        createdAt: Date
    ) {
        self.id = id
        self.placeID = placeID
        self.placeName = placeName
        self.startDate = startDate
        self.partySize = partySize
        self.status = status
        self.paymentStatus = paymentStatus
        self.paymentMethod = paymentMethod
        self.note = note
        self.reference = reference
        self.createdAt = createdAt
    }

    public var isUpcoming: Bool { isUpcoming(at: Date()) }

    public func isUpcoming(at date: Date) -> Bool {
        status.isActive && startDate >= date
    }

    /// Whether the user may still cancel.
    ///
    /// The server is the authority; this only decides whether to *offer* the
    /// action, so a cancel button never appears on something already finished.
    public func isCancellable(at date: Date = Date()) -> Bool {
        status.isActive && startDate > date
    }
}

/// What the client sends when proposing a booking.
public struct BookingRequest: Hashable, Sendable, Codable {
    public let placeID: UUID
    public let startDate: Date
    public let partySize: Int
    public let note: String?

    public init(placeID: UUID, startDate: Date, partySize: Int, note: String? = nil) {
        self.placeID = placeID
        self.startDate = startDate
        self.partySize = partySize
        self.note = note
    }

    /// Client-side sanity checks, so an obviously invalid request is not sent.
    ///
    /// These are convenience only — the server validates independently and is
    /// the authority. A client check that the server does not repeat is not a
    /// rule, it is a suggestion.
    public func validate(now: Date = Date(), maximumPartySize: Int = 20) -> BookingValidationError? {
        if partySize < 1 { return .partyTooSmall }
        if partySize > maximumPartySize { return .partyTooLarge(maximum: maximumPartySize) }
        if startDate <= now { return .inThePast }
        // A year out is almost certainly a date-picker mistake.
        if startDate > now.addingTimeInterval(365 * 86_400) { return .tooFarAhead }
        return nil
    }
}

public enum BookingValidationError: Error, Equatable, Sendable {
    case partyTooSmall
    case partyTooLarge(maximum: Int)
    case inThePast
    case tooFarAhead

    public var message: String {
        switch self {
        case .partyTooSmall: return "Choose at least one guest."
        case .partyTooLarge(let maximum): return "For more than \(maximum) guests, contact the venue directly."
        case .inThePast: return "Pick a time in the future."
        case .tooFarAhead: return "That date is too far ahead."
        }
    }
}

public protocol BookingServing: Sendable {
    func create(_ request: BookingRequest) async throws -> Booking
    func bookings() async throws -> [Booking]
    func booking(id: UUID) async throws -> Booking
    func cancel(id: UUID) async throws -> Booking
}

extension Array where Element == Booking {
    /// Soonest first — the next thing the traveller has to turn up for.
    public var upcoming: [Booking] {
        filter(\.isUpcoming).sorted { $0.startDate < $1.startDate }
    }

    /// Most recent first, for a history list.
    public var past: [Booking] {
        filter { !$0.isUpcoming }.sorted { $0.startDate > $1.startDate }
    }
}
