import JWT
import Vapor

/// Claims carried by a LarioGo access token.
///
/// Deliberately minimal: an identifier and an expiry. Anything else (email,
/// display name) would be a stale copy of the database and would leak user data
/// into a value the client can decode.
struct UserToken: Content, Authenticatable, JWTPayload {
    /// Token lifetime. Short enough to limit damage from a leaked token, long
    /// enough that a tourist mid-trip is not re-authenticating constantly.
    static let lifetime: TimeInterval = 60 * 60 * 24 * 7

    enum CodingKeys: String, CodingKey {
        case subject = "sub"
        case expiration = "exp"
        case issuedAt = "iat"
    }

    var subject: SubjectClaim
    var expiration: ExpirationClaim
    var issuedAt: IssuedAtClaim

    var userID: UUID? {
        UUID(uuidString: subject.value)
    }

    init(userID: UUID, now: Date = Date()) {
        self.subject = SubjectClaim(value: userID.uuidString)
        self.expiration = ExpirationClaim(value: now.addingTimeInterval(Self.lifetime))
        self.issuedAt = IssuedAtClaim(value: now)
    }

    func verify(using signer: JWTSigner) throws {
        try expiration.verifyNotExpired()
        guard userID != nil else {
            throw Abort(.unauthorized, reason: "Malformed token subject.")
        }
    }
}
