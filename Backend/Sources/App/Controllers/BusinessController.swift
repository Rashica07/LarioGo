import Fluent
import Vapor

/// The business portal's API.
///
/// Everything hangs off an organisation identifier, and every handler resolves
/// the caller's membership through `BusinessContext` before touching anything.
/// There is no route here that reads or writes another product's data directly:
/// the catalogue is reached through `Place`, which this service owns, and any
/// future cross-product traffic goes through the Traversar API layer rather
/// than through a second connection string.
struct BusinessController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let business = routes.grouped("business").authenticated()

        business.post("organizations", use: createOrganization)
        business.get("organizations", use: listOrganizations)

        let one = business.grouped("organizations", ":organizationID")
        one.get("dashboard", use: dashboard)
        one.get("profile", ":placeID", use: readProfile)
        one.patch("profile", ":placeID", use: updateProfile)
        one.post("profile", ":placeID", "publish", use: publishProfile)
        one.post("claims", use: submitClaim)
        one.get("claims", use: listClaims)
        one.get("reservations", use: listReservations)
        one.patch("reservations", ":reservationID", use: updateReservation)
    }

    // MARK: Organisations

    /// Creates an organisation and makes the caller its owner, in one
    /// transaction: an organisation with no members would be unreachable by
    /// anybody, including the person who just made it.
    func createOrganization(req: Request) async throws -> OrganizationResponse {
        let input = try req.content.decode(CreateOrganizationRequest.self)
        try input.validate()

        let user = try await req.requireCurrentUser()
        let userID = try user.requireID()

        return try await req.db.transaction { db in
            let organization = Organization(
                name: input.name.trimmingCharacters(in: .whitespacesAndNewlines),
                slug: try await Self.availableSlug(for: input.name, on: db),
                legalName: input.legalName,
                vatNumber: input.vatNumber,
                contactEmail: input.contactEmail
            )
            try await organization.save(on: db)

            let membership = OrganizationMembership(
                organizationID: try organization.requireID(),
                userID: userID,
                role: .owner,
                // The creator does not need to accept their own invitation.
                acceptedAt: Date()
            )
            try await membership.save(on: db)

            return try OrganizationResponse(organization, role: .owner)
        }
    }

    /// Appends a counter until the slug is free. Two "Trattoria del Porto" in
    /// different villages is entirely normal around the lake.
    private static func availableSlug(for name: String, on db: Database) async throws -> String {
        let base = Organization.slugify(name)
        var candidate = base
        var suffix = 2
        while try await Organization.query(on: db).filter(\.$slug == candidate).first() != nil {
            candidate = "\(base)-\(suffix)"
            suffix += 1
            if suffix > 50 {
                candidate = "\(base)-\(UUID().uuidString.prefix(6).lowercased())"
                break
            }
        }
        return candidate
    }

    func listOrganizations(req: Request) async throws -> [OrganizationResponse] {
        try await req.organizations().map { try OrganizationResponse($0.0, role: $0.1) }
    }

    // MARK: Dashboard

    /// One round trip for the whole landing screen.
    ///
    /// The "needs attention" list is derived from real state, not decorated:
    /// if there is nothing to do it comes back empty and the portal says so,
    /// rather than inventing a task to fill a panel.
    func dashboard(req: Request) async throws -> DashboardResponse {
        let organizationID = try req.parameters.require("organizationID", as: UUID.self)
        let context = try await req.businessContext(organizationID: organizationID)
        try context.require(.viewDashboard)

        let claims = try await Claim.query(on: req.db)
            .filter(\.$organization.$id == organizationID)
            .all()
        let openClaims = claims.filter { !$0.state.isTerminal }.count
        let approved = claims.filter { $0.state == .approved }

        let profile = try await BusinessProfile.query(on: req.db)
            .filter(\.$organization.$id == organizationID)
            .first()

        let now = Date()
        let reservations = try await Reservation.query(on: req.db)
            .filter(\.$organization.$id == organizationID)
            .filter(\.$startsAt >= now)
            .sort(\.$startsAt)
            .limit(20)
            .all()
        let upcoming = reservations.filter { $0.state.isOpen }
        let pending = upcoming.filter { $0.state == .requested }

        var attention: [DashboardResponse.AttentionItem] = []

        if !pending.isEmpty {
            attention.append(.init(
                kind: "reservations",
                message: pending.count == 1
                    ? "Una richiesta di prenotazione attende risposta."
                    : "\(pending.count) richieste di prenotazione attendono risposta.",
                action: "reservations"
            ))
        }

        if approved.isEmpty {
            attention.append(.init(
                kind: "claim",
                message: openClaims > 0
                    ? "La richiesta di gestione della scheda è in verifica."
                    : "Nessuna scheda del catalogo è ancora associata a questa attività.",
                action: openClaims > 0 ? nil : "claims"
            ))
        }

        if context.organization.verification == .verified,
           let profile, !profile.isPublished {
            attention.append(.init(
                kind: "profile",
                message: "Ci sono modifiche alla scheda non ancora pubblicate.",
                action: "profile"
            ))
        }

        if let profile, profile.completeness < 60 {
            attention.append(.init(
                kind: "completeness",
                message: "La scheda è compilata al \(profile.completeness)%: orari e recapiti sono ciò che i visitatori cercano per primo.",
                action: "profile"
            ))
        }

        return DashboardResponse(
            organization: try OrganizationResponse(context.organization, role: context.role),
            profileCompleteness: profile?.completeness,
            listingClaimed: !approved.isEmpty,
            openClaims: openClaims,
            upcomingReservations: try upcoming.prefix(8).map { try ReservationResponse($0) },
            pendingRequests: pending.count,
            needsAttention: attention
        )
    }

    // MARK: Profile

    func readProfile(req: Request) async throws -> BusinessProfileResponse {
        let organizationID = try req.parameters.require("organizationID", as: UUID.self)
        let placeID = try req.parameters.require("placeID", as: UUID.self)
        let context = try await req.businessContext(organizationID: organizationID)
        try context.require(.viewDashboard)

        let place = try await Self.claimedPlace(placeID, organizationID: organizationID, on: req.db)
        let profile = try await Self.profile(organizationID: organizationID, placeID: placeID, on: req.db)
        return try BusinessProfileResponse(profile: profile, place: place)
    }

    /// Writes to the overlay, never to the catalogue row.
    ///
    /// The `Place` record is ODbL-derived; editing it here would blend licensed
    /// and proprietary data in the same column and destroy the provenance we are
    /// required to be able to state.
    func updateProfile(req: Request) async throws -> BusinessProfileResponse {
        let organizationID = try req.parameters.require("organizationID", as: UUID.self)
        let placeID = try req.parameters.require("placeID", as: UUID.self)
        let context = try await req.businessContext(organizationID: organizationID)
        try context.require(.editProfile)

        let input = try req.content.decode(UpdateProfileRequest.self)
        try input.validate()

        let place = try await Self.claimedPlace(placeID, organizationID: organizationID, on: req.db)
        let profile = try await Self.profile(organizationID: organizationID, placeID: placeID, on: req.db)

        if let value = input.name { profile.name = value }
        if let value = input.summary { profile.summary = value }
        if let value = input.about { profile.about = value }
        if let value = input.address { profile.address = value }
        if let value = input.phone { profile.phone = value }
        if let value = input.website { profile.website = value }
        if let value = input.openingHours { profile.openingHours = value }
        if let value = input.priceLevel { profile.priceLevel = value }
        if let value = input.cuisines { profile.cuisines = value }
        if let value = input.services { profile.services = value }
        if let value = input.photoUrls { profile.photoUrls = value }
        if let value = input.acceptsReservations { profile.acceptsReservations = value }
        if let value = input.capacity { profile.capacity = value }

        // Editing takes it back to draft: a published listing must reflect what
        // was reviewed, not whatever was typed a second ago.
        profile.isPublished = false
        try await profile.save(on: req.db)

        return try BusinessProfileResponse(profile: profile, place: place)
    }

    func publishProfile(req: Request) async throws -> BusinessProfileResponse {
        let organizationID = try req.parameters.require("organizationID", as: UUID.self)
        let placeID = try req.parameters.require("placeID", as: UUID.self)
        let context = try await req.businessContext(organizationID: organizationID)
        try context.require(.editProfile)
        try context.requirePublishable()

        let place = try await Self.claimedPlace(placeID, organizationID: organizationID, on: req.db)
        let profile = try await Self.profile(organizationID: organizationID, placeID: placeID, on: req.db)

        profile.isPublished = true
        profile.publishedAt = Date()
        try await profile.save(on: req.db)

        return try BusinessProfileResponse(profile: profile, place: place)
    }

    // MARK: Claims

    func submitClaim(req: Request) async throws -> ClaimResponse {
        let organizationID = try req.parameters.require("organizationID", as: UUID.self)
        let context = try await req.businessContext(organizationID: organizationID)
        try context.require(.submitClaim)

        let input = try req.content.decode(SubmitClaimRequest.self)
        guard try await Place.find(input.placeID, on: req.db) != nil else {
            throw Abort(.notFound, reason: "Scheda del catalogo non trovata.")
        }

        // One open claim per listing per organisation, and never a second claim
        // on something already approved.
        let existing = try await Claim.query(on: req.db)
            .filter(\.$organization.$id == organizationID)
            .filter(\.$place.$id == input.placeID)
            .all()
        if existing.contains(where: { !$0.state.isTerminal }) {
            throw Abort(.conflict, reason: "Esiste già una richiesta aperta per questa scheda.")
        }
        if existing.contains(where: { $0.state == .approved }) {
            throw Abort(.conflict, reason: "Questa scheda è già associata all'organizzazione.")
        }

        let claim = Claim(
            organizationID: organizationID,
            placeID: input.placeID,
            method: input.method,
            note: input.note,
            submittedByUserID: try context.user.requireID()
        )

        return try await req.db.transaction { db in
            try await claim.save(on: db)
            // An organisation with a claim under review is "pending", so the
            // portal can show one status rather than making the user infer it.
            if context.organization.verification == .unverified {
                context.organization.verification = .pending
                context.organization.verificationChangedAt = Date()
                try await context.organization.save(on: db)
            }
            return try ClaimResponse(claim)
        }
    }

    func listClaims(req: Request) async throws -> [ClaimResponse] {
        let organizationID = try req.parameters.require("organizationID", as: UUID.self)
        let context = try await req.businessContext(organizationID: organizationID)
        try context.require(.viewDashboard)

        return try await Claim.query(on: req.db)
            .filter(\.$organization.$id == organizationID)
            .sort(\.$createdAt, .descending)
            .all()
            .map { try ClaimResponse($0) }
    }

    // MARK: Reservations

    func listReservations(req: Request) async throws -> [ReservationResponse] {
        let organizationID = try req.parameters.require("organizationID", as: UUID.self)
        let context = try await req.businessContext(organizationID: organizationID)
        try context.require(.manageReservations)

        var query = Reservation.query(on: req.db)
            .filter(\.$organization.$id == organizationID)

        // ?stato=requested filters the queue to what needs answering.
        if let raw = req.query[String.self, at: "stato"],
           let state = ReservationState(rawValue: raw) {
            query = query.filter(\.$state == state)
        }

        return try await query
            .sort(\.$startsAt)
            .limit(200)
            .all()
            .map { try ReservationResponse($0) }
    }

    func updateReservation(req: Request) async throws -> ReservationResponse {
        let organizationID = try req.parameters.require("organizationID", as: UUID.self)
        let reservationID = try req.parameters.require("reservationID", as: UUID.self)
        let context = try await req.businessContext(organizationID: organizationID)
        try context.require(.manageReservations)

        guard let reservation = try await Reservation.query(on: req.db)
            .filter(\.$id == reservationID)
            // Scoped to the organisation: an identifier from another business
            // must read as absent, not as forbidden.
            .filter(\.$organization.$id == organizationID)
            .first()
        else {
            throw Abort(.notFound, reason: "Prenotazione non trovata.")
        }

        let input = try req.content.decode(UpdateReservationRequest.self)
        guard input.state != .cancelledByGuest else {
            throw Abort(.forbidden, reason: "Solo l'ospite può annullare la propria prenotazione.")
        }

        try reservation.transition(to: input.state, reason: input.reason)
        if let note = input.internalNote { reservation.internalNote = note }
        try await reservation.save(on: req.db)

        return try ReservationResponse(reservation)
    }

    // MARK: Helpers

    /// The listing, but only if this organisation has an approved claim on it.
    private static func claimedPlace(
        _ placeID: UUID,
        organizationID: UUID,
        on db: Database
    ) async throws -> Place {
        let approved = try await Claim.query(on: db)
            .filter(\.$organization.$id == organizationID)
            .filter(\.$place.$id == placeID)
            .filter(\.$state == ClaimState.approved)
            .first()
        guard approved != nil else {
            throw Abort(.forbidden, reason: "Questa scheda non è associata all'organizzazione.")
        }
        guard let place = try await Place.find(placeID, on: db) else {
            throw Abort(.notFound, reason: "Scheda del catalogo non trovata.")
        }
        return place
    }

    /// Fetches the overlay, creating an empty one the first time.
    private static func profile(
        organizationID: UUID,
        placeID: UUID,
        on db: Database
    ) async throws -> BusinessProfile {
        if let existing = try await BusinessProfile.query(on: db)
            .filter(\.$organization.$id == organizationID)
            .filter(\.$place.$id == placeID)
            .first() {
            return existing
        }
        let created = BusinessProfile(organizationID: organizationID, placeID: placeID)
        try await created.save(on: db)
        return created
    }
}
