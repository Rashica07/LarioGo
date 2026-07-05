//
//  ExploreView.swift
//  LarioGo
//
//  Created by user on 29.6.26.
//


//
//  ExploreView.swift
//  LarioGo
//

import SwiftUI

struct ExploreView: View {
    @State private var selectedCategory: SiteCategory? = nil
    let onSelectSite: (Site) -> Void

    private let sites = TourismData.sites
    private let featured = TourismData.featuredSites
    private let events = TourismData.events

    private var filteredSites: [Site] {
        guard let selectedCategory else { return sites }
        return sites.filter { $0.category == selectedCategory }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header

                section(title: "Featured", subtitle: "Must-see around the lake") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(featured) { site in
                                Button { onSelectSite(site) } label: { FeaturedCard(site: site) }
                                    .buttonStyle(.pressableScale(0.97))
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .scrollClipDisabled()
                }

                categoryFilter

                section(title: "Discover", subtitle: nil) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 16) {
                            ForEach(filteredSites) { site in
                                Button { onSelectSite(site) } label: { SiteRowCard(site: site) }
                                    .buttonStyle(.pressableScale(0.97))
                            }
                        }
                        .padding(.horizontal, 20)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedCategory)
                    }
                    .scrollClipDisabled()
                }

                section(title: "What's on", subtitle: "Events this season") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(events) { event in EventCard(event: event) }
                        }
                        .padding(.horizontal, 20)
                    }
                    .scrollClipDisabled()
                }
                .padding(.bottom, 24)
            }
            .padding(.top, 8)
        }
        .background(Theme.sand)
    }

    private var header: some View {
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
        .padding(.horizontal, 20)
    }

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                FilterChip(title: "All", symbol: "square.grid.2x2.fill", isSelected: selectedCategory == nil) {
                    Haptics.selection()
                    selectedCategory = nil
                }
                ForEach(SiteCategory.allCases) { category in
                    FilterChip(title: category.rawValue, symbol: category.symbol, isSelected: selectedCategory == category) {
                        Haptics.selection()
                        selectedCategory = selectedCategory == category ? nil : category
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .scrollClipDisabled()
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
}

/// Selectable category chip with spring + haptic feedback.
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
    }
}
