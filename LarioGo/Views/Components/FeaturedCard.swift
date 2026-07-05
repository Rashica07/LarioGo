//
//  FeaturedCard.swift
//  LarioGo
//
//  Created by user on 29.6.26.
//


//
//  Cards.swift
//  LarioGo
//

import SwiftUI

/// Large hero card used in the featured carousel.
struct FeaturedCard: View {
    let site: Site

    var body: some View {
        SiteImage(imageName: site.imageName, symbol: site.category.symbol, cornerRadius: Theme.Radius.card)
            .frame(width: 300, height: 380)
            .overlay {
                LinearGradient(
                    colors: [.clear, .clear, .black.opacity(0.75)],
                    startPoint: .top, endPoint: .bottom
                )
            }
            .overlay(alignment: .topLeading) { CategoryTag(category: site.category).padding(16) }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(site.name)
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    Text(site.tagline)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                    HStack(spacing: 12) {
                        Label(String(format: "%.1f", site.rating), systemImage: "star.fill")
                        Label(site.visitDuration, systemImage: "clock")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.top, 2)
                }
                .padding(18)
            }
            .clipShape(.rect(cornerRadius: Theme.Radius.card))
            .shadow(color: Theme.azure.opacity(0.25), radius: 14, x: 0, y: 8)
    }
}

/// Compact horizontal card for the "Discover more" rail.
struct SiteRowCard: View {
    let site: Site

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SiteImage(imageName: site.imageName, symbol: site.category.symbol)
                .frame(width: 200, height: 130)
                .clipShape(.rect(cornerRadius: Theme.Radius.chip))
            VStack(alignment: .leading, spacing: 4) {
                Text(site.name)
                    .font(.headline)
                    .foregroundStyle(Color.inkPrimary)
                    .lineLimit(1)
                Text(site.category.rawValue)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.teal)
            }
            .padding(.top, 10)
            .padding(.horizontal, 4)
        }
        .frame(width: 200, alignment: .leading)
    }
}

/// Calendar-style event card.
struct EventCard: View {
    let event: TourEvent

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 2) {
                Text(event.dayString).font(.title.bold())
                Text(event.monthString).font(.caption.weight(.bold))
            }
            .foregroundStyle(.white)
            .frame(width: 76)
            .frame(maxHeight: .infinity)
            .background(Theme.lakeGradient)

            VStack(alignment: .leading, spacing: 5) {
                Text(event.category.uppercased())
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Theme.teal)
                Text(event.title)
                    .font(.headline)
                    .foregroundStyle(Color.inkPrimary)
                    .lineLimit(2)
                Label(event.location, systemImage: "mappin.circle.fill")
                    .font(.caption)
                    .foregroundStyle(Color.inkSecondary)
            }
            .padding(14)
            Spacer(minLength: 0)
        }
        .frame(width: 290, height: 110)
        .background(.white)
        .clipShape(.rect(cornerRadius: Theme.Radius.card))
        .shadow(color: Theme.azure.opacity(0.12), radius: 8, x: 0, y: 4)
    }
}

/// Pill showing a site's category with its glyph.
struct CategoryTag: View {
    let category: SiteCategory

    var body: some View {
        Label(category.rawValue, systemImage: category.symbol)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(.ultraThinMaterial, in: .capsule)
    }
}
