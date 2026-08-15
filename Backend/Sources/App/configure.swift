import Fluent
import FluentPostgresDriver
import JWT
import Vapor

/// Configuration errors that must stop the process rather than degrade quietly.
///
/// A server that boots with a default signing key is worse than one that refuses
/// to boot: it issues tokens anyone can forge.
enum ConfigurationError: Error, CustomStringConvertible {
    case missingJWTSecret
    case weakJWTSecret(length: Int)

    var description: String {
        switch self {
        case .missingJWTSecret:
            return """
            JWT_SECRET is not set. Generate one with `openssl rand -base64 48` and \
            export it. The server will not start without it.
            """
        case .weakJWTSecret(let length):
            return "JWT_SECRET is only \(length) characters; at least 32 are required."
        }
    }
}

public func configure(_ app: Application) async throws {
    // MARK: Database
    if let databaseURL = Environment.get("DATABASE_URL") {
        // Managed hosts (Railway, Fly, Heroku) inject a single URL. Their certs
        // are not in the container trust store, so verification is relaxed for
        // the TLS handshake only — the connection is still encrypted.
        var tlsConfiguration = TLSConfiguration.makeClientConfiguration()
        tlsConfiguration.certificateVerification = .none
        try app.databases.use(
            .postgres(
                url: databaseURL,
                tlsConfiguration: Environment.get("DATABASE_DISABLE_TLS") == "true"
                    ? nil
                    : tlsConfiguration
            ),
            as: .psql
        )
    } else {
        app.databases.use(
            .postgres(
                configuration: SQLPostgresConfiguration(
                    hostname: Environment.get("DATABASE_HOST") ?? "localhost",
                    port: Environment.get("DATABASE_PORT").flatMap(Int.init)
                        ?? SQLPostgresConfiguration.ianaPortNumber,
                    username: Environment.get("DATABASE_USERNAME") ?? "lariogo",
                    password: Environment.get("DATABASE_PASSWORD") ?? "lariogo",
                    database: Environment.get("DATABASE_NAME") ?? "lariogo",
                    tls: .disable
                )
            ),
            as: .psql
        )
    }

    // MARK: Security
    app.passwords.use(.bcrypt)

    guard let jwtSecret = Environment.get("JWT_SECRET") else {
        // Tests and local development get an ephemeral key rather than a
        // hardcoded one, so a dev secret can never leak into production.
        if app.environment == .production {
            throw ConfigurationError.missingJWTSecret
        }
        // Plain stdlib on purpose: this must not depend on a helper whose
        // availability cannot be checked without a compiler.
        let alphabet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        let ephemeral = String((0..<64).compactMap { _ in alphabet.randomElement() })
        app.logger.warning("JWT_SECRET unset — generated an ephemeral key. Tokens will not survive a restart.")
        app.jwt.signers.use(.hs256(key: ephemeral))
        try await configureRoutesAndMigrations(app)
        return
    }

    guard jwtSecret.count >= 32 else {
        throw ConfigurationError.weakJWTSecret(length: jwtSecret.count)
    }
    app.jwt.signers.use(.hs256(key: jwtSecret))

    try await configureRoutesAndMigrations(app)
}

private func configureRoutesAndMigrations(_ app: Application) async throws {
    // MARK: Middleware
    app.middleware.use(ErrorMiddleware.default(environment: app.environment))

    let corsOrigin: CORSMiddleware.AllowOriginSetting
    if let allowed = Environment.get("CORS_ALLOWED_ORIGIN") {
        corsOrigin = .custom(allowed)
    } else if app.environment == .production {
        // Never reflect arbitrary origins in production.
        corsOrigin = .none
    } else {
        corsOrigin = .all
    }
    app.middleware.use(CORSMiddleware(configuration: .init(
        allowedOrigin: corsOrigin,
        allowedMethods: [.GET, .POST, .PATCH, .DELETE, .OPTIONS],
        allowedHeaders: [.accept, .authorization, .contentType, .origin]
    )))

    // MARK: Body size
    app.routes.defaultMaxBodySize = "512kb"

    // MARK: Migrations
    app.migrations.add(CreateUser())
    app.migrations.add(CreatePlace())
    // Seed content is a migration so a fresh environment is immediately useful.
    // It no-ops when the table already has rows, and is skipped in production
    // unless explicitly enabled — real deployments get licensed content, not
    // the sample dining and event entries.
    if app.environment != .production || Environment.get("SEED_CONTENT") == "true" {
        app.migrations.add(SeedPlaces())
    }

    if Environment.get("AUTO_MIGRATE") == "true" || app.environment == .testing {
        try await app.autoMigrate()
    }

    // MARK: Routes
    try routes(app)
}
