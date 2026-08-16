import Fluent
import Vapor

/// A Traversar employee's internal privileges.
///
/// SEPARATE TABLE, SEPARATE ENUM, ON PURPOSE.
///
/// The obvious design is one `role` column on `User` covering travellers,
/// business people and staff. It is also the design where a bug in business
/// role assignment hands somebody the ability to approve their own claim.
/// Keeping internal authority in its own table means no code path that reads a
/// `BusinessRole` can ever produce an internal permission: there is nothing to
/// confuse, because the two enums never meet.
///
/// Rows here are created out of band — a migration or an operator running a
/// command — never through a public endpoint. There is deliberately no route
/// that writes to this table.
enum InternalRole: String, Codable, CaseIterable, Sendable {
    /// Reads the review queue, cannot decide.
    case analyst
    /// Approves and rejects claims, edits catalogue records.
    case moderator
    /// Everything, including granting internal roles.
    case administrator

    var canReviewClaims: Bool {
        self == .moderator || self == .administrator
    }

    var canGrantInternalRoles: Bool {
        self == .administrator
    }
}

final class InternalStaff: Model, @unchecked Sendable {
    static let schema = "internal_staff"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "user_id")
    var user: User

    @Enum(key: "role")
    var role: InternalRole

    /// Lets access be revoked without destroying the audit trail of what this
    /// person approved while they held it.
    @Field(key: "is_active")
    var isActive: Bool

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() {}

    init(id: UUID? = nil, userID: UUID, role: InternalRole, isActive: Bool = true) {
        self.id = id
        self.$user.id = userID
        self.role = role
        self.isActive = isActive
    }
}
