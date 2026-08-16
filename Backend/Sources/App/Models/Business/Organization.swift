import Fluent
import Vapor

/// Where a business sits in the verification process.
///
/// A listing exists in the catalogue long before anyone claims it — it came
/// from OpenStreetMap. These states describe our confidence that the people
/// editing it are actually the people who run it.
enum VerificationState: String, Codable, CaseIterable, Sendable {
    /// Registered, but has not asked to be associated with any listing yet.
    case unverified
    /// A claim is open and waiting on a human at Traversar.
    case pending
    /// We have satisfied ourselves that this organisation runs this business.
    case verified
    /// The claim was refused. The reason lives on the claim, not here.
    case rejected
    /// Verified once, then suspended. Distinct from `rejected` so that a
    /// suspension can be lifted without re-running the whole check.
    case suspended

    /// Whether the organisation may currently publish changes to a listing.
    ///
    /// Deliberately a whitelist. A state added later is non-publishing until
    /// somebody decides otherwise, which is the safe direction to fail.
    var canPublish: Bool {
        self == .verified
    }
}

/// A business entity: one restaurant, hotel, museum or tour operator.
///
/// This is *not* a user. People belong to an organisation through
/// `OrganizationMembership`, so a restaurant can have an owner, a manager and
/// three staff without any of them sharing a login — which is what actually
/// happens the moment a second person needs access.
final class Organization: Model, @unchecked Sendable {
    static let schema = "organizations"

    @ID(key: .id)
    var id: UUID?

    /// Trading name. Not necessarily the registered company name.
    @Field(key: "name")
    var name: String

    /// URL-safe identifier, stable once assigned. Used in the business portal
    /// and, later, in any partner-facing reference.
    @Field(key: "slug")
    var slug: String

    /// Registered company name, VAT number and so on. Optional because a sole
    /// trader may not have all of it, and because demanding it up front would
    /// stop people finishing registration.
    @OptionalField(key: "legal_name")
    var legalName: String?

    @OptionalField(key: "vat_number")
    var vatNumber: String?

    /// Where Traversar writes when something needs a decision. Kept separate
    /// from the members' personal addresses so that staff turnover does not
    /// silently break the channel.
    @Field(key: "contact_email")
    var contactEmail: String

    @Enum(key: "verification")
    var verification: VerificationState

    /// Set when verification last changed state. Used to age out stale pending
    /// claims rather than letting them sit forever.
    @OptionalField(key: "verification_changed_at")
    var verificationChangedAt: Date?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    /// Soft delete: a business that leaves must not take its reservation
    /// history with it, because the other party to those bookings still has
    /// rights over their own records.
    @Timestamp(key: "deleted_at", on: .delete)
    var deletedAt: Date?

    @Children(for: \.$organization)
    var memberships: [OrganizationMembership]

    @Children(for: \.$organization)
    var claims: [Claim]

    init() {}

    init(
        id: UUID? = nil,
        name: String,
        slug: String? = nil,
        legalName: String? = nil,
        vatNumber: String? = nil,
        contactEmail: String,
        verification: VerificationState = .unverified
    ) {
        self.id = id
        self.name = name
        self.slug = slug ?? Organization.slugify(name)
        self.legalName = legalName
        self.vatNumber = vatNumber
        self.contactEmail = User.normalize(email: contactEmail)
        self.verification = verification
    }

    /// Lowercase, ASCII-ish, hyphen-separated.
    ///
    /// Italian trading names carry accents constantly ("Trattoria Città Alta"),
    /// and an accented byte in a URL is a support ticket waiting to happen.
    static func slugify(_ value: String) -> String {
        let folded = value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        var out = ""
        var lastWasSeparator = false
        for character in folded {
            if character.isLetter || character.isNumber {
                // `Character(_ :String)` va in trap se la stringa non contiene
                // esattamente un carattere, e alcune minuscole ne producono due:
                // "ß" diventa "ss". Un'attività con una ß nel nome — non rara
                // fra i clienti di lingua tedesca sul lago — avrebbe fatto
                // cadere il processo durante la registrazione.
                out += String(character).lowercased()
                lastWasSeparator = false
            } else if !lastWasSeparator && !out.isEmpty {
                out.append("-")
                lastWasSeparator = true
            }
        }
        while out.hasSuffix("-") { out.removeLast() }
        // A name made entirely of symbols would otherwise produce an empty
        // slug and collide with every other such name.
        return out.isEmpty ? UUID().uuidString.lowercased() : String(out.prefix(80))
    }
}
