//
//  SearchViewModel.swift
//  LarioGo
//

import Foundation
import LarioCore
import SwiftUI

@MainActor
final class SearchViewModel: ObservableObject {

    @Published var text = "" {
        didSet { guard text != oldValue else { return }; scheduleSearch() }
    }
    @Published private(set) var state: LoadState<[PlaceResult]> = .idle
    @Published private(set) var isLoadingMore = false

    // Filters. Each change re-runs immediately — a tap is a deliberate act and
    // does not need the typing debounce.
    @Published var kinds: Set<PlaceKind> = [] { didSet { runNow() } }
    @Published var category: PlaceCategory? { didSet { runNow() } }
    @Published var minimumRating: Double? { didSet { runNow() } }
    @Published var maximumPrice: PriceLevel? { didSet { runNow() } }
    @Published var sort: PlaceSort = .relevance { didSet { runNow() } }
    @Published var maximumDistance: Double? { didSet { runNow() } }

    private let placeService: any PlaceServing
    private let locationProvider: LocationProviding
    private var searchTask: Task<Void, Never>?
    private var origin: Coordinate?
    private var page = 1
    private var total = 0

    /// Long enough to skip most intermediate keystrokes, short enough that the
    /// list still feels live. Below ~200 ms a fast typist fires a request per
    /// character; above ~500 ms it feels laggy.
    private let debounce: Duration = .milliseconds(300)
    private let perPage = 20

    init(placeService: any PlaceServing, locationProvider: LocationProviding) {
        self.placeService = placeService
        self.locationProvider = locationProvider
    }

    var results: [PlaceResult] { state.value ?? [] }
    var hasMore: Bool { results.count < total }

    var activeFilterCount: Int { currentQuery.activeFilterCount }

    /// Distinguishes "type something" from "nothing matched", which need
    /// different empty states.
    var hasNarrowedAnything: Bool { !currentQuery.isEmpty }

    private var currentQuery: PlaceQuery {
        PlaceQuery(
            text: text,
            kinds: kinds,
            categories: category.map { [$0] } ?? [],
            minimumRating: minimumRating,
            maximumPriceLevel: maximumPrice,
            origin: origin,
            maximumDistance: maximumDistance,
            sort: sort
        )
    }

    // MARK: - Running

    func onAppear() async {
        origin = await locationProvider.currentCoordinate()
        if case .idle = state { runNow() }
    }

    /// Cancels any in-flight or pending search, waits out the debounce, then runs.
    private func scheduleSearch() {
        searchTask?.cancel()
        searchTask = Task { [weak self] in
            guard let self else { return }
            // Cancellation during the sleep is the normal path while typing.
            try? await Task.sleep(for: debounce)
            guard !Task.isCancelled else { return }
            await self.execute(resetPage: true)
        }
    }

    private func runNow() {
        searchTask?.cancel()
        searchTask = Task { [weak self] in
            await self?.execute(resetPage: true)
        }
    }

    func retry() { runNow() }

    private func execute(resetPage: Bool) async {
        if resetPage { page = 1 }
        // Only show a spinner when there is nothing to look at; replacing
        // results with a spinner on every keystroke is worse than stale results.
        if results.isEmpty { state = .loading }

        do {
            let response = try await placeService.places(
                matching: currentQuery, page: page, per: perPage
            )
            guard !Task.isCancelled else { return }
            total = response.total
            state = .loaded(page == 1 ? response.results : results + response.results)
        } catch let error as ServiceError where error == .cancelled {
            return
        } catch let error as ServiceError {
            guard !Task.isCancelled else { return }
            state = .failed(error)
        } catch {
            guard !Task.isCancelled else { return }
            state = .failed(.unknown(error.localizedDescription))
        }
    }

    /// Infinite scroll. Guarded so a fast scroll cannot fire several pages at once.
    func loadMoreIfNeeded(currentItem: PlaceResult) async {
        guard hasMore, !isLoadingMore, !state.isLoading else { return }
        guard let index = results.firstIndex(where: { $0.id == currentItem.id }) else { return }
        // Start fetching a few rows early so the list does not visibly stall.
        guard index >= results.count - 4 else { return }

        isLoadingMore = true
        defer { isLoadingMore = false }
        page += 1
        await execute(resetPage: false)
    }

    func clearFilters() {
        kinds = []
        category = nil
        minimumRating = nil
        maximumPrice = nil
        maximumDistance = nil
        sort = .relevance
    }

    func clearAll() {
        text = ""
        clearFilters()
    }

    deinit { searchTask?.cancel() }
}
