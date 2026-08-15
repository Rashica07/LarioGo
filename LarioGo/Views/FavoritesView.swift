//
//  FavoritesView.swift
//  LarioGo
//

import LarioCore
import SwiftUI

struct FavoritesView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @ObservedObject var model: FavoritesViewModel
    let onSelect: (Place) -> Void

    var body: some View {
        Group {
            switch model.state {
            case .idle, .loading:
                ProgressView().controlSize(.large).tint(Theme.teal)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .failed(let error):
                // Saved identifiers are on disk regardless; only the display
                // data failed, so say that rather than implying they are lost.
                VStack(spacing: 16) {
                    ErrorStateView(error: error) { Task { await model.load() } }
                    if model.count > 0 {
                        Text("\(model.count) saved place\(model.count == 1 ? "" : "s") are still stored on this device.")
                            .font(.caption)
                            .foregroundStyle(Color.inkSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .loaded(let places):
                if places.isEmpty {
                    emptyState
                } else {
                    list(places)
                }
            }
        }
        .background(Theme.sand)
        .navigationTitle("Saved")
        .task { await model.load() }
        .refreshable { await model.load() }
    }

    private func list(_ places: [Place]) -> some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(places) { place in
                    Button { onSelect(place) } label: {
                        PlaceRow(
                            result: PlaceResult(place: place, distance: nil),
                            showsSampleBadge: environment.mustLabelSampleContent
                        )
                    }
                    .buttonStyle(.pressableScale(0.98))
                    .contextMenu {
                        Button(role: .destructive) {
                            Haptics.tap()
                            Task { await model.remove(place) }
                        } label: {
                            Label("Remove", systemImage: "heart.slash")
                        }
                    }
                    // Swipe is the expected gesture on a saved list; the context
                    // menu is the discoverable backup.
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            Task { await model.remove(place) }
                        } label: {
                            Label("Remove", systemImage: "heart.slash")
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "heart")
                .font(.system(size: 46))
                .foregroundStyle(Theme.teal.opacity(0.45))
            Text("Nothing saved yet")
                .font(.headline)
                .foregroundStyle(Color.inkPrimary)
            Text("Tap the heart on any place to keep it here — it stays available offline.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.inkSecondary)
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Heart button used on cards and detail views.
struct FavoriteButton: View {
    @ObservedObject var model: FavoritesViewModel
    let place: Place
    var size: CGFloat = 44

    private var isFavorite: Bool { model.isFavorite(place.id) }

    var body: some View {
        Button {
            Haptics.tap()
            Task { await model.toggle(place) }
        } label: {
            Image(systemName: isFavorite ? "heart.fill" : "heart")
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(isFavorite ? Theme.coral : .white)
                .frame(width: size, height: size)
                .background(.ultraThinMaterial, in: .circle)
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.pressableScale(0.88))
        .accessibilityLabel(isFavorite ? "Remove from saved" : "Save this place")
        .accessibilityAddTraits(isFavorite ? [.isSelected] : [])
    }
}
