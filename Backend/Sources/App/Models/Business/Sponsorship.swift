import Fluent
import Vapor

enum SponsorshipKind: String, Codable, CaseIterable, Sendable {
    /// A clearly labelled slot, separate from the results list.
    case labelledPlacement
    /// A time-boxed offer attached to a listing ("aperitivo a metà prezzo").
    case promotion
    /// Editorial inclusion in a territorial initiative, agreed with an ente.
    case territorialCampaign
}

enum SponsorshipState: String, Codable, CaseIterable, Sendable {
    case draft
    case pendingReview
    case active
    case paused
    case ended
    case rejected
}

/// A paid or agreed placement.
///
/// THE RULE THIS MODEL EXISTS TO ENFORCE.
///
/// Sponsorship must never change the order of organic results. The published
/// commitment is that ranking depends on distance, opening hours and relevance,
/// and that the position in the list is not for sale. A schema that *could*
/// express "boost this listing by N" would eventually be used that way, under
/// deadline, by somebody who did not read the commitment.
///
/// So there is no weight, no boost, no priority column here, and there is no
/// relation from this table into the ranking path. A sponsorship can occupy a
/// slot that is drawn separately and labelled, or attach an offer to a listing
/// the search already returned. It cannot reorder anything.
///
/// If a future requirement genuinely needs ordering influence, it needs a
/// product decision and a change to the public commitments first — not a column.
final class Sponsorship: Model, @unchecked Sendable {
    static let schema = "sponsorships"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "organization_id")
    var organization: Organization

    /// The listing the sponsorship concerns.
    @Parent(key: "place_id")
    var place: Place

    @Enum(key: "kind")
    var kind: SponsorshipKind

    @Enum(key: "state")
    var state: SponsorshipState

    /// Shown to the visitor, alongside the disclosure label. Reviewed before it
    /// goes active — an unreviewed free-text field on a paid placement is how
    /// misleading claims reach the public.
    @Field(key: "headline")
    var headline: String

    @OptionalField(key: "detail")
    var detail: String?

    @Field(key: "starts_on")
    var startsOn: Date

    @Field(key: "ends_on")
    var endsOn: Date

    /// The wording shown to visitors. Stored per record rather than hardcoded
    /// so that a territorial campaign can say "in collaborazione con il Comune"
    /// instead of "Sponsorizzato" — but it can never be empty.
    @Field(key: "disclosure_label")
    var disclosureLabel: String

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        organizationID: UUID,
        placeID: UUID,
        kind: SponsorshipKind,
        headline: String,
        detail: String? = nil,
        startsOn: Date,
        endsOn: Date,
        disclosureLabel: String = "Contenuto sponsorizzato",
        state: SponsorshipState = .draft
    ) {
        self.id = id
        self.$organization.id = organizationID
        self.$place.id = placeID
        self.kind = kind
        self.headline = headline
        self.detail = detail
        self.startsOn = startsOn
        self.endsOn = endsOn
        self.disclosureLabel = disclosureLabel
        self.state = state
    }

    func validate() throws {
        guard endsOn > startsOn else {
            throw Abort(.badRequest, reason: "La data di fine deve seguire quella di inizio.")
        }
        guard !disclosureLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            // Enforced here as well as in the database: an unlabelled paid
            // placement is indistinguishable from an organic result, which is
            // the one thing this whole model exists to prevent.
            throw Abort(.badRequest, reason: "Un posizionamento a pagamento richiede un'etichetta visibile.")
        }
        guard !headline.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw Abort(.badRequest, reason: "Serve un titolo.")
        }
    }

    /// Whether it should be shown today. Time-boxed by data, so an expired
    /// campaign disappears without anybody remembering to switch it off.
    func isLive(on date: Date = Date()) -> Bool {
        state == .active && date >= startsOn && date <= endsOn
    }
}
