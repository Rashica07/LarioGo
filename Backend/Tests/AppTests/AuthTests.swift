@testable import App
import XCTVapor

final class AuthTests: XCTestCase {
    var app: Application!

    override func setUp() async throws {
        app = Application(.testing)
        try await configure(app)
        // Start from a clean slate so tests do not depend on execution order.
        try await User.query(on: app.db).delete()
    }

    override func tearDown() async throws {
        app.shutdown()
        app = nil
    }

    // MARK: - Registration

    func testRegisterReturnsTokenAndUser() async throws {
        try await app.test(.POST, "api/v1/auth/register", beforeRequest: { req in
            try req.content.encode([
                "email": "traveller@example.com",
                "password": "a-long-enough-password",
                "displayName": "Alpine Traveller",
            ])
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
            let body = try res.content.decode(AuthResponse.self)
            XCTAssertFalse(body.token.isEmpty)
            XCTAssertEqual(body.user.email, "traveller@example.com")
            XCTAssertEqual(body.user.displayName, "Alpine Traveller")
            XCTAssertGreaterThan(body.expiresIn, 0)
        })
    }

    func testRegisterNormalizesEmailCaseAndWhitespace() async throws {
        try await register(email: "  Traveller@Example.COM  ")

        // The normalized form is what got stored...
        let stored = try await User.query(on: app.db).first()
        XCTAssertEqual(stored?.email, "traveller@example.com")

        // ...and a differently-cased duplicate must still collide.
        try await app.test(.POST, "api/v1/auth/register", beforeRequest: { req in
            try req.content.encode([
                "email": "TRAVELLER@example.com",
                "password": "a-long-enough-password",
                "displayName": "Impostor",
            ])
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .conflict)
        })
    }

    func testRegisterRejectsDuplicateEmail() async throws {
        try await register(email: "dup@example.com")
        try await app.test(.POST, "api/v1/auth/register", beforeRequest: { req in
            try req.content.encode([
                "email": "dup@example.com",
                "password": "another-long-password",
                "displayName": "Second",
            ])
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .conflict)
        })
    }

    func testRegisterRejectsShortPassword() async throws {
        try await app.test(.POST, "api/v1/auth/register", beforeRequest: { req in
            try req.content.encode([
                "email": "short@example.com",
                "password": "abc",
                "displayName": "Short",
            ])
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .badRequest)
        })
    }

    func testRegisterRejectsMalformedEmail() async throws {
        try await app.test(.POST, "api/v1/auth/register", beforeRequest: { req in
            try req.content.encode([
                "email": "not-an-email",
                "password": "a-long-enough-password",
                "displayName": "Nope",
            ])
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .badRequest)
        })
    }

    func testPasswordIsNeverStoredInPlaintext() async throws {
        let password = "a-long-enough-password"
        try await register(email: "hash@example.com", password: password)

        let stored = try await User.query(on: app.db).first()
        let hash = try XCTUnwrap(stored?.passwordHash)
        XCTAssertNotEqual(hash, password)
        XCTAssertFalse(hash.contains(password))
        XCTAssertTrue(hash.hasPrefix("$2"), "Expected a bcrypt hash, got: \(hash.prefix(4))")
    }

    // MARK: - Login

    func testLoginSucceedsWithCorrectPassword() async throws {
        try await register(email: "login@example.com", password: "a-long-enough-password")

        try await app.test(.POST, "api/v1/auth/login", beforeRequest: { req in
            try req.content.encode([
                "email": "login@example.com",
                "password": "a-long-enough-password",
            ])
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
            let body = try res.content.decode(AuthResponse.self)
            XCTAssertFalse(body.token.isEmpty)
        })
    }

    func testLoginIsCaseInsensitiveOnEmail() async throws {
        try await register(email: "case@example.com", password: "a-long-enough-password")

        try await app.test(.POST, "api/v1/auth/login", beforeRequest: { req in
            try req.content.encode([
                "email": "CASE@Example.com",
                "password": "a-long-enough-password",
            ])
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
        })
    }

    func testLoginFailsWithWrongPassword() async throws {
        try await register(email: "wrong@example.com", password: "a-long-enough-password")

        try await app.test(.POST, "api/v1/auth/login", beforeRequest: { req in
            try req.content.encode([
                "email": "wrong@example.com",
                "password": "definitely-not-the-password",
            ])
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .unauthorized)
        })
    }

    func testLoginDoesNotRevealWhetherAccountExists() async throws {
        try await register(email: "known@example.com", password: "a-long-enough-password")

        var wrongPasswordBody = ""
        var unknownAccountBody = ""

        try await app.test(.POST, "api/v1/auth/login", beforeRequest: { req in
            try req.content.encode(["email": "known@example.com", "password": "bad-password-here"])
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .unauthorized)
            wrongPasswordBody = res.body.string
        })

        try await app.test(.POST, "api/v1/auth/login", beforeRequest: { req in
            try req.content.encode(["email": "ghost@example.com", "password": "bad-password-here"])
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .unauthorized)
            unknownAccountBody = res.body.string
        })

        XCTAssertEqual(
            wrongPasswordBody, unknownAccountBody,
            "Responses differ, which lets an attacker enumerate registered emails"
        )
    }

    // MARK: - /me

    func testMeReturnsTheAuthenticatedUser() async throws {
        let token = try await register(email: "me@example.com")

        try await app.test(.GET, "api/v1/auth/me", beforeRequest: { req in
            req.headers.bearerAuthorization = .init(token: token)
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
            let body = try res.content.decode(UserResponse.self)
            XCTAssertEqual(body.email, "me@example.com")
        })
    }

    func testMeRejectsMissingToken() async throws {
        try await app.test(.GET, "api/v1/auth/me", afterResponse: { res async throws in
            XCTAssertEqual(res.status, .unauthorized)
        })
    }

    func testMeRejectsGarbageToken() async throws {
        try await app.test(.GET, "api/v1/auth/me", beforeRequest: { req in
            req.headers.bearerAuthorization = .init(token: "not.a.jwt")
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .unauthorized)
        })
    }

    func testMeRejectsTokenForDeletedUser() async throws {
        let token = try await register(email: "deleted@example.com")
        try await User.query(on: app.db).delete()

        try await app.test(.GET, "api/v1/auth/me", beforeRequest: { req in
            req.headers.bearerAuthorization = .init(token: token)
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .unauthorized, "A token must stop working once its account is gone")
        })
    }

    // MARK: - Health

    func testHealthReportsDatabaseUp() async throws {
        try await app.test(.GET, "health", afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
            let body = try res.content.decode(HealthResponse.self)
            XCTAssertEqual(body.status, "ok")
            XCTAssertEqual(body.database, "up")
        })
    }

    // MARK: - Helpers

    /// Registers a user and returns the issued token.
    @discardableResult
    private func register(
        email: String,
        password: String = "a-long-enough-password",
        displayName: String = "Test Traveller"
    ) async throws -> String {
        var token = ""
        try await app.test(.POST, "api/v1/auth/register", beforeRequest: { req in
            try req.content.encode([
                "email": email,
                "password": password,
                "displayName": displayName,
            ])
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok, "Setup registration failed: \(res.body.string)")
            token = try res.content.decode(AuthResponse.self).token
        })
        return token
    }
}
