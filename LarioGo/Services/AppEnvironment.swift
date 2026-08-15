//
//  AppEnvironment.swift
//  LarioGo
//
//  Owns configuration, services and session for the whole app.
//

import Foundation
import LarioCore
import SwiftUI

/// The app's composition root.
///
/// Everything that needs a service reads it from here, so there is exactly one
/// place that knows whether the app is running on mock content or a live API.
/// Views and view models never construct a service themselves.
@MainActor
final class AppEnvironment: ObservableObject {

    /// Current data source. Changing it rebuilds the services immediately, so
    /// the switcher in Profile takes effect without an app restart.
    @Published private(set) var configuration: AppConfiguration

    @Published private(set) var placeService: any PlaceServing
    @Published private(set) var authService: any AuthServing
    @Published private(set) var bookingService: any BookingServing

    @Published private(set) var session: AuthSession?

    /// The last configuration error, surfaced rather than swallowed: a build
    /// pointed at a live API with no base URL should say so, not silently fall
    /// back to mock content.
    @Published private(set) var configurationError: String?

    private let sessionStore: SessionStoring

    init(
        configuration: AppConfiguration = .current,
        sessionStore: SessionStoring = KeychainSessionStore()
    ) {
        self.configuration = configuration
        self.sessionStore = sessionStore

        // Build a usable environment even if configuration is wrong, so the app
        // still launches and can explain itself.
        do {
            let factory = try ServiceFactory(configuration: configuration)
            self.placeService = factory.places
            self.authService = factory.auth
            self.bookingService = factory.bookings
            self.configurationError = nil
        } catch {
            self.placeService = MockPlaceService(behaviour: configuration.mockBehaviour)
            self.authService = MockAuthService(behaviour: configuration.mockBehaviour)
            self.bookingService = MockBookingService(behaviour: configuration.mockBehaviour)
            self.configurationError = String(describing: error)
        }

        self.session = sessionStore.load().flatMap { $0.isValid() ? $0 : nil }
        if session == nil { sessionStore.clear() }
    }

    // MARK: - Session

    var isSignedIn: Bool { session != nil }
    var currentUser: UserProfile? { session?.user }

    func signIn(_ session: AuthSession) {
        self.session = session
        sessionStore.save(session)
    }

    func signOut() {
        session = nil
        sessionStore.clear()
    }

    /// Called when the server rejects the token, so a dead session does not sit
    /// around looking signed in.
    func sessionExpired() {
        guard session != nil else { return }
        signOut()
    }

    // MARK: - Data source switching

    /// Whether the UI must badge content as sample data.
    var mustLabelSampleContent: Bool { configuration.mustLabelContentAsSample }

    func setDataSource(_ mode: DataSourceMode) {
        var updated = configuration
        updated.dataSource = mode
        apply(updated)
    }

    func setMockBehaviour(_ behaviour: MockBehaviour) {
        var updated = configuration
        updated.mockBehaviour = behaviour
        apply(updated)
    }

    private func apply(_ updated: AppConfiguration) {
        do {
            let factory = try ServiceFactory(configuration: updated)
            configuration = updated
            placeService = factory.places
            authService = factory.auth
            bookingService = factory.bookings
            configurationError = nil
            // Switching sources invalidates a session issued by the other one:
            // a mock token means nothing to the real API, and vice versa.
            signOut()
        } catch {
            configurationError = String(describing: error)
        }
    }
}

// MARK: - Session storage

protocol SessionStoring: Sendable {
    func load() -> AuthSession?
    func save(_ session: AuthSession)
    func clear()
}

/// Stores the session in the Keychain.
///
/// Not `UserDefaults`: that is an unencrypted plist inside the app container,
/// readable from a backup or a jailbroken device. A bearer token is a credential
/// and belongs in the Keychain.
struct KeychainSessionStore: SessionStoring {
    private let service = "com.traversar.lariogo"
    private let account = "session"

    func load() -> AuthSession? {
        guard let data = Keychain.read(service: service, account: account) else { return nil }
        return try? JSONDecoder().decode(AuthSession.self, from: data)
    }

    func save(_ session: AuthSession) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        Keychain.write(data, service: service, account: account)
    }

    func clear() {
        Keychain.delete(service: service, account: account)
    }
}

/// In-memory store for previews and tests.
final class InMemorySessionStore: SessionStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var stored: AuthSession?

    init(initial: AuthSession? = nil) { self.stored = initial }

    func load() -> AuthSession? { lock.lock(); defer { lock.unlock() }; return stored }
    func save(_ session: AuthSession) { lock.lock(); stored = session; lock.unlock() }
    func clear() { lock.lock(); stored = nil; lock.unlock() }
}
