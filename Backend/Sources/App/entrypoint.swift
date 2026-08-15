import Logging
import Vapor

@main
enum Entrypoint {
    static func main() async throws {
        var env = try Environment.detect()
        try LoggingSystem.bootstrap(from: &env)

        // `Application(_:)` is unavailable from an async context and becomes a
        // hard error under Swift 6; `Application.make` is the async-safe form.
        // It pairs with `asyncShutdown()` rather than `shutdown()`.
        let app = try await Application.make(env)

        do {
            try await configure(app)
            try await app.execute()
        } catch {
            app.logger.report(error: error)
            // Shut down before rethrowing, so a failed boot does not leave the
            // event loop group and database pool running.
            try? await app.asyncShutdown()
            throw error
        }

        try await app.asyncShutdown()
    }
}
