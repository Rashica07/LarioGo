import Fluent
import Vapor

/// The internal side of claim verification.
///
/// Mounted under `/internal`, guarded by `InternalStaff` and nothing else. A
/// business role — however senior inside its own organisation — cannot reach
/// these routes, because the guard reads a different table and a different enum.
/// That is the whole point of keeping the two apart: without it, an owner could
/// approve their own claim.
struct ClaimReviewController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let review = routes.grouped("internal").authenticated()
        review.get("claims", use: queue)
        review.patch("claims", ":claimID", use: decide)
    }

    /// Claims waiting on a human, oldest first.
    func queue(req: Request) async throws -> [ClaimReviewResponse] {
        _ = try await req.requireClaimReviewer()

        let claims = try await Claim.query(on: req.db)
            .with(\.$organization)
            .with(\.$place)
            .sort(\.$createdAt)
            .limit(200)
            .all()

        return try claims
            .filter { !$0.state.isTerminal }
            .map { try ClaimReviewResponse($0) }
    }

    /// Records a decision.
    ///
    /// Approving does two things that must not come apart: it marks the claim
    /// approved and it marks the organisation verified. Both happen in one
    /// transaction, because an approved claim on an unverified organisation
    /// would leave the business unable to publish with no visible reason why.
    func decide(req: Request) async throws -> ClaimReviewResponse {
        let staff = try await req.requireClaimReviewer()
        let claimID = try req.parameters.require("claimID", as: UUID.self)
        let input = try req.content.decode(DecideClaimRequest.self)

        guard let claim = try await Claim.query(on: req.db)
            .filter(\.$id == claimID)
            .with(\.$organization)
            .with(\.$place)
            .first()
        else {
            throw Abort(.notFound, reason: "Richiesta non trovata.")
        }

        let reviewerID = staff.$user.id

        return try await req.db.transaction { db in
            try claim.transition(to: input.state, reason: input.reason, decidedBy: reviewerID)
            try await claim.save(on: db)

            switch input.state {
            case .approved:
                claim.organization.verification = .verified
                claim.organization.verificationChangedAt = Date()
                try await claim.organization.save(on: db)
            case .rejected:
                // Only drop back to rejected if nothing else was already
                // approved: a business with two listings should not lose its
                // verified standing because one claim failed.
                let others = try await Claim.query(on: db)
                    .filter(\.$organization.$id == claim.$organization.id)
                    .filter(\.$state == ClaimState.approved)
                    .count()
                if others == 0 {
                    claim.organization.verification = .rejected
                    claim.organization.verificationChangedAt = Date()
                    try await claim.organization.save(on: db)
                }
            default:
                break
            }

            return try ClaimReviewResponse(claim)
        }
    }
}

/// A claim as a reviewer sees it: enough context to decide without opening
/// three other screens.
struct ClaimReviewResponse: Content {
    let id: UUID
    let state: String
    let method: String
    let note: String?
    let decisionReason: String?
    let createdAt: Date?

    let organizationID: UUID
    let organizationName: String
    let organizationContact: String
    let organizationVerification: String

    let placeID: UUID
    let placeName: String
    let placeAddress: String?
    /// The number on the catalogue listing. For the `phoneOnListing` method
    /// this *is* the evidence: the reviewer rings it.
    let placePhone: String?
    let placeWebsite: String?

    init(_ claim: Claim) throws {
        self.id = try claim.requireID()
        self.state = claim.state.rawValue
        self.method = claim.method.rawValue
        self.note = claim.note
        self.decisionReason = claim.decisionReason
        self.createdAt = claim.createdAt

        self.organizationID = try claim.organization.requireID()
        self.organizationName = claim.organization.name
        self.organizationContact = claim.organization.contactEmail
        self.organizationVerification = claim.organization.verification.rawValue

        self.placeID = try claim.place.requireID()
        self.placeName = claim.place.name
        self.placeAddress = claim.place.address
        self.placePhone = claim.place.phone
        self.placeWebsite = claim.place.website
    }
}
