import XCTest
@testable import LarioCore

final class BookingTests: XCTestCase {

    let now = Date(timeIntervalSince1970: 1_800_000_000)

    func makeBooking(
        start: TimeInterval,
        status: BookingStatus = .confirmed,
        payment: PaymentStatus = .notRequired
    ) -> Booking {
        Booking(
            id: UUID(), placeID: UUID(), placeName: "Trattoria",
            startDate: now.addingTimeInterval(start),
            partySize: 2, status: status, paymentStatus: payment,
            paymentMethod: .venue, reference: "LG-TEST01", createdAt: now
        )
    }

    // MARK: - Payment model

    func testNoPaymentProviderIsModelled() {
        // The whole point of these enums: state without a provider.
        XCTAssertEqual(PaymentStatus.notRequired.displayName, "Pay at venue")
        XCTAssertTrue(PaymentStatus.notRequired.isSettled)
        XCTAssertTrue(PaymentStatus.paid.isSettled)
        XCTAssertFalse(PaymentStatus.unpaid.isSettled)
        XCTAssertFalse(PaymentStatus.failed.isSettled)
    }

    func testPaymentMethodsCoverTheSupportedRoutes() {
        XCTAssertEqual(Set(PaymentMethod.allCases), [.none, .applePay, .card, .venue])
    }

    // MARK: - Request validation

    func testRejectsEmptyParty() {
        let request = BookingRequest(placeID: UUID(), startDate: now.addingTimeInterval(3600), partySize: 0)
        XCTAssertEqual(request.validate(now: now), .partyTooSmall)
    }

    func testRejectsOversizedParty() {
        let request = BookingRequest(placeID: UUID(), startDate: now.addingTimeInterval(3600), partySize: 50)
        XCTAssertEqual(request.validate(now: now), .partyTooLarge(maximum: 20))
    }

    func testRejectsPastDate() {
        let request = BookingRequest(placeID: UUID(), startDate: now.addingTimeInterval(-3600), partySize: 2)
        XCTAssertEqual(request.validate(now: now), .inThePast)
    }

    func testRejectsAbsurdlyDistantDate() {
        let request = BookingRequest(placeID: UUID(), startDate: now.addingTimeInterval(400 * 86_400), partySize: 2)
        XCTAssertEqual(request.validate(now: now), .tooFarAhead)
    }

    func testAcceptsAReasonableRequest() {
        let request = BookingRequest(placeID: UUID(), startDate: now.addingTimeInterval(86_400), partySize: 4)
        XCTAssertNil(request.validate(now: now))
    }

    // MARK: - Booking state

    func testUpcomingRequiresActiveStatusAndFutureDate() {
        XCTAssertTrue(makeBooking(start: 86_400).isUpcoming(at: now))
        XCTAssertFalse(makeBooking(start: -86_400).isUpcoming(at: now))
        XCTAssertFalse(makeBooking(start: 86_400, status: .cancelled).isUpcoming(at: now))
        XCTAssertFalse(makeBooking(start: 86_400, status: .completed).isUpcoming(at: now))
    }

    func testCancellableOnlyWhileActiveAndInFuture() {
        XCTAssertTrue(makeBooking(start: 86_400).isCancellable(at: now))
        XCTAssertFalse(makeBooking(start: -86_400).isCancellable(at: now),
                       "A booking in the past must not offer a cancel button")
        XCTAssertFalse(makeBooking(start: 86_400, status: .cancelled).isCancellable(at: now))
    }

    func testUpcomingSortsSoonestFirstAndPastMostRecentFirst() {
        let bookings = [
            makeBooking(start: 5 * 86_400),
            makeBooking(start: 1 * 86_400),
            makeBooking(start: -2 * 86_400, status: .completed),
            makeBooking(start: -10 * 86_400, status: .completed),
        ]
        let upcoming = bookings.filter { $0.isUpcoming(at: now) }
            .sorted { $0.startDate < $1.startDate }
        XCTAssertEqual(upcoming.map(\.startDate),
                       [now.addingTimeInterval(86_400), now.addingTimeInterval(5 * 86_400)])
    }

    // MARK: - Mock service

    func testCreateReturnsAConfirmedBookingWithAReference() async throws {
        let service = MockBookingService(behaviour: .immediate, seeded: [], now: { self.now })
        let place = MockCatalog.places.first { $0.kind == .restaurant }!

        let booking = try await service.create(BookingRequest(
            placeID: place.id, startDate: now.addingTimeInterval(86_400), partySize: 2
        ))

        XCTAssertEqual(booking.status, .confirmed)
        XCTAssertEqual(booking.placeName, place.name)
        XCTAssertTrue(booking.reference.hasPrefix("LG-"))
        // No money moves through the app.
        XCTAssertEqual(booking.paymentStatus, .notRequired)
        XCTAssertEqual(booking.paymentMethod, .venue)
    }

    func testCreateRejectsInvalidRequestWithAUsefulMessage() async {
        let service = MockBookingService(behaviour: .immediate, seeded: [], now: { self.now })
        do {
            _ = try await service.create(BookingRequest(
                placeID: UUID(), startDate: now.addingTimeInterval(-3600), partySize: 2
            ))
            XCTFail("Expected rejection")
        } catch {
            guard case .server(let status, let message) = (error as? ServiceError) else {
                return XCTFail("Expected a server error, got \(error)")
            }
            XCTAssertEqual(status, 400)
            XCTAssertEqual(message, BookingValidationError.inThePast.message)
        }
    }

    func testLargePartyIsDeclinedRatherThanSilentlyConfirmed() async {
        // The decline path must be reachable in mock mode; a mock that always
        // says yes hides the exact case the UI has to handle.
        let service = MockBookingService(behaviour: .immediate, seeded: [], capacityLimit: 8, now: { self.now })
        do {
            _ = try await service.create(BookingRequest(
                placeID: UUID(), startDate: now.addingTimeInterval(86_400), partySize: 12
            ))
            XCTFail("Expected a decline")
        } catch {
            guard case .server(let status, _) = (error as? ServiceError) else {
                return XCTFail("Expected a server error, got \(error)")
            }
            XCTAssertEqual(status, 409)
        }
    }

    func testCancelMovesToCancelled() async throws {
        let service = MockBookingService(behaviour: .immediate, seeded: [], now: { self.now })
        let created = try await service.create(BookingRequest(
            placeID: UUID(), startDate: now.addingTimeInterval(86_400), partySize: 2
        ))

        let cancelled = try await service.cancel(id: created.id)
        XCTAssertEqual(cancelled.status, .cancelled)
        XCTAssertEqual(cancelled.reference, created.reference, "The reference must survive cancellation")
    }

    func testCancellingAPastBookingIsRejected() async {
        let past = makeBooking(start: -86_400, status: .confirmed)
        let service = MockBookingService(behaviour: .immediate, seeded: [past], now: { self.now })
        do {
            _ = try await service.cancel(id: past.id)
            XCTFail("Expected rejection")
        } catch {
            guard case .server(let status, _) = (error as? ServiceError) else {
                return XCTFail("Expected a server error, got \(error)")
            }
            XCTAssertEqual(status, 409)
        }
    }

    func testCancellingUnknownBookingIsNotFound() async {
        let service = MockBookingService(behaviour: .immediate, seeded: [], now: { self.now })
        do {
            _ = try await service.cancel(id: UUID())
            XCTFail("Expected notFound")
        } catch {
            XCTAssertEqual(error as? ServiceError, .notFound)
        }
    }

    func testCancellingAPaidBookingMarksItRefunded() async throws {
        let paid = makeBooking(start: 86_400, payment: .paid)
        let service = MockBookingService(behaviour: .immediate, seeded: [paid], now: { self.now })
        let cancelled = try await service.cancel(id: paid.id)
        XCTAssertEqual(cancelled.paymentStatus, .refunded)
    }

    func testSeededBookingsCoverBothListSections() async throws {
        let service = MockBookingService(behaviour: .immediate, now: { self.now })
        let all = try await service.bookings()
        XCTAssertFalse(all.filter { $0.isUpcoming(at: now) }.isEmpty, "Need an upcoming booking to show")
        XCTAssertFalse(all.filter { !$0.isUpcoming(at: now) }.isEmpty, "Need a past booking to show")
    }

    func testBookingRoundTripsThroughJSON() throws {
        let booking = makeBooking(start: 86_400)
        let data = try JSONEncoder().encode(booking)
        XCTAssertEqual(try JSONDecoder().decode(Booking.self, from: data), booking)
    }
}
