import Fluent
import Vapor

/// Where a claim sits. Terminal states are `approved`, `rejected` and
/// `withdrawn`; everything else can still move.
enum ClaimState: String, Codable, CaseIterable, Sendable {
    /// Submitted, nobody has looked yet.
    case submitted
    /// A reviewer has asked for something — a utility bill, a callback on the
    /// number in the listing — and is waiting.
    case awaitingEvidence
    /// Under active review.
    case inReview
    case approved
    case rejected
    /// The organisation pulled it. Kept rather than deleted so a pattern of
    /// claim-and-withdraw is visible.
    case withdrawn

    var isTerminal: Bool {
        switch self {
        case .approved, .rejected, .withdrawn: return true
        case .submitted, .awaitingEvidence, .inReview: return false
        }
    }

    /// Legal transitions. Written as data because a state machine scattered
    /// across handlers is a state machine nobody can audit.
    var allowedNext: Set<ClaimState> {
        switch self {
        case .submitted: return [.awaitingEvidence, .inReview, .withdrawn, .rejected]
        case .awaitingEvidence: return [.inReview, .withdrawn, .rejected]
        case .inReview: return [.approved, .rejected, .awaitingEvidence]
        case .approved, .rejected, .withdrawn: return []
        }
    }
}

/// How the claimant proposes to prove they run the place.
enum ClaimMethod: String, Codable, CaseIterable, Sendable {
    /// We ring the number already on the catalogue listing. Cheap, and strong:
    /// it proves control of the contact the listing already advertises.
    case phoneOnListing
    /// Email at the domain of the website already on the listing.
    case emailAtListedDomain
    /// A document — licence, VAT registration, utility bill.
    case document
    /// A reviewer went, or knows. Recorded honestly rather than dressed up.
    case manual
}

/// An organisation asserting that it runs a catalogue listing.
///
/// The catalogue entry exists first: it came from OpenStreetMap. A claim does
/// not create the place and does not modify it — it creates a relationship
/// which, once approved, lets the organisation publish a `BusinessProfile`
/// overlay on top.
final class Claim: Model, @unchecked Sendable {
    static let schema = "business_claims"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "organization_id")
    var organization: Organization

    @Parent(key: "place_id")
    var place: Place

    @Enum(key: "state")
    var state: ClaimState

    @Enum(key: "method")
    var method: ClaimMethod

    /// What the claimant told us. Free text, shown to the reviewer.
    @OptionalField(key: "note")
    var note: String?

    /// Why it was refused. Required when moving to `rejected`, because
    /// "rejected" with no reason generates a support thread every single time.
    @OptionalField(key: "decision_reason")
    var decisionReason: String?

    /// Which member submitted it.
    @Parent(key: "submitted_by_user_id")
    var submittedBy: User

    /// Which internal person decided. Null until a decision exists.
    @OptionalParent(key: "decided_by_user_id")
    var decidedBy: User?

    @OptionalField(key: "decided_at")
    var decidedAt: Date?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        organizationID: UUID,
        placeID: UUID,
        method: ClaimMethod,
        note: String? = nil,
        submittedByUserID: UUID,
        state: ClaimState = .submitted
    ) {
        self.id = id
        self.$organization.id = organizationID
        self.$place.id = placeID
        self.method = method
        self.note = note
        self.$submittedBy.id = submittedByUserID
        self.state = state
    }

    /// Applies a transition, refusing illegal ones.
    ///
    /// Throws rather than silently ignoring: a caller that tried to approve an
    /// already-rejected claim has a bug, and hiding it would let the two
    /// records drift apart.
    func transition(to next: ClaimState, reason: String? = nil, decidedBy: UUID? = nil) throws {
        guard state.allowedNext.contains(next) else {
            throw Abort(
                .conflict,
                reason: "Una richiesta in stato \(state.rawValue) non può passare a \(next.rawValue)."
            )
        }
        if next == .rejected, (reason ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw Abort(.badRequest, reason: "Il rifiuto richiede una motivazione.")
        }
        state = next
        decisionReason = reason ?? decisionReason
        if next.isTerminal {
            decidedAt = Date()
            $decidedBy.id = decidedBy
        }
    }
}
