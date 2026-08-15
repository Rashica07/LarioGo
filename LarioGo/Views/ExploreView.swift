//
//  ExploreView.swift
//  LarioGo
//

import LarioCore
import SwiftUI

struct ExploreView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @StateObject private var model: DiscoveryViewModel
    @ObservedObject var favorites: FavoritesViewModel
    @State private var showingARScanner = false
    let onSelect: (Place) -> Void

    init(
        placeService: any PlaceServing,
        locationProvider: LocationProviding,
        favorites: FavoritesViewModel,
        onSelect: @escaping (Place) -> Void
    ) {
        _model = StateObject(wrappedValue: DiscoveryViewModel(
            placeService: placeService, locationProvider: locationProvider
        ))
        self.favorites = favorites
        self.onSelect = onSelect
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                content
            }
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Theme.sand)
        .refreshable { await model.refresh() }
        .task {
            // Only loads on first appearance; returning to the tab keeps what
            // is already on screen rather than flashing a spinner.
            if model.feed == nil { model.load() }
        }
        .fullScreenCover(isPresented: $showingARScanner) {
            ARViewfinder()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .idle, .loading:
            loadingPlaceholder

        case .failed(let error):
            ErrorStateView(error: error) { model.retry() }
                .frame(maxWidth: .infinity)
                .padding(.top, 60)

        case .loaded(let feed):
            if feed.isEmpty {
                emptyState
            } else {
                feedSections(feed)
            }
        }
    }

    @ViewBuilder
    private func feedSections(_ feed: DiscoveryFeed) -> some View {
        // Order answers "what can I do right now?" before "what is famous?" —
        // nearby first when location is known, then curated, then planning.
        if !feed.nearby.isEmpty {
            carousel(title: "Near you", subtitle: "Closest first", results: feed.nearby)
        }
        if !feed.featured.isEmpty {
            heroCarousel(title: "Featured", subtitle: "Must-see around the lake", results: feed.featured)
        }
        if !feed.happeningSoon.isEmpty {
            carousel(title: "What's on", subtitle: "Happening this week", results: feed.happeningSoon)
        }
        if !feed.restaurants.isEmpty {
            carousel(title: "Where to eat", subtitle: nil, results: feed.restaurants)
        }
        if !feed.topRated.isEmpty {
            carousel(title: "Highly rated", subtitle: nil, results: feed.topRated)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Welcome to")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.teal)
                Text("Lecco & Lake Como")
                    .font(.largeTitle.bold())
                    .foregroundStyle(Theme.azure)
                Text("Your official guide to the Lario.")
                    .font(.body)
                    .foregroundStyle(Color.inkSecondary)
            }

            Spacer()

            Button {
                Haptics.tap()
                showingARScanner = true
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "arkit").font(.title2)
                    Text("AR Scan").font(.caption2.bold())
                }
                .foregroundStyle(.white)
                .frame(width: 62, height: 62)
                .background(Theme.lakeGradient, in: .circle)
                .shadow(color: Theme.teal.opacity(0.3), radius: 6, x: 0, y: 3)
            }
            .buttonStyle(.pressableScale(0.92))
            .accessibilityLabel("Scan a landmark with the camera")
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Sections

    private func heroCarousel(title: String, subtitle: String?, results: [PlaceResult]) -> some View {
        section(title: title, subtitle: subtitle) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(results) { result in
                        Button { onSelect(result.place) } label: {
                            FeaturedCard(
                                result: result,
                                showsSampleBadge: environment.mustLabelSampleContent
                            )
                        }
                        .buttonStyle(.pressableScale(0.97))
                        .overlay(alignment: .topTrailing) {
                            FavoriteButton(model: favorites, place: result.place, size: 40)
                                .padding(12)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            .scrollClipDisabled()
        }
    }

    private func carousel(title: String, subtitle: String?, results: [PlaceResult]) -> some View {
        section(title: title, subtitle: subtitle) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 16) {
                    ForEach(results) { result in
                        Button { onSelect(result.place) } label: {
                            PlaceCardSmall(
                                result: result,
                                showsSampleBadge: environment.mustLabelSampleContent
                            )
                        }
                        .buttonStyle(.pressableScale(0.97))
                    }
                }
                .padding(.horizontal, 20)
            }
            .scrollClipDisabled()
        }
    }

    @ViewBuilder
    private func section<Content: View>(
        title: String,
        subtitle: String?,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.title2.bold())
                    .foregroundStyle(Color.inkPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(Color.inkSecondary)
                }
            }
            .padding(.horizontal, 20)
            content()
        }
    }

    // MARK: - States

    /// Shaped like the real content rather than a bare spinner, so the layout
    /// does not jump when results arrive.
    private var loadingPlaceholder: some View {
        VStack(alignment: .leading, spacing: 28) {
            ForEach(0..<2, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 14) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.inkSecondary.opacity(0.12))
                        .frame(width: 160, height: 22)
                        .padding(.horizontal, 20)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(0..<3, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: Theme.Radius.chip)
                                    .fill(Color.inkSecondary.opacity(0.10))
                                    .frame(width: 200, height: 175)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .scrollClipDisabled()
                    .disabled(true)
                }
            }
        }
        .redacted(reason: .placeholder)
        .accessibilityLabel("Loading places")
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "binoculars")
                .font(.system(size: 46))
                .foregroundStyle(Theme.teal.opacity(0.45))
            Text("Nothing to show yet")
                .font(.headline)
                .foregroundStyle(Color.inkPrimary)
            Text("No content is available for this area right now.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.inkSecondary)
            Button("Reload") { model.retry() }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.teal)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 40)
        .padding(.top, 60)
    }
}

/// Selectable chip with spring and haptic feedback.
///
/// Used by Explore, Map, Search and Tickets. Lives here for now; it belongs in
/// Views/Components and is on the polish list.
struct FilterChip: View {
    let title: String
    let symbol: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? .white : Theme.azure)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background {
                    Capsule()
                        .fill(isSelected ? AnyShapeStyle(Theme.lakeGradient) : AnyShapeStyle(Color.white))
                }
                .overlay(
                    Capsule().stroke(Theme.azure.opacity(isSelected ? 0 : 0.15), lineWidth: 1)
                )
        }
        .buttonStyle(.pressableScale(0.92))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
