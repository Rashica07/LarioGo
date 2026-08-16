import Fluent
import Vapor

/// Lifecycle of a reservation as the business sees it.
enum ReservationState: String, Codable, CaseIterable, Sendable {
    /// Sent by the guest, the business has not answered.
    case requested
    case confirmed
    /// Refused by the business, with a reason.
    case declined
    /// Called off by the guest.
    case cancelledByGuest
    /// Called off by the business after confirming.
    case cancelledByBusiness
    case completed
    /// Confirmed, nobody came.
    case noShow

    var isOpen: Bool {
        self == .requested || self == .confirmed
    }

    var allowedNext: Set<ReservationState> {
        switch self {
        case .requested: return [.confirmed, .declined, .cancelledByGuest]
        case .confirmed: return [.completed, .noShow, .cancelledByBusiness, .cancelledByGuest]
        case .declined, .cancelledByGuest, .cancelledByBusiness, .completed, .noShow: return []
        }
    }
}

/// A booking, from the business side of the counter.
///
/// WHAT IS DELIBERATELY NOT STORED HERE.
///
/// A restaurant needs to know who is coming, for how many, and how to reach
/// them if the kitchen floods. It does not need a durable copy of the guest's
/// account. So this row keeps a first name, one contact channel and a short
/// human-quotable reference — and nothing else. Anything more is retained by
/// the guest's own account, where the guest can delete it.
///
/// There is no payment field. Money is not handled here, and a column that
/// looks like it holds a payment state would invite someone to treat it as one.
final class Reservation: Model, @unchecked Sendable {
    static let schema = "reservations"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "organization_id")
    var organization: Organization

    @Parent(key: "place_id")
    var place: Place

    /// The guest's account, when the booking came through a Traversar app.
    /// Null for a reservation entered by staff over the telephone.
    @OptionalParent(key: "guest_user_id")
    var guest: User?

    /// Short code the guest and the business can both say out loud, e.g. "7QK4M2".
    @Field(key: "reference")
    var reference: String

    /// First name only. Enough to greet somebody at the door.
    @Field(key: "guest_name")
    var guestName: String

    /// One channel, for this booking. Not a marketing list.
    @OptionalField(key: "guest_contact")
    var guestContact: String?

    @Field(key: "starts_at")
    var startsAt: Date

    @Field(key: "party_size")
    var partySize: Int

    @Enum(key: "state")
    var state: ReservationState

    /// Allergies, a wheelchair, a birthday. Written by the guest.
    @OptionalField(key: "guest_note")
    var guestNote: String?

    /// Written by the business, never shown to the guest.
    @OptionalField(key: "internal_note")
    var internalNote: String?

    /// Why it was declined or cancelled by the business.
    @OptionalField(key: "state_reason")
    var stateReason: String?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        organizationID: UUID,
        placeID: UUID,
        guestUserID: UUID? = nil,
        guestName: String,
        guestContact: String? = nil,
        startsAt: Date,
        partySize: Int,
        guestNote: String? = nil,
        reference: String = Reservation.makeReference(),
        state: ReservationState = .requested
    ) {
        self.id = id
        self.$organization.id = organizationID
        self.$place.id = placeID
        self.$guest.id = guestUserID
        self.guestName = guestName
        self.guestContact = guestContact
        self.startsAt = startsAt
        self.partySize = partySize
        self.guestNote = guestNote
        self.reference = reference
        self.state = state
    }

    /// Six characters, no vowels and no easily-confused glyphs.
    ///
    /// No vowels so the generator cannot produce a real word by accident; no
    /// 0/O/1/I because these get read down a noisy telephone line.
    static func makeReference() -> String {
        let alphabet = Array("BCDFGHJKLMNPQRSTVWXYZ23456789")
        return String((0..<6).map { _ in alphabet.randomElement()! })
    }

    func transition(to next: ReservationState, reason: String? = nil) throws {
        guard state.allowedNext.contains(next) else {
            throw Abort(
                .conflict,
                reason: "Una prenotazione in stato \(state.rawValue) non può passare a \(next.rawValue)."
            )
        }
        let needsReason: Set<ReservationState> = [.declined, .cancelledByBusiness]
        if needsReason.contains(next),
           (reason ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw Abort(.badRequest, reason: "Serve una motivazione per rifiutare o annullare.")
        }
        state = next
        stateReason = reason ?? stateReason
    }
}
