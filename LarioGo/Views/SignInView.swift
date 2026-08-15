//
//  SignInView.swift
//  LarioGo
//

import LarioCore
import SwiftUI

struct SignInView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: AuthViewModel
    @FocusState private var focusedField: AuthViewModel.Field?

    init(authService: any AuthServing, onSignedIn: @escaping (AuthSession) -> Void) {
        _model = StateObject(wrappedValue: AuthViewModel(authService: authService, onSignedIn: onSignedIn))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header
                modePicker
                fields
                errorBanner
                submitButton
                guestNote
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
        }
        .background(Theme.sand)
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle().fill(Theme.lakeGradient).frame(width: 76, height: 76)
                Image(systemName: "mountain.2.fill")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)
            }
            Text(model.mode == .signIn ? "Welcome back" : "Join LarioGo")
                .font(.title2.bold())
                .foregroundStyle(Theme.azure)
            Text(model.mode == .signIn
                 ? "Sign in to sync your saved places and trips."
                 : "Create an account to keep your trips across devices.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.inkSecondary)
        }
        .padding(.bottom, 4)
    }

    private var modePicker: some View {
        Picker("Mode", selection: Binding(
            get: { model.mode },
            set: { model.switchMode(to: $0) }
        )) {
            ForEach(AuthViewModel.Mode.allCases, id: \.self) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private var fields: some View {
        VStack(spacing: 16) {
            if model.mode == .register {
                field(
                    title: "Name", text: $model.displayName, field: .displayName,
                    systemImage: "person.fill"
                )
                .textContentType(.name)
                .submitLabel(.next)
            }

            field(title: "Email", text: $model.email, field: .email, systemImage: "envelope.fill")
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.next)

            secureField
        }
    }

    private var secureField: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .foregroundStyle(Theme.teal)
                    .frame(width: 22)
                SecureField("Password", text: $model.password)
                    .focused($focusedField, equals: .password)
                    // `.newPassword` lets the system offer a strong password on
                    // registration; `.password` would offer autofill instead.
                    .textContentType(model.mode == .register ? .newPassword : .password)
                    .submitLabel(.go)
                    .onSubmit { Task { await model.submit() } }
            }
            .padding(14)
            .background(.white, in: .rect(cornerRadius: Theme.Radius.button))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.button)
                    .stroke(model.fieldErrors[.password] != nil ? Theme.coral : .clear, lineWidth: 1)
            )

            if let message = model.fieldErrors[.password] {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(Theme.coral)
            } else if model.mode == .register {
                Text("At least 8 characters.")
                    .font(.caption)
                    .foregroundStyle(Color.inkSecondary)
            }
        }
    }

    private func field(
        title: String,
        text: Binding<String>,
        field: AuthViewModel.Field,
        systemImage: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .foregroundStyle(Theme.teal)
                    .frame(width: 22)
                TextField(title, text: text)
                    .focused($focusedField, equals: field)
            }
            .padding(14)
            .background(.white, in: .rect(cornerRadius: Theme.Radius.button))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.button)
                    .stroke(model.fieldErrors[field] != nil ? Theme.coral : .clear, lineWidth: 1)
            )

            if let message = model.fieldErrors[field] {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(Theme.coral)
            }
        }
    }

    @ViewBuilder
    private var errorBanner: some View {
        if let message = model.errorMessage {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline)
                .foregroundStyle(Theme.coral)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Theme.coral.opacity(0.10), in: .rect(cornerRadius: Theme.Radius.button))
                .transition(.opacity.combined(with: .move(edge: .top)))
                .accessibilityAddTraits(.isStaticText)
        }
    }

    private var submitButton: some View {
        Button {
            focusedField = nil
            Task { await model.submit() }
        } label: {
            ZStack {
                // Kept in the layout while loading so the button does not
                // change height and shift everything below it.
                Text(model.mode.rawValue)
                    .opacity(model.isSubmitting ? 0 : 1)
                if model.isSubmitting {
                    ProgressView().tint(.white)
                }
            }
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                model.canSubmit ? AnyShapeStyle(Theme.lakeGradient) : AnyShapeStyle(Color.gray.opacity(0.4)),
                in: .rect(cornerRadius: Theme.Radius.button)
            )
        }
        .buttonStyle(.pressableScale(0.97))
        .disabled(!model.canSubmit)
        .animation(.easeInOut(duration: 0.2), value: model.isSubmitting)
    }

    private var guestNote: some View {
        VStack(spacing: 6) {
            Text("You don't need an account to explore.")
                .font(.footnote)
                .foregroundStyle(Color.inkSecondary)
            if environment.mustLabelSampleContent {
                Text("Running on sample data — any account here is local only.")
                    .font(.caption2)
                    .foregroundStyle(Theme.coral)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 4)
    }
}

#Preview {
    NavigationStack {
        SignInView(authService: MockAuthService(behaviour: .immediate)) { _ in }
            .environmentObject(AppEnvironment(configuration: .testing, sessionStore: InMemorySessionStore()))
    }
}
