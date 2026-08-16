import Fluent

/// Creates the whole business domain in one migration.
///
/// Kept as a single unit because the tables are useless individually — a
/// membership without an organisation is not a partial feature, it is a broken
/// schema — and because reverting half of it would leave foreign keys dangling.
///
/// Order is not cosmetic: Postgres enum types must exist before a column can
/// use them, and a table must exist before another references it.
struct CreateBusinessDomain: AsyncMigration {
    func prepare(on database: Database) async throws {
        // MARK: Enum types
        let verification = try await database.enum("verification_state")
            .case("unverified")
            .case("pending")
            .case("verified")
            .case("rejected")
            .case("suspended")
            .create()

        let businessRole = try await database.enum("business_role")
            .case("owner")
            .case("admin")
            .case("manager")
            .case("staff")
            .create()

        let internalRole = try await database.enum("internal_role")
            .case("analyst")
            .case("moderator")
            .case("administrator")
            .create()

        let claimState = try await database.enum("claim_state")
            .case("submitted")
            .case("awaitingEvidence")
            .case("inReview")
            .case("approved")
            .case("rejected")
            .case("withdrawn")
            .create()

        let claimMethod = try await database.enum("claim_method")
            .case("phoneOnListing")
            .case("emailAtListedDomain")
            .case("document")
            .case("manual")
            .create()

        let reservationState = try await database.enum("reservation_state")
            .case("requested")
            .case("confirmed")
            .case("declined")
            .case("cancelledByGuest")
            .case("cancelledByBusiness")
            .case("completed")
            .case("noShow")
            .create()

        let sponsorshipKind = try await database.enum("sponsorship_kind")
            .case("labelledPlacement")
            .case("promotion")
            .case("territorialCampaign")
            .create()

        let enquiryKind = try await database.enum("enquiry_kind")
            .case("demo")
            .case("sponsorship")
            .case("territory")
            .case("integration")
            .create()

        let enquiryState = try await database.enum("enquiry_state")
            .case("received")
            .case("contacted")
            .case("closed")
            .case("discarded")
            .create()

        let sponsorshipState = try await database.enum("sponsorship_state")
            .case("draft")
            .case("pendingReview")
            .case("active")
            .case("paused")
            .case("ended")
            .case("rejected")
            .create()

        // MARK: Organisations
        try await database.schema(Organization.schema)
            .id()
            .field("name", .string, .required)
            .field("slug", .string, .required)
            .field("legal_name", .string)
            .field("vat_number", .string)
            .field("contact_email", .string, .required)
            .field("verification", verification, .required)
            .field("verification_changed_at", .datetime)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .field("deleted_at", .datetime)
            .unique(on: "slug")
            .create()

        // MARK: Memberships
        try await database.schema(OrganizationMembership.schema)
            .id()
            .field("organization_id", .uuid, .required,
                   .references(Organization.schema, "id", onDelete: .cascade))
            .field("user_id", .uuid, .required,
                   .references(User.schema, "id", onDelete: .cascade))
            .field("role", businessRole, .required)
            .field("accepted_at", .datetime)
            .field("invited_by_user_id", .uuid,
                   .references(User.schema, "id", onDelete: .setNull))
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            // One membership per person per organisation. Without this, an
            // invitation sent twice produces two rows with different roles and
            // the effective permission becomes whichever the query returns first.
            .unique(on: "organization_id", "user_id")
            .create()

        // MARK: Internal staff
        try await database.schema(InternalStaff.schema)
            .id()
            .field("user_id", .uuid, .required,
                   .references(User.schema, "id", onDelete: .cascade))
            .field("role", internalRole, .required)
            // No SQL-level default: `.sql(.default(_:))` lives in FluentSQL,
            // which this target does not import, and the model always supplies
            // a value anyway.
            .field("is_active", .bool, .required)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .unique(on: "user_id")
            .create()

        // MARK: Claims
        try await database.schema(Claim.schema)
            .id()
            .field("organization_id", .uuid, .required,
                   .references(Organization.schema, "id", onDelete: .cascade))
            .field("place_id", .uuid, .required,
                   .references(Place.schema, "id", onDelete: .cascade))
            .field("state", claimState, .required)
            .field("method", claimMethod, .required)
            .field("note", .string)
            .field("decision_reason", .string)
            .field("submitted_by_user_id", .uuid, .required,
                   .references(User.schema, "id", onDelete: .cascade))
            .field("decided_by_user_id", .uuid,
                   .references(User.schema, "id", onDelete: .setNull))
            .field("decided_at", .datetime)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()

        // MARK: Business profiles
        try await database.schema(BusinessProfile.schema)
            .id()
            .field("organization_id", .uuid, .required,
                   .references(Organization.schema, "id", onDelete: .cascade))
            .field("place_id", .uuid, .required,
                   .references(Place.schema, "id", onDelete: .cascade))
            .field("is_published", .bool, .required)
            .field("name", .string)
            .field("summary", .string)
            .field("about", .string)
            .field("address", .string)
            .field("phone", .string)
            .field("website", .string)
            .field("opening_hours", .string)
            .field("price_level", .int)
            .field("cuisines", .array(of: .string), .required)
            .field("services", .array(of: .string), .required)
            .field("photo_urls", .array(of: .string), .required)
            .field("accepts_reservations", .bool, .required)
            .field("capacity", .int)
            .field("published_at", .datetime)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            // One overlay per organisation per listing. Two would make the
            // merge order arbitrary.
            .unique(on: "organization_id", "place_id")
            .create()

        // MARK: Reservations
        try await database.schema(Reservation.schema)
            .id()
            .field("organization_id", .uuid, .required,
                   .references(Organization.schema, "id", onDelete: .cascade))
            .field("place_id", .uuid, .required,
                   .references(Place.schema, "id", onDelete: .cascade))
            // The guest's account may go; the business still needs its booking
            // history, so the reference is cleared rather than the row deleted.
            .field("guest_user_id", .uuid,
                   .references(User.schema, "id", onDelete: .setNull))
            .field("reference", .string, .required)
            .field("guest_name", .string, .required)
            .field("guest_contact", .string)
            .field("starts_at", .datetime, .required)
            .field("party_size", .int, .required)
            .field("state", reservationState, .required)
            .field("guest_note", .string)
            .field("internal_note", .string)
            .field("state_reason", .string)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .unique(on: "reference")
            .create()

        // MARK: Sponsorships
        try await database.schema(Sponsorship.schema)
            .id()
            .field("organization_id", .uuid, .required,
                   .references(Organization.schema, "id", onDelete: .cascade))
            .field("place_id", .uuid, .required,
                   .references(Place.schema, "id", onDelete: .cascade))
            .field("kind", sponsorshipKind, .required)
            .field("state", sponsorshipState, .required)
            .field("headline", .string, .required)
            .field("detail", .string)
            .field("starts_on", .datetime, .required)
            .field("ends_on", .datetime, .required)
            // Required at the database level too: a paid placement with no
            // visible label is the failure mode this column exists to prevent,
            // and application validation alone would not survive a bulk import.
            .field("disclosure_label", .string, .required)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()

        // MARK: Enquiries
        // No foreign keys: whoever sends one is not a customer yet, and may
        // never become one.
        try await database.schema(Enquiry.schema)
            .id()
            .field("kind", enquiryKind, .required)
            .field("state", enquiryState, .required)
            .field("name", .string, .required)
            .field("email", .string, .required)
            .field("organization_name", .string)
            .field("phone", .string)
            .field("message", .string)
            .field("source_path", .string)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()
    }

    func revert(on database: Database) async throws {
        // Reverse order: children before parents, tables before their enums.
        try await database.schema(Enquiry.schema).delete()
        try await database.schema(Sponsorship.schema).delete()
        try await database.schema(Reservation.schema).delete()
        try await database.schema(BusinessProfile.schema).delete()
        try await database.schema(Claim.schema).delete()
        try await database.schema(InternalStaff.schema).delete()
        try await database.schema(OrganizationMembership.schema).delete()
        try await database.schema(Organization.schema).delete()

        try await database.enum("enquiry_state").delete()
        try await database.enum("enquiry_kind").delete()
        try await database.enum("sponsorship_state").delete()
        try await database.enum("sponsorship_kind").delete()
        try await database.enum("reservation_state").delete()
        try await database.enum("claim_method").delete()
        try await database.enum("claim_state").delete()
        try await database.enum("internal_role").delete()
        try await database.enum("business_role").delete()
        try await database.enum("verification_state").delete()
    }
}
