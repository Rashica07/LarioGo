//
//  PlaceDetailView.swift
//  LarioGo
//
//  Detail screen for LarioCore.Place. Follows the visual language already
//  established by SiteDetailView rather than introducing a second one.
//

import LarioCore
import MapKit
import SwiftUI

struct PlaceDetailView: View {
    @EnvironmentObject private var environment: AppEnvironment
    let place: Place
    @ObservedObject var favorites: FavoritesViewModel
    @ObservedObject var itineraries: ItineraryViewModel
    @State private var showingTripPicker = false
    @State private var addedConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                hero
                header
                if place.isSampleContent && environment.mustLabelSampleContent {
                    sampleNotice
                }
                facts
                if !place.about.isEmpty { about }
                if let schedule = place.schedule { scheduleSection(schedule) }
                if let dining = place.dining, !dining.cuisines.isEmpty { diningSection(dining) }
                addToTripButton
                mapSection
                contactSection
            }
            .padding(.bottom, 32)
        }
        .background(Theme.sand)
        .navigationTitle(place.name)
        .navigationBarTitleDisplayMode(.inline)
        .ignoresSafeArea(edges: .top)
    }

    // MARK: - Actions

    private var addToTripButton: some View {
        VStack(spacing: 8) {
            Button {
                Haptics.tap()
                if itineraries.trips.count <= 1 {
                    // One trip or none: add straight away rather than showing a
                    // picker with a single option.
                    let added = itineraries.add(place, to: itineraries.trips.first?.id, on: Date())
                    addedConfirmation = added
                } else {
                    showingTripPicker = true
                }
            } label: {
                Label(
                    itineraries.contains(place) ? "In your trip" : "Add to trip",
                    systemImage: itineraries.contains(place) ? "checkmark.circle.fill" : "plus.circle.fill"
                )
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(
                    itineraries.contains(place)
                        ? AnyShapeStyle(Theme.teal.opacity(0.85))
                        : AnyShapeStyle(Theme.lakeGradient),
                    in: .rect(cornerRadius: Theme.Radius.button)
                )
            }
            .buttonStyle(.pressableScale(0.97))

            if addedConfirmation {
                Text("Added to your trip.")
                    .font(.caption)
                    .foregroundStyle(Theme.teal)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 20)
        .animation(.easeInOut(duration: 0.2), value: addedConfirmation)
        .confirmationDialog("Add to which trip?", isPresented: $showingTripPicker, titleVisibility: .visible) {
            ForEach(itineraries.trips) { trip in
                Button(trip.name) {
                    addedConfirmation = itineraries.add(place, to: trip.id, on: Date())
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Sections

    private var hero: some View {
        SiteImage(
            imageName: place.primaryImageName ?? "",
            symbol: place.category.symbol
        )
        .frame(height: 280)
        .overlay {
            LinearGradient(
                colors: [.clear, .clear, .black.opacity(0.55)],
                startPoint: .top, endPoint: .bottom
            )
        }
        .overlay(alignment: .bottomTrailing) {
            FavoriteButton(model: favorites, place: place, size: 52)
                .padding(18)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(place.category.displayName, systemImage: place.category.symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.teal)

            Text(place.name)
                .font(.title.bold())
                .foregroundStyle(Theme.azure)

            if !place.tagline.isEmpty {
                Text(place.tagline)
                    .font(.subheadline)
                    .foregroundStyle(Color.inkSecondary)
            }
        }
        .padding(.horizontal, 20)
    }

    /// Shown whenever invented content could be mistaken for a real listing.
    private var sampleNotice: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "flask.fill").foregroundStyle(Theme.coral)
            Text("This is sample content for testing. It is not a real business or event, and its details are invented.")
                .font(.caption)
                .foregroundStyle(Color.inkSecondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.coral.opacity(0.10), in: .rect(cornerRadius: Theme.Radius.chip))
        .padding(.horizontal, 20)
    }

    private var facts: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                if let rating = place.ratingDisplay {
                    factChip("star.fill", rating, "\(place.reviewCount) reviews")
                } else {
                    // Never 0.0 — an absent rating is not a bad one.
                    factChip("sparkles", "New", "No reviews yet")
                }
                if let duration = place.visitDuration {
                    factChip("clock", duration, "Typical visit")
                }
                if let price = place.priceDisplay {
                    factChip("eurosign.circle", price, "Price")
                }
                factChip("mappin.circle.fill", place.region, "Region")
            }
            .padding(.horizontal, 20)
        }
        .scrollClipDisabled()
    }

    private func factChip(_ symbol: String, _ value: String, _ caption: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Label(value, systemImage: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.inkPrimary)
            Text(caption)
                .font(.caption2)
                .foregroundStyle(Color.inkSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.white, in: .rect(cornerRadius: Theme.Radius.chip))
        .shadow(color: Theme.azure.opacity(0.06), radius: 4, x: 0, y: 2)
    }

    private var about: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("About").font(.headline).foregroundStyle(Color.inkPrimary)
            Text(place.about)
                .font(.body)
                .foregroundStyle(Color.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 20)
    }

    private func scheduleSection(_ schedule: EventSchedule) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("When").font(.headline).foregroundStyle(Color.inkPrimary)
            Label(
                EventDateFormatter.relative(schedule.startDate),
                systemImage: "calendar"
            )
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.teal)
            Text(EventDateFormatter.full(schedule.startDate))
                .font(.caption)
                .foregroundStyle(Color.inkSecondary)
            if let organizer = schedule.organizer {
                Text("Organised by \(organizer)")
                    .font(.caption)
                    .foregroundStyle(Color.inkSecondary)
            }
        }
        .padding(.horizontal, 20)
    }

    private func diningSection(_ dining: DiningDetails) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Cuisine").font(.headline).foregroundStyle(Color.inkPrimary)
            Text(dining.cuisines.joined(separator: " · "))
                .font(.subheadline)
                .foregroundStyle(Color.inkSecondary)
            if dining.acceptsReservations {
                Label("Takes reservations", systemImage: "calendar.badge.plus")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.teal)
            }
        }
        .padding(.horizontal, 20)
    }

    private var mapSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Location").font(.headline).foregroundStyle(Color.inkPrimary)
            Map(initialPosition: .region(MKCoordinateRegion(
                center: place.coordinate.clCoordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))) {
                Marker(place.name, systemImage: place.category.symbol, coordinate: place.coordinate.clCoordinate)
                    .tint(Theme.teal)
            }
            .frame(height: 180)
            .clipShape(.rect(cornerRadius: Theme.Radius.card))
            .allowsHitTesting(false)

            if let address = place.address {
                Text(address).font(.caption).foregroundStyle(Color.inkSecondary)
            }
        }
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private var contactSection: some View {
        // Sample content deliberately carries no phone or website, so this
        // section simply does not appear rather than showing empty rows.
        if place.website != nil || place.phone != nil {
            VStack(alignment: .leading, spacing: 10) {
                Text("Contact").font(.headline).foregroundStyle(Color.inkPrimary)
                if let website = place.website {
                    Link(destination: website) {
                        Label(website.host() ?? "Website", systemImage: "safari")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.teal)
                }
                if let phone = place.phone,
                   let url = URL(string: "tel://\(phone.filter { !$0.isWhitespace })") {
                    Link(destination: url) {
                        Label(phone, systemImage: "phone.fill")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.teal)
                }
            }
            .padding(.horizontal, 20)
        }
    }
}
