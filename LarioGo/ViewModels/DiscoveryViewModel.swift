//
//  DiscoveryViewModel.swift
//  LarioGo
//

import Foundation
import LarioCore
import SwiftUI

/// Every async screen is in exactly one of these states.
///
/// Modelled as an enum rather than parallel `isLoading` / `error` / `items`
/// properties, because those permit nonsense combinations — loading *and*
/// errored, or empty with no explanation — which is how "spinner forever"
/// screens happen.
enum LoadState<Value> {
    case idle
    case loading
    case loaded(Value)
    case failed(ServiceError)

    var value: Value? {
        if case .loaded(let value) = self { return value }
        return nil
    }

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    var error: ServiceError? {
        if case .failed(let error) = self { return error }
        return nil
    }
}

/// Backs the Explore tab.
@MainActor
final class DiscoveryViewModel: ObservableObject {

    @Published private(set) var state: LoadState<DiscoveryFeed> = .idle
    @Published var selectedCategory: PlaceCategory?

    private let placeService: any PlaceServing
    private let locationProvider: LocationProviding
    /// Tracked so a rapid re-entry cancels the previous load instead of racing it.
    private var loadTask: Task<Void, Never>?

    init(placeService: any PlaceServing, locationProvider: LocationProviding) {
        self.placeService = placeService
        self.locationProvider = locationProvider
    }

    var feed: DiscoveryFeed? { state.value }

    /// True only once loading has finished and genuinely produced nothing —
    /// so the empty state never flashes while the first request is in flight.
    var isEmpty: Bool {
        guard case .loaded(let feed) = state else { return false }
        return feed.isEmpty
    }

    func load() {
        loadTask?.cancel()
        loadTask = Task { [weak self] in
            await self?.performLoad()
        }
    }

    /// Pull to refresh. Keeps the current content on screen rather than
    /// dropping back to a spinner over a blank page.
    func refresh() async {
        await performLoad(showsSpinner: state.value == nil)
    }

    private func performLoad(showsSpinner: Bool = true) async {
        if showsSpinner { state = .loading }

        let origin = await locationProvider.currentCoordinate()
        do {
            let feed = try await placeService.discoveryFeed(near: origin)
            guard !Task.isCancelled else { return }
            state = .loaded(feed)
        } catch is CancellationError {
            // A cancelled load was superseded; leave the state alone.
        } catch let error as ServiceError where error == .cancelled {
            return
        } catch let error as ServiceError {
            guard !Task.isCancelled else { return }
            // A failed refresh must not wipe content the user is already
            // reading — keep it and surface the error separately.
            if state.value == nil { state = .failed(error) }
        } catch {
            guard !Task.isCancelled else { return }
            if state.value == nil { state = .failed(.unknown(error.localizedDescription)) }
        }
    }

    func retry() { load() }

    deinit { loadTask?.cancel() }
}

// MARK: - Location

/// Location access, behind a protocol so view models can be tested without
/// CoreLocation and previews do not trigger a permission prompt.
protocol LocationProviding: Sendable {
    func currentCoordinate() async -> Coordinate?
}

/// Always returns a fixed point. Used in previews and tests.
struct FixedLocationProvider: LocationProviding {
    let coordinate: Coordinate?

    /// Piazza San Nicolò, Lecco — the centre of the MVP area.
    static let lecco = FixedLocationProvider(
        coordinate: Coordinate(latitude: 45.8566, longitude: 9.3931)
    )
    static let unavailable = FixedLocationProvider(coordinate: nil)

    func currentCoordinate() async -> Coordinate? { coordinate }
}
