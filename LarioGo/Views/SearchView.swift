//
//  SearchView.swift
//  LarioGo
//

import LarioCore
import SwiftUI

struct SearchView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @StateObject private var model: SearchViewModel
    @State private var showingFilters = false
    let onSelect: (Place) -> Void

    init(
        placeService: any PlaceServing,
        locationProvider: LocationProviding,
        onSelect: @escaping (Place) -> Void
    ) {
        _model = StateObject(wrappedValue: SearchViewModel(
            placeService: placeService, locationProvider: locationProvider
        ))
        self.onSelect = onSelect
    }

    var body: some View {
        VStack(spacing: 0) {
            searchField
            filterBar
            content
        }
        .background(Theme.sand)
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.onAppear() }
        .sheet(isPresented: $showingFilters) {
            SearchFiltersView(model: model)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Search field

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.inkSecondary)
            TextField("Places, food, events…", text: $model.text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
            if !model.text.isEmpty {
                Button {
                    Haptics.tap()
                    model.text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.inkSecondary)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(12)
        .background(.white, in: .rect(cornerRadius: Theme.Radius.button))
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Filters

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                Button {
                    Haptics.selection()
                    showingFilters = true
                } label: {
                    Label(
                        model.activeFilterCount > 0 ? "Filters (\(model.activeFilterCount))" : "Filters",
                        systemImage: "slider.horizontal.3"
                    )
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(model.activeFilterCount > 0 ? .white : Theme.azure)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background {
                        Capsule().fill(model.activeFilterCount > 0
                                       ? AnyShapeStyle(Theme.lakeGradient)
                                       : AnyShapeStyle(Color.white))
                    }
                }
                .buttonStyle(.pressableScale(0.94))

                ForEach(PlaceKind.allCases, id: \.self) { kind in
                    FilterChip(
                        title: kind.displayName,
                        symbol: kind.symbol,
                        isSelected: model.kinds.contains(kind)
                    ) {
                        Haptics.selection()
                        if model.kinds.contains(kind) {
                            model.kinds.remove(kind)
                        } else {
                            model.kinds.insert(kind)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .scrollClipDisabled()
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .idle, .loading:
            // A spinner rather than a skeleton: results change shape between
            // kinds, so a skeleton would guess wrong most of the time.
            Spacer()
            ProgressView().controlSize(.large).tint(Theme.teal)
            Spacer()

        case .failed(let error):
            Spacer()
            ErrorStateView(error: error) { model.retry() }
            Spacer()

        case .loaded(let results):
            if results.isEmpty {
                Spacer()
                emptyState
                Spacer()
            } else {
                resultsList(results)
            }
        }
    }

    private func resultsList(_ results: [PlaceResult]) -> some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(results) { result in
                    Button { onSelect(result.place) } label: {
                        PlaceRow(result: result, showsSampleBadge: environment.mustLabelSampleContent)
                    }
                    .buttonStyle(.pressableScale(0.98))
                    .task { await model.loadMoreIfNeeded(currentItem: result) }
                }

                if model.isLoadingMore {
                    ProgressView().tint(Theme.teal).padding(.vertical, 12)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: model.hasNarrowedAnything ? "magnifyingglass" : "sparkles")
                .font(.system(size: 44))
                .foregroundStyle(Theme.teal.opacity(0.5))
            Text(model.hasNarrowedAnything ? "No matches" : "Find something to do")
                .font(.headline)
                .foregroundStyle(Color.inkPrimary)
            Text(model.hasNarrowedAnything
                 ? "Try fewer filters or a different word."
                 : "Search for a place, a cuisine or an event.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.inkSecondary)

            // Only offered when there is actually something to clear.
            if model.activeFilterCount > 0 {
                Button("Clear filters") {
                    Haptics.tap()
                    model.clearFilters()
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.teal)
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 40)
    }
}

// MARK: - Row

struct PlaceRow: View {
    let result: PlaceResult
    var showsSampleBadge = false

    private var place: Place { result.place }

    var body: some View {
        HStack(spacing: 14) {
            SiteImage(
                imageName: place.primaryImageName ?? "",
                symbol: place.category.symbol
            )
            .frame(width: 84, height: 84)
            .clipShape(.rect(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 5) {
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
                        // Never render an unrated place as 0.0 — a zero reads
                        // as terrible rather than absent.
                        Text("New").foregroundStyle(Theme.teal)
                    }
                    if let distance = result.formattedDistance {
                        Label(distance, systemImage: "location.fill")
                    }
                    if let price = place.priceDisplay {
                        Text(price)
                    }
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.inkSecondary)

                if showsSampleBadge && place.isSampleContent {
                    SampleContentBadge()
                }
            }

            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(Color.inkSecondary.opacity(0.5))
        }
        .padding(12)
        .background(.white, in: .rect(cornerRadius: Theme.Radius.card))
        .shadow(color: Theme.azure.opacity(0.06), radius: 6, x: 0, y: 3)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Error state

struct ErrorStateView: View {
    let error: ServiceError
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: error == .offline ? "wifi.slash" : "exclamationmark.triangle.fill")
                .font(.system(size: 42))
                .foregroundStyle(Theme.coral.opacity(0.8))
            Text(error.userMessage)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.inkSecondary)

            // Retry is offered only when it could actually help.
            if error.isRetryable {
                Button {
                    Haptics.tap()
                    onRetry()
                } label: {
                    Text("Try again")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Theme.lakeGradient, in: .capsule)
                }
                .buttonStyle(.pressableScale(0.95))
            }
        }
        .padding(.horizontal, 40)
    }
}

// MARK: - Filters sheet

struct SearchFiltersView: View {
    @ObservedObject var model: SearchViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Sort by") {
                    Picker("Sort", selection: $model.sort) {
                        Text("Relevance").tag(PlaceSort.relevance)
                        Text("Distance").tag(PlaceSort.distance)
                        Text("Rating").tag(PlaceSort.rating)
                        Text("Price").tag(PlaceSort.priceLowToHigh)
                        Text("Name").tag(PlaceSort.name)
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section("Category") {
                    Picker("Category", selection: $model.category) {
                        Text("Any").tag(Optional<PlaceCategory>.none)
                        ForEach(PlaceCategory.allCases, id: \.self) { category in
                            Text(category.displayName).tag(Optional(category))
                        }
                    }
                }

                Section("Minimum rating") {
                    Picker("Rating", selection: $model.minimumRating) {
                        Text("Any").tag(Optional<Double>.none)
                        Text("3.5+").tag(Optional(3.5))
                        Text("4.0+").tag(Optional(4.0))
                        Text("4.5+").tag(Optional(4.5))
                    }
                    .pickerStyle(.segmented)
                }

                Section("Maximum price") {
                    Picker("Price", selection: $model.maximumPrice) {
                        Text("Any").tag(Optional<PriceLevel>.none)
                        ForEach(PriceLevel.allCases, id: \.self) { level in
                            Text(level.symbol).tag(Optional(level))
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Distance") {
                    Picker("Distance", selection: $model.maximumDistance) {
                        Text("Any").tag(Optional<Double>.none)
                        Text("1 km").tag(Optional(1000.0))
                        Text("5 km").tag(Optional(5000.0))
                        Text("20 km").tag(Optional(20000.0))
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Reset") { model.clearFilters() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
