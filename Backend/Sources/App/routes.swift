import Fluent
import Vapor

func routes(_ app: Application) throws {
    // Liveness/readiness. Deployment platforms poll this; it must stay cheap
    // and must not require auth.
    app.get("health") { req async -> HealthResponse in
        var databaseReachable = false
        do {
            _ = try await User.query(on: req.db).count()
            databaseReachable = true
        } catch {
            req.logger.error("Health check could not reach the database: \(error)")
        }
        return HealthResponse(
            status: databaseReachable ? "ok" : "degraded",
            service: "lariogo-api",
            database: databaseReachable ? "up" : "down"
        )
    }

    // Everything else is versioned. Clients pin /api/v1 so a future /api/v2
    // can change shape without breaking shipped app versions.
    let v1 = app.grouped("api", "v1")
    try v1.register(collection: AuthController())
    // Discovery content is readable without authentication: a tourist should be
    // able to open the app and see what is around them before making an account.
    try v1.register(collection: PlaceController())
}

struct HealthResponse: Content {
    let status: String
    let service: String
    let database: String
}
