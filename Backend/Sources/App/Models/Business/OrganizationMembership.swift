import Fluent
import Vapor

/// What a person may do inside one organisation.
///
/// Ordered by authority so comparisons are a single `>=` rather than a set of
/// `if` branches that eventually disagree with each other.
enum BusinessRole: String, Codable, CaseIterable, Sendable, Comparable {
    /// Can do everything, including transferring ownership and deleting the
    /// organisation. Exactly one per organisation, enforced in the service.
    case owner
    /// Everything except ownership transfer and deletion.
    case admin
    /// Day-to-day running: profile, opening hours, availability, reservations.
    case manager
    /// Reservations only. The role a seasonal hire gets.
    case staff

    private var rank: Int {
        switch self {
        case .owner: return 4
        case .admin: return 3
        case .manager: return 2
        case .staff: return 1
        }
    }

    static func < (lhs: BusinessRole, rhs: BusinessRole) -> Bool {
        lhs.rank < rhs.rank
    }
}

/// Things a member can attempt. Kept as capabilities rather than scattering
/// role checks through the controllers, so adding a role later means editing
/// one table instead of hunting comparisons.
enum BusinessCapability: String, Sendable {
    case viewDashboard
    case manageReservations
    case editProfile
    case manageMembers
    case submitClaim
    case manageSponsorship
    case deleteOrganization
}

extension BusinessRole {
    /// The lowest role that may perform each action.
    func can(_ capability: BusinessCapability) -> Bool {
        switch capability {
        case .viewDashboard, .manageReservations:
            return self >= .staff
        case .editProfile:
            return self >= .manager
        case .manageMembers, .submitClaim, .manageSponsorship:
            return self >= .admin
        case .deleteOrganization:
            return self == .owner
        }
    }
}

/// Joins a `User` to an `Organization` with a role.
///
/// The same person can belong to several organisations — a consultant looking
/// after three hotels is ordinary, not an edge case — so the role lives on the
/// membership and never on the user.
final class OrganizationMembership: Model, @unchecked Sendable {
    static let schema = "organization_memberships"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "organization_id")
    var organization: Organization

    @Parent(key: "user_id")
    var user: User

    @Enum(key: "role")
    var role: BusinessRole

    /// Null until the invited person accepts. An unaccepted membership grants
    /// nothing: capability checks read `acceptedAt` as well as the role.
    @OptionalField(key: "accepted_at")
    var acceptedAt: Date?

    /// Who added them. Useful when a business asks later how someone got access.
    @OptionalParent(key: "invited_by_user_id")
    var invitedBy: User?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        organizationID: UUID,
        userID: UUID,
        role: BusinessRole,
        acceptedAt: Date? = nil,
        invitedByUserID: UUID? = nil
    ) {
        self.id = id
        self.$organization.id = organizationID
        self.$user.id = userID
        self.role = role
        self.acceptedAt = acceptedAt
        self.$invitedBy.id = invitedByUserID
    }

    /// A membership only confers rights once accepted.
    var isActive: Bool { acceptedAt != nil }
}
