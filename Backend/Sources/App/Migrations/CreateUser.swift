import Fluent

struct CreateUser: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(User.schema)
            .id()
            .field("email", .string, .required)
            .field("password_hash", .string, .required)
            .field("display_name", .string, .required)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            // Enforced at the database level, not just in the handler: two
            // concurrent registrations for the same address would otherwise
            // both pass an application-level existence check.
            .unique(on: "email")
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema(User.schema).delete()
    }
}
