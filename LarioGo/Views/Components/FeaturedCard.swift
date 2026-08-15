//
//  FeaturedCard.swift
//  LarioGo
//
//  Cards used across discovery surfaces.
//
//  SiteRowCard and EventCard lived here and were removed when Explore moved to
//  LarioCore.Place — they had no remaining call sites. They are in git history
//  if the Site-based versions are ever needed again.
//

import LarioCore
import SwiftUI

/// Large hero card used in the featured carousel.
struct FeaturedCard: View {
    let result: PlaceResult
    var showsSampleBadge = false

    private var place: Place { result.place }

    var body: some View {
        SiteImage(
            imageName: place.primaryImageName ?? "",
            symbol: place.category.symbol,
            cornerRadius: Theme.Radius.card
        )
        .frame(width: 300, height: 380)
        .overlay {
            LinearGradient(
                colors: [.clear, .clear, .black.opacity(0.75)],
                startPoint: .top, endPoint: .bottom
            )
        }
        .overlay(alignment: .topLeading) {
            Label(place.category.displayName, systemImage: place.category.symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(.ultraThinMaterial, in: .capsule)
                .padding(16)
        }
        .overlay(alignment: .bottomLeading) {
            VStack(alignment: .leading, spacing: 6) {
                Text(place.name)
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .lineLimit(2)

                if !place.tagline.isEmpty {
                    Text(place.tagline)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(2)
                }

                HStack(spacing: 12) {
                    if let rating = place.ratingDisplay {
                        Label(rating, systemImage: "star.fill")
                    } else {
                        Text("New")
                    }
                    if let duration = place.visitDuration {
                        Label(duration, systemImage: "clock")
                    }
                    if let distance = result.formattedDistance {
                        Label(distance, systemImage: "location.fill")
                    }
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.9))
                .padding(.top, 2)

                if showsSampleBadge && place.isSampleContent {
                    SampleContentBadge().padding(.top, 2)
                }
            }
            .padding(18)
            // Leaves room for the favourite button in the top-right corner.
            .padding(.trailing, 40)
        }
        .clipShape(.rect(cornerRadius: Theme.Radius.card))
        .shadow(color: Theme.azure.opacity(0.25), radius: 14, x: 0, y: 8)
        .accessibilityElement(children: .combine)
    }
}

/// Compact card for the horizontal discovery rails.
struct PlaceCardSmall: View {
    let result: PlaceResult
    var showsSampleBadge = false

    private var place: Place { result.place }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SiteImage(
                imageName: place.primaryImageName ?? "",
                symbol: place.category.symbol
            )
            .frame(width: 200, height: 130)
            .clipShape(.rect(cornerRadius: Theme.Radius.chip))

            VStack(alignment: .leading, spacing: 4) {
                Text(place.name)
                    .font(.headline)
                    .foregroundStyle(Color.inkPrimary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(place.category.displayName)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Theme.teal)
                    if let distance = result.formattedDistance {
                        Text("· \(distance)")
                            .font(.caption)
                            .foregroundStyle(Color.inkSecondary)
                    }
                }

                // Events lead with when, not what — that is the question the
                // user is actually asking on this rail.
                if let schedule = place.schedule {
                    Label(
                        EventDateFormatter.relative(schedule.startDate),
                        systemImage: "calendar"
                    )
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.coral)
                }

                if showsSampleBadge && place.isSampleContent {
                    SampleContentBadge()
                }
            }
            .padding(.top, 10)
            .padding(.horizontal, 4)
        }
        .frame(width: 200, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// Pill showing a legacy `Site` category with its glyph.
///
/// Still used by SiteDetailView, which has not moved to `Place` yet.
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
