//
//  BookingViewModel.swift
//  LarioGo
//

import Foundation
import LarioCore
import SwiftUI

@MainActor
final class BookingViewModel: ObservableObject {

    @Published private(set) var bookings: [Booking] = []
    @Published private(set) var state: LoadState<[Booking]> = .idle

    private let service: any BookingServing

    init(service: any BookingServing) {
        self.service = service
    }

    var upcoming: [Booking] { bookings.upcoming }
    var past: [Booking] { bookings.past }

    func load() async {
        if bookings.isEmpty { state = .loading }
        do {
            let all = try await service.bookings()
            bookings = all
            state = .loaded(all)
        } catch let error as ServiceError {
            // A failed refresh keeps whatever is already listed.
            if bookings.isEmpty { state = .failed(error) }
        } catch {
            if bookings.isEmpty { state = .failed(.unknown(error.localizedDescription)) }
        }
    }

    @discardableResult
    func create(_ request: BookingRequest) async throws -> Booking {
        let booking = try await service.create(request)
        bookings.append(booking)
        state = .loaded(bookings)
        return booking
    }

    func cancel(_ booking: Booking) async throws {
        let updated = try await service.cancel(id: booking.id)
        if let index = bookings.firstIndex(where: { $0.id == updated.id }) {
            bookings[index] = updated
        }
        state = .loaded(bookings)
    }
}

/// Drives the booking form for one place.
@MainActor
final class BookingFormViewModel: ObservableObject {

    @Published var date: Date
    @Published var partySize = 2
    @Published var note = ""
    @Published private(set) var isSubmitting = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var confirmed: Booking?

    let place: Place
    private let bookings: BookingViewModel

    /// Party sizes offered in the picker. Above this the user is pointed at the
    /// venue directly rather than being allowed to submit something that will
    /// almost certainly be declined.
    let partySizes = Array(1...12)

    init(place: Place, bookings: BookingViewModel, now: Date = Date()) {
        self.place = place
        self.bookings = bookings
        // Default to the next round hour at least an hour out, rather than
        // "now", which is never a valid reservation time.
        let calendar = Calendar.current
        let oneHourOut = now.addingTimeInterval(3600)
        var components = calendar.dateComponents([.year, .month, .day, .hour], from: oneHourOut)
        components.minute = 0
        self.date = calendar.date(from: components) ?? oneHourOut
    }

    var validationMessage: String? {
        BookingRequest(placeID: place.id, startDate: date, partySize: partySize)
            .validate()?.message
    }

    var canSubmit: Bool { !isSubmitting && validationMessage == nil }

    func submit() async {
        errorMessage = nil
        let request = BookingRequest(
            placeID: place.id,
            startDate: date,
            partySize: partySize,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? nil
                : note.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        if let message = request.validate()?.message {
            errorMessage = message
            return
        }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            confirmed = try await bookings.create(request)
            Haptics.success()
        } catch let error as ServiceError {
            // A decline carries an actionable message from the venue; anything
            // else gets the neutral user-facing copy.
            if case .server(_, let message) = error, let message {
                errorMessage = message
            } else {
                errorMessage = error.userMessage
            }
        } catch {
            errorMessage = ServiceError.unknown(error.localizedDescription).userMessage
        }
    }
}
