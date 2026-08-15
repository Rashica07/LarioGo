import Vapor

// MARK: - Requests

struct RegisterRequest: Content, Validatable {
    let email: String
    let password: String
    let displayName: String

    static func validations(_ validations: inout Validations) {
        validations.add("email", as: String.self, is: .email)
        // 8 is the floor, not the goal. Length beats composition rules, so no
        // character-class requirements — they mostly produce "Password1!".
        validations.add("password", as: String.self, is: .count(8...256))
        validations.add("displayName", as: String.self, is: .count(1...80))
    }
}

struct LoginRequest: Content {
    let email: String
    let password: String
}

// MARK: - Responses

struct UserResponse: Content {
    let id: UUID
    let email: String
    let displayName: String
    let createdAt: Date?
}

struct AuthResponse: Content {
    let token: String
    /// Seconds until `token` expires, so the client can refresh proactively
    /// instead of waiting for a 401.
    let expiresIn: Int
    let user: UserResponse
}
