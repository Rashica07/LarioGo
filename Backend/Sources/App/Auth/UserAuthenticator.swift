import Fluent
import JWT
import Vapor

/// Verifies the `Authorization: Bearer <jwt>` header and logs the claims in.
///
/// This authenticates the *token* only — no database round-trip. Routes that
/// need the actual record use `Request.currentUser()`, which also catches the
/// case of a valid token whose user has since been deleted.
struct UserTokenAuthenticator: AsyncBearerAuthenticator {
    func authenticate(bearer: BearerAuthorization, for request: Request) async throws {
        // A malformed or expired token must not fail the request outright:
        // leaving the user unauthenticated lets `guardMiddleware` produce a
        // consistent 401, and lets optional-auth routes still serve guests.
        guard let payload = try? request.jwt.verify(bearer.token, as: UserToken.self) else {
            return
        }
        request.auth.login(payload)
    }
}

extension Request {
    /// The authenticated user's record, or `nil` when the request is anonymous.
    ///
    /// Returns `nil` rather than throwing when the token is valid but the user
    /// no longer exists, so callers decide whether that is a 401 or a guest.
    func currentUser() async throws -> User? {
        guard let token = auth.get(UserToken.self), let id = token.userID else { return nil }
        return try await User.find(id, on: db)
    }

    /// The authenticated user's record, or a 401.
    func requireCurrentUser() async throws -> User {
        guard let user = try await currentUser() else {
            throw Abort(.unauthorized, reason: "Authentication required.")
        }
        return user
    }
}

extension RoutesBuilder {
    /// Routes that require a valid token.
    func authenticated() -> RoutesBuilder {
        grouped(UserTokenAuthenticator(), UserToken.guardMiddleware())
    }
}
