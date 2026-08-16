import Fluent
import Vapor

/// What somebody is asking for.
enum EnquiryKind: String, Codable, CaseIterable, Sendable {
    /// Wants to be shown the portal, usually with their own listing in it.
    case demo
    /// Wants to discuss a labelled placement or a territorial campaign.
    case sponsorship
    /// Runs a comune, consorzio or pro loco.
    case territory
    /// Wants API access.
    case integration
}

enum EnquiryState: String, Codable, CaseIterable, Sendable {
    case received
    case contacted
    case closed
    /// Obvious spam. Kept rather than deleted so the filter can be judged.
    case discarded
}

/// An enquiry from someone who is not yet a customer.
///
/// This is the first thing on the business side that a stranger can actually
/// use, so it is also the first place that will be hit by form spam. Hence the
/// honeypot and the minimum-interval check in the controller rather than a
/// captcha: a captcha punishes the restaurateur on a bad connection to stop a
/// script that does not care.
///
/// Deliberately minimal. A person asking to see a demo has no reason to hand
/// over anything beyond a name, a way to reply, and what they want.
final class Enquiry: Model, @unchecked Sendable {
    static let schema = "business_enquiries"

    @ID(key: .id)
    var id: UUID?

    @Enum(key: "kind")
    var kind: EnquiryKind

    @Enum(key: "state")
    var state: EnquiryState

    @Field(key: "name")
    var name: String

    @Field(key: "email")
    var email: String

    /// Trading name of their business, when they gave one.
    @OptionalField(key: "organization_name")
    var organizationName: String?

    @OptionalField(key: "phone")
    var phone: String?

    @OptionalField(key: "message")
    var message: String?

    /// Which page they were on. Tells us which argument actually works, without
    /// tracking anybody across the site.
    @OptionalField(key: "source_path")
    var sourcePath: String?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        kind: EnquiryKind,
        name: String,
        email: String,
        organizationName: String? = nil,
        phone: String? = nil,
        message: String? = nil,
        sourcePath: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.state = .received
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.email = User.normalize(email: email)
        self.organizationName = organizationName
        self.phone = phone
        self.message = message
        self.sourcePath = sourcePath
    }
}
