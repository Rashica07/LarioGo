//
//  MapTabView.swift
//  LarioGo
//

import LarioCore
import MapKit
import SwiftUI

struct MapTabView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @StateObject private var model: MapViewModel
    let onSelect: (Place) -> Void

    init(
        placeService: any PlaceServing,
        locationProvider: LocationProviding,
        onSelect: @escaping (Place) -> Void
    ) {
        _model = StateObject(wrappedValue: MapViewModel(
            placeService: placeService, locationProvider: locationProvider
        ))
        self.onSelect = onSelect
    }

    var body: some View {
        Map(position: $model.cameraPosition, selection: $model.selectedPlaceID) {
            ForEach(model.results) { result in
                Annotation(
                    result.place.name,
                    coordinate: result.place.coordinate.clCoordinate,
                    anchor: .bottom
                ) {
                    MapPin(
                        symbol: result.place.category.symbol,
                        isSelected: result.id == model.selectedPlaceID
                    )
                    .onTapGesture {
                        Haptics.selection()
                        model.select(result)
                    }
                    .accessibilityLabel(result.place.name)
                    .accessibilityHint(result.place.category.displayName)
                }
                .tag(result.id)
            }
            UserAnnotation()
        }
        .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll))
        .ignoresSafeArea(edges: .top)
        .overlay(alignment: .top) { titleBar }
        .overlay(alignment: .bottomTrailing) { recentreButton }
        .overlay(alignment: .bottom) { bottomOverlay }
        .task { await model.onAppear() }
    }

    // MARK: - Chrome

    private var titleBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "map.fill").foregroundStyle(Theme.teal)
                Text("Explore the Map")
                    .font(.headline)
                    .foregroundStyle(Theme.azure)
                Spacer()
                Group {
                    if model.state.isLoading {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("\(model.results.count) places")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.inkSecondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))

            kindFilters
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var kindFilters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(title: "All", symbol: "square.grid.2x2.fill",
                           isSelected: model.selectedKinds.isEmpty) {
                    Haptics.selection()
                    model.selectedKinds = []
                }
                ForEach(PlaceKind.allCases, id: \.self) { kind in
                    FilterChip(title: kind.displayName, symbol: kind.symbol,
                               isSelected: model.selectedKinds.contains(kind)) {
                        Haptics.selection()
                        if model.selectedKinds.contains(kind) {
                            model.selectedKinds.remove(kind)
                        } else {
                            model.selectedKinds.insert(kind)
                        }
                    }
                }
            }
            .padding(.horizontal, 2)
        }
        .scrollClipDisabled()
    }

    private var recentreButton: some View {
        Button {
            Haptics.tap()
            model.recentre()
        } label: {
            Image(systemName: "location.fill")
                .font(.headline)
                .foregroundStyle(Theme.teal)
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial, in: .circle)
        }
        .buttonStyle(.pressableScale(0.9))
        .accessibilityLabel("Centre on my location")
        .padding(.trailing, 16)
        // Sits above the preview card when one is showing.
        .padding(.bottom, model.selectedResult == nil ? 24 : 130)
    }

    @ViewBuilder
    private var bottomOverlay: some View {
        if let selected = model.selectedResult {
            MapPreviewCard(
                result: selected,
                showsSampleBadge: environment.mustLabelSampleContent
            ) {
                onSelect(selected.place)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .id(selected.id)
        } else if case .failed(let error) = model.state {
            // Shown as a dismissible banner rather than replacing the map —
            // a cached map with an error notice beats a blank screen.
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Theme.coral)
                Text(error.userMessage)
                    .font(.caption)
                    .foregroundStyle(Color.inkPrimary)
                Spacer()
                if error.isRetryable {
                    Button("Retry") { model.retry() }
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.teal)
                }
            }
            .padding(12)
            .background(.ultraThinMaterial, in: .rect(cornerRadius: Theme.Radius.chip))
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        } else if case .loaded(let results) = model.state, results.isEmpty {
            HStack(spacing: 10) {
                Text("No places match these filters.")
                    .font(.caption)
                    .foregroundStyle(Color.inkPrimary)
                Spacer()
                if model.activeFilterCount > 0 {
                    Button("Clear") { model.clearFilters() }
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.teal)
                }
            }
            .padding(12)
            .background(.ultraThinMaterial, in: .rect(cornerRadius: Theme.Radius.chip))
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
    }
}

// MARK: - Pin

/// High-contrast custom map pin. Unchanged in appearance from the original —
/// only its input changed, from `Site` to a category symbol.
struct MapPin: View {
    let symbol: String
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(isSelected ? AnyShapeStyle(Theme.coral) : AnyShapeStyle(Theme.lakeGradient))
                    .frame(width: isSelected ? 46 : 38, height: isSelected ? 46 : 38)
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                Image(systemName: symbol)
                    .font(.system(size: isSelected ? 20 : 16, weight: .bold))
                    .foregroundStyle(.white)
            }
            .overlay(Circle().stroke(.white, lineWidth: 3))
            Triangle()
                .fill(isSelected ? Theme.coral : Theme.teal)
                .frame(width: 14, height: 9)
                .offset(y: -1)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.6), value: isSelected)
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}

/// Compact card surfaced when a pin is selected.
struct MapPreviewCard: View {
    let result: PlaceResult
    var showsSampleBadge = false
    let onOpen: () -> Void

    private var place: Place { result.place }

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 14) {
                SiteImage(
                    imageName: place.primaryImageName ?? "",
                    symbol: place.category.symbol
                )
                .frame(width: 70, height: 70)
                .clipShape(.rect(cornerRadius: 14))

                VStack(alignment: .leading, spacing: 4) {
                    Text(place.name)
                        .font(.headline)
                        .foregroundStyle(Color.inkPrimary)
                        .lineLimit(1)
                    if !place.tagline.isEmpty {
                        Text(place.tagline)
                            .font(.caption)
                            .foregroundStyle(Color.inkSecondary)
                            .lineLimit(2)
                    }
                    HStack(spacing: 10) {
                        if let rating = place.ratingDisplay {
                            Label(rating, systemImage: "star.fill")
                        } else {
                            Text("New")
                        }
                        if let distance = result.formattedDistance {
                            Label(distance, systemImage: "location.fill")
                        }
                    }
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Theme.teal)

                    if showsSampleBadge && place.isSampleContent {
                        SampleContentBadge()
                    }
                }

                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.teal)
            }
            .padding(12)
            .background(.white, in: .rect(cornerRadius: Theme.Radius.card))
            .shadow(color: .black.opacity(0.18), radius: 14, x: 0, y: 6)
        }
        .buttonStyle(.pressableScale(0.97))
        .accessibilityElement(children: .combine)
    }
}
