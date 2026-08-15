//
//  AuthViewModel.swift
//  LarioGo
//

import Foundation
import LarioCore
import SwiftUI

@MainActor
final class AuthViewModel: ObservableObject {

    enum Mode: String, CaseIterable {
        case signIn = "Sign In"
        case register = "Create Account"
    }

    @Published var mode: Mode = .signIn
    @Published var email = ""
    @Published var password = ""
    @Published var displayName = ""
    @Published private(set) var isSubmitting = false
    @Published private(set) var errorMessage: String?

    /// Field-level messages, shown inline rather than as one blanket error at
    /// the bottom — "something went wrong" does not tell anyone which box to fix.
    @Published private(set) var fieldErrors: [Field: String] = [:]

    enum Field: Hashable { case email, password, displayName }

    private let authService: any AuthServing
    private let onSignedIn: (AuthSession) -> Void

    init(authService: any AuthServing, onSignedIn: @escaping (AuthSession) -> Void) {
        self.authService = authService
        self.onSignedIn = onSignedIn
    }

    // MARK: - Validation

    /// Deliberately permissive: a single `@` with something either side. Strict
    /// email regexes reject valid addresses, and the server is the real
    /// authority anyway.
    static func isPlausibleEmail(_ email: String) -> Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2 else { return false }
        return !parts[0].isEmpty && parts[1].contains(".") && !parts[1].hasSuffix(".")
    }

    var canSubmit: Bool {
        guard !isSubmitting else { return false }
        guard Self.isPlausibleEmail(email), password.count >= 8 else { return false }
        if mode == .register {
            return !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return true
    }

    /// Validates on submit, not on every keystroke — telling someone their
    /// email is invalid while they are still typing it is hostile.
    private func validate() -> Bool {
        var errors: [Field: String] = [:]
        if !Self.isPlausibleEmail(email) {
            errors[.email] = "Enter a valid email address."
        }
        if password.count < 8 {
            errors[.password] = "Use at least 8 characters."
        }
        if mode == .register, displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors[.displayName] = "Tell us what to call you."
        }
        fieldErrors = errors
        return errors.isEmpty
    }

    // MARK: - Submission

    func submit() async {
        errorMessage = nil
        guard validate() else { return }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let session: AuthSession
            switch mode {
            case .signIn:
                session = try await authService.login(email: email, password: password)
            case .register:
                session = try await authService.register(
                    email: email, password: password, displayName: displayName
                )
            }
            password = ""   // never keep the plaintext around after use
            onSignedIn(session)
        } catch let error as ServiceError {
            errorMessage = Self.message(for: error, mode: mode)
        } catch {
            errorMessage = ServiceError.unknown(error.localizedDescription).userMessage
        }
    }

    /// Server messages are surfaced when they are actionable (duplicate email,
    /// weak password) and replaced with neutral copy when they are not.
    static func message(for error: ServiceError, mode: Mode) -> String {
        switch error {
        case .unauthorized where mode == .signIn:
            // Deliberately does not say whether the account exists.
            return "That email or password isn't right."
        case .server(let status, let message) where (400...409).contains(status):
            return message ?? error.userMessage
        default:
            return error.userMessage
        }
    }

    func switchMode(to mode: Mode) {
        self.mode = mode
        errorMessage = nil
        fieldErrors = [:]
    }
}
