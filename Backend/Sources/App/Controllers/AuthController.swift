import Fluent
import JWT
import Vapor

struct AuthController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let auth = routes.grouped("auth")
        auth.post("register", use: register)
        auth.post("login", use: login)
        auth.grouped(UserTokenAuthenticator(), UserToken.guardMiddleware())
            .get("me", use: me)
    }

    // MARK: POST /api/v1/auth/register

    @Sendable
    func register(req: Request) async throws -> AuthResponse {
        try RegisterRequest.validate(content: req)
        let payload = try req.content.decode(RegisterRequest.self)

        let email = User.normalize(email: payload.email)
        let displayName = payload.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !displayName.isEmpty else {
            throw Abort(.badRequest, reason: "Display name cannot be blank.")
        }

        let user = User(
            email: email,
            passwordHash: try await req.password.async.hash(payload.password),
            displayName: displayName
        )

        do {
            try await user.save(on: req.db)
        } catch let error as DatabaseError where error.isConstraintFailure {
            // The unique index is the authority. Checking for an existing row
            // first would still race with a concurrent registration.
            throw Abort(.conflict, reason: "An account with that email already exists.")
        }

        return try issueToken(for: user, on: req)
    }

    // MARK: POST /api/v1/auth/login

    @Sendable
    func login(req: Request) async throws -> AuthResponse {
        let payload = try req.content.decode(LoginRequest.self)
        let email = User.normalize(email: payload.email)

        let user = try await User.query(on: req.db)
            .filter(\.$email == email)
            .first()

        // Same error and roughly the same work whether the account is missing
        // or the password is wrong, so this cannot be used to enumerate which
        // email addresses are registered.
        guard let user else {
            _ = try? await req.password.async.verify(payload.password, created: Self.dummyHash)
            throw Abort(.unauthorized, reason: "Invalid email or password.")
        }

        guard try await req.password.async.verify(payload.password, created: user.passwordHash) else {
            throw Abort(.unauthorized, reason: "Invalid email or password.")
        }

        return try issueToken(for: user, on: req)
    }

    // MARK: GET /api/v1/auth/me

    @Sendable
    func me(req: Request) async throws -> UserResponse {
        // Deliberately re-reads the record instead of trusting the token, so a
        // deleted or renamed account is reflected immediately.
        try await req.requireCurrentUser().response
    }

    // MARK: Helpers

    private func issueToken(for user: User, on req: Request) throws -> AuthResponse {
        let token = UserToken(userID: try user.requireID())
        return AuthResponse(
            token: try req.jwt.sign(token),
            expiresIn: Int(UserToken.lifetime),
            user: try user.response
        )
    }

    /// A real bcrypt hash of a throwaway value, used to keep the timing of a
    /// failed lookup close to that of a wrong password.
    private static let dummyHash =
        "$2b$12$Ck2Vn1Rh1XwvBqXqPRVX9uCbz2sRA7pnKGr7ZQ1oMSJ0h5Bd3rXKe"
}
