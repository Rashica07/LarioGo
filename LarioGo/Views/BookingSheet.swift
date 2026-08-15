//
//  BookingSheet.swift
//  LarioGo
//
//  Reservation flow: date, time, party size, confirmation.
//

import LarioCore
import SwiftUI

struct BookingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var environment: AppEnvironment
    @StateObject private var model: BookingFormViewModel

    init(place: Place, bookings: BookingViewModel) {
        _model = StateObject(wrappedValue: BookingFormViewModel(place: place, bookings: bookings))
    }

    var body: some View {
        NavigationStack {
            Group {
                if let booking = model.confirmed {
                    BookingConfirmationView(booking: booking) { dismiss() }
                } else {
                    form
                }
            }
            .background(Theme.sand)
            .navigationTitle(model.confirmed == nil ? "Reserve" : "Confirmed")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if model.confirmed == nil {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
            }
        }
    }

    private var form: some View {
        Form {
            Section {
                LabeledContent("Place", value: model.place.name)
                if environment.mustLabelSampleContent && model.place.isSampleContent {
                    // Nobody should think they hold a real table at an invented
                    // restaurant.
                    Label(
                        "Sample listing — this reservation is not real and no venue will be expecting you.",
                        systemImage: "flask.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(Theme.coral)
                }
            }

            Section("When") {
                DatePicker(
                    "Date and time",
                    selection: $model.date,
                    in: Date()...,
                    displayedComponents: [.date, .hourAndMinute]
                )
            }

            Section("Guests") {
                Picker("Party size", selection: $model.partySize) {
                    ForEach(model.partySizes, id: \.self) { size in
                        Text("\(size)").tag(size)
                    }
                }
                Text("For larger groups, contact the venue directly.")
                    .font(.caption)
                    .foregroundStyle(Color.inkSecondary)
            }

            Section("Anything to add?") {
                TextField("Optional note", text: $model.note, axis: .vertical)
                    .lineLimit(2...4)
            }

            Section {
                // Payment posture is stated up front rather than discovered at
                // the venue. No money moves through the app.
                Label("You'll pay at the venue. No payment is taken here.",
                      systemImage: "creditcard.trianglebadge.exclamationmark")
                    .font(.caption)
                    .foregroundStyle(Color.inkSecondary)
            }

            if let message = model.validationMessage ?? model.errorMessage {
                Section {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline)
                        .foregroundStyle(Theme.coral)
                }
            }

            Section {
                Button {
                    Task { await model.submit() }
                } label: {
                    HStack {
                        Spacer()
                        if model.isSubmitting {
                            ProgressView().tint(.white)
                        } else {
                            Text("Request reservation").font(.headline)
                        }
                        Spacer()
                    }
                    .foregroundStyle(.white)
                    .padding(.vertical, 6)
                }
                .listRowBackground(
                    model.canSubmit ? AnyShapeStyle(Theme.lakeGradient) : AnyShapeStyle(Color.gray.opacity(0.4))
                )
                .disabled(!model.canSubmit)
            }
        }
    }
}

// MARK: - Confirmation

struct BookingConfirmationView: View {
    let booking: Booking
    let onDone: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                ZStack {
                    Circle().fill(Theme.teal.opacity(0.15)).frame(width: 96, height: 96)
                    Image(systemName: "checkmark")
                        .font(.system(size: 42, weight: .bold))
                        .foregroundStyle(Theme.teal)
                }
                .padding(.top, 24)

                VStack(spacing: 6) {
                    Text("You're booked")
                        .font(.title2.bold())
                        .foregroundStyle(Theme.azure)
                    Text(booking.placeName)
                        .font(.headline)
                        .foregroundStyle(Color.inkPrimary)
                }

                VStack(spacing: 0) {
                    detailRow("Reference", booking.reference, mono: true)
                    Divider()
                    detailRow("When", EventDateFormatter.full(booking.startDate))
                    Divider()
                    detailRow("Guests", "\(booking.partySize)")
                    Divider()
                    detailRow("Status", booking.status.displayName)
                    Divider()
                    detailRow("Payment", booking.paymentStatus.displayName)
                    if let note = booking.note, !note.isEmpty {
                        Divider()
                        detailRow("Note", note)
                    }
                }
                .background(.white, in: .rect(cornerRadius: Theme.Radius.card))
                .shadow(color: Theme.azure.opacity(0.08), radius: 10, x: 0, y: 5)

                Text("Quote your reference at the venue. You can find this again under Profile → Bookings.")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.inkSecondary)

                Button(action: onDone) {
                    Text("Done")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Theme.lakeGradient, in: .rect(cornerRadius: Theme.Radius.button))
                }
                .buttonStyle(.pressableScale(0.97))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
    }

    private func detailRow(_ label: String, _ value: String, mono: Bool = false) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Color.inkSecondary)
            Spacer(minLength: 16)
            Text(value)
                .font(mono ? .subheadline.monospaced().weight(.bold) : .subheadline.weight(.semibold))
                .foregroundStyle(Color.inkPrimary)
                .multilineTextAlignment(.trailing)
        }
        .padding(14)
    }
}

// MARK: - History

struct BookingsView: View {
    @ObservedObject var model: BookingViewModel
    @State private var cancelling: Booking?

    var body: some View {
        Group {
            switch model.state {
            case .idle, .loading:
                ProgressView().controlSize(.large).tint(Theme.teal)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .failed(let error):
                ErrorStateView(error: error) { Task { await model.load() } }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .loaded:
                if model.bookings.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
        }
        .background(Theme.sand)
        .navigationTitle("Bookings")
        .task { await model.load() }
        .refreshable { await model.load() }
        .confirmationDialog(
            "Cancel this booking?",
            isPresented: Binding(get: { cancelling != nil }, set: { if !$0 { cancelling = nil } }),
            titleVisibility: .visible
        ) {
            Button("Cancel booking", role: .destructive) {
                if let booking = cancelling {
                    Task { try? await model.cancel(booking) }
                }
                cancelling = nil
            }
            Button("Keep it", role: .cancel) { cancelling = nil }
        }
    }

    private var list: some View {
        List {
            if !model.upcoming.isEmpty {
                Section("Upcoming") {
                    ForEach(model.upcoming) { booking in
                        BookingRow(booking: booking)
                            .swipeActions(edge: .trailing) {
                                if booking.isCancellable() {
                                    Button(role: .destructive) { cancelling = booking } label: {
                                        Label("Cancel", systemImage: "xmark.circle")
                                    }
                                }
                            }
                    }
                }
            }
            if !model.past.isEmpty {
                Section("Past") {
                    ForEach(model.past) { BookingRow(booking: $0) }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 44))
                .foregroundStyle(Theme.teal.opacity(0.45))
            Text("No bookings yet")
                .font(.headline)
                .foregroundStyle(Color.inkPrimary)
            Text("Reserve a table from any restaurant that takes bookings.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.inkSecondary)
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct BookingRow: View {
    let booking: Booking

    private var statusColour: Color {
        switch booking.status {
        case .confirmed: return Theme.teal
        case .pending: return Theme.azure
        case .cancelled, .declined: return Theme.coral
        case .completed: return Color.inkSecondary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(booking.placeName)
                    .font(.headline)
                    .foregroundStyle(Color.inkPrimary)
                Spacer()
                Text(booking.status.displayName)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(statusColour)
            }
            Text(EventDateFormatter.full(booking.startDate))
                .font(.caption)
                .foregroundStyle(Color.inkSecondary)
            HStack(spacing: 10) {
                Label("\(booking.partySize)", systemImage: "person.2.fill")
                Text(booking.reference).monospaced()
            }
            .font(.caption2)
            .foregroundStyle(Color.inkSecondary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}
