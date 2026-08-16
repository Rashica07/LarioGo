import Fluent
import Vapor

// MARK: - Requests

struct CreateOrganizationRequest: Content {
    let name: String
    let contactEmail: String
    let legalName: String?
    let vatNumber: String?

    func validate() throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            throw Abort(.badRequest, reason: "Il nome dell'attività è troppo corto.")
        }
        guard trimmed.count <= 120 else {
            throw Abort(.badRequest, reason: "Il nome dell'attività è troppo lungo.")
        }
        guard contactEmail.contains("@"), contactEmail.count >= 5 else {
            throw Abort(.badRequest, reason: "Indirizzo email non valido.")
        }
    }
}

struct UpdateProfileRequest: Content {
    let name: String?
    let summary: String?
    let about: String?
    let address: String?
    let phone: String?
    let website: String?
    let openingHours: String?
    let priceLevel: Int?
    let cuisines: [String]?
    let services: [String]?
    let photoUrls: [String]?
    let acceptsReservations: Bool?
    let capacity: Int?

    func validate() throws {
        if let priceLevel, !(1...4).contains(priceLevel) {
            throw Abort(.badRequest, reason: "Il livello di prezzo va da 1 a 4.")
        }
        if let capacity, capacity < 0 {
            throw Abort(.badRequest, reason: "La capienza non può essere negativa.")
        }
        if let website, !website.isEmpty,
           !(website.hasPrefix("http://") || website.hasPrefix("https://")) {
            throw Abort(.badRequest, reason: "Il sito web deve iniziare con http:// o https://.")
        }
    }
}

struct SubmitClaimRequest: Content {
    let placeID: UUID
    let method: ClaimMethod
    let note: String?
}

struct DecideClaimRequest: Content {
    let state: ClaimState
    let reason: String?
}

struct UpdateReservationRequest: Content {
    let state: ReservationState
    let reason: String?
    let internalNote: String?
}

struct InviteMemberRequest: Content {
    let email: String
    let role: BusinessRole

    func validate() throws {
        guard role != .owner else {
            // Ownership moves through an explicit transfer, not an invitation:
            // otherwise an admin could mint a second owner and lock the first out.
            throw Abort(.badRequest, reason: "La proprietà si trasferisce, non si invita.")
        }
    }
}

// MARK: - Responses

struct OrganizationResponse: Content {
    let id: UUID
    let name: String
    let slug: String
    let contactEmail: String
    let verification: String
    let role: String
    let createdAt: Date?

    init(_ organization: Organization, role: BusinessRole) throws {
        self.id = try organization.requireID()
        self.name = organization.name
        self.slug = organization.slug
        self.contactEmail = organization.contactEmail
        self.verification = organization.verification.rawValue
        self.role = role.rawValue
        self.createdAt = organization.createdAt
    }
}

/// One field of the merged listing, with where the value came from.
///
/// The provenance is not decoration: place data is ODbL, business data is not,
/// and any surface that shows the merged result has to be able to attribute the
/// ODbL half correctly.
struct MergedField: Content {
    enum Source: String, Content {
        case business
        case catalogue
        case missing
    }

    let value: String?
    let source: Source

    init(business: String?, catalogue: String?) {
        if let business, !business.isEmpty {
            self.value = business
            self.source = .business
        } else if let catalogue, !catalogue.isEmpty {
            self.value = catalogue
            self.source = .catalogue
        } else {
            self.value = nil
            self.source = .missing
        }
    }
}

struct BusinessProfileResponse: Content {
    let placeID: UUID
    let isPublished: Bool
    let completeness: Int
    let name: MergedField
    let summary: MergedField
    let about: MergedField
    let address: MergedField
    let phone: MergedField
    let website: MergedField
    let openingHours: String?
    let priceLevel: Int?
    let cuisines: [String]
    let services: [String]
    let photoUrls: [String]
    let acceptsReservations: Bool
    let capacity: Int?
    /// Present whenever any field still comes from the catalogue.
    let attribution: String?

    init(profile: BusinessProfile, place: Place) throws {
        self.placeID = try place.requireID()
        self.isPublished = profile.isPublished
        self.completeness = profile.completeness
        self.name = MergedField(business: profile.name, catalogue: place.name)
        self.summary = MergedField(business: profile.summary, catalogue: place.summary)
        self.about = MergedField(business: profile.about, catalogue: place.about)
        self.address = MergedField(business: profile.address, catalogue: place.address)
        self.phone = MergedField(business: profile.phone, catalogue: place.phone)
        self.website = MergedField(business: profile.website, catalogue: place.website)
        self.openingHours = profile.openingHours
        self.priceLevel = profile.priceLevel ?? place.priceLevel
        self.cuisines = profile.cuisines.isEmpty ? place.cuisines : profile.cuisines
        self.services = profile.services
        self.photoUrls = profile.photoUrls
        self.acceptsReservations = profile.acceptsReservations
        self.capacity = profile.capacity

        let usesCatalogue = [name, summary, about, address, phone, website]
            .contains { $0.source == .catalogue }
        let fromOSM = place.tags.contains("source:openstreetmap")
        self.attribution = (usesCatalogue && fromOSM) ? "© OpenStreetMap contributors" : nil
    }
}

struct ClaimResponse: Content {
    let id: UUID
    let placeID: UUID
    let state: String
    let method: String
    let note: String?
    let decisionReason: String?
    let decidedAt: Date?
    let createdAt: Date?

    init(_ claim: Claim) throws {
        self.id = try claim.requireID()
        self.placeID = claim.$place.id
        self.state = claim.state.rawValue
        self.method = claim.method.rawValue
        self.note = claim.note
        self.decisionReason = claim.decisionReason
        self.decidedAt = claim.decidedAt
        self.createdAt = claim.createdAt
    }
}

/// A reservation as the business is allowed to see it.
///
/// Carries a first name and one contact channel — enough to run a service — and
/// deliberately no account identifier, email history or anything else the guest
/// did not need to hand over to book a table.
struct ReservationResponse: Content {
    let id: UUID
    let reference: String
    let guestName: String
    let guestContact: String?
    let startsAt: Date
    let partySize: Int
    let state: String
    let guestNote: String?
    let internalNote: String?
    let stateReason: String?

    init(_ reservation: Reservation) throws {
        self.id = try reservation.requireID()
        self.reference = reservation.reference
        self.guestName = reservation.guestName
        self.guestContact = reservation.guestContact
        self.startsAt = reservation.startsAt
        self.partySize = reservation.partySize
        self.state = reservation.state.rawValue
        self.guestNote = reservation.guestNote
        self.internalNote = reservation.internalNote
        self.stateReason = reservation.stateReason
    }
}

/// Everything the dashboard needs, in one round trip.
struct DashboardResponse: Content {
    struct AttentionItem: Content {
        let kind: String
        let message: String
        /// Where the portal should send the user to deal with it.
        let action: String?
    }

    let organization: OrganizationResponse
    let profileCompleteness: Int?
    let listingClaimed: Bool
    let openClaims: Int
    let upcomingReservations: [ReservationResponse]
    let pendingRequests: Int
    let needsAttention: [AttentionItem]
}
