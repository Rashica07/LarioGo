import Fluent
import Vapor

/// The authenticated person's standing inside one organisation.
///
/// Resolved once per request and passed around, so a handler cannot forget to
/// check and cannot accidentally check a different organisation than the one it
/// is about to write to.
struct BusinessContext: Sendable {
    let user: User
    let organization: Organization
    let role: BusinessRole

    /// Whether this person may do a thing here.
    func can(_ capability: BusinessCapability) -> Bool {
        role.can(capability)
    }

    /// Enforces a capability, or 403.
    ///
    /// 403 and not 404: the caller is a member, so hiding the resource would
    /// only confuse them. For non-members `resolve` already returns 404, which
    /// is the case where hiding matters.
    func require(_ capability: BusinessCapability) throws {
        guard can(capability) else {
            throw Abort(.forbidden, reason: "Il ruolo \(role.rawValue) non consente questa operazione.")
        }
    }

    /// Whether the organisation may currently publish to the public catalogue.
    func requirePublishable() throws {
        guard organization.verification.canPublish else {
            throw Abort(
                .forbidden,
                reason: "L'organizzazione non è verificata: le modifiche restano in bozza."
            )
        }
    }
}

extension Request {
    /// Resolves the caller's standing in the given organisation.
    ///
    /// Returns 404 rather than 403 when there is no membership. A 403 would
    /// confirm that the organisation exists, which lets anyone with a token
    /// enumerate the customer list one identifier at a time.
    func businessContext(organizationID: UUID) async throws -> BusinessContext {
        let user = try await requireCurrentUser()
        let userID = try user.requireID()

        guard
            let membership = try await OrganizationMembership.query(on: db)
                .filter(\.$organization.$id == organizationID)
                .filter(\.$user.$id == userID)
                .with(\.$organization)
                .first(),
            membership.isActive
        else {
            throw Abort(.notFound, reason: "Organizzazione non trovata.")
        }

        return BusinessContext(
            user: user,
            organization: membership.organization,
            role: membership.role
        )
    }

    /// Every organisation the caller actively belongs to.
    func organizations() async throws -> [(Organization, BusinessRole)] {
        let user = try await requireCurrentUser()
        let memberships = try await OrganizationMembership.query(on: db)
            .filter(\.$user.$id == user.requireID())
            .with(\.$organization)
            .all()
        return memberships.filter(\.isActive).map { ($0.organization, $0.role) }
    }

    /// The caller's internal Traversar role, if any.
    ///
    /// Reads a different table from the business path on purpose: no business
    /// membership, however elevated, can produce a value here.
    func internalStaff() async throws -> InternalStaff? {
        guard let user = try await currentUser() else { return nil }
        let staff = try await InternalStaff.query(on: db)
            .filter(\.$user.$id == user.requireID())
            .first()
        return staff?.isActive == true ? staff : nil
    }

    /// Requires an internal role able to decide on claims.
    func requireClaimReviewer() async throws -> InternalStaff {
        guard let staff = try await internalStaff(), staff.role.canReviewClaims else {
            // 404, not 403: the review queue should not announce itself to
            // people who are not part of it.
            throw Abort(.notFound)
        }
        return staff
    }
}
