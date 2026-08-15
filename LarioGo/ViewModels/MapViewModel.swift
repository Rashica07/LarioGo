//
//  MapViewModel.swift
//  LarioGo
//

import Foundation
import LarioCore
import MapKit
import SwiftUI

@MainActor
final class MapViewModel: ObservableObject {

    @Published private(set) var state: LoadState<[PlaceResult]> = .idle
    @Published var selectedKinds: Set<PlaceKind> = [] { didSet { reload() } }
    @Published var selectedCategory: PlaceCategory? { didSet { reload() } }
    @Published var selectedPlaceID: UUID?

    /// Camera is owned here so "search this area" and "recentre on me" can move
    /// it without the view holding duplicate state.
    @Published var cameraPosition: MapCameraPosition = .region(.lakeComo)

    private let placeService: any PlaceServing
    private let locationProvider: LocationProviding
    private var origin: Coordinate?
    private var loadTask: Task<Void, Never>?

    /// The map shows everything at once rather than paging — a partially
    /// populated map is misleading in a way a partial list is not. Capped well
    /// above the current catalogue so nothing silently disappears.
    private let mapResultLimit = 300

    init(placeService: any PlaceServing, locationProvider: LocationProviding) {
        self.placeService = placeService
        self.locationProvider = locationProvider
    }

    var results: [PlaceResult] { state.value ?? [] }

    var selectedResult: PlaceResult? {
        results.first { $0.id == selectedPlaceID }
    }

    var activeFilterCount: Int {
        (selectedKinds.isEmpty ? 0 : 1) + (selectedCategory == nil ? 0 : 1)
    }

    func onAppear() async {
        origin = await locationProvider.currentCoordinate()
        if case .idle = state { reload() }
    }

    func reload() {
        loadTask?.cancel()
        loadTask = Task { [weak self] in await self?.load() }
    }

    private func load() async {
        if results.isEmpty { state = .loading }

        var query = PlaceQuery(
            kinds: selectedKinds,
            categories: selectedCategory.map { [$0] } ?? [],
            origin: origin,
            sort: origin == nil ? .rating : .distance
        )
        query.text = ""

        do {
            let page = try await placeService.places(matching: query, page: 1, per: mapResultLimit)
            guard !Task.isCancelled else { return }
            state = .loaded(page.results)

            // A selected pin that is filtered out must not stay selected, or the
            // preview card shows a place no longer on the map.
            if let id = selectedPlaceID, !page.results.contains(where: { $0.id == id }) {
                selectedPlaceID = nil
            }
        } catch let error as ServiceError where error == .cancelled {
            return
        } catch let error as ServiceError {
            guard !Task.isCancelled else { return }
            if results.isEmpty { state = .failed(error) }
        } catch {
            guard !Task.isCancelled else { return }
            if results.isEmpty { state = .failed(.unknown(error.localizedDescription)) }
        }
    }

    func retry() { reload() }

    func clearFilters() {
        selectedKinds = []
        selectedCategory = nil
    }

    /// Frames the user's location, or the region if it is unknown.
    func recentre() {
        withAnimation(.easeInOut(duration: 0.4)) {
            if let origin {
                cameraPosition = .region(MKCoordinateRegion(
                    center: origin.clCoordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
                ))
            } else {
                cameraPosition = .region(.lakeComo)
            }
        }
    }

    func select(_ result: PlaceResult) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            selectedPlaceID = result.id
        }
    }

    func deselect() {
        withAnimation(.easeOut(duration: 0.2)) { selectedPlaceID = nil }
    }

    deinit { loadTask?.cancel() }
}
