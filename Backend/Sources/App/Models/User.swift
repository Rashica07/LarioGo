import Fluent
import Vapor

/// A LarioGo traveller account.
///
/// `passwordHash` is never exposed: `User` deliberately does not conform to
/// `Content`, so it cannot be returned from a route by accident. Responses go
/// through `UserResponse` instead.
final class User: Model, @unchecked Sendable {
    static let schema = "users"

    @ID(key: .id)
    var id: UUID?

    /// Stored lowercased and trimmed so lookups are case-insensitive.
    @Field(key: "email")
    var email: String

    @Field(key: "password_hash")
    var passwordHash: String

    @Field(key: "display_name")
    var displayName: String

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        email: String,
        passwordHash: String,
        displayName: String
    ) {
        self.id = id
        self.email = User.normalize(email: email)
        self.passwordHash = passwordHash
        self.displayName = displayName
    }

    /// Canonical form used for both storage and lookup.
    static func normalize(email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

extension User {
    var response: UserResponse {
        get throws {
            UserResponse(
                id: try requireID(),
                email: email,
                displayName: displayName,
                createdAt: createdAt
            )
        }
    }
}
