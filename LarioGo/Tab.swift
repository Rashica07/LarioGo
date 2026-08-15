//
//  Tab.swift
//  LarioGo
//

import LarioCore
import SwiftUI

enum Tab: Hashable {
    case explore, map, search, saved, profile
}

struct ContentView: View {
    @EnvironmentObject private var environment: AppEnvironment

    @State private var selectedTab: Tab = .explore
    @State private var explorePath = NavigationPath()
    @State private var mapPath = NavigationPath()
    @State private var searchPath = NavigationPath()
    @State private var savedPath = NavigationPath()

    /// Owned here rather than per-tab so the heart state stays consistent
    /// everywhere a place appears — Explore, Search, Saved and Detail.
    @StateObject private var favorites: FavoritesViewModel
    /// Shared for the same reason as favourites: "in your trip" must read the
    /// same on every screen.
    @StateObject private var itineraries: ItineraryViewModel

    init(favorites: FavoritesViewModel, itineraries: ItineraryViewModel) {
        _favorites = StateObject(wrappedValue: favorites)
        _itineraries = StateObject(wrappedValue: itineraries)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack(path: $explorePath) {
                ExploreView(
                    placeService: environment.placeService,
                    locationProvider: FixedLocationProvider.lecco,
                    favorites: favorites
                ) { place in
                    explorePath.append(place)
                }
                .withPlaceDestinations(favorites: favorites, itineraries: itineraries)
            }
            .tabItem { Label("Explore", systemImage: "sparkles") }
            .tag(Tab.explore)

            NavigationStack(path: $mapPath) {
                MapTabView(
                    placeService: environment.placeService,
                    locationProvider: FixedLocationProvider.lecco
                ) { place in
                    mapPath.append(place)
                }
                .withPlaceDestinations(favorites: favorites, itineraries: itineraries)
            }
            .tabItem { Label("Map", systemImage: "map.fill") }
            .tag(Tab.map)

            NavigationStack(path: $searchPath) {
                SearchView(
                    placeService: environment.placeService,
                    locationProvider: FixedLocationProvider.lecco
                ) { place in
                    searchPath.append(place)
                }
                .withPlaceDestinations(favorites: favorites, itineraries: itineraries)
            }
            .tabItem { Label("Search", systemImage: "magnifyingglass") }
            .tag(Tab.search)

            NavigationStack(path: $savedPath) {
                FavoritesView(model: favorites) { place in savedPath.append(place) }
                    .withPlaceDestinations(favorites: favorites, itineraries: itineraries)
            }
            .tabItem { Label("Saved", systemImage: "heart.fill") }
            // A count here would be noise; the heart is enough of a signal.
            .tag(Tab.saved)

            NavigationStack {
                ProfileView(itineraries: itineraries)
            }
            .tabItem { Label("Profile", systemImage: "person.fill") }
            .tag(Tab.profile)
        }
        .tint(Theme.teal)
        .onChange(of: selectedTab) { _, _ in Haptics.selection() }
    }
}

private extension View {
    /// Both destination types are registered on every stack.
    ///
    /// The existing Explore and Map screens still push `Site`, while Search and
    /// Saved push `LarioCore.Place`. Registering both lets the new tabs ship
    /// without rewriting the existing screens first — they migrate to `Place`
    /// when their view models land, and this modifier is the only thing that
    /// then needs changing.
    func withPlaceDestinations(
        favorites: FavoritesViewModel,
        itineraries: ItineraryViewModel
    ) -> some View {
        self
            .navigationDestination(for: Site.self) { SiteDetailView(site: $0) }
            .navigationDestination(for: Place.self) { place in
                PlaceDetailView(place: place, favorites: favorites, itineraries: itineraries)
            }
    }
}
